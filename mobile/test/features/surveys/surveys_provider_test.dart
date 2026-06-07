import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/surveys/data/surveys_repository.dart';
import 'package:pom_app/features/surveys/providers/surveys_provider.dart';
import 'package:pom_app/models/user_model.dart';

class MockSurveysRepository extends Mock implements SurveysRepository {}

void main() {
  SurveyModel survey(String id, {SurveyStatus status = SurveyStatus.active}) =>
      SurveyModel(
        id: id,
        companyId: '__admin__',
        title: 'S$id',
        description: '',
        emoji: '📊',
        status: status,
        questions: const [],
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
  setUp(() => repo = MockSurveysRepository());

  ProviderContainer makeContainer(UserModel u, List<SurveyModel> surveys) {
    when(() => repo.watchEligibleSurveys(any()))
        .thenAnswer((_) => Stream.value(surveys));
    final c = ProviderContainer(overrides: [
      surveysRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(u),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('myResponseSurveyIdsProvider reflects user.answeredSurveyIds '
      '(no survey_responses read)', () {
    final c = makeContainer(user(answered: ['s1', 's2']), const []);
    expect(c.read(myResponseSurveyIdsProvider), {'s1', 's2'});
  });

  test('myResponseSurveyIdsProvider is empty when nothing answered', () {
    final c = makeContainer(user(), const []);
    expect(c.read(myResponseSurveyIdsProvider), <String>{});
  });

  test('pending excludes answered/non-active; completed includes answered',
      () async {
    final c = makeContainer(
      user(answered: ['s1']),
      [
        survey('s1'), // answered, active        → completed
        survey('s2'), // unanswered, active      → pending
        survey('s3', status: SurveyStatus.draft), // draft → neither
      ],
    );

    // Subscribe so the eligible-surveys stream provider starts emitting.
    c.listen(pendingSurveysProvider, (_, __) {}, fireImmediately: true);
    c.listen(completedSurveysProvider, (_, __) {}, fireImmediately: true);
    await pumpEventQueue();

    final pending = c.read(pendingSurveysProvider).valueOrNull;
    final completed = c.read(completedSurveysProvider).valueOrNull;

    expect(pending?.map((s) => s.id).toList(), ['s2']);
    expect(completed?.map((s) => s.id).toList(), ['s1']);
  });
}
