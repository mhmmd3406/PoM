#!/usr/bin/env node
'use strict';

/**
 * PoM — Faz 2.0 Veri Temeli: Genel Anket (gate survey) toplulaştırma verisi
 * =============================================================================
 * `computeSurveyAggregate` Cloud Function'ının (Faz 2a) çalışabilmesi için canlı
 * veriyi hazırlar. İki şey yapar:
 *
 *   1. companies/* dokümanlarına tutarlı `industry` + `employeeCount` yazar
 *      (katılım oranı ve sektör grupları bunlara dayanır).
 *   2. Gate anketi (UvBNk4IL…) için MEVCUT kullanıcılar adına TUTARLI yanıtlar
 *      üretir: `userIdHash = sha256(uid)` (mobil submit formülüyle birebir) →
 *      CF, her user için sha256(uid) hesaplayıp join yapabilir → yanıtın ait
 *      olduğu şirket/departman user dokümanından gelir.
 *
 * Gate anketi platform anketidir (companyId='__admin__'); yanıtın kendisi gerçek
 * şirketi TAŞIMAZ, bu yüzden join şarttır (Option A — onaylanan mimari).
 *
 * NON-DESTRUCTIVE: kullanıcıları/check-in'leri SİLMEZ. Sadece company meta yazar
 * ve `seed:true` işaretli yanıtlar ekler (→ `--purge` ile geri alınabilir).
 *
 * Auth: firebase-tools OAuth refresh token → Firestore REST (Owner, kuralları
 * bypass eder; SA gerekmez). check_firestore.js / set_admin_rest.js deseni.
 *
 * Kullanım:
 *   node scripts/seed_gate_aggregate_data.js --plan     # sadece raporla (yazmaz)
 *   node scripts/seed_gate_aggregate_data.js --apply     # companies + yanıtları yaz
 *   node scripts/seed_gate_aggregate_data.js --purge     # seed:true gate yanıtlarını sil
 * =============================================================================
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const FT = path.join(process.env.USERPROFILE || process.env.HOME || '',
  '.config/configstore/firebase-tools.json');
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT_ID = 'pomapp-c3ccc';
const SURVEY_ID = process.env.SURVEY_ID || 'UvBNk4IL4oe1VW2xFznT';
const DB = `projects/${PROJECT_ID}/databases/(default)`;

const ARGV = process.argv.slice(2);
const MODE = ARGV.includes('--apply') ? 'apply'
  : ARGV.includes('--purge') ? 'purge'
  : ARGV.includes('--verify') ? 'verify'
  // --write-aggregates: produce survey_aggregates docs in the EXACT shape the
  // computeSurveyAggregate Cloud Function writes (functions/src/index.ts). Used
  // to unblock mobile dev while the CF deploy is blocked on billing; the CF then
  // refreshes the same docs on schedule once billing is restored.
  : ARGV.includes('--write-aggregates') ? 'aggregates' : 'plan';

const COMPANY_MIN_N = 15;
const DEPT_MIN_N = 10;

// Industry fallback for companies missing the field (banks). comp_* already
// carry an industry, kept as-is.
const INDUSTRY_FALLBACK = {
  akbank: 'Bankacılık', garanti_bbva: 'Bankacılık', ziraat_bankasi: 'Bankacılık',
  yapi_kredi: 'Bankacılık', is_bankasi: 'Bankacılık', turkcell: 'Telekomünikasyon',
  startup_co: 'Teknoloji',
};

// ─── REST helpers ─────────────────────────────────────────────────────────────

function req(method, hostname, p, headers, body) {
  const b = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : '';
  return new Promise((res, rej) => {
    const r = https.request({ hostname, path: p, method,
      headers: { ...headers, ...(b ? { 'Content-Length': Buffer.byteLength(b) } : {}) } }, x => {
      let d = ''; x.on('data', c => d += c);
      x.on('end', () => { try { res({ status: x.statusCode, body: JSON.parse(d) }); }
        catch (e) { res({ status: x.statusCode, body: d }); } });
    });
    r.on('error', rej); if (b) r.write(b); r.end();
  });
}
async function getToken() {
  const rt = JSON.parse(fs.readFileSync(FT, 'utf8')).tokens.refresh_token;
  const body = `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(rt)}&grant_type=refresh_token`;
  const r = await req('POST', 'oauth2.googleapis.com', '/token',
    { 'Content-Type': 'application/x-www-form-urlencoded' }, body);
  if (r.status !== 200) throw new Error(`token: ${JSON.stringify(r.body)}`);
  return r.body.access_token;
}
// Firestore typed-value (de)serialization
function fromVal(v) {
  if (v == null) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return parseInt(v.integerValue, 10);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(fromVal);
  if ('mapValue' in v) { const o = {}; for (const k in (v.mapValue.fields || {})) o[k] = fromVal(v.mapValue.fields[k]); return o; }
  return null;
}
function toVal(x) {
  if (x === null || x === undefined) return { nullValue: null };
  if (typeof x === 'boolean') return { booleanValue: x };
  if (typeof x === 'number') return Number.isInteger(x) ? { integerValue: String(x) } : { doubleValue: x };
  if (typeof x === 'string') return { stringValue: x };
  if (x instanceof Date) return { timestampValue: x.toISOString() };
  if (Array.isArray(x)) return { arrayValue: { values: x.map(toVal) } };
  if (typeof x === 'object') { const f = {}; for (const k in x) f[k] = toVal(x[k]); return { mapValue: { fields: f } }; }
  throw new Error('toVal: ' + typeof x);
}

async function listAll(tok, collection) {
  const out = [];
  let pageToken = '';
  do {
    const qs = `pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const r = await req('GET', 'firestore.googleapis.com',
      `/v1/${DB}/documents/${collection}?${qs}`, { Authorization: `Bearer ${tok}` });
    if (r.status !== 200) throw new Error(`list ${collection}: ${JSON.stringify(r.body)}`);
    for (const d of (r.body.documents || []))
      out.push({ id: d.name.split('/').pop(), name: d.name, f: fromVal({ mapValue: { fields: d.fields } }) });
    pageToken = r.body.nextPageToken || '';
  } while (pageToken);
  return out;
}
async function runQuery(tok, body) {
  const r = await req('POST', 'firestore.googleapis.com',
    `/v1/${DB}/documents:runQuery`, { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' }, body);
  if (r.status !== 200) throw new Error(`runQuery: ${JSON.stringify(r.body)}`);
  return (r.body || []).filter(x => x.document)
    .map(x => ({ name: x.document.name, f: fromVal({ mapValue: { fields: x.document.fields } }) }));
}
async function commit(tok, writes) {
  // Firestore :commit allows up to 500 writes per call.
  for (let i = 0; i < writes.length; i += 450) {
    const chunk = writes.slice(i, i + 450);
    const r = await req('POST', 'firestore.googleapis.com',
      `/v1/${DB}/documents:commit`, { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      { writes: chunk });
    if (r.status !== 200) throw new Error(`commit: ${JSON.stringify(r.body)}`);
  }
}

// ─── Answer generation (realistic, varied per company/department) ─────────────

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
function gauss() { // Box-Muller
  let u = 0, v = 0; while (u === 0) u = Math.random(); while (v === 0) v = Math.random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
// Deterministic per-company baseline so aggregates differ but are stable-ish.
function companyBaseline(companyId) {
  const h = parseInt(sha256(companyId).slice(0, 8), 16) / 0xffffffff; // 0..1
  return 2.8 + h * 1.6; // 2.8 .. 4.4 target mean (1–5)
}
function deptOffset(dept) {
  const h = parseInt(sha256(dept).slice(0, 8), 16) / 0xffffffff;
  return (h - 0.5) * 0.8; // ±0.4
}
/** Build an answers map for one respondent at a given target mean. */
function buildAnswers(questions, target) {
  const ans = {};
  for (const q of questions) {
    const t = clamp(target + gauss() * 0.6, 1, 5); // per-question 1–5 intent
    switch (q.type) {
      case 'scale5':
        ans[q.id] = clamp(Math.round(t), 1, 5);
        break;
      case 'emoji5':
        ans[q.id] = clamp(Math.round(t) - 1, 0, 4); // mobile 0-indexed
        break;
      case 'scale10': {
        const ten = clamp(Math.round(((t - 1) / 4) * 10), 0, 10);
        ans[q.id] = ten;
        break;
      }
      case 'yesno':
      case 'trueFalse': {
        // "good" answer probability scales with t; reverseScore flips which is good.
        const pGood = clamp((t - 1) / 4, 0.05, 0.95);
        const good = Math.random() < pGood;
        ans[q.id] = q.reverseScore ? !good : good; // reverseScore: good outcome = "Hayır"(false)
        break;
      }
      default: // text — leave unanswered (no numeric score)
        break;
    }
  }
  return ans;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

(async () => {
  console.log(`[mode] ${MODE}  survey=${SURVEY_ID}  project=${PROJECT_ID}`);
  const tok = await getToken();

  // ── PURGE ────────────────────────────────────────────────────────────────
  if (MODE === 'purge') {
    // Query by surveyId only (single-field index), filter seed in code — avoids
    // needing a composite index for surveyId+seed.
    const allResps = await runQuery(tok, { structuredQuery: {
      from: [{ collectionId: 'survey_responses' }],
      where: { fieldFilter: { field: { fieldPath: 'surveyId' }, op: 'EQUAL', value: { stringValue: SURVEY_ID } } } } });
    const seedResps = allResps.filter(r => r.f.seed === true);
    console.log(`[purge] ${seedResps.length} seed yanıt silinecek`);
    await commit(tok, seedResps.map(r => ({ delete: r.name })));
    const realCount = allResps.filter(r => !r.f.seed).length;
    await commit(tok, [{ update: { name: `${DB}/documents/surveys/${SURVEY_ID}`,
      fields: { responseCount: toVal(realCount) } }, updateMask: { fieldPaths: ['responseCount'] } }]);
    console.log(`[purge] tamam. responseCount → ${realCount}`);
    return;
  }

  // ── VERIFY (reference implementation of the future Cloud Function) ─────────
  if (MODE === 'verify') {
    const sres0 = await req('GET', 'firestore.googleapis.com',
      `/v1/${DB}/documents/surveys/${SURVEY_ID}`, { Authorization: `Bearer ${tok}` });
    const qs0 = fromVal({ mapValue: { fields: sres0.body.fields } }).questions || [];
    const users0 = (await listAll(tok, 'users')).filter(u => u.f.companyId && !u.f.deleted);
    // sha256(uid) → user group (mirrors the CF join)
    const hashToUser = new Map();
    for (const u of users0) hashToUser.set(sha256(u.id), { companyId: u.f.companyId, department: u.f.department || '(belirsiz)' });
    const resps0 = await runQuery(tok, { structuredQuery: {
      from: [{ collectionId: 'survey_responses' }],
      where: { fieldFilter: { field: { fieldPath: 'surveyId' }, op: 'EQUAL', value: { stringValue: SURVEY_ID } } } } });

    const norm = (a, type, rev) => {
      if (a == null) return null;
      if (type === 'emoji5') return typeof a === 'number' ? a + 1 : null;
      if (type === 'scale5') return typeof a === 'number' ? a : null;
      if (type === 'scale10') return typeof a === 'number' ? (a / 10) * 4 + 1 : null;
      if (type === 'yesno' || type === 'trueFalse') return typeof a === 'boolean' ? (a ? (rev ? 1 : 5) : (rev ? 5 : 1)) : null;
      return null;
    };
    const enpsQ = qs0.find(q => q.isEnps && q.type === 'scale10');
    const groups = {}; // key → { catSums:{cat:[vals]}, enps:[], n }
    let joined = 0;
    for (const r of resps0) {
      const g = hashToUser.get(r.f.userIdHash);
      if (!g) continue; // unjoined (real submissions from non-seed users etc.)
      joined++;
      const keys = [`şirket:${g.companyId}`, `dept:${g.companyId}/${g.department}`];
      for (const k of keys) {
        groups[k] = groups[k] || { cat: {}, enps: [], n: 0 };
        groups[k].n++;
        for (const q of qs0) {
          if (!q.category || q.type === 'text') continue;
          const v = norm(r.f.answers[q.id], q.type, q.reverseScore);
          if (v == null) continue;
          (groups[k].cat[q.category] = groups[k].cat[q.category] || []).push(v);
        }
        if (enpsQ && typeof r.f.answers[enpsQ.id] === 'number') groups[k].enps.push(r.f.answers[enpsQ.id]);
      }
    }
    console.log(`\n[verify] join: ${joined}/${resps0.length} yanıt sha256(uid) ile bir user'a eşleşti.`);
    const mean = a => a.reduce((s, v) => s + v, 0) / a.length;
    const enpsScore = a => a.length ? Math.round((a.filter(x => x >= 9).length / a.length) * 100 - (a.filter(x => x <= 6).length / a.length) * 100) : null;
    for (const k of Object.keys(groups).sort()) {
      const g = groups[k];
      const isDept = k.startsWith('dept:');
      const floor = isDept ? DEPT_MIN_N : COMPANY_MIN_N;
      if (g.n < floor) { console.log(`  🔒 ${k}  (n=${g.n} < ${floor}, gizli)`); continue; }
      const catMeans = Object.entries(g.cat).map(([c, vals]) => [c, mean(vals)]).sort((a, b) => b[1] - a[1]);
      const overall = mean(catMeans.map(c => c[1]));
      const top = catMeans[0], bot = catMeans[catMeans.length - 1];
      console.log(`  ✓ ${k}  n=${g.n}  genel=${overall.toFixed(2)}  eNPS=${enpsScore(g.enps)}  ↑${top[0]} ${top[1].toFixed(1)}  ↓${bot[0]} ${bot[1].toFixed(1)}`);
    }
    return;
  }

  // ── WRITE-AGGREGATES (mirror of computeSurveyAggregate CF doc shape) ───────
  if (MODE === 'aggregates') {
    const sres1 = await req('GET', 'firestore.googleapis.com',
      `/v1/${DB}/documents/surveys/${SURVEY_ID}`, { Authorization: `Bearer ${tok}` });
    const questions1 = (fromVal({ mapValue: { fields: sres1.body.fields } }).questions || []).filter(Boolean);
    const enpsQ1 = questions1.find(q => q.isEnps && q.type === 'scale10');
    const users1 = (await listAll(tok, 'users')).filter(u => u.f.companyId && !u.f.deleted);
    const hashToUser1 = new Map();
    for (const u of users1) hashToUser1.set(sha256(u.id), { companyId: u.f.companyId, department: u.f.department || '(belirsiz)' });
    const companies1 = await listAll(tok, 'companies');
    const industryOf = new Map(companies1.map(c => [c.id, c.f.industry || 'Diğer']));
    const resps1 = await runQuery(tok, { structuredQuery: {
      from: [{ collectionId: 'survey_responses' }],
      where: { fieldFilter: { field: { fieldPath: 'surveyId' }, op: 'EQUAL', value: { stringValue: SURVEY_ID } } } } });

    const norm = (a, type, rev) => {
      if (a == null) return null;
      if (type === 'emoji5') return typeof a === 'number' ? a + 1 : null;
      if (type === 'scale5') return typeof a === 'number' ? a : null;
      if (type === 'scale10') return typeof a === 'number' ? (a / 10) * 4 + 1 : null;
      if (type === 'yesno' || type === 'trueFalse') return typeof a === 'boolean' ? (a ? (rev ? 1 : 5) : (rev ? 5 : 1)) : null;
      return null;
    };
    const newAcc = () => ({ n: 0, cat: {}, enps: [] });
    const accInto = (acc, answers) => {
      acc.n++;
      for (const q of questions1) {
        if (!q.category || q.type === 'text') continue;
        const v = norm(answers[q.id], q.type, q.reverseScore);
        if (v != null) (acc.cat[q.category] = acc.cat[q.category] || []).push(v);
      }
      if (enpsQ1 && typeof answers[enpsQ1.id] === 'number') acc.enps.push(answers[enpsQ1.id]);
    };
    const mean = a => a.reduce((s, v) => s + v, 0) / a.length;
    const r2 = n => Math.round(n * 100) / 100;
    const enpsScore = a => a.length ? Math.round((a.filter(x => x >= 9).length / a.length) * 100 - (a.filter(x => x <= 6).length / a.length) * 100) : null;
    const summarize = (acc, minN) => {
      if (acc.n < minN) return { n: acc.n, locked: true, overall: null, categories: {}, enps: null };
      const categories = {};
      for (const [c, vals] of Object.entries(acc.cat)) if (vals.length) categories[c] = r2(mean(vals));
      const cv = Object.values(categories);
      return { n: acc.n, locked: false, overall: cv.length ? r2(cv.reduce((s, v) => s + v, 0) / cv.length) : null, categories, enps: enpsScore(acc.enps) };
    };

    const companyAcc = {}, deptAcc = {}, sectorAcc = {};
    for (const r of resps1) {
      const g = hashToUser1.get(r.f.userIdHash);
      if (!g) continue;
      const ind = industryOf.get(g.companyId) || 'Diğer';
      (companyAcc[g.companyId] = companyAcc[g.companyId] || newAcc()); accInto(companyAcc[g.companyId], r.f.answers);
      (deptAcc[g.companyId] = deptAcc[g.companyId] || {});
      (deptAcc[g.companyId][g.department] = deptAcc[g.companyId][g.department] || newAcc()); accInto(deptAcc[g.companyId][g.department], r.f.answers);
      (sectorAcc[ind] = sectorAcc[ind] || Object.assign(newAcc(), { companies: new Set() })); accInto(sectorAcc[ind], r.f.answers); sectorAcc[ind].companies.add(g.companyId);
    }

    const writes = [];
    for (const companyId of Object.keys(companyAcc)) {
      const ind = industryOf.get(companyId) || 'Diğer';
      const sa = sectorAcc[ind];
      const departments = {};
      for (const [d, acc] of Object.entries(deptAcc[companyId] || {})) departments[d] = summarize(acc, DEPT_MIN_N);
      const sector = sa ? Object.assign({ industry: ind, nCompanies: sa.companies.size }, summarize(sa, COMPANY_MIN_N)) : null;
      writes.push({ update: { name: `${DB}/documents/survey_aggregates/${SURVEY_ID}__${companyId}`,
        fields: toVal({
          surveyId: SURVEY_ID, companyId, companyMinN: COMPANY_MIN_N, departmentMinN: DEPT_MIN_N,
          company: summarize(companyAcc[companyId], COMPANY_MIN_N), departments, sector,
          updatedAt: new Date(), seed: true,
        }).mapValue.fields } });
    }
    console.log(`[aggregates] ${writes.length} survey_aggregates doc yazılıyor (CF doc şekli)…`);
    await commit(tok, writes);
    const visible = Object.keys(companyAcc).filter(c => companyAcc[c].n >= COMPANY_MIN_N);
    console.log(`[aggregates] tamam. min-N geçen şirket: ${visible.length} (${visible.join(', ')}).`);
    return;
  }

  // ── Read survey questions + users + companies ──────────────────────────────
  const sres = await req('GET', 'firestore.googleapis.com',
    `/v1/${DB}/documents/surveys/${SURVEY_ID}`, { Authorization: `Bearer ${tok}` });
  if (sres.status !== 200) throw new Error(`survey: ${JSON.stringify(sres.body)}`);
  const questions = fromVal({ mapValue: { fields: sres.body.fields } }).questions || [];

  const users = (await listAll(tok, 'users')).filter(u => u.f.companyId && !u.f.deleted);
  const companies = await listAll(tok, 'companies');

  // Group users by company + department
  const byCompany = {}; // companyId → { total, depts: {dept: count}, users: [...] }
  for (const u of users) {
    const c = u.f.companyId, d = u.f.department || '(belirsiz)';
    byCompany[c] = byCompany[c] || { total: 0, depts: {}, users: [] };
    byCompany[c].total++; byCompany[c].depts[d] = (byCompany[c].depts[d] || 0) + 1;
    byCompany[c].users.push(u);
  }

  console.log(`\n[veri] anket soru=${questions.length}  kullanıcı=${users.length}  şirket=${companies.length}\n`);
  console.log('ŞİRKET / DEPARTMAN DAĞILIMI (min-N: şirket≥15, dept≥10):');
  const sortedC = Object.keys(byCompany).sort((a, b) => byCompany[b].total - byCompany[a].total);
  for (const c of sortedC) {
    const info = byCompany[c];
    const ind = companies.find(x => x.id === c)?.f.industry || INDUSTRY_FALLBACK[c] || '—';
    const okC = info.total >= COMPANY_MIN_N ? '✓' : '✗(<15)';
    const depts = Object.entries(info.depts)
      .map(([d, n]) => `${d}:${n}${n >= DEPT_MIN_N ? '✓' : '✗'}`).join('  ');
    console.log(`  ${okC} ${c} (${ind}) n=${info.total}  →  ${depts}`);
  }

  if (MODE === 'plan') {
    const visibleC = sortedC.filter(c => byCompany[c].total >= COMPANY_MIN_N).length;
    console.log(`\n[plan] --apply ile: ${companies.length} şirkete industry/employeeCount yazılır,`);
    console.log(`       ${users.length} kullanıcı için seed:true gate yanıtı üretilir.`);
    console.log(`       Min-N geçen şirket: ${visibleC}/${sortedC.length}.`);
    console.log(`       (Yazmadı — gerçekleştirmek için --apply.)`);
    return;
  }

  // ── APPLY ──────────────────────────────────────────────────────────────────
  const writes = [];

  // 1) Company meta (industry + employeeCount = gerçek kullanıcı sayısı)
  for (const c of companies) {
    const info = byCompany[c.id];
    const employeeCount = info ? info.total : (c.f.employeeCount || 0);
    const industry = c.f.industry || INDUSTRY_FALLBACK[c.id] || 'Diğer';
    writes.push({ update: { name: `${DB}/documents/companies/${c.id}`,
      fields: { industry: toVal(industry), employeeCount: toVal(employeeCount) } },
      updateMask: { fieldPaths: ['industry', 'employeeCount'] } });
  }
  // Kullanıcı olup company dokümanı olmayanlar için company oluştur
  for (const c of sortedC) {
    if (!companies.find(x => x.id === c)) {
      writes.push({ update: { name: `${DB}/documents/companies/${c}`,
        fields: { name: toVal(c), industry: toVal(INDUSTRY_FALLBACK[c] || 'Diğer'),
          employeeCount: toVal(byCompany[c].total), created_at: toVal(new Date()) } } });
    }
  }

  // 2) Gate responses — userIdHash = sha256(uid); answers vary by company+dept
  const now = new Date();
  let respN = 0;
  for (const c of sortedC) {
    const base = companyBaseline(c);
    for (const u of byCompany[c].users) {
      const target = clamp(base + deptOffset(u.f.department || ''), 1.4, 4.8);
      const answers = buildAnswers(questions, target);
      const docId = `seed_${SURVEY_ID}_${u.id}`.replace(/[^a-zA-Z0-9_]/g, '').slice(0, 1400);
      writes.push({ update: { name: `${DB}/documents/survey_responses/${docId}`,
        fields: {
          surveyId: toVal(SURVEY_ID),
          companyId: toVal('__admin__'), // mirrors real submit (platform survey)
          userIdHash: toVal(sha256(u.id)), // mobile submit formula → CF joins on sha256(uid)
          answers: toVal(answers),
          seed: toVal(true),
          created_at: toVal(now),
        } } });
      respN++;
    }
  }

  // 3) responseCount = mevcut gerçek + seed
  const existing = await runQuery(tok, { structuredQuery: {
    from: [{ collectionId: 'survey_responses' }],
    where: { fieldFilter: { field: { fieldPath: 'surveyId' }, op: 'EQUAL', value: { stringValue: SURVEY_ID } } } } });
  const realCount = existing.filter(r => !r.f.seed).length;
  writes.push({ update: { name: `${DB}/documents/surveys/${SURVEY_ID}`,
    fields: { responseCount: toVal(realCount + respN) } }, updateMask: { fieldPaths: ['responseCount'] } });

  console.log(`\n[apply] ${companies.length} company güncelle + ${respN} seed yanıt yaz (toplam ${writes.length} write)…`);
  await commit(tok, writes);
  console.log(`[apply] tamam. responseCount → ${realCount + respN} (gerçek ${realCount} + seed ${respN}).`);
})().catch(e => { console.error('[error]', e); process.exit(1); });
