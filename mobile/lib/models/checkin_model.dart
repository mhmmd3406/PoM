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
    final scores = data['scores'] as Map<String, dynamic>?;
    final createdAtRaw = data['createdAt'] ?? data['created_at'];
    return CheckinModel(
      id: doc.id,
      uid: (data['uid'] ?? data['userId']) as String? ?? '',
      overallMood: (scores?['Genel Ruh Hali'] ?? data['overallMood'])
              ?.round() as int? ??
          3,
      workStress: (scores?['İş Stresi'] ?? data['workStress'])
              ?.round() as int? ??
          3,
      teamHarmony: (scores?['Takım Uyumu'] ?? data['teamHarmony'])
              ?.round() as int? ??
          3,
      personalGrowth: (scores?['Kişisel Gelişim'] ?? data['personalGrowth'])
              ?.round() as int? ??
          3,
      workLifeBalance:
          (scores?['İş-Yaşam Dengesi'] ?? data['workLifeBalance'])
                  ?.round() as int? ??
              3,
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
      'scores': {
        'Genel Ruh Hali': overallMood.toDouble(),
        'İş Stresi': workStress.toDouble(),
        'Takım Uyumu': teamHarmony.toDouble(),
        'Kişisel Gelişim': personalGrowth.toDouble(),
        'İş-Yaşam Dengesi': workLifeBalance.toDouble(),
      },
      'overallMood': overallMood,
      'workStress': workStress,
      'teamHarmony': teamHarmony,
      'personalGrowth': personalGrowth,
      'workLifeBalance': workLifeBalance,
      'createdAt': ts,
      'created_at': ts,
      if (companyId != null) 'companyId': companyId,
      if (department != null) 'department': department,
      'isAnonymized': isAnonymized,
    };
  }
}
