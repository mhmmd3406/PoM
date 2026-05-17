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
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';

// Route names
class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const kvkk = '/kvkk';
  static const checkin = '/checkin';
  static const insights = '/insights';
  static const wallet = '/wallet';
  static const subscription = '/subscription';
  static const benchmarking = '/benchmarking';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateNotifierProvider);
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isAuthenticated = authState.user != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnKvkk = state.matchedLocation == AppRoutes.kvkk;

      // Not authenticated → go to login
      if (!isAuthenticated) {
        return isOnLogin ? null : AppRoutes.login;
      }

      // Authenticated but KVKK not accepted → go to KVKK
      final kvkkAccepted = authState.user?.kvkkAccepted ?? false;
      if (!kvkkAccepted && !isOnKvkk) {
        return AppRoutes.kvkk;
      }

      // Already on login/kvkk but authenticated and KVKK accepted → go home
      if ((isOnLogin || isOnKvkk) && kvkkAccepted) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
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
