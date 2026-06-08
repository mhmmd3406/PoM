import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Debug bypass mode uses a fake in-memory test user (see AuthStateNotifier)
  // that is NOT a real Firebase Auth principal. Firestore security rules require
  // `request.auth != null` to read `surveys` / `survey_responses`, so without a
  // session those reads are rejected and the survey list (and the gate survey)
  // silently shows empty — even though the admin panel writes to the same
  // project. Signing in anonymously gives the bypassed user a real session so it
  // can read (and answer) live surveys. No-op once a session already exists.
  // Requires the Anonymous provider enabled in Firebase Console → Authentication.
  if (kDebugMode &&
      AppConstants.debugBypassAuth &&
      FirebaseAuth.instance.currentUser == null) {
    // Cold-boot emulators aren't always network-ready the instant the app
    // starts, so retry signInAnonymously() with short backoff.
    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        break;
      } catch (e) {
        if (attempt == 5) {
          debugPrint(
            'Anonim Firebase girişi 5 denemede başarısız — anketler '
            'yüklenemeyebilir. Firebase Console → Authentication → Sign-in '
            'method → Anonymous etkin mi? Hata: $e',
          );
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  // Wire Crashlytics fatal error handlers (no-op in debug to keep stack traces readable).
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Initialize Turkish locale data for DateFormat.
  await initializeDateFormatting('tr_TR', null);

  // Stripe init is skipped gracefully if the publishable key is a placeholder.
  final stripeKey = AppConstants.stripePublishableKey;
  if (!stripeKey.contains('REPLACE_ME') && stripeKey.isNotEmpty) {
    try {
      Stripe.publishableKey = stripeKey;
      await Stripe.instance.applySettings();
    } catch (_) {}
  }

  runApp(const ProviderScope(child: PomApp()));
}

class PomApp extends ConsumerWidget {
  const PomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'PoM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
