/**
 * e2e_verify.js — Uçtan uca anket akışı doğrulaması (CANLI Firestore + CANLI kurallar)
 *
 * "Panelden anket oluştur + Yayınla (active) → mobilde görünmeli ve cevaplanabilmeli"
 * akışının her adımını, GERÇEK kullanıcı token'larıyla, deploy edilmiş güvenlik
 * kuralları altında test eder (Admin SDK KULLANMAZ — Admin SDK kuralları baypas
 * ederdi; buradaki amaç kuralları gerçekten sınamak).
 *
 *   PANEL  (admin@pom.app idToken, is_admin claim'li):
 *     A1) accounts:signInWithPassword → idToken (custom claim'ler token'da)
 *     A2) surveys koleksiyonuna status='active', companyId='__admin__' anket OLUŞTUR
 *
 *   MOBİL  (anonim idToken — uygulamanın signInAnonymously() ile aldığı token):
 *     B1) accounts:signUp (anonim) → idToken + uid
 *     B2) surveys WHERE companyId IN ['garanti_bbva','__admin__']  → yeni anket görünmeli
 *     B3) survey_responses'e cevap dokümanı EKLE (submitResponse 1. adım)
 *     B4) surveys/{id}.responseCount +1 (submitResponse best-effort 2. adım)
 *     B5) users/{uid}.answeredSurveyIds += surveyId (submitResponse 3. adım —
 *          "zaten cevaplandı" işareti kullanıcının KENDİ dokümanına yazılır)
 *     B6) users/{uid} OKU → answeredSurveyIds surveyId içermeli  → KRİTİK
 *          (watchAnsweredSurveyIds — "zaten cevaplandı/Tamamlanan" filtresi)
 *     B7) BAŞKA anonim kullanıcı survey_responses'i şirketler-arası OKUYAMAMALI
 *          → KRİTİK GÜVENLİK: eski açığın kapandığının kanıtı (permission-denied)
 *
 *   PANEL RESULTS (admin idToken):
 *     C1) survey_responses WHERE surveyId == <yeni> → admin yanıtı okuyabilmeli
 *
 *   TEMİZLİK (admin idToken): oluşturulan response + survey dokümanlarını sil.
 *
 * Çalıştırma:  node e2e_verify.js
 */
'use strict';

const https = require('https');
const crypto = require('crypto');
const path = require('path');
const admin = require('firebase-admin');

const API_KEY = 'AIzaSyBNj_7VEcXJ4AzS6i1q2ysupHP4FayEqiU';
const PROJECT = 'pomapp-c3ccc';
const ADMIN_UID = 'MCZ5LPZYgNbASe4DNAGVGqYM6iM2'; // admin@pom.app — claims {is_admin:true}
const COMPANY = 'garanti_bbva'; // debug_pro persona'nın companyId'si (mobil whereIn)
const SURVEY_COMPANY = '__admin__'; // tüm kullanıcılara görünür

const DOC_BASE = `/v1/projects/${PROJECT}/databases/(default)/documents`;

function req(method, host, path, headers, body) {
  const b = body == null ? '' : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const r = https.request(
      { host, path, method, headers: { ...headers, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(b) } },
      (res) => {
        let d = '';
        res.on('data', (c) => (d += c));
        res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch (_) { resolve({ status: res.statusCode, body: d }); } });
      },
    );
    r.on('error', reject);
    if (b) r.write(b);
    r.end();
  });
}

const fsReq = (method, path, token, body) =>
  req(method, 'firestore.googleapis.com', path, token ? { Authorization: `Bearer ${token}` } : {}, body);

function decodeJwt(idToken) {
  try {
    const p = idToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(p, 'base64').toString('utf8'));
  } catch (_) { return {}; }
}

function surveyQuery(token) {
  return fsReq('POST', `${DOC_BASE}:runQuery`, token, {
    structuredQuery: {
      from: [{ collectionId: 'surveys' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'companyId' },
          op: 'IN',
          value: { arrayValue: { values: [{ stringValue: COMPANY }, { stringValue: SURVEY_COMPANY }] } },
        },
      },
    },
  });
}

