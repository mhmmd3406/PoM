import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/kvkk_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/benchmarking/presentation/benchmarking_screen.dart';
import '../../features/checkin/presentation/checkin_flow_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/surveys/presentation/surveys_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';

class AppRoutes {
  static const home         = '/';
  static const onboarding   = '/onboarding';
  static const login        = '/login';
  static const kvkk         = '/kvkk';
  static const checkin      = '/checkin';
  static const insights     = '/insights';
  static const surveys      = '/surveys';
  static const profile      = '/profile';
  static const wallet       = '/wallet';
  static const subscription = '/subscription';
  static const benchmarking = '/benchmarking';
  static const reports      = '/reports';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateNotifierProvider);
      if (authState.isLoading) return null;

      final isAuthenticated = authState.user != null;
      final kvkkAccepted = authState.user?.kvkkAccepted ?? false;
      final loc = state.matchedLocation;

      // Fully authenticated users skip onboarding/login/kvkk → home
      if (isAuthenticated && kvkkAccepted) {
        const authScreens = [
          AppRoutes.onboarding,
          AppRoutes.login,
          AppRoutes.kvkk,
        ];
        if (authScreens.contains(loc)) return AppRoutes.home;
        return null;
      }

      // Onboarding: allow unauthenticated users through
      if (loc == AppRoutes.onboarding) return null;

      // Not authenticated → login (unless already there)
      if (!isAuthenticated) {
        return loc == AppRoutes.login ? null : AppRoutes.login;
      }

      // Authenticated but KVKK not accepted → KVKK screen
      if (!kvkkAccepted && loc != AppRoutes.kvkk) {
        return AppRoutes.kvkk;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.kvkk,
        builder: (context, state) => const KvkkScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkin,
        builder: (context, state) => const CheckinFlowScreen(),
      ),
      GoRoute(
        path: AppRoutes.insights,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: AppRoutes.surveys,
        builder: (context, state) => const SurveysScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.benchmarking,
        builder: (context, state) => const BenchmarkingScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Sayfa bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.error?.message ?? 'Bilinmeyen hata'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    ),
  );
});
