import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/surveys/data/survey_model.dart';
import 'package:pom_app/features/surveys/data/surveys_repository.dart';
import 'package:pom_app/features/surveys/presentation/survey_answer_screen.dart';
import 'package:pom_app/models/user_model.dart';

class MockSurveysRepository extends Mock implements SurveysRepository {}

void main() {
  const survey = SurveyModel(
    id: 's1',
    companyId: '__admin__',
    title: 'Test Anketi',
    description: '',
    emoji: '📊',
    status: SurveyStatus.active,
    questions: [
      SurveyQuestion(
          id: 'q1', text: 'Nasılsın?', type: SurveyQuestionType.emoji5),
    ],
    minNThreshold: 5,
    responseCount: 0,
  );

  UserModel user({List<String> answered = const []}) => UserModel(
        uid: 'u1',
        linkedinHash: 'h1',
        companyId: 'c1',
        answeredSurveyIds: answered,
      );

  late MockSurveysRepository repo;
  setUp(() {
    repo = MockSurveysRepository();
    when(() => repo.getSurvey('s1')).thenAnswer((_) async => survey);
  });

  Widget harness(UserModel u) => ProviderScope(
        overrides: [
          surveysRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(u),
        ],
        child: const MaterialApp(home: SurveyAnswerScreen(surveyId: 's1')),
      );

  testWidgets(
      'F5: survey opens (no PERMISSION_DENIED error) when not yet answered',
      (tester) async {
    await tester.pumpWidget(harness(user()));
    await tester.pumpAndSettle();

    // The question renders — _load no longer errors out on a survey_responses
    // read (which previously failed with PERMISSION_DENIED for __admin__).
    expect(find.text('Nasılsın?'), findsOneWidget);
    expect(find.text('Anket yüklenemedi. Lütfen tekrar deneyin.'), findsNothing);
  });

  testWidgets(
      'F5: already-answered is derived from the user model, not a query',
      (tester) async {
    await tester.pumpWidget(harness(user(answered: ['s1'])));
    await tester.pumpAndSettle();

    expect(find.text('Zaten Yanıtladın'), findsOneWidget);
    expect(find.text('Nasılsın?'), findsNothing);
  });
}
