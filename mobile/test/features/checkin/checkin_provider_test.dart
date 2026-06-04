import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pom_app/features/checkin/data/checkin_repository.dart';
import 'package:pom_app/features/checkin/providers/checkin_provider.dart';
import 'package:pom_app/models/checkin_model.dart';
import 'package:pom_app/models/user_model.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';

class MockCheckinRepository extends Mock implements CheckinRepository {}

void main() {
  late MockCheckinRepository mockRepo;

  const testUser = UserModel(
    uid: 'u1',
    linkedinHash: 'hash1',
    role: 'pro',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
  );

  final fakeCheckin = CheckinModel(
    id: 'c1',
    uid: 'u1',
    overallMood: 4,
    workStress: 3,
    teamHarmony: 5,
    personalGrowth: 4,
    workLifeBalance: 3,
    createdAt: DateTime(2024, 6, 1),
  );

  setUp(() {
    mockRepo = MockCheckinRepository();
  });

  // Build a container that injects a static user and a mock repo,
  // bypassing Firebase entirely.
  ProviderContainer makeContainer({UserModel? user}) {
    return ProviderContainer(
      overrides: [
        checkinRepositoryProvider.overrideWithValue(mockRepo),
        currentUserProvider.overrideWithValue(user ?? testUser),
      ],
    );
  }

  group('CheckinFlowNotifier', () {
    test('initial state has step 0 and no answers', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(checkinFlowProvider);
      expect(state.currentStep, 0);
      expect(state.overallMood, null);
      expect(state.isSubmitting, false);
      expect(state.isComplete, false);
    });

    test('selectAnswer sets value for current step', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(checkinFlowProvider.notifier).selectAnswer(4);
      expect(container.read(checkinFlowProvider).overallMood, 4);
    });

    test('nextStep increments step', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(checkinFlowProvider.notifier).nextStep();
      expect(container.read(checkinFlowProvider).currentStep, 1);
    });

    test('previousStep does not go below 0', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(checkinFlowProvider.notifier).previousStep();
      expect(container.read(checkinFlowProvider).currentStep, 0);

      container.read(checkinFlowProvider.notifier).nextStep();
      container.read(checkinFlowProvider.notifier).previousStep();
      expect(container.read(checkinFlowProvider).currentStep, 0);
    });

    test('submit returns null with error when steps incomplete', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Only answer step 0
      container.read(checkinFlowProvider.notifier).selectAnswer(3);

      final result = await container.read(checkinFlowProvider.notifier).submit();
      expect(result, null);
      expect(container.read(checkinFlowProvider).error, isNotNull);
    });

    test('submit calls repository and marks isComplete on success', () async {
      when(() => mockRepo.submitCheckin(
            uid: any(named: 'uid'),
            overallMood: any(named: 'overallMood'),
            workStress: any(named: 'workStress'),
            teamHarmony: any(named: 'teamHarmony'),
            personalGrowth: any(named: 'personalGrowth'),
            workLifeBalance: any(named: 'workLifeBalance'),
            companyId: any(named: 'companyId'),
            department: any(named: 'department'),
          )).thenAnswer((_) async => fakeCheckin);

      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkinFlowProvider.notifier);
      notifier.selectAnswer(4); // step 0
      notifier.nextStep();
      notifier.selectAnswer(3); // step 1
      notifier.nextStep();
      notifier.selectAnswer(5); // step 2
      notifier.nextStep();
      notifier.selectAnswer(4); // step 3
      notifier.nextStep();
      notifier.selectAnswer(3); // step 4

      final result = await notifier.submit();

      expect(result, isNotNull);
      expect(result!.id, 'c1');
      expect(container.read(checkinFlowProvider).isComplete, true);
      expect(container.read(checkinFlowProvider).isSubmitting, false);
    });

    test('submit sets error message on repository failure', () async {
      when(() => mockRepo.submitCheckin(
            uid: any(named: 'uid'),
            overallMood: any(named: 'overallMood'),
            workStress: any(named: 'workStress'),
            teamHarmony: any(named: 'teamHarmony'),
            personalGrowth: any(named: 'personalGrowth'),
            workLifeBalance: any(named: 'workLifeBalance'),
            companyId: any(named: 'companyId'),
            department: any(named: 'department'),
          )).thenThrow(Exception('network error'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkinFlowProvider.notifier);
      notifier.selectAnswer(4);
      notifier.nextStep();
      notifier.selectAnswer(3);
      notifier.nextStep();
      notifier.selectAnswer(5);
      notifier.nextStep();
      notifier.selectAnswer(4);
      notifier.nextStep();
      notifier.selectAnswer(3);

      final result = await notifier.submit();

      expect(result, null);
      expect(container.read(checkinFlowProvider).error, contains('Gönderme başarısız'));
      expect(container.read(checkinFlowProvider).isSubmitting, false);
    });

    test('reset returns to initial state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkinFlowProvider.notifier);
      notifier.selectAnswer(4);
      notifier.nextStep();
      notifier.reset();

      final state = container.read(checkinFlowProvider);
      expect(state.currentStep, 0);
      expect(state.overallMood, null);
    });
  });
}
