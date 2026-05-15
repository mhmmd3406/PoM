import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/insight_model.dart';

class InsightsRepository {
  InsightsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Stream personal insights document for a user.
  Stream<InsightModel?> watchInsights(String uid) {
    return _firestore
        .collection(AppConstants.insightsCollection)
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? InsightModel.fromFirestore(snap) : null);
  }

  Future<InsightModel?> getInsights(String uid) async {
    final snap = await _firestore
        .collection(AppConstants.insightsCollection)
        .doc(uid)
        .get();
    return snap.exists ? InsightModel.fromFirestore(snap) : null;
  }

  /// Fetch company aggregate (returns null if N < threshold).
  Future<Map<String, double>?> getCompanyAggregate(String companyId) async {
    final snap = await _firestore
        .collection(AppConstants.companiesCollection)
        .doc(companyId)
        .collection('aggregates')
        .doc('current')
        .get();

    if (!snap.exists) return null;
    final data = snap.data()!;
    final n = data['n'] as int? ?? 0;
    if (n < AppConstants.defaultCompanyMinN) return null;

    final scores = data['scores'] as Map<String, dynamic>? ?? {};
    return scores.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Fetch industry benchmark scores.
  Future<Map<String, double>?> getBenchmarkScores(String industry) async {
    final snap = await _firestore
        .collection('benchmarks')
        .doc(industry)
        .get();

    if (!snap.exists) return null;
    final scores = snap.data()?['scores'] as Map<String, dynamic>? ?? {};
    return scores.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(firestore: ref.watch(firestoreProvider));
});
