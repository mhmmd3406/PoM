import 'package:cloud_firestore/cloud_firestore.dart';

class PomUser {
  const PomUser({
    required this.uid,
    required this.linkedinHash,
    this.bankId,
    this.businessFamily,
    this.departmentType,
    this.seniorityLevel,
    required this.credits,
    required this.joinedAt,
    this.lastCheckinAt,
    required this.checkinStreak,
  });

  final String uid;
  final String linkedinHash;
  final String? bankId;
  final String? businessFamily;
  final String? departmentType;
  final String? seniorityLevel;
  final int credits;
  final DateTime joinedAt;
  final DateTime? lastCheckinAt;
  final int checkinStreak;

  bool get isProfileComplete => bankId != null && businessFamily != null;

  bool get canCheckinThisWeek {
    if (lastCheckinAt == null) return true;
    return DateTime.now().difference(lastCheckinAt!) >
        const Duration(days: 7);
  }

  factory PomUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PomUser(
      uid: doc.id,
      linkedinHash: d['linkedin_hash'] as String,
      bankId: d['bank_id'] as String?,
      businessFamily: d['business_family'] as String?,
      departmentType: d['department_type'] as String?,
      seniorityLevel: d['seniority_level'] as String?,
      credits: (d['credits'] as num).toInt(),
      joinedAt: (d['joined_at'] as Timestamp).toDate(),
      lastCheckinAt: (d['last_checkin_at'] as Timestamp?)?.toDate(),
      checkinStreak: (d['checkin_streak'] as num? ?? 0).toInt(),
    );
  }
}

class Bank {
  const Bank({required this.id, required this.name, required this.country});

  final String id;
  final String name;
  final String country;

  factory Bank.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Bank(
      id: doc.id,
      name: d['name'] as String,
      country: d['country'] as String,
    );
  }
}

class CheckinRatings {
  const CheckinRatings({
    required this.salary,
    required this.benefits,
    required this.workModel,
    required this.culture,
    required this.wlb,
  });

  final int salary;
  final int benefits;
  final int workModel;
  final int culture;
  final int wlb;

  Map<String, dynamic> toMap() => {
        'salary': salary,
        'benefits': benefits,
        'work_model': workModel,
        'culture': culture,
        'wlb': wlb,
      };
}

class InsightData {
  const InsightData({
    required this.bankAverages,
    required this.bankEntryCount,
    this.sectorAverages,
    required this.year,
    required this.month,
  });

  final Map<String, double> bankAverages;
  final int bankEntryCount;
  final Map<String, double>? sectorAverages;
  final int year;
  final int month;

  double get overallScore => bankAverages['overall'] ?? 0;

  factory InsightData.fromMap(Map<String, dynamic> data) {
    Map<String, double> parseAverages(Map<String, dynamic> m) =>
        m.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return InsightData(
      bankAverages: parseAverages(
        (data['bank'] as Map<String, dynamic>)['averages'] as Map<String, dynamic>,
      ),
      bankEntryCount:
          ((data['bank'] as Map<String, dynamic>)['entryCount'] as num).toInt(),
      sectorAverages: data['sector'] != null
          ? parseAverages(
              (data['sector'] as Map<String, dynamic>)['averages'] as Map<String, dynamic>,
            )
          : null,
      year: (data['period'] as Map<String, dynamic>)['year'] as int,
      month: (data['period'] as Map<String, dynamic>)['month'] as int,
    );
  }
}
