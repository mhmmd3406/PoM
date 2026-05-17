import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PoM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
