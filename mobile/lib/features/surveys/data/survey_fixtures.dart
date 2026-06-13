// DEBUG-ONLY survey fixtures.
//
// These power a rich, above-threshold evaluation experience when the app runs
// in auth-bypass debug builds (`kDebugMode && AppConstants.debugBypassAuth`),
// where there is no Firebase auth and the real survey / aggregate / benchmark
// documents cannot be read from Firestore. They are wired in ONLY behind that
// bypass guard (see surveys_provider.dart and auth_provider.dart kDebugUsers),
// so production builds never reference this data.
//
// The numbers are synthetic but internally consistent: the personal answers
// score to ~3.7 overall, the company/department aggregates clear the min-N
// thresholds, and the cross-company benchmark carries five sample companies and
// a sector — enough to exercise every survey-insight screen.

import 'survey_aggregate.dart';
import 'survey_benchmark.dart';
import 'survey_model.dart';

/// Synthetic gate-survey id used by the fixtures.
const kFixtureGateSurveyId = 'fixture_gate_survey';

/// The 12 experience categories. Shared verbatim across the survey questions,
/// the personal result, the company/sector aggregate and the benchmark so the
/// per-category comparison bars line up by name.
const kFixtureCategories = <String>[
  'İş Yükü ve Denge',
  'Yönetim ve Liderlik',
  'Takım ve İşbirliği',
  'Kariyer ve Gelişim',
  'Tanınma ve Takdir',
  'Ücret ve Yan Haklar',
  'İletişim ve Şeffaflık',
  'Özerklik ve Katılım',
  'Araçlar ve Kaynaklar',
  'Kurum Kültürü ve Değerler',
  'Refah ve Destek',
  'Anlam ve Amaç',
];

/// Personal answers per category — two scale5 values whose mean is the personal
/// score for that category. Tuned for a believable profile: strongest = Takım /
/// Kültür (4.5), weakest = Ücret (2.5), overall ≈ 3.7 (band "Yüksek").
const _personalAnswers = <List<int>>[
  [3, 4], // İş Yükü ve Denge      → 3.5
  [4, 4], // Yönetim ve Liderlik   → 4.0
  [5, 4], // Takım ve İşbirliği    → 4.5
  [3, 3], // Kariyer ve Gelişim    → 3.0
  [4, 3], // Tanınma ve Takdir     → 3.5
  [2, 3], // Ücret ve Yan Haklar   → 2.5
  [4, 4], // İletişim ve Şeffaflık → 4.0
  [4, 4], // Özerklik ve Katılım   → 4.0
  [3, 4], // Araçlar ve Kaynaklar  → 3.5
  [5, 4], // Kurum Kültürü         → 4.5
  [4, 3], // Refah ve Destek       → 3.5
  [4, 4], // Anlam ve Amaç         → 4.0
];

const _enpsQuestionId = 'gq_enps';

List<SurveyQuestion> _buildQuestions() {
  final qs = <SurveyQuestion>[];
  for (var c = 0; c < kFixtureCategories.length; c++) {
    final cat = kFixtureCategories[c];
    qs.add(SurveyQuestion(
      id: 'gq_${c}_0',
      text: '$cat alanında genel memnuniyetin nedir?',
      type: SurveyQuestionType.scale5,
      category: cat,
    ));
    qs.add(SurveyQuestion(
      id: 'gq_${c}_1',
      text: '$cat konusunda beklentilerin karşılanıyor mu?',
      type: SurveyQuestionType.scale5,
      category: cat,
    ));
  }
  qs.add(const SurveyQuestion(
    id: _enpsQuestionId,
    text: 'PoM\'u bir arkadaşına tavsiye etme olasılığın nedir? (0–10)',
    type: SurveyQuestionType.scale10,
    isEnps: true,
  ));
  return qs;
}

/// The synthetic gate survey (48-question stand-in: 24 categorized + eNPS).
final kFixtureGateSurvey = SurveyModel(
  id: kFixtureGateSurveyId,
  companyId: '__admin__',
  title: 'Genel Çalışan Deneyimi Anketi',
  description: 'Çalışan deneyimini 12 boyutta ölçen genel anket (demo verisi).',
  emoji: '📋',
  status: SurveyStatus.active,
  questions: _buildQuestions(),
  minNThreshold: 15,
  responseCount: 412,
  createdAt: DateTime(2026, 5, 1),
);

/// The current user's own answers to [kFixtureGateSurvey] — baked into each
/// debug persona so the personal result, home card and result screen render.
final kFixtureGateAnswers = <String, dynamic>{
  for (var c = 0; c < kFixtureCategories.length; c++) ...{
    'gq_${c}_0': _personalAnswers[c][0],
    'gq_${c}_1': _personalAnswers[c][1],
  },
  _enpsQuestionId: 9, // promoter
};

