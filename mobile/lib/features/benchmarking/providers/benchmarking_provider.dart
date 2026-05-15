import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/benchmarking_repository.dart';

// ─── Company search ───────────────────────────────────────────────────────────

final companySearchQueryProvider = StateProvider<String>((ref) => '');

final companySearchResultsProvider =
    FutureProvider.autoDispose<List<CompanySummary>>((ref) async {
  final query = ref.watch(companySearchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repo = ref.watch(benchmarkingRepositoryProvider);
  return repo.searchCompanies(query);
});

// ─── Selected companies for comparison ───────────────────────────────────────

final selectedCompanyAProvider =
    StateProvider<CompanySummary?>((ref) => null);

final selectedCompanyBProvider =
    StateProvider<CompanySummary?>((ref) => null);

// ─── Active slot being filled (A or B) ───────────────────────────────────────

final activeSlotProvider = StateProvider<String>((ref) => 'A');
