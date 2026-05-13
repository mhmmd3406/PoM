'use strict';

/**
 * Maps a raw LinkedIn job title to a PoM Business Family.
 *
 * Business Families
 *   Branch  → Ops | Sales/Mkt
 *   HQ      → IT | Ops | Credit/Mkt | Treasury/Finance | Legal/Other
 *
 * Returns: { businessFamily, departmentType, seniorityLevel }
 */

// ---------------------------------------------------------------------------
// Keyword tables — ordered from most-specific to least-specific per family
// ---------------------------------------------------------------------------

const BRANCH_SIGNALS = [
  // English
  'branch',
  'teller',
  'cashier',
  'counter service',
  'front office',
  'retail banking',
  'personal banking',
  // Turkish
  'şube',       // branch
  'vezne',      // teller desk
  'bireysel',   // retail/personal (branch context)
];

const FAMILIES = [
  // --- HQ: IT ---
  {
    family: 'IT',
    departmentType: 'HQ',
    keywords: [
      'software engineer',
      'software developer',
      'frontend',
      'backend',
      'fullstack',
      'full stack',
      'data engineer',
      'data scientist',
      'data analyst',
      'machine learning',
      'ml engineer',
      'devops',
      'devsecops',
      'cloud engineer',
      'cloud architect',
      'solutions architect',
      'enterprise architect',
      'cybersecurity',
      'information security',
      'infosec',
      'network engineer',
      'systems engineer',
      'infrastructure',
      'platform engineer',
      'sre',
      'site reliability',
      'qa engineer',
      'quality assurance',
      'test engineer',
      'it manager',
      'it director',
      'cto',
      'chief technology',
      'chief information',
      'cio',
      'digital transformation',
      'digital banking',
      'mobile developer',
      'ios developer',
      'android developer',
      'database administrator',
      'dba',
      'business analyst',  // in tech context — refined below by branch signals
      'product manager',   // in tech context
      'scrum master',
      'agile coach',
      'blockchain',
      'api developer',
      // Turkish IT titles
      'yazılım mühendisi',
      'yazılım geliştirici',
      'yazılım uzmanı',
      'veri bilimci',
      'veri mühendisi',
      'veri analisti',
      'siber güvenlik',
      'bilgi güvenliği',
      'sistem yöneticisi',
      'ağ mühendisi',
      'altyapı uzmanı',
      'bilgi işlem',        // IT department
      'uygulama geliştirici',
      'mobil geliştirici',
      'test mühendisi',
      'kalite güvence',
      'dijital dönüşüm',
      'dijital bankacılık',
      'yapay zeka',
      'makine öğrenmesi',
    ],
  },

  // --- HQ: Treasury / Finance ---
  {
    family: 'Treasury/Finance',
    departmentType: 'HQ',
    keywords: [
      'treasury',
      'asset management',
      'fund manager',
      'portfolio manager',
      'investment banking',
      'capital markets',
      'fixed income',
      'derivatives',
      'forex',
      'fx trader',
      'equity trader',
      'quantitative analyst',
      'quant',
      'financial analyst',
      'financial controller',
      'cfo',
      'chief financial',
      'finance manager',
      'budget analyst',
      'accounting',
      'accountant',
      'actuarial',
      'actuary',
      'liquidity',
      'alm',  // asset-liability management
      'market risk',
      // Turkish Treasury/Finance titles
      'portföy yönetmeni',   // Portfolio Manager
      'portföy yöneticisi',
      'hazine',              // Treasury
      'varlık yönetimi',     // Asset Management
      'sermaye piyasaları',  // Capital Markets
      'sabit getirili',      // Fixed Income
      'türev ürünler',       // Derivatives
      'finansal analist',    // Financial Analyst
      'mali işler',          // Finance/Accounting
      'muhasebe',            // Accounting
      'muhasebeci',
      'bütçe',               // Budget
      'aktüer',              // Actuary
      'likidite',            // Liquidity
      'piyasa riski',        // Market Risk
      'yatırım bankacılığı', // Investment Banking
      'kurumsal finansman',  // Corporate Finance
      'özel sermaye',        // Private Equity
    ],
  },

  // --- HQ: Credit / Marketing ---
  {
    family: 'Credit/Mkt',
    departmentType: 'HQ',
    keywords: [
      'credit analyst',
      'credit risk',
      'credit officer',
      'loan officer',        // HQ origination — branch loan officers mapped below
      'underwriter',
      'underwriting',
      'mortgage analyst',
      'corporate banking',
      'commercial banking',
      'product marketing',
      'marketing manager',
      'brand manager',
      'digital marketing',
      'growth hacker',
      'seo',
      'content strategist',
      'communications manager',
      'public relations',
      'campaign manager',
      // Turkish Credit/Marketing titles
      'kredi analisti',       // Credit Analyst
      'kredi riski',          // Credit Risk
      'kredi yöneticisi',     // Credit Manager
      'kredi yönetmeni',
      'kredi tahsis',         // Credit Allocation
      'kredi değerlendirme',
      'krediler',
      'ticari kredi',
      'bireysel kredi',
      'ipotek',               // Mortgage
      'konut kredisi',
      'kurumsal bankacılık',  // Corporate Banking
      'ticari bankacılık',    // Commercial Banking
      'kurumsal pazarlama',
      'pazarlama müdürü',
      'pazarlama yöneticisi',
      'ürün yöneticisi',      // Product Manager (marketing context)
      'marka yöneticisi',     // Brand Manager
      'dijital pazarlama',    // Digital Marketing
      'kampanya yöneticisi',
      'müşteri segmentasyonu',
    ],
  },

  // --- HQ: Legal / Other ---
  {
    family: 'Legal/Other',
    departmentType: 'HQ',
    keywords: [
      'legal',
      'counsel',
      'attorney',
      'solicitor',
      'barrister',
      'compliance officer',
      'aml',
      'kyc',
      'regulatory',
      'risk manager',         // non-market risk
      'operational risk',
      'internal audit',
      'human resources',
      'hr manager',
      'hr business partner',
      'talent acquisition',
      'recruiter',
      'learning and development',
      'l&d',
      'organizational',
      'admin',
      'executive assistant',
      'office manager',
      'facilities',
      'procurement',
      'vendor management',
      'strategy',
      'corporate strategy',
      'management consultant',
      // Turkish Legal/Audit/HR titles — Müfettiş burada çünkü iç denetim/teftiş
      'müfettiş',            // Inspector → Internal Audit
      'başmüfettiş',         // Chief Inspector
      'teftiş',              // Inspection/Audit department
      'iç denetim',          // Internal Audit
      'iç denetçi',
      'denetçi',             // Auditor
      'iç kontrol',          // Internal Control
      'uyum',                // Compliance
      'uyum yöneticisi',
      'hukuk',               // Legal
      'hukuk müşaviri',      // Legal Counsel
      'avukat',              // Attorney
      'risk yönetimi',       // Risk Management
      'operasyonel risk',    // Operational Risk
      'mevzuat',             // Regulatory
      'regülasyon',
      'insan kaynakları',    // Human Resources
      'i̇nsan kaynakları',
      'ik müdürü',
      'yetenek yönetimi',    // Talent Management
      'işe alım',            // Recruitment
      'eğitim ve gelişim',   // L&D
      'idari işler',         // Administrative
      'satın alma',          // Procurement
      'strateji',            // Strategy
      'kurumsal strateji',
    ],
  },

  // --- HQ: Ops ---
  {
    family: 'Ops',
    departmentType: 'HQ',
    keywords: [
      'operations manager',
      'operations director',
      'hq operations',
      'central operations',
      'process improvement',
      'process excellence',
      'lean six sigma',
      'business operations',
      'project manager',
      'program manager',
      'change management',
      'transformation',
      // Turkish HQ Ops titles
      'operasyon müdürü',    // Operations Manager
      'operasyon yöneticisi',
      'süreç yönetimi',      // Process Management
      'süreç iyileştirme',   // Process Improvement
      'proje yöneticisi',    // Project Manager
      'program yöneticisi',
      'değişim yönetimi',    // Change Management
      'merkezi operasyon',   // Central Operations
    ],
  },

  // --- Branch: Sales / Marketing ---
  {
    family: 'Sales/Mkt',
    departmentType: 'Branch',
    keywords: [
      'relationship manager',
      'customer relationship',
      'client advisor',
      'financial advisor',
      'wealth advisor',
      'private banker',
      'mortgage advisor',
      'loan advisor',
      'sales representative',
      'sales officer',
      'branch sales',
      'insurance advisor',
      'bancassurance',
      // Turkish Branch Sales titles
      'müşteri ilişkileri yöneticisi', // Relationship Manager
      'müşteri ilişkileri yönetmeni',
      'müşteri temsilcisi',            // Customer Representative (sales)
      'bireysel bankacılık danışmanı', // Retail Banking Advisor
      'özel bankacılık',               // Private Banking
      'özel bankacı',
      'finansal danışman',             // Financial Advisor
      'yatırım danışmanı',             // Investment Advisor
      'portföy danışmanı',             // Portfolio Advisor (branch-level)
      'sigorta danışmanı',             // Insurance Advisor
      'konut kredisi danışmanı',       // Mortgage Advisor
      'satış uzmanı',                  // Sales Specialist
    ],
  },

  // --- Branch: Ops (catch-all for branch-level roles) ---
  {
    family: 'Ops',
    departmentType: 'Branch',
    keywords: [
      'branch manager',
      'branch operations',
      'branch supervisor',
      'teller',
      'cashier',
      'customer service',
      'service officer',
      'back office',
      // Turkish Branch Ops titles
      'şube müdürü',         // Branch Manager
      'şube operasyon',      // Branch Operations
      'şube yöneticisi',
      'veznedar',            // Teller
      'kasiyer',             // Cashier
      'müşteri hizmetleri',  // Customer Service
      'gişe yetkilisi',      // Counter Officer
      'arka ofis',           // Back Office
      'operasyon yetkilisi', // Operations Officer (branch)
    ],
  },
];

