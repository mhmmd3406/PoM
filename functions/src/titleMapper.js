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
  'branch',
  'teller',
  'cashier',
  'counter service',
  'front office',  // branch context only when paired with retail signals
  'retail banking',
  'personal banking',
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
      'chief', 'ceo', 'cto', 'cio', 'cfo', 'coo', 'cro',
      'managing director', 'md',
      'executive vice president', 'evp',
      'senior vice president', 'svp',
      'vice president', 'vp',
      'director',
      'head of',
      'head,',
    ],
  },
  {
    level: 'senior',
    keywords: [
      'senior',
      'sr.',
      'sr ',
      'lead',
      'principal',
      'manager',
      'supervisor',
      'team lead',
      'specialist',
    ],
  },
  {
    level: 'junior',
    keywords: [
      'junior',
      'jr.',
      'jr ',
      'associate',
      'graduate',
      'intern',
      'trainee',
      'entry level',
      'entry-level',
      'apprentice',
    ],
  },
];

// ---------------------------------------------------------------------------
// Core mapping logic
// ---------------------------------------------------------------------------

/**
 * Checks whether a normalized title contains a keyword.
 * For single-word keywords (acronyms like 'cto', 'cio') uses word boundaries
 * to avoid false substring matches (e.g. 'cto' inside 'director').
 */
function titleIncludes(normalizedTitle, keyword) {
  if (!keyword.includes(' ')) {
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

  const normalized = title.toLowerCase().trim();
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
