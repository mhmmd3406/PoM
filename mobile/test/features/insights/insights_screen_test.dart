import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/insights/presentation/insights_screen.dart';
import 'package:pom_app/features/insights/providers/insights_provider.dart';
import 'package:pom_app/models/insight_model.dart';
import 'package:pom_app/models/user_model.dart';

void main() {
  const freeUser = UserModel(uid: 'u1', linkedinHash: 'h1', role: 'free');

  final testInsight = InsightModel(
    uid: 'u1',
    personalScores: const {
      'overallMood': 4.0,
      'workStress': 3.0,
      'teamHarmony': 4.0,
      'personalGrowth': 4.0,
      'workLifeBalance': 3.0,
    },
    companyScores: null,
    benchmarkScores: null,
    updatedAt: DateTime(2026, 6, 1),
    totalCheckins: 5,
    trend: 0,
  );

  testWidgets(
      'F4: Insights exposes a benchmark entry that reaches /benchmarking',
      (tester) async {
    // Wide surface so an unrelated narrow-width overflow in _TrendCard's legend
    // (pre-existing, not part of F4) doesn't interfere with this test.
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
            path: '/insights', builder: (c, s) => const InsightsScreen()),
        GoRoute(
          path: '/benchmarking',
          builder: (c, s) =>
              const Scaffold(body: Text('BENCHMARK ROUTE REACHED')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(freeUser),
          insightsStreamProvider.overrideWith((ref) => Stream.value(testInsight)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The benchmark entry button is present in the Insights header.
    expect(find.text('Karşılaştır'), findsOneWidget);

    // Tapping it navigates to the (previously unreachable) /benchmarking route.
    await tester.tap(find.text('Karşılaştır'));
    await tester.pumpAndSettle();
    expect(find.text('BENCHMARK ROUTE REACHED'), findsOneWidget);
  });
}
