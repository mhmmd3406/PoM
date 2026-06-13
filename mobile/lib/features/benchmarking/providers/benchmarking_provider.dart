import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/benchmarking_repository.dart';

// Mock companies used in debug-bypass mode.
const _mockCompanies = [
  CompanySummary(
    id: 'garanti_bbva',
    name: 'Garanti BBVA',
    industry: 'Bankacılık',
    n: 73,
    scores: {
      'overallMood': 3.9,
      'workStress': 3.4,
      'teamHarmony': 4.1,
      'personalGrowth': 3.7,
      'workLifeBalance': 3.2,
    },
  ),
  CompanySummary(
    id: 'is_bankasi',
    name: 'İş Bankası',
    industry: 'Bankacılık',
    n: 68,
    scores: {
      'overallMood': 3.7,
      'workStress': 3.2,
      'teamHarmony': 3.8,
      'personalGrowth': 3.5,
      'workLifeBalance': 3.0,
    },
  ),
  CompanySummary(
    id: 'akbank',
    name: 'Akbank',
    industry: 'Bankacılık',
    n: 71,
    scores: {
      'overallMood': 4.0,
      'workStress': 3.6,
      'teamHarmony': 4.2,
      'personalGrowth': 3.9,
      'workLifeBalance': 3.5,
    },
  ),
  CompanySummary(
    id: 'yapi_kredi',
    name: 'Yapı Kredi',
    industry: 'Bankacılık',
    n: 65,
    scores: {
      'overallMood': 3.6,
      'workStress': 3.1,
      'teamHarmony': 3.7,
      'personalGrowth': 3.4,
      'workLifeBalance': 2.9,
    },
  ),
  CompanySummary(
    id: 'ziraat_bankasi',
    name: 'Ziraat Bankası',
    industry: 'Bankacılık',
    n: 70,
    scores: {
      'overallMood': 3.8,
      'workStress': 3.3,
      'teamHarmony': 3.9,
      'personalGrowth': 3.6,
      'workLifeBalance': 3.3,
    },
  ),
];

// Selected period: '30d' | '90d' | 'all'
final selectedPeriodProvider = StateProvider<String>((ref) => '90d');

// All selected companies for comparison (max 6).
final selectedCompaniesProvider =
    StateProvider<List<CompanySummary>>((ref) => []);

// ─── Genel Anket karşılaştırma hedef seçimi ───────────────────────────────────
// Sektör ortalamasını kıyasa ekle.
final surveyIncludeSectorProvider = StateProvider<bool>((ref) => false);
// "Tümü": seçili şirketler yerine min-N geçen TÜM şirketleri kıyasla.
final surveyShowAllProvider = StateProvider<bool>((ref) => false);

// ─── Company search ──────────────────────────────────────────────────────────

final companySearchQueryProvider = StateProvider<String>((ref) => '');

final companySearchResultsProvider =
    FutureProvider.autoDispose<List<CompanySummary>>((ref) async {
  final query = ref.watch(companySearchQueryProvider);
  if (query.trim().isEmpty) return [];

  if (kDebugMode && AppConstants.debugBypassAuth) {
    final q = query.toLowerCase();
    return _mockCompanies
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  final repo = ref.watch(benchmarkingRepositoryProvider);
  return repo.searchCompanies(query);
});