// ── Aggregate (company / department / sector) ────────────────────────────────

/// Company-average per-category profile (distinct from personal so the bars
/// differ). Mean ≈ 3.5.
const _companyCats = <String, double>{
  'İş Yükü ve Denge': 3.3,
  'Yönetim ve Liderlik': 3.7,
  'Takım ve İşbirliği': 4.1,
  'Kariyer ve Gelişim': 3.2,
  'Tanınma ve Takdir': 3.4,
  'Ücret ve Yan Haklar': 2.9,
  'İletişim ve Şeffaflık': 3.6,
  'Özerklik ve Katılım': 3.5,
  'Araçlar ve Kaynaklar': 3.4,
  'Kurum Kültürü ve Değerler': 4.0,
  'Refah ve Destek': 3.3,
  'Anlam ve Amaç': 3.8,
};

const _sectorCats = <String, double>{
  'İş Yükü ve Denge': 3.1,
  'Yönetim ve Liderlik': 3.5,
  'Takım ve İşbirliği': 3.8,
  'Kariyer ve Gelişim': 3.1,
  'Tanınma ve Takdir': 3.2,
  'Ücret ve Yan Haklar': 3.0,
  'İletişim ve Şeffaflık': 3.4,
  'Özerklik ve Katılım': 3.3,
  'Araçlar ve Kaynaklar': 3.3,
  'Kurum Kültürü ve Değerler': 3.7,
  'Refah ve Destek': 3.2,
  'Anlam ve Amaç': 3.6,
};

Map<String, double> _shiftCats(Map<String, double> base, double delta) =>
    base.map((k, v) => MapEntry(k, (v + delta).clamp(1.0, 5.0)));

/// All department names used by the debug personas, each above the dept min-N.
GroupAgg _dept(double overall, int n, int enps) => GroupAgg(
      n: n,
      locked: false,
      overall: overall,
      categories: _shiftCats(_companyCats, overall - 3.5),
      enps: enps,
    );

final _fixtureDepartments = <String, GroupAgg>{
  'Ürün': _dept(3.7, 22, 28),
  'Pazarlama': _dept(3.4, 18, 16),
  'İnsan Kaynakları': _dept(3.8, 14, 33),
  'Teknoloji': _dept(3.6, 26, 24),
  'Satış': _dept(3.2, 19, 8),
  'Operasyon': _dept(3.3, 15, 12),
};

/// Above-threshold aggregate for any company/department (the comparison view is
/// Sen vs Şirket vs Sektör, so the same generic aggregate serves every persona).
SurveyAggregate fixtureAggregate(String companyId) => SurveyAggregate(
      surveyId: kFixtureGateSurveyId,
      companyId: companyId,
      companyMinN: 15,
      departmentMinN: 10,
      company: GroupAgg(
        n: 87,
        locked: false,
        overall: 3.5,
        categories: _companyCats,
        enps: 22,
      ),
      departments: _fixtureDepartments,
      sector: SectorAgg(
        industry: 'Bankacılık',
        nCompanies: 5,
        n: 555,
        locked: false,
        overall: 3.4,
        categories: _sectorCats,
        enps: 18,
      ),
    );

// ── Cross-company benchmark ──────────────────────────────────────────────────

BenchGroup _company(String key, String label, double overall, int enps, int n) =>
    BenchGroup(
      key: key,
      label: label,
      industry: 'Bankacılık',
      n: n,
      overall: overall,
      categories: _shiftCats(_companyCats, overall - 3.5),
      enps: enps,
    );

/// Five sample companies + sector for the "Şirket Karşılaştırması" view.
final kFixtureBenchmark = SurveyBenchmark(
  surveyId: kFixtureGateSurveyId,
  companyMinN: 15,
  companies: [
    _company('ziraat', 'Ziraat Bankası', 3.95, 38, 210),
    _company('garanti_bbva', 'Garanti BBVA', 3.91, 34, 120),
    _company('is_bankasi', 'İş Bankası', 3.37, 12, 95),
    _company('yapi_kredi', 'Yapı Kredi', 3.26, 8, 70),
    _company('akbank', 'Akbank', 2.84, -10, 60),
  ],
  sectors: {
    'Bankacılık': BenchGroup(
      key: 'Bankacılık',
      label: 'Bankacılık sektörü',
      industry: 'Bankacılık',
      n: 555,
      overall: 3.4,
      categories: _sectorCats,
      enps: 18,
    ),
  },
);
