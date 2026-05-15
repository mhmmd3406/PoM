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

  factory CheckinModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CheckinModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      overallMood: data['overallMood'] as int? ?? 3,
      workStress: data['workStress'] as int? ?? 3,
      teamHarmony: data['teamHarmony'] as int? ?? 3,
      personalGrowth: data['personalGrowth'] as int? ?? 3,
      workLifeBalance: data['workLifeBalance'] as int? ?? 3,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      companyId: data['companyId'] as String?,
      department: data['department'] as String?,
      isAnonymized: data['isAnonymized'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'overallMood': overallMood,
      'workStress': workStress,
      'teamHarmony': teamHarmony,
      'personalGrowth': personalGrowth,
      'workLifeBalance': workLifeBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      if (companyId != null) 'companyId': companyId,
      if (department != null) 'department': department,
      'isAnonymized': isAnonymized,
    };
  }
}
