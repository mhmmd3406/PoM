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

  /// Personal dimension scores — keys match AppConstants.checkinDimensions
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

  factory InsightModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, double> _parseScores(dynamic raw) {
      if (raw == null) return {};
      final map = raw as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return InsightModel(
      uid: doc.id,
      personalScores: _parseScores(data['personalScores']),
      companyScores: data['companyScores'] != null
          ? _parseScores(data['companyScores'])
          : null,
      benchmarkScores: data['benchmarkScores'] != null
          ? _parseScores(data['benchmarkScores'])
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      companyId: data['companyId'] as String?,
      totalCheckins: data['totalCheckins'] as int? ?? 0,
      trend: data['trend'] as int?,
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
