import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinModel {
  const CheckinModel({
    required this.id,
    required this.uid,
    required this.overallMood,
    required this.workStress,
    required this.teamHarmony,
    required this.personalGrowth,
    required this.workLifeBalance,
    required this.createdAt,
    this.companyId,
    this.department,
    this.isAnonymized = true,
  });

  final String id;
  final String uid;

  /// 1–5 scale (1 = worst, 5 = best)
  final int overallMood;
  final int workStress;
  final int teamHarmony;
  final int personalGrowth;
  final int workLifeBalance;

  final DateTime createdAt;
  final String? companyId;
  final String? department;
  final bool isAnonymized;

  double get averageScore =>
      (overallMood + workStress + teamHarmony + personalGrowth + workLifeBalance) /
      5.0;

  List<double> get scores => [
        overallMood.toDouble(),
        workStress.toDouble(),
        teamHarmony.toDouble(),
        personalGrowth.toDouble(),
        workLifeBalance.toDouble(),
      ];

  /// Canonical dimension keys stored inside the `scores` map. These match the
  /// keys consumed by `computeInsights` (Cloud Functions) and the .NET B2B
  /// `InsightsAggregator`, so all three layers now speak one vocabulary.
  static const moodKey = 'overallMood';
  static const stressKey = 'workStress';
  static const teamKey = 'teamHarmony';
  static const growthKey = 'personalGrowth';
  static const balanceKey = 'workLifeBalance';

  factory CheckinModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final scores = data['scores'] as Map<String, dynamic>?;
    final createdAtRaw = data['createdAt'] ?? data['created_at'];

    int read(String key) => (scores?[key] as num?)?.round() ?? 3;

    return CheckinModel(
      id: doc.id,
      uid: (data['uid'] ?? data['userId']) as String? ?? '',
      overallMood: read(moodKey),
      workStress: read(stressKey),
      teamHarmony: read(teamKey),
      personalGrowth: read(growthKey),
      workLifeBalance: read(balanceKey),
      createdAt:
          createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now(),
      companyId: data['companyId'] as String?,
      department: data['department'] as String?,
      isAnonymized: data['isAnonymized'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    final ts = Timestamp.fromDate(createdAt);
    return {
      'uid': uid,
      'userId': uid,
      // Single canonical representation — camelCase English keys. The previous
      // Turkish keys and the redundant flat top-level fields are gone.
      'scores': {
        moodKey: overallMood.toDouble(),
        stressKey: workStress.toDouble(),
        teamKey: teamHarmony.toDouble(),
        growthKey: personalGrowth.toDouble(),
        balanceKey: workLifeBalance.toDouble(),
      },
      // Both timestamp keys retained: computeInsights orders by `created_at`,
      // the mobile check-in repo orders by `createdAt`.
      'createdAt': ts,
      'created_at': ts,
      if (companyId != null) 'companyId': companyId,
      if (department != null) 'department': department,
      'isAnonymized': isAnonymized,
    };
  }
}