// ---------------------------------------------------------------------------
// Seniority mapping
// ---------------------------------------------------------------------------

const SENIORITY_LEVELS = [
  {
    level: 'exec',
    keywords: [
      // English
      'chief', 'ceo', 'cto', 'cio', 'cfo', 'coo', 'cro',
      'managing director', 'md',
      'executive vice president', 'evp',
      'senior vice president', 'svp',
      'vice president', 'vp',
      'director',
      'head of',
      'head,',
      // Turkish exec
      'genel müdür',              // General Manager / CEO
      'genel müdür yardımcısı',   // Deputy GM
      'başkan',                   // President / Chairman
      'yönetim kurulu',           // Board Member
      'icra kurulu',              // Executive Board
      'grup başkanı',             // Group Head
      'bölüm başkanı',            // Division Head
      'direktör',                 // Director
      'baş mühendis',             // Chief Engineer (space prevents matching 'başmüfettiş')
      'baş ekonomist',
      'baş analist',
    ],
  },
  {
    level: 'senior',
    keywords: [
      // English
      'senior', 'sr.', 'sr ', 'lead', 'principal',
      'manager', 'supervisor', 'team lead', 'specialist',
      // Turkish senior
      'kıdemli',      // Senior
      'müdür',        // Manager (almost always senior level in TR banks)
      'yönetici',     // Manager/Executive (mid-exec range)
      'yönetmen',     // Manager variant
      'uzman',        // Specialist/Expert
      'başuzman',     // Senior Specialist
      'sorumlu',      // In-charge / Responsible
      'şef',          // Chief/Supervisor (team level)
      'başmüfettiş',  // Chief Inspector (compound word, not C-suite)
      'başdenetçi',   // Chief Auditor (compound)
    ],
  },
  {
    level: 'junior',
    keywords: [
      // English
      'junior', 'jr.', 'jr ', 'associate', 'graduate',
      'intern', 'trainee', 'entry level', 'entry-level', 'apprentice',
      // Turkish junior
      'stajyer',      // Intern
      'asistan',      // Assistant
      'yardımcı',     // Assistant/Deputy (junior connotation)
      'memur',        // Clerk (entry-level in Turkish banks)
      'personel',     // Staff (generic entry-level)
    ],
  },
];

