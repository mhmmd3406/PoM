import 'package:cloud_firestore/cloud_firestore.dart';

class InsightModel {
  const InsightModel({
    required this.uid,
    required this.personalScores,
    required this.companyScores,
    required this.benchmarkScores,
    required this.updatedAt,
    this.companyId,
    this.totalCheckins = 0,
    this.trend,
  });

  final String uid;

  /// Personal dimension scores — keyed by the canonical camelCase dimension
  /// keys (see [_dimensionOrder]); AppConstants.checkinDimensions holds the
  /// matching Turkish display labels in the same order.
  final Map<String, double> personalScores;

  /// Company-average dimension scores (null if N < threshold)
  final Map<String, double>? companyScores;

  /// Industry benchmark scores
  final Map<String, double>? benchmarkScores;

  final DateTime updatedAt;
  final String? companyId;
  final int totalCheckins;

  /// +1 improving, -1 declining, 0 stable
  final int? trend;

  double get personalAverage =>
      personalScores.isEmpty
          ? 0
          : personalScores.values.reduce((a, b) => a + b) /
              personalScores.length;

  double get companyAverage =>
      companyScores == null || companyScores!.isEmpty
          ? 0
          : companyScores!.values.reduce((a, b) => a + b) /
              companyScores!.length;

  double get benchmarkAverage =>
      benchmarkScores == null || benchmarkScores!.isEmpty
          ? 0
          : benchmarkScores!.values.reduce((a, b) => a + b) /
              benchmarkScores!.length;

  List<double> get personalList => _toOrderedList(personalScores);
  List<double> get companyList =>
      companyScores != null ? _toOrderedList(companyScores!) : [];
  List<double> get benchmarkList =>
      benchmarkScores != null ? _toOrderedList(benchmarkScores!) : [];

  static const _dimensionOrder = [
    'overallMood',
    'workStress',
    'teamHarmony',
    'personalGrowth',
    'workLifeBalance',
  ];

  List<double> _toOrderedList(Map<String, double> map) {
    return _dimensionOrder.map((k) => map[k] ?? 3.0).toList();
  }

  /// Parses the document written by the `computeInsights` Cloud Function, whose
  /// shape is nested:
  ///   { personal: { avg: {dim: score}, checkin_count, trend_slope, ... },
  ///     company:  { avg: {...}, checkin_count } | null,
  ///     department_stats: {...} | null,
  ///     companyId, updated_at }
  /// (Benchmark scores have no source here — they are fetched separately by
  /// InsightsRepository.getBenchmarkScores.)
  factory InsightModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, double> avgOf(dynamic section) {
      if (section is! Map) return {};
      final avg = section['avg'];
      if (avg is! Map) return {};
      return avg.map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      );
    }

    final personal = data['personal'];
    final company = data['company'];

    final trendSlope = personal is Map ? personal['trend_slope'] as num? : null;
    final int? trend = trendSlope == null
        ? null
        : (trendSlope > 0.01 ? 1 : (trendSlope < -0.01 ? -1 : 0));

    return InsightModel(
      uid: doc.id,
      personalScores: avgOf(personal),
      companyScores: company != null ? avgOf(company) : null,
      benchmarkScores: null,
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
      companyId: data['companyId'] as String?,
      totalCheckins:
          personal is Map ? (personal['checkin_count'] as int? ?? 0) : 0,
      trend: trend,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'personalScores': personalScores,
      if (companyScores != null) 'companyScores': companyScores,
      if (benchmarkScores != null) 'benchmarkScores': benchmarkScores,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (companyId != null) 'companyId': companyId,
      'totalCheckins': totalCheckins,
      if (trend != null) 'trend': trend,
    };
  }
}
