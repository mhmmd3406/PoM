import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/features/auth/providers/auth_provider.dart';
import 'package:pom_app/features/profile/presentation/profile_screen.dart';
import 'package:pom_app/models/user_model.dart';

void main() {
  testWidgets(
      'F3: tapping "Hesabımı sil" opens a confirmation dialog (no longer dead)',
      (tester) async {
    // Tall + 800px-wide surface: wide enough that the header chip row doesn't
    // overflow (a narrower surface does), tall enough that the lazily-built
    // ListView realises every row, so the delete row is present + tappable.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = UserModel(
      uid: 'u1',
      linkedinHash: 'h1',
      displayName: 'Mehmet Demir',
      email: 'mehmet@pom.app',
      role: 'pro',
      kvkkAccepted: true,
      kvkkVersion: '1.0',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(user)],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hesabımı sil'));
    await tester.pumpAndSettle();

    // The confirmation dialog (unique title "Hesabını sil") proves the button
    // is wired. No repository/Cloud Function call runs until the user confirms,
    // so the test stays Firebase-free.
    expect(find.text('Hesabını sil'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
  });
}
