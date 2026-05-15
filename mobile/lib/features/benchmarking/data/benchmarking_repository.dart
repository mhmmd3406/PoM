import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';

class CompanySummary {
  const CompanySummary({
    required this.id,
    required this.name,
    required this.industry,
    required this.n,
    required this.scores,
  });

  final String id;
  final String name;
  final String industry;

  /// Number of employees who contributed (for anonymisation threshold).
  final int n;

  /// Dimension scores — null if n < threshold.
  final Map<String, double>? scores;

  bool get hasEnoughData => n >= AppConstants.defaultCompanyMinN;

  double get averageScore {
    if (scores == null || scores!.isEmpty) return 0;
    return scores!.values.reduce((a, b) => a + b) / scores!.length;
  }
}

class BenchmarkingRepository {
  BenchmarkingRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Search companies by name prefix (up to [limit] results).
  Future<List<CompanySummary>> searchCompanies(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    // Firestore range query for prefix search
    final end = query.endsWith('') ? query : '$query';

    final snap = await _firestore
        .collection(AppConstants.companiesCollection)
        .orderBy('nameLower')
        .startAt([query.toLowerCase()])
        .endAt([end.toLowerCase()])
        .limit(limit)
        .get();

    return snap.docs.map((doc) => _fromDoc(doc)).toList();
  }

  /// Get a single company summary by ID.
  Future<CompanySummary?> getCompany(String companyId) async {
    final doc = await _firestore
        .collection(AppConstants.companiesCollection)
        .doc(companyId)
        .get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  CompanySummary _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final n = data['n'] as int? ?? 0;
    Map<String, double>? scores;
    if (n >= AppConstants.defaultCompanyMinN) {
      final rawScores = data['scores'] as Map<String, dynamic>? ?? {};
      scores = rawScores.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    return CompanySummary(
      id: doc.id,
      name: data['name'] as String? ?? '',
      industry: data['industry'] as String? ?? '',
      n: n,
      scores: scores,
    );
  }
}

final benchmarkingRepositoryProvider =
    Provider<BenchmarkingRepository>((ref) {
  return BenchmarkingRepository(firestore: ref.watch(firestoreProvider));
});
