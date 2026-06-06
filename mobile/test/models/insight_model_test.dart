import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/models/insight_model.dart';

void main() {
  InsightModel make({
    Map<String, double>? personal,
    Map<String, double>? company,
    Map<String, double>? benchmark,
  }) =>
      InsightModel(
        uid: 'u1',
        personalScores: personal ?? const {},
        companyScores: company,
        benchmarkScores: benchmark,
        updatedAt: DateTime(2026, 6, 1),
      );

  group('InsightModel averages', () {
    test('personalAverage is the mean of personal scores', () {
      final m = make(personal: const {'a': 4.0, 'b': 2.0});
      expect(m.personalAverage, 3.0);
    });

    test('personalAverage is 0 when empty', () {
      expect(make().personalAverage, 0);
    });

    test('companyAverage is 0 when companyScores is null', () {
      expect(make().companyAverage, 0);
    });

    test('benchmarkAverage is the mean of benchmark scores', () {
      final m = make(benchmark: const {'a': 3.0, 'b': 4.0, 'c': 5.0});
      expect(m.benchmarkAverage, 4.0);
    });

    test('benchmarkAverage is 0 when benchmarkScores is null', () {
      expect(make().benchmarkAverage, 0);
    });

    test('benchmarkAverage is 0 when benchmarkScores is empty', () {
      expect(make(benchmark: const {}).benchmarkAverage, 0);
    });
  });
}
