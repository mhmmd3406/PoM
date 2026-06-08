#!/usr/bin/env node
/**
 * PoM — Genel Çalışan Deneyimi Anketi Seed Script
 *
 * Belge: "GENEL ANKET.docx" + "PUANLAMA VE DEĞERLENDİRME METODOLOJİSİ.docx"
 *
 * 12 kategori, ~48 soru (orijinal ~168 sorudan metodoloji önerileri doğrultusunda
 * indirgenmiş; kategori başına 4 soru, ~10-15 dakika tamamlanma süresi).
 *
 * Normalizasyon kuralları (raporlama motoruyla tutarlı):
 *   scale5 / emoji5 → 1–5 (direkt)
 *   scale10         → (değer/10)*4 + 1 → 1–5
 *   yesno           → reverseScore=false: Evet=5, Hayır=1
 *                     reverseScore=true : Evet=1, Hayır=5 (olumsuz sorular)
 *
 * Anket özellikleri:
 *   - companyId : '__admin__'  (tüm kullanıcılara görünür)
 *   - status    : 'draft'      (varsayılan; panelden yayınlanmadan önce gözden geçirin)
 *                 '--active' bayrağıyla doğrudan 'active' basılır (test/smoke için).
 *   - isGate    : true
 *   - isMandatory: false       (panelden zorunlu yapılabilir; '--mandatory' ile true)
 *
 * Kullanım:
 *   # Emülatöre karşı (varsayılan port 8080):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_genel_anket.js
 *
 *   # Test: girişte hemen görünmesi için aktif + (opsiyonel) zorunlu:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed_genel_anket.js --active
 *
 *   # Gerçek projeye karşı (dikkatli kullanın):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node scripts/seed_genel_anket.js --prod
 */

'use strict';

const admin = require('firebase-admin');
const { randomUUID } = require('crypto');

// ─── Args ─────────────────────────────────────────────────────────────────────

const ARGV = process.argv.slice(2);
const isProd = ARGV.includes('--prod');
const wantActive = ARGV.includes('--active');
const wantMandatory = ARGV.includes('--mandatory');
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'pomapp-c3ccc';

// ─── Init ─────────────────────────────────────────────────────────────────────

if (!isProd && !process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
}

if (!admin.apps.length) {
  admin.initializeApp(
    isProd
      ? { credential: admin.credential.applicationDefault() } // GOOGLE_APPLICATION_CREDENTIALS
      : { projectId: PROJECT_ID },
  );
}

const db = admin.firestore();

// ─── Survey definition ────────────────────────────────────────────────────────

/**
 * q(text, type, category, hint?, reverseScore?, isEnps?)
 */
function q(text, type, category, hint = '', reverseScore = false, isEnps = false) {
  return { id: randomUUID(), text, type, category, hint, reverseScore, isEnps };
}

