import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/features/profile/data/account_repository.dart';

void main() {
  group('jsonSafe', () {
    test('converts a Firestore Timestamp into an ISO-8601 string', () {
      final dt = DateTime.utc(2026, 6, 6, 12);
      final result = jsonSafe(Timestamp.fromDate(dt));
      expect(result, isA<String>());
      // Round-trips back to the same instant regardless of the host timezone.
      expect(DateTime.parse(result as String).toUtc(), dt);
    });

    test('recurses into maps/lists and yields a jsonEncode-able structure', () {
      final input = {
        'name': 'Mehmet',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'scores': [1, 2, 3],
        'nested': {'at': Timestamp.fromDate(DateTime.utc(2025, 12, 31))},
      };

      final out = jsonSafe(input) as Map<String, dynamic>;

      expect(out['name'], 'Mehmet');
      expect(out['scores'], [1, 2, 3]);
      expect(out['createdAt'], isA<String>());
      expect((out['nested'] as Map)['at'], isA<String>());
      // The key guarantee: the export can be serialised without throwing on
      // a raw Timestamp.
      expect(() => jsonEncode(out), returnsNormally);
    });

    test('leaves plain JSON primitives untouched', () {
      expect(jsonEncode(jsonSafe({'a': 1, 'b': 'x', 'c': true})),
          '{"a":1,"b":"x","c":true}');
    });
  });
}
