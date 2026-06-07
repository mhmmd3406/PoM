import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/checkin/providers/checkin_provider.dart';
import 'package:pom_app/features/home/presentation/home_screen.dart';
import 'package:pom_app/features/insights/providers/insights_provider.dart';
import 'package:pom_app/features/surveys/data/survey_model.dart';
import 'package:pom_app/features/surveys/data/surveys_repository.dart';
import 'package:pom_app/models/insight_model.dart';
import 'package:pom_app/models/user_model.dart';

class MockSurveysRepository extends Mock implements SurveysRepository {}

void main() {
  const testUser = UserModel(
    uid: 'u1',
    linkedinHash: 'h1',
    displayName: 'Test User',
    companyId: 'c1',
  );

  // personal avg = 4.0, company avg = 3.5, benchmark (sector) avg = 3.8
  final testInsight = InsightModel(
    uid: 'u1',
    personalScores: const {
      'overallMood': 4.0,
      'workStress': 4.0,
      'teamHarmony': 4.0,
      'personalGrowth': 4.0,
      'workLifeBalance': 4.0,
    },
    companyScores: const {
      'overallMood': 3.5,
      'workStress': 3.5,
      'teamHarmony': 3.5,
      'personalGrowth': 3.5,
      'workLifeBalance': 3.5,
    },
    benchmarkScores: const {
      'overallMood': 3.8,
      'workStress': 3.8,
      'teamHarmony': 3.8,
      'personalGrowth': 3.8,
      'workLifeBalance': 3.8,
    },
    updatedAt: DateTime(2026, 6, 1),
    totalCheckins: 7,
    trend: 1,
  );

  late MockSurveysRepository surveysRepo;
  setUp(() {
    surveysRepo = MockSurveysRepository();
    when(() => surveysRepo.watchEligibleSurveys(any()))
        .thenAnswer((_) => Stream.value(const <SurveyModel>[]));
  });

  Widget harness() => ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          insightsStreamProvider.overrideWith((ref) => Stream.value(testInsight)),
          checkinCooldownProvider.overrideWith((ref) => Future.value(Duration.zero)),
          surveysRepositoryProvider.overrideWithValue(surveysRepo),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );

  testWidgets('F2: home renders real insight data, not hardcoded values',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Real personal average (4.0) and company average (3.5) render.
    expect(find.text('4.0'), findsWidgets);
    expect(find.text('3.5'), findsOneWidget);

    // Real sector average from benchmark scores (3.8) — NOT the old fake "3.6".
    expect(find.text('Sektör ort. 3.8'), findsOneWidget);
    expect(find.text('Sektör ort. 3.6'), findsNothing);

    // Trend shows direction only — the fabricated "+0.3" magnitude is gone.
    expect(find.text('↑ Geçen haftaya göre'), findsOneWidget);
    expect(find.text('↑ +0.3 geçen haftaya göre'), findsNothing);
  });
}