const QUESTIONS = [

  // ── 1. Ücret ve Yan Haklar ─────────────────────────────────────────────────
  q('Aldığım maaş yaptığım işe uygundur.',
    'scale5', 'Ücret ve Yan Haklar', '1=Kesinlikle katılmıyorum · 5=Kesinlikle katılıyorum'),
  q('Şirketin ücret politikasının adil olduğunu düşünüyorum.',
    'scale5', 'Ücret ve Yan Haklar'),
  q('Ücret ve yan haklar paketini genel olarak nasıl değerlendirirsiniz?',
    'scale10', 'Ücret ve Yan Haklar', '0=Hiç tatmin edici değil · 10=Çok tatmin edici'),
  q('Yan haklar hakkında yeterli bilgilendirme yapılıyor mu?',
    'yesno', 'Ücret ve Yan Haklar'),

  // ── 2. Yönetici Memnuniyeti ────────────────────────────────────────────────
  q('Yöneticim bana saygılı davranır.',
    'scale5', 'Yönetici Memnuniyeti'),
  q('Yöneticim çalışan görüşlerine önem verir.',
    'scale5', 'Yönetici Memnuniyeti'),
  q('Yöneticinizin liderlik becerisini puanlayınız.',
    'scale10', 'Yönetici Memnuniyeti', '0=Çok zayıf · 10=Mükemmel'),
  q('Son 6 ay içinde yöneticinizden yapılandırılmış geri bildirim aldınız mı?',
    'yesno', 'Yönetici Memnuniyeti'),

  // ── 3. İş Ortamı ve Kurum Kültürü ─────────────────────────────────────────
  q('Çalışma ortamında saygı kültürü hakimdir.',
    'scale5', 'İş Ortamı ve Kurum Kültürü'),
  q('Şirket etik değerlere önem verir.',
    'scale5', 'İş Ortamı ve Kurum Kültürü'),
  q('Kurum kültürünü genel olarak puanlayınız.',
    'scale10', 'İş Ortamı ve Kurum Kültürü', '0=Çok olumsuz · 10=Çok olumlu'),
  // reverseScore=true: Evet yanıtı olumsuz bir durumu ifade ediyor
  q('Son 1 yıl içinde iş ortamında psikolojik baskıya veya dışlanmaya maruz kaldınız mı?',
    'yesno', 'İş Ortamı ve Kurum Kültürü', '', true),

  // ── 4. Kariyer ve Gelişim ──────────────────────────────────────────────────
  q('Kariyer gelişim fırsatları yeterlidir.',
    'scale5', 'Kariyer ve Gelişim'),
  q('Yeni beceriler kazanmam teşvik edilir.',
    'scale5', 'Kariyer ve Gelişim'),
  q('Kariyer gelişim imkânlarını puanlayınız.',
    'scale10', 'Kariyer ve Gelişim', '0=Hiç yok · 10=Çok güçlü'),
  q('Son 12 ay içinde mesleki gelişiminize katkı sağlayan bir eğitim aldınız mı?',
    'yesno', 'Kariyer ve Gelişim'),

  // ── 5. İş Yükü ve İş-Yaşam Dengesi ───────────────────────────────────────
  q('İş yüküm yönetilebilir seviyededir.',
    'scale5', 'İş Yükü ve İş-Yaşam Dengesi'),
  q('İşim özel hayatımı olumsuz etkilemiyor.',
    'scale5', 'İş Yükü ve İş-Yaşam Dengesi'),
  q('İş–özel hayat dengenizi puanlayınız.',
    'scale10', 'İş Yükü ve İş-Yaşam Dengesi', '0=Çok kötü · 10=Mükemmel'),
  // reverseScore=true: düzenli fazla mesai olumsuz bir gösterge
  q('Son 3 ay içinde haftalık düzenli fazla mesai yaptınız mı?',
    'yesno', 'İş Yükü ve İş-Yaşam Dengesi', '', true),

  // ── 6. Fiziksel Çalışma Ortamı ────────────────────────────────────────────
  q('Teknik ekipmanlar işimi verimli yapabilmem için yeterlidir.',
    'scale5', 'Fiziksel Çalışma Ortamı'),
  q('Uzaktan çalışma altyapısı ihtiyaçlarımı karşılıyor.',
    'scale5', 'Fiziksel Çalışma Ortamı'),
  q('Fiziksel çalışma ortamını genel olarak puanlayınız.',
    'scale10', 'Fiziksel Çalışma Ortamı', '0=Çok yetersiz · 10=Mükemmel'),
  q('İşinizi yapmak için ihtiyaç duyduğunuz tüm ekipmanlara sahip misiniz?',
    'yesno', 'Fiziksel Çalışma Ortamı'),

  // ── 7. İletişim ve Şeffaflık ───────────────────────────────────────────────
  q('Şirket, çalışanları önemli konularda zamanında bilgilendirir.',
    'scale5', 'İletişim ve Şeffaflık'),
  q('Çalışan görüşleri yönetim tarafından dikkate alınır.',
    'scale5', 'İletişim ve Şeffaflık'),
  q('Yönetim şeffaflığını puanlayınız.',
    'scale10', 'İletişim ve Şeffaflık', '0=Hiç şeffaf değil · 10=Tam şeffaf'),
  q('Şirket hedefleri ve stratejisi size net olarak aktarılıyor mu?',
    'yesno', 'İletişim ve Şeffaflık'),

  // ── 8. Takdir ve Ödüllendirme ─────────────────────────────────────────────
  q('Başarılar şirket içinde görünür şekilde takdir edilir.',
    'scale5', 'Takdir ve Ödüllendirme'),
  q('Ödüllendirme sistemi adil ve objektiftir.',
    'scale5', 'Takdir ve Ödüllendirme'),
  q('Takdir kültürünü genel olarak puanlayınız.',
    'scale10', 'Takdir ve Ödüllendirme', '0=Hiç yok · 10=Çok güçlü'),
  q('Son 6 ay içinde bir başarınız nedeniyle takdir aldınız mı?',
    'yesno', 'Takdir ve Ödüllendirme'),

  // ── 9. Liderlik ve Şirket Yönetimi ────────────────────────────────────────
  q('Şirket yönetimine güveniyorum.',
    'scale5', 'Liderlik ve Şirket Yönetimi'),
  q('Yönetim kararları tutarlı ve öngörülebilirdir.',
    'scale5', 'Liderlik ve Şirket Yönetimi'),
  q('Şirket yönetimine duyduğunuz genel güveni puanlayınız.',
    'scale10', 'Liderlik ve Şirket Yönetimi', '0=Hiç güvenmiyorum · 10=Tam güveniyorum'),
  q('Üst yönetimin çalışan geri bildirimlerini dikkate aldığını düşünüyor musunuz?',
    'yesno', 'Liderlik ve Şirket Yönetimi'),

  // ── 10. Psikolojik Güvenlik ve Refah ──────────────────────────────────────
  q('İş ortamında psikolojik olarak güvende hissediyorum.',
    'scale5', 'Psikolojik Güvenlik ve Refah'),
  q('İş kaynaklı stres yönetilebilir seviyededir.',
    'scale5', 'Psikolojik Güvenlik ve Refah'),
  q('Psikolojik güvenlik seviyenizi puanlayınız.',
    'scale10', 'Psikolojik Güvenlik ve Refah', '0=Hiç güvende değilim · 10=Tam güvendeyim'),
  // reverseScore=true: tükenmişlik olumsuz bir gösterge
  q('Son 12 ay içinde işle ilgili tükenmişlik hissettiniz mi?',
    'yesno', 'Psikolojik Güvenlik ve Refah', '', true),

  // ── 11. İşin Kendisi ──────────────────────────────────────────────────────
  q('Yaptığım işi anlamlı buluyorum.',
    'scale5', 'İşin Kendisi'),
  q('İşimde yetkinliklerimi kullanarak gelişim hissediyorum.',
    'scale5', 'İşin Kendisi'),
  q('İşinizden genel memnuniyetinizi puanlayınız.',
    'scale10', 'İşin Kendisi', '0=Hiç memnun değilim · 10=Çok memnunum'),
  q('Günlük işleriniz sizi motive ediyor mu?',
    'yesno', 'İşin Kendisi'),

  // ── 12. Çalışan Bağlılığı ve eNPS ────────────────────────────────────────
  // isEnps=true: bu soru eNPS hesaplamasında kullanılır
  q('Bu şirketi çalışılacak bir yer olarak yakın çevrenize tavsiye etme olasılığınızı puanlayınız.',
    'scale10', 'Çalışan Bağlılığı ve eNPS',
    '0–6 Eleştiren · 7–8 Pasif · 9–10 Destekleyen',
    false, true),
  q('Şirketin bir parçası olmaktan gurur duyuyorum.',
    'scale5', 'Çalışan Bağlılığı ve eNPS'),
  q('Önümüzdeki 2 yıl içinde bu şirkette çalışmaya devam etme isteğinizi puanlayınız.',
    'scale10', 'Çalışan Bağlılığı ve eNPS', '0=Kesinlikle hayır · 10=Kesinlikle evet'),
  // reverseScore=true: iş değiştirme düşüncesi olumsuz bir gösterge
  q('Son 12 ay içinde iş değiştirmeyi ciddi olarak düşündünüz mü?',
    'yesno', 'Çalışan Bağlılığı ve eNPS', '', true),
];

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const status = wantActive ? 'active' : 'draft';
  console.log(`\n🚀 PoM Genel Anket Seed — ${isProd ? 'PRODUCTION' : 'Emulator'} (status=${status})\n`);

  // Duplicate guard: check for existing gate survey.
  const existing = await db.collection('surveys')
    .where('companyId', '==', '__admin__')
    .where('isGate', '==', true)
    .get();

  if (!existing.empty) {
    console.log('⚠️  Zaten bir giriş (gate) anketi mevcut:');
    existing.forEach(d => {
      console.log(`   id=${d.id}  title="${d.data().title}"  status=${d.data().status}`);
    });
    console.log('\n   Yeni anket oluşturulmadı. Mevcut anketi silip tekrar çalıştırabilirsiniz.');
    process.exit(0);
  }

  const surveyRef = db.collection('surveys').doc();
  await surveyRef.set({
    companyId:     '__admin__',
    title:         'Genel Çalışan Deneyimi Anketi',
    description:   '12 boyutlu kapsamlı çalışan memnuniyeti ölçümü. Yanıtlar anonim kaydedilir ve bireysel olarak raporlanmaz.',
    emoji:         '📋',
    status,                        // draft (varsayılan) | active (--active)
    isGate:        true,
    isMandatory:   wantMandatory,  // false (varsayılan) | true (--mandatory)
    questions:     QUESTIONS,
    minNThreshold: 5,
    responseCount: 0,
    created_at:    admin.firestore.FieldValue.serverTimestamp(),
    updated_at:    admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Anket oluşturuldu`);
  console.log(`   id       : ${surveyRef.id}`);
  console.log(`   sorular  : ${QUESTIONS.length}`);
  console.log(`   durum    : ${status}${wantActive ? '' : '  (yayınlamak için panel → Anketler → Yayınla)'}`);
  console.log(`   isGate   : true`);
  console.log(`   zorunlu  : ${wantMandatory}\n`);
}

main().catch(err => {
  console.error('\n❌ Hata:', err.message ?? err);
  process.exit(1);
});
