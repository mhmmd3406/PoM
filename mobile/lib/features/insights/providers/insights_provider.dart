import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/insights_repository.dart';

// Mock insight returned in debug-bypass mode so the screen works without
// a real Firebase Auth session or seeded data for the test user.
final _mockInsight = InsightModel(
  uid: 'test_user_001',
  personalScores: const {
    'overallMood': 4.0,
    'workStress': 3.5,
    'teamHarmony': 4.2,
    'personalGrowth': 3.8,
    'workLifeBalance': 3.2,
  },
  companyScores: const {
    'overallMood': 3.8,
    'workStress': 3.2,
    'teamHarmony': 3.9,
    'personalGrowth': 3.5,
    'workLifeBalance': 3.0,
  },
  benchmarkScores: null,
  updatedAt: DateTime(2026, 5, 17),
  companyId: 'garanti_bbva',
  totalCheckins: 8,
  trend: 1,
);

final insightsStreamProvider = StreamProvider.autoDispose<InsightModel?>((ref) {
  // In debug bypass mode, return mock data — no Firebase Auth session exists.
  if (kDebugMode && AppConstants.debugBypassAuth) {
    return Stream.value(_mockInsight);
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.empty();

  final repo = ref.watch(insightsRepositoryProvider);
  return repo.watchInsights(user.uid);
});
