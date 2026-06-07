import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/checkin/data/checkin_repository.dart';
import 'package:pom_app/features/checkin/presentation/checkin_flow_screen.dart';
import 'package:pom_app/features/checkin/providers/checkin_provider.dart';
import 'package:pom_app/models/checkin_model.dart';
import 'package:pom_app/models/user_model.dart';

class MockCheckinRepository extends Mock implements CheckinRepository {}

void main() {
  const testUser = UserModel(
    uid: 'u1',
    linkedinHash: 'hash1',
    userIdHash: 'hash_u1',
    role: 'pro',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
  );

  final fakeCheckin = CheckinModel(
    id: 'c1',
    userIdHash: 'hash_u1',
    overallMood: 5,
    workStress: 5,
    teamHarmony: 5,
    personalGrowth: 5,
    workLifeBalance: 5,
    createdAt: DateTime(2024, 6, 1),
  );

  late MockCheckinRepository mockRepo;

  setUp(() {
    mockRepo = MockCheckinRepository();
    when(() => mockRepo.submitCheckin(
          uid: any(named: 'uid'),
          userIdHash: any(named: 'userIdHash'),
          overallMood: any(named: 'overallMood'),
          workStress: any(named: 'workStress'),
          teamHarmony: any(named: 'teamHarmony'),
          personalGrowth: any(named: 'personalGrowth'),
          workLifeBalance: any(named: 'workLifeBalance'),
          companyId: any(named: 'companyId'),
          department: any(named: 'department'),
        )).thenAnswer((_) async => fakeCheckin);
  });

  Widget harness() => ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          checkinRepositoryProvider.overrideWithValue(mockRepo),
          checkinCooldownProvider.overrideWith((ref) => Future.value(Duration.zero)),
        ],
        child: const MaterialApp(home: CheckinFlowScreen()),
      );

  // The value-5 emoji is unique to each of the 5 steps, in order — used to
  // unambiguously tap one answer per step.
  const step5Emojis = ['😄', '😎', '🤗', '🚀', '🌟'];

  testWidgets(
      'F1: answering all 5 steps submits the check-in and shows success',
      (tester) async {
    // Use a realistic phone-sized surface so the success screen (designed for
    // tall phone viewports) does not overflow the 800x600 test default.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    for (var i = 0; i < step5Emojis.length; i++) {
      expect(find.text(step5Emojis[i]), findsOneWidget,
          reason: 'step ${i + 1} emoji should be on screen');
      await tester.tap(find.text(step5Emojis[i]));
      await tester.pump(); // record selection + schedule the delayed advance
      await tester.pump(const Duration(milliseconds: 450)); // fire delayed onNext
      await tester.pumpAndSettle(); // finish page transition / submit
    }

    // The final step must trigger submit() exactly once …
    verify(() => mockRepo.submitCheckin(
          uid: any(named: 'uid'),
          userIdHash: any(named: 'userIdHash'),
          overallMood: any(named: 'overallMood'),
          workStress: any(named: 'workStress'),
          teamHarmony: any(named: 'teamHarmony'),
          personalGrowth: any(named: 'personalGrowth'),
          workLifeBalance: any(named: 'workLifeBalance'),
          companyId: any(named: 'companyId'),
          department: any(named: 'department'),
        )).called(1);

    // … and the success screen must appear.
    expect(find.text('Teşekkürler!'), findsOneWidget);
  });
}