function responsesBySurveyQuery(token, surveyId) {
  return fsReq('POST', `${DOC_BASE}:runQuery`, token, {
    structuredQuery: {
      from: [{ collectionId: 'survey_responses' }],
      where: { fieldFilter: { field: { fieldPath: 'surveyId' }, op: 'EQUAL', value: { stringValue: surveyId } } },
    },
  });
}

// Gerçek admin hesabının (is_admin:true) idToken'ını parola olmadan üretir:
// SA ile custom token → Identity Toolkit signInWithCustomToken → idToken.
// Sonuç token hesapta KAYITLI custom claim'leri (is_admin) taşır → admin portal
// oturumuyla Firestore kuralları açısından özdeş; parola sıfırlama yan etkisi yok.
async function adminIdToken() {
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(require(path.join(__dirname, 'sa_key.json'))) });
  }
  const customToken = await admin.auth().createCustomToken(ADMIN_UID);
  const ex = await req('POST', 'identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithCustomToken?key=${API_KEY}`, {}, { token: customToken, returnSecureToken: true });
  if (ex.status !== 200 || !ex.body.idToken) {
    throw new Error(`custom token exchange ${ex.status}: ${JSON.stringify(ex.body).slice(0, 160)}`);
  }
  return ex.body.idToken;
}

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok });
  console.log(`   ${ok ? '✅' : '❌'} ${name}${detail ? ' — ' + detail : ''}`);
}

