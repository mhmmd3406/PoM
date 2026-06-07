import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/models/checkin_model.dart';

void main() {
  final now = DateTime(2024, 6, 1, 12);

  final checkin = CheckinModel(
    id: 'c1',
    userIdHash: 'hash_u1',
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

    test('toFirestore writes pseudonymous userIdHash and no raw uid/userId', () {
      final map = checkin.toFirestore();
      expect(map['userIdHash'], 'hash_u1');
      expect(map.containsKey('uid'), false);
      expect(map.containsKey('userId'), false);
    });

    test('toFirestore writes scores map with canonical camelCase keys', () {
      final map = checkin.toFirestore();
      final scores = map['scores'] as Map<String, dynamic>;
      expect(scores['overallMood'], 4.0);
      expect(scores['workStress'], 3.0);
      expect(scores['teamHarmony'], 5.0);
      expect(scores['personalGrowth'], 2.0);
      expect(scores['workLifeBalance'], 4.0);
      // Old Turkish keys and the redundant flat top-level fields are gone.
      expect(scores.containsKey('Genel Ruh Hali'), false);
      expect(map.containsKey('overallMood'), false);
    });

    test('toFirestore does not include null optional fields', () {
      final map = checkin.toFirestore();
      expect(map.containsKey('companyId'), false);
      expect(map.containsKey('department'), false);
    });

    test('toFirestore includes companyId and department when set', () {
      final withCompany = CheckinModel(
        id: 'c2',
        userIdHash: 'hash_u1',
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
