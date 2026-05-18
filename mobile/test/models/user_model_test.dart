import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    const user = UserModel(
      uid: 'u1',
      linkedinHash: 'hash1',
      role: 'free',
    );

    test('default values are correct', () {
      expect(user.role, 'free');
      expect(user.isAdmin, false);
      expect(user.kvkkAccepted, false);
      expect(user.creditBalance, 0);
    });

    test('isPro is true for pro/enterprise/daas roles', () {
      expect(user.copyWith(role: 'free').isPro, false);
      expect(user.copyWith(role: 'pro').isPro, true);
      expect(user.copyWith(role: 'enterprise').isPro, true);
      expect(user.copyWith(role: 'daas').isPro, true);
    });

    test('isEnterprise is true only for enterprise/daas roles', () {
      expect(user.copyWith(role: 'pro').isEnterprise, false);
      expect(user.copyWith(role: 'enterprise').isEnterprise, true);
      expect(user.copyWith(role: 'daas').isEnterprise, true);
    });

    test('isDaas is true only for daas role', () {
      expect(user.copyWith(role: 'enterprise').isDaas, false);
      expect(user.copyWith(role: 'daas').isDaas, true);
    });

    test('copyWith overrides specified fields', () {
      final updated = user.copyWith(
        displayName: 'Test User',
        creditBalance: 50,
        companyId: 'acme',
      );
      expect(updated.uid, 'u1');
      expect(updated.displayName, 'Test User');
      expect(updated.creditBalance, 50);
      expect(updated.companyId, 'acme');
    });

    test('toFirestore does not include null optional fields', () {
      final map = user.toFirestore();
      expect(map.containsKey('displayName'), false);
      expect(map.containsKey('avatarUrl'), false);
      expect(map.containsKey('companyId'), false);
      expect(map['role'], 'free');
      expect(map['isAdmin'], false);
      expect(map['creditBalance'], 0);
    });

    test('toFirestore includes non-null optional fields', () {
      final map = user.copyWith(displayName: 'Ali', companyId: 'acme').toFirestore();
      expect(map['displayName'], 'Ali');
      expect(map['companyId'], 'acme');
    });
  });
}