async function main() {
  const now = new Date().toISOString();
  const tag = `[E2E ${now}]`;
  let surveyId = null;
  let responseName = null; // full doc path for cleanup
  let anonUid = null;      // mobile (anon) uid — for users-doc cleanup
  let adminToken = null;

  console.log(`\n🔁 PoM uçtan uca anket doğrulaması — proje ${PROJECT}\n`);

  try {
    // ─── PANEL: admin girişi + anket oluştur + yayınla ──────────────────────
    console.log('PANEL (admin@pom.app, is_admin):');
    try {
      adminToken = await adminIdToken();
    } catch (e) {
      check('Admin oturumu (is_admin idToken)', false, e.message);
      throw new Error('Admin oturumu alınamadı — sonraki adımlar atlanıyor.');
    }
    const claims = decodeJwt(adminToken);
    check('Admin oturumu (is_admin idToken)', !!adminToken, `uid=${claims.user_id || ADMIN_UID}`);
    check('Token is_admin claim taşıyor', claims.is_admin === true, `is_admin=${claims.is_admin}`);

    const surveyDoc = {
      fields: {
        companyId: { stringValue: SURVEY_COMPANY },
        title: { stringValue: `${tag} Doğrulama Anketi` },
        description: { stringValue: 'Otomatik uçtan uca doğrulama anketi — çalışma sonunda silinir.' },
        emoji: { stringValue: '🧪' },
        status: { stringValue: 'active' },
        isGate: { booleanValue: false },
        isMandatory: { booleanValue: false },
        minNThreshold: { integerValue: '1' },
        responseCount: { integerValue: '0' },
        questions: { arrayValue: { values: [
          { mapValue: { fields: {
            id: { stringValue: 'q1' }, text: { stringValue: 'Bugün kendini nasıl hissediyorsun?' },
            type: { stringValue: 'emoji5' }, category: { stringValue: 'Genel' },
            hint: { stringValue: '' }, reverseScore: { booleanValue: false }, isEnps: { booleanValue: false },
          } } },
          { mapValue: { fields: {
            id: { stringValue: 'q2' }, text: { stringValue: 'Bu şirketi tavsiye eder misin?' },
            type: { stringValue: 'yesno' }, category: { stringValue: 'Genel' },
            hint: { stringValue: '' }, reverseScore: { booleanValue: false }, isEnps: { booleanValue: false },
          } } },
        ] } },
        created_at: { timestampValue: now },
        updated_at: { timestampValue: now },
      },
    };
    const created = await fsReq('POST', `${DOC_BASE}/surveys`, adminToken, surveyDoc);
    if (created.status === 200 && created.body.name) {
      surveyId = created.body.name.split('/').pop();
      check('Anket oluştur + Yayınla (status=active)', true, `surveyId=${surveyId}`);
    } else {
      check('Anket oluştur + Yayınla (status=active)', false, `status ${created.status}: ${JSON.stringify(created.body).slice(0, 200)}`);
      throw new Error('Anket oluşturulamadı — sonraki adımlar atlanıyor.');
    }

    // ─── MOBİL: anonim oturum + görünürlük + cevaplama ──────────────────────
    console.log('\nMOBİL (anonim Firebase oturumu):');
    const anon = await req('POST', 'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${API_KEY}`, {}, { returnSecureToken: true });
    if (anon.status !== 200 || !anon.body.idToken) {
      check('Anonim giriş (signInAnonymously)', false, `status ${anon.status}`);
      throw new Error('Anonim giriş başarısız.');
    }
    const anonToken = anon.body.idToken;
    anonUid = anon.body.localId;
    const userIdHash = crypto.createHash('sha256').update(anonUid).digest('hex');
    check('Anonim giriş (signInAnonymously)', true, `uid=${anonUid}`);

    // B2: surveys görünürlüğü (watchEligibleSurveys)
    const list = await surveyQuery(anonToken);
    const docs = (Array.isArray(list.body) ? list.body : []).filter((e) => e.document).map((e) => e.document);
    const mine = docs.find((d) => d.name.split('/').pop() === surveyId);
    const active = mine && mine.fields.status && mine.fields.status.stringValue === 'active';
    check('Mobil anketi görüyor (companyId IN sorgusu)', list.status === 200 && !!mine && active,
      list.status !== 200 ? `status ${list.status}` : `dönen ${docs.length} anket, yeni anket ${mine ? 'VAR' : 'YOK'}, status=${mine && mine.fields.status && mine.fields.status.stringValue}`);

    // B3: cevap dokümanı oluştur (submitResponse adım 1)
    const respDoc = {
      fields: {
        surveyId: { stringValue: surveyId },
        companyId: { stringValue: SURVEY_COMPANY },
        userIdHash: { stringValue: userIdHash },
        answers: { mapValue: { fields: { q1: { integerValue: '5' }, q2: { booleanValue: true } } } },
        created_at: { timestampValue: new Date().toISOString() },
      },
    };
    const resp = await fsReq('POST', `${DOC_BASE}/survey_responses`, anonToken, respDoc);
    if (resp.status === 200 && resp.body.name) responseName = resp.body.name;
    check('Mobil cevap gönderebiliyor (survey_responses create)', resp.status === 200,
      resp.status !== 200 ? `status ${resp.status}: ${JSON.stringify(resp.body).slice(0, 160)}` : `responseId=${resp.body.name.split('/').pop()}`);

    // B4: responseCount +1 (submitResponse best-effort adım 2)
    const cur = await fsReq('GET', `${DOC_BASE}/surveys/${surveyId}`, anonToken, null);
    const curCount = cur.status === 200 ? Number((cur.body.fields.responseCount && cur.body.fields.responseCount.integerValue) || 0) : 0;
    const bump = await fsReq('PATCH', `${DOC_BASE}/surveys/${surveyId}?updateMask.fieldPaths=responseCount`, anonToken,
      { fields: { responseCount: { integerValue: String(curCount + 1) } } });
    check('Mobil responseCount +1 artırabiliyor (surveys update kuralı)', bump.status === 200,
      bump.status !== 200 ? `status ${bump.status}: ${JSON.stringify(bump.body).slice(0, 160)}` : `${curCount} → ${curCount + 1}`);

    // B5: submitResponse adım 3 — "zaten cevaplandı" işareti kullanıcının KENDİ
    //     dokümanına (users/{uid}.answeredSurveyIds) yazılır. Mobil artık
    //     survey_responses OKUMUYOR; bu alan yalnız sahibe (isOwner) açıktır.
    const mark = await fsReq('PATCH',
      `${DOC_BASE}/users/${anonUid}?updateMask.fieldPaths=answeredSurveyIds`, anonToken,
      { fields: { answeredSurveyIds: { arrayValue: { values: [{ stringValue: surveyId }] } } } });
    check('Mobil "cevaplandı" işaretini kendi dokümanına yazabiliyor (users.answeredSurveyIds)',
      mark.status === 200,
      mark.status !== 200 ? `status ${mark.status}: ${JSON.stringify(mark.body).slice(0, 160)}` : 'answeredSurveyIds güncellendi');

    // B6: KRİTİK — mobil cevapladığı anketleri KENDİ dokümanından okuyabilmeli
    //     (watchAnsweredSurveyIds — "Tamamlanan/bekleyen" filtresi, yeni tasarım).
    const myUser = await fsReq('GET', `${DOC_BASE}/users/${anonUid}`, anonToken, null);
    const answered = (myUser.status === 200 && myUser.body.fields && myUser.body.fields.answeredSurveyIds
      && myUser.body.fields.answeredSurveyIds.arrayValue && myUser.body.fields.answeredSurveyIds.arrayValue.values) || [];
    const sawMine = answered.some((v) => v.stringValue === surveyId);
    check('Mobil kendi cevapladıklarını okuyabiliyor (users.answeredSurveyIds — KRİTİK FİX)',
      myUser.status === 200 && sawMine,
      myUser.status !== 200 ? `status ${myUser.status}` : `${answered.length} kayıt, bu anket ${sawMine ? 'VAR (Tamamlanan filtresi çalışır)' : 'YOK'}`);

    // B7: KRİTİK GÜVENLİK — BAŞKA bir authed (anonim) kullanıcı survey_responses'i
    //     şirketler-arası OKUYAMAMALI. company_id claim'i olmadığından kural
    //     (isAdmin || isCompanyMember) sorguyu reddetmeli → 200+veri DÖNMEMELİ.
    const other = await req('POST', 'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${API_KEY}`, {}, { returnSecureToken: true });
    const otherToken = other.body && other.body.idToken;
    const leak = await responsesBySurveyQuery(otherToken, surveyId);
    const leakDocs = (Array.isArray(leak.body) ? leak.body : []).filter((e) => e.document);
    check('Şirketler-arası okuma KAPALI (yabancı kullanıcı yanıtları okuyamıyor)',
      !(leak.status === 200 && leakDocs.length > 0),
      `status ${leak.status}, dönen ${leakDocs.length} yanıt`);

    // ─── PANEL RESULTS: admin yanıtları okuyabilmeli ───────────────────────
    console.log('\nPANEL RESULTS (admin):');
    const adminResp = await responsesBySurveyQuery(adminToken, surveyId);
    const adminDocs = (Array.isArray(adminResp.body) ? adminResp.body : []).filter((e) => e.document);
    check('Admin anket yanıtlarını okuyabiliyor (panel sonuçlar)', adminResp.status === 200 && adminDocs.length >= 1,
      adminResp.status !== 200 ? `status ${adminResp.status}` : `${adminDocs.length} yanit`);
  } finally {
    // ─── TEMİZLİK ──────────────────────────────────────────────────────────
    console.log('\nTEMİZLİK:');
    if (adminToken && responseName) {
      const d = await fsReq('DELETE', `/v1/${responseName}`, adminToken, null);
      console.log(`   ${d.status === 200 ? '🧹' : '⚠️ '} response sil → status ${d.status}`);
    }
    if (adminToken && anonUid) {
      const d = await fsReq('DELETE', `${DOC_BASE}/users/${anonUid}`, adminToken, null);
      console.log(`   ${d.status === 200 ? '🧹' : '⚠️ '} mobil user doc sil → status ${d.status}`);
    }
    if (adminToken && surveyId) {
      const d = await fsReq('DELETE', `${DOC_BASE}/surveys/${surveyId}`, adminToken, null);
      console.log(`   ${d.status === 200 ? '🧹' : '⚠️ '} survey sil → status ${d.status}`);
    }
  }

  // ─── ÖZET ────────────────────────────────────────────────────────────────
  const passed = results.filter((r) => r.ok).length;
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`SONUÇ: ${passed}/${results.length} kontrol geçti.`);
  if (failed.length) {
    console.log('BAŞARISIZ:');
    failed.forEach((f) => console.log(`   ❌ ${f.name}`));
    process.exit(1);
  }
  console.log('✅ Uçtan uca akış doğrulandı: panelden yayınlanan anket mobilde görünür ve cevaplanabilir.');
}

main().catch((e) => { console.error('\n❌ Beklenmeyen hata:', e.message); process.exit(1); });
