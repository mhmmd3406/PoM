import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/checkin/checkin_screen.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/wallet/wallet_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = auth.asData?.value != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/' ||
          state.matchedLocation == '/onboarding/profile';

      if (!isLoggedIn && !isAuthRoute) return '/';
      if (isLoggedIn && state.matchedLocation == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/onboarding/profile',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/checkin', builder: (_, __) => const CheckinScreen()),
      GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
    ],
  );
});
