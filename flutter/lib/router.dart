import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/kvkk_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/checkin/checkin_screen.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn  = auth.asData?.value != null;
      final loc         = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/' || loc == '/onboarding/profile';
      final isKvkkRoute = loc == '/onboarding/kvkk';
      final isLegalRoute = loc.startsWith('/legal');

      if (!isLoggedIn && !isAuthRoute) return '/';
      if (isLoggedIn  && loc == '/login') return '/home';

      // KVKK consent gate: after login, check if user has accepted current version
      if (isLoggedIn && !isAuthRoute && !isKvkkRoute && !isLegalRoute) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return '/';

        try {
          final results = await Future.wait([
            FirebaseFirestore.instance.collection('users').doc(uid).get(),
            FirebaseFirestore.instance.doc('platform_config/legal_texts').get(),
          ]);

          final userDoc   = results[0];
          final configDoc = results[1];

          final currentVersion  = (configDoc.data()?['kvkk_version'] as String?) ?? '';
          final acceptedVersion = (userDoc.data()?['kvkk_version_accepted'] as String?) ?? '';

          if (currentVersion.isNotEmpty && acceptedVersion != currentVersion) {
            return '/onboarding/kvkk';
          }
        } catch (_) {
          // If check fails, allow navigation (fail open — don't block the user indefinitely)
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/onboarding/profile',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/kvkk',
        builder: (_, __) => const KvkkScreen(),
      ),
      GoRoute(path: '/home',         builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/checkin',      builder: (_, __) => const CheckinScreen()),
      GoRoute(path: '/insights',     builder: (_, __) => const InsightsScreen()),
      GoRoute(path: '/wallet',       builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/settings',     builder: (_, __) => const SettingsScreen()),
    ],
  );
});
