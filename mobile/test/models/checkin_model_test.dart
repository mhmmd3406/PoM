import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/models/checkin_model.dart';

void main() {
  final now = DateTime(2024, 6, 1, 12);

  final checkin = CheckinModel(
    id: 'c1',
    uid: 'u1',
    overallMood: 4,
    workStress: 3,
    teamHarmony: 5,
    personalGrowth: 2,
    workLifeBalance: 4,
    createdAt: now,
  );

  group('CheckinModel', () {
    test('averageScore is correct', () {
      expect(checkin.averageScore, (4 + 3 + 5 + 2 + 4) / 5.0);
    });

    test('scores list has correct length and values', () {
      expect(checkin.scores.length, 5);
      expect(checkin.scores, [4.0, 3.0, 5.0, 2.0, 4.0]);
    });

    test('isAnonymized defaults to true', () {
      expect(checkin.isAnonymized, true);
    });

    test('toFirestore includes both uid and userId for backwards compat', () {
      final map = checkin.toFirestore();
      expect(map['uid'], 'u1');
      expect(map['userId'], 'u1');
    });

    test('toFirestore writes scores map with Turkish keys', () {
      final map = checkin.toFirestore();
      final scores = map['scores'] as Map<String, dynamic>;
      expect(scores['Genel Ruh Hali'], 4.0);
      expect(scores['İş Stresi'], 3.0);
      expect(scores['Takım Uyumu'], 5.0);
      expect(scores['Kişisel Gelişim'], 2.0);
      expect(scores['İş-Yaşam Dengesi'], 4.0);
    });

    test('toFirestore does not include null optional fields', () {
      final map = checkin.toFirestore();
      expect(map.containsKey('companyId'), false);
      expect(map.containsKey('department'), false);
    });

    test('toFirestore includes companyId and department when set', () {
      final withCompany = CheckinModel(
        id: 'c2',
        uid: 'u1',
        overallMood: 3,
        workStress: 3,
        teamHarmony: 3,
        personalGrowth: 3,
        workLifeBalance: 3,
        createdAt: now,
        companyId: 'acme',
        department: 'eng',
      );
      final map = withCompany.toFirestore();
      expect(map['companyId'], 'acme');
      expect(map['department'], 'eng');
    });
  });
}
