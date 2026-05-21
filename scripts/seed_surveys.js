/**
 * seed_surveys.js
 *
 * Populates Firestore with synthetic survey data for all user types.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json node seed_surveys.js
 *
 * What it creates:
 *   - 2 platform-wide admin surveys (companyId: '__admin__')
 *   - 2 company surveys for each of: startup_co, garanti_bbva, turkcell, akbank
 *   - Simulated responses from debug users (uid: debug_free, debug_pro, etc.)
 */

const admin = require('firebase-admin')
const crypto = require('crypto')

admin.initializeApp()
const db = admin.firestore()

// ── Helpers ───────────────────────────────────────────────────────────────────

const ts = () => admin.firestore.FieldValue.serverTimestamp()
const pastDate = (daysAgo) => {
  const d = new Date()
  d.setDate(d.getDate() - daysAgo)
  return admin.firestore.Timestamp.fromDate(d)
}
const futureDate = (daysAhead) => {
  const d = new Date()
  d.setDate(d.getDate() + daysAhead)
  return admin.firestore.Timestamp.fromDate(d)
}
const hashUid = (uid) => crypto.createHash('sha256').update(uid).digest('hex')
const uuid = () => crypto.randomUUID()

// ── Debug user map ─────────────────────────────────────────────────────────────

const DEBUG_USERS = [
  { uid: 'debug_free',       companyId: 'startup_co',   displayName: 'Ayşe Kaya' },
  { uid: 'debug_pro',        companyId: 'garanti_bbva', displayName: 'Mehmet Demir' },
  { uid: 'debug_enterprise', companyId: 'turkcell',     displayName: 'Zeynep Arslan' },
  { uid: 'debug_daas',       companyId: 'akbank',       displayName: 'Can Öztürk' },
]

// ── Survey definitions ────────────────────────────────────────────────────────

const ADMIN_SURVEYS = [
  {
    companyId: '__admin__',
    title: 'Genel İş Yaşamı Kalitesi',
    description: 'PoM platformunun tüm kullanıcılarına yönelik genel refah anketi.',
    emoji: '🌟',
    status: 'active',
    minNThreshold: 5,
    deadline: futureDate(14),
    questions: [
      { id: uuid(), text: 'Bu haftaki genel ruh haliniz nasıl?', type: 'emoji5', hint: 'Genel hissini emoji ile belirt.' },
      { id: uuid(), text: 'İş-yaşam dengenizden memnun musunuz?', type: 'yesno', hint: 'Evet ya da hayır seç.' },
      { id: uuid(), text: 'PoM uygulamasını bir meslektaşınıza önerme olasılığınız?', type: 'scale10', hint: '0: kesinlikle hayır · 10: kesinlikle evet' },
      { id: uuid(), text: 'Çalışma ortamınızı nasıl değerlendiriyorsunuz?', type: 'emoji5', hint: 'Genel izlenimini belirt.' },
      { id: uuid(), text: 'Gelecek ay için motivasyon seviyeniz nedir?', type: 'scale10', hint: '0: çok düşük · 10: çok yüksek' },
    ],
  },
  {
    companyId: '__admin__',
    title: 'Dijital Dönüşüm ve Uzaktan Çalışma',
    description: 'Dijital araçlara adaptasyon ve uzaktan çalışma alışkanlıkları.',
    emoji: '💻',
    status: 'active',
    minNThreshold: 5,
    deadline: futureDate(21),
    questions: [
      { id: uuid(), text: 'Dijital araçları kullanma konusunda kendinizi yeterli hissediyor musunuz?', type: 'yesno', hint: 'Evet ya da hayır seç.' },
      { id: uuid(), text: 'Uzaktan çalışma verimliliğinizi artırıyor mu?', type: 'yesno', hint: 'Dürüstçe yanıtlayın.' },
      { id: uuid(), text: 'Ekibinizle dijital iletişim kalitesini değerlendirin.', type: 'emoji5', hint: '😞: çok kötü · 😄: harika' },
      { id: uuid(), text: 'Haftada kaç gün evden çalışmayı tercih edersiniz? (0-10 arası)', type: 'scale10', hint: '0: hiç · 10: her zaman' },
    ],
  },
]