// ---------------------------------------------------------------------------
// Core mapping logic
// ---------------------------------------------------------------------------

/**
 * Checks whether a normalized title contains a keyword.
 *
 * Uses regex \b word boundaries ONLY for short pure-ASCII acronyms (≤4 chars,
 * no spaces, only [a-z0-9]). This prevents 'cto' matching inside 'director'
 * while avoiding broken boundaries for Turkish characters (JS \w is ASCII-only,
 * so \b breaks on 'ö', 'ş', 'ü', etc. and on Turkish morphological suffixes
 * like 'yönetmeni' vs keyword 'yönetmen').
 */
function titleIncludes(normalizedTitle, keyword) {
  const isShortAsciiAcronym =
    keyword.length <= 4 && !keyword.includes(' ') && /^[a-z0-9]+$/.test(keyword);
  if (isShortAsciiAcronym) {
    return new RegExp(`\\b${keyword}\\b`).test(normalizedTitle);
  }
  return normalizedTitle.includes(keyword);
}

/**
 * @param {string} title - Raw LinkedIn job title
 * @returns {{ businessFamily: string, departmentType: string, seniorityLevel: string }}
 */
function mapTitleToBusinessFamily(title) {
  if (!title || typeof title !== 'string') {
    return { businessFamily: 'Legal/Other', departmentType: 'HQ', seniorityLevel: 'mid' };
  }

  // Replace Turkish dotted-I (İ, U+0130) with plain 'i' BEFORE toLowerCase().
  // This fixes the JS default behavior where "İ".toLowerCase() = "i̇"
  // (two codepoints: i + combining dot), breaking keyword matches.
  // We do NOT use toLocaleLowerCase('tr') because that maps English 'I' → 'ı'
  // (dotless i), which breaks English keywords like 'information' → 'ınformation'.
  const normalized = title.replace(/İ/g, 'i').toLowerCase().trim();
  const isBranchRole = BRANCH_SIGNALS.some((sig) => titleIncludes(normalized, sig));

  // Find best matching family
  let matched = null;

  for (const entry of FAMILIES) {
    // If we already detected a branch signal, skip HQ-only families for ambiguous terms
    if (isBranchRole && entry.departmentType === 'HQ') {
      const directHqSignals = ['hq', 'central', 'corporate', 'group', 'headquarters'];
      const hasDirectHqSignal = directHqSignals.some((s) => titleIncludes(normalized, s));
      if (!hasDirectHqSignal && entry.family !== 'IT') {
        // IT is unambiguous even in branch buildings — skip other HQ families
        // unless there's an explicit HQ signal
        const isItRole = FAMILIES[0].keywords.some((k) => titleIncludes(normalized, k));
        if (!isItRole) continue;
      }
    }

    const hit = entry.keywords.find((kw) => titleIncludes(normalized, kw));
    if (hit) {
      matched = entry;
      break; // FAMILIES is ordered most-specific → least-specific
    }
  }

  // Determine seniority
  let seniorityLevel = 'mid';
  for (const { level, keywords } of SENIORITY_LEVELS) {
    if (keywords.some((kw) => titleIncludes(normalized, kw))) {
      seniorityLevel = level;
      break;
    }
  }

  if (!matched) {
    return { businessFamily: 'Legal/Other', departmentType: 'HQ', seniorityLevel };
  }

  return {
    businessFamily: matched.family,
    departmentType: matched.departmentType,
    seniorityLevel,
  };
}

module.exports = { mapTitleToBusinessFamily };