const COMPANY_SURVEYS = {
  startup_co: [
    {
      title: 'Startup Çalışma Kültürü Anketi',
      description: 'Şirket kültürü ve ekip dinamiklerine dair sorular.',
      emoji: '🚀',
      status: 'active',
      minNThreshold: 3,
      deadline: futureDate(10),
      questions: [
        { id: uuid(), text: 'Şirket kültüründen memnun musunuz?', type: 'emoji5', hint: 'Genel hissini belirt.' },
        { id: uuid(), text: 'Ekibinizle iletişim yeterli mi?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Hedefler yeterince net tanımlanıyor mu?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Şirkete olan bağlılık düzeyiniz nedir?', type: 'scale10', hint: '0: düşük · 10: yüksek' },
      ],
    },
    {
      title: 'Q2 Çalışan Memnuniyeti',
      description: 'İkinci çeyrek genel değerlendirme.',
      emoji: '📊',
      status: 'closed',
      minNThreshold: 3,
      deadline: pastDate(5),
      questions: [
        { id: uuid(), text: 'Bu çeyreği genel olarak nasıl değerlendirirsiniz?', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Yöneticin destek sağladı mı?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Şirketi bir arkadaşına tavsiye eder misin?', type: 'scale10', hint: '0-10' },
      ],
    },
  ],
  garanti_bbva: [
    {
      title: 'Hibrit Çalışma Modeli Değerlendirmesi',
      description: 'Hibrit çalışma uygulamasına ilişkin çalışan görüşleri.',
      emoji: '🏠',
      status: 'active',
      minNThreshold: 5,
      deadline: futureDate(7),
      questions: [
        { id: uuid(), text: 'Hibrit çalışma modelinden ne kadar memnunsunuz?', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Ofis günleriniz verimli geçiyor mu?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Haftada kaç gün ofise gelmek istersiniz? (0-10)', type: 'scale10', hint: '' },
        { id: uuid(), text: 'Uzaktan çalışırken konsantre olabiliyor musunuz?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Genel iş-yaşam dengenizi değerlendirin.', type: 'emoji5', hint: '' },
      ],
    },
    {
      title: 'İK Eğitim İhtiyaç Analizi',
      description: 'Çalışanların gelişim ve eğitim beklentileri.',
      emoji: '🎓',
      status: 'active',
      minNThreshold: 5,
      deadline: futureDate(30),
      questions: [
        { id: uuid(), text: 'Kariyer gelişimi için yeterli fırsat sunuluyor mu?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Hangi alanda eğitim almak istersiniz?', type: 'text', hint: 'Birden fazla alan yazabilirsiniz.' },
        { id: uuid(), text: 'Mevcut yetkinlik düzeyi yeterli mi?', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Eğitim programlarına katılım istekliliğiniz?', type: 'scale10', hint: '' },
      ],
    },
  ],
  turkcell: [
    {
      title: 'Yönetici Liderlik Değerlendirmesi',
      description: 'Yöneticilerin liderlik becerilerine ilişkin anonim geri bildirim.',
      emoji: '🤝',
      status: 'active',
      minNThreshold: 5,
      deadline: futureDate(14),
      questions: [
        { id: uuid(), text: 'Yöneticiniz açık ve net iletişim kuruyor mu?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Yöneticinizin liderlik tarzını değerlendirin.', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Yöneticinize güven düzeyiniz nedir?', type: 'scale10', hint: '' },
        { id: uuid(), text: 'Yöneticinizden yeterli geri bildirim alıyor musunuz?', type: 'yesno', hint: '' },
      ],
    },
    {
      title: 'Çalışan Bağlılık Endeksi',
      description: 'Çalışanların şirkete bağlılık düzeyini ölçen kapsamlı anket.',
      emoji: '❤️',
      status: 'active',
      minNThreshold: 5,
      deadline: futureDate(20),
      questions: [
        { id: uuid(), text: 'Şirketimizde uzun vadeli kariyer planı yapıyor musunuz?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Şirkete bağlılık düzeyinizi belirtin.', type: 'scale10', hint: '' },
        { id: uuid(), text: 'Çalışma ortamından memnuniyetiniz?', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Şirketi bir arkadaşınıza iş yeri olarak tavsiye eder misiniz?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Önümüzdeki 1 yılda burada çalışmaya devam etmeyi düşünüyor musunuz?', type: 'yesno', hint: '' },
      ],
    },
  ],
  akbank: [
    {
      title: 'Dijital Bankacılık Operasyon Anketi',
      description: 'Dijital dönüşüm sürecindeki çalışan deneyimi.',
      emoji: '🏦',
      status: 'active',
      minNThreshold: 5,
      deadline: futureDate(15),
      questions: [
        { id: uuid(), text: 'Yeni dijital sistemlere adaptasyon süreciniz nasıl gitti?', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Teknik destek ekibinden yeterli yardım aldınız mı?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Yeni sistemler iş verimliliğinizi artırdı mı?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Genel dijital dönüşüm sürecini değerlendirin.', type: 'scale10', hint: '0: çok zor · 10: çok kolay' },
      ],
    },
    {
      title: 'Fiziksel Çalışma Ortamı Değerlendirmesi',
      description: 'Ofis ortamı ve ergonomi hakkında çalışan görüşleri.',
      emoji: '🪑',
      status: 'active',
      minNThreshold: 3,
      deadline: futureDate(25),
      questions: [
        { id: uuid(), text: 'Çalışma masanız ve ekipmanlarınız yeterli mi?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Ofis ortamının genel konforunu değerlendirin.', type: 'emoji5', hint: '' },
        { id: uuid(), text: 'Toplantı odası kapasitesi yeterli mi?', type: 'yesno', hint: '' },
        { id: uuid(), text: 'Ofis ortamına genel memnuniyet puanınız?', type: 'scale10', hint: '' },
      ],
    },
  ],
}

// ── Response generators ───────────────────────────────────────────────────────

function generateAnswer(question) {
  switch (question.type) {
    case 'emoji5':
      return Math.floor(Math.random() * 5)         // 0–4
    case 'yesno':
      return Math.random() > 0.35                   // ~65% yes
    case 'scale10':
      return Math.floor(Math.random() * 11)         // 0–10
    case 'text':
      const textOptions = [
        'Liderlik ve yönetim becerileri',
        'Teknik beceriler ve yazılım araçları',
        'İletişim ve sunum',
        'Proje yönetimi',
        'Veri analizi',
      ]
      return textOptions[Math.floor(Math.random() * textOptions.length)]
    default:
      return 0
  }
}

function generateResponses(questions) {
  const answers = {}
  for (const q of questions) {
    answers[q.id] = generateAnswer(q)
  }
  return answers
}

// ── Main seeding logic ────────────────────────────────────────────────────────

async function seedSurveys() {
  console.log('🌱 PoM survey seed başlıyor…\n')

  const allSurveyRefs = []  // { ref, survey, companyId }

  // 1. Admin (platform-wide) surveys
  console.log('📢 Platform anketleri ekleniyor…')
  for (const s of ADMIN_SURVEYS) {
    const ref = await db.collection('surveys').add({
      ...s,
      responseCount: 0,
      created_at: ts(),
      updated_at: ts(),
    })
    allSurveyRefs.push({ ref, survey: s, companyId: '__admin__' })
    console.log(`  ✓ [__admin__] ${s.title}`)
  }

  // 2. Company surveys
  console.log('\n🏢 Şirket anketleri ekleniyor…')
  for (const [companyId, surveys] of Object.entries(COMPANY_SURVEYS)) {
    for (const s of surveys) {
      const ref = await db.collection('surveys').add({
        ...s,
        companyId,
        responseCount: 0,
        created_at: ts(),
        updated_at: ts(),
      })
      allSurveyRefs.push({ ref, survey: s, companyId })
      console.log(`  ✓ [${companyId}] ${s.title}`)
    }
  }

  // 3. Simulate responses from debug users for active surveys
  console.log('\n👤 Kullanıcı yanıtları simüle ediliyor…')

  for (const { ref: surveyRef, survey, companyId } of allSurveyRefs) {
    if (survey.status !== 'active') continue

    // Find eligible debug users
    const eligibleUsers = DEBUG_USERS.filter(
      (u) => companyId === '__admin__' || u.companyId === companyId,
    )

    // Each user has a 70% chance of having answered
    const responders = eligibleUsers.filter(() => Math.random() < 0.7)

    for (const user of responders) {
      const answers = generateResponses(survey.questions)
      await db.collection('survey_responses').add({
        surveyId: surveyRef.id,
        companyId,
        userIdHash: hashUid(user.uid),
        answers,
        created_at: pastDate(Math.floor(Math.random() * 7)),
      })
    }

    // Add 10–40 simulated anonymous responses
    const anonCount = Math.floor(Math.random() * 31) + 10
    for (let i = 0; i < anonCount; i++) {
      const fakeUid = `anon_${companyId}_${i}_${Date.now()}`
      await db.collection('survey_responses').add({
        surveyId: surveyRef.id,
        companyId,
        userIdHash: hashUid(fakeUid),
        answers: generateResponses(survey.questions),
        created_at: pastDate(Math.floor(Math.random() * 14)),
      })
    }

    // Update responseCount on the survey
    const totalResponses = responders.length + anonCount
    await surveyRef.update({ responseCount: totalResponses })
    console.log(
      `  ✓ ${survey.title}: ${totalResponses} yanıt (${responders.length} debug + ${anonCount} anonim)`,
    )
  }

  console.log('\n✅ Seed tamamlandı!')
  console.log('\nKullanıcı hash değerleri (debug için):')
  for (const u of DEBUG_USERS) {
    console.log(`  ${u.uid} (${u.displayName}) → ${hashUid(u.uid).slice(0, 16)}…`)
  }
}

seedSurveys().catch(console.error).finally(() => process.exit())
