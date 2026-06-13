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
import '../../features/legal/legal_provider.dart';
import '../../features/legal/presentation/legal_text_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/surveys/presentation/survey_answer_screen.dart';
import '../../features/surveys/presentation/survey_result_screen.dart';
import '../../features/surveys/presentation/surveys_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../widgets/connection_error_widget.dart';
import '../widgets/pro_gate.dart';

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
  static const benchmarking  = '/benchmarking';
  static const reports       = '/reports';
  static const legal         = '/legal/:key';
  static const surveyAnswer  = '/survey/:id/answer';
  static const surveyResult  = '/survey/:id/result';
  static const surveyLock    = '/survey/:id/lock';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider.notifier);
  // Refresh on auth changes AND when the published legal texts load/change, so
  // a newly-published KVKK version re-triggers the redirect check below.
  final refresh = _RouterRefresh(ref, authNotifier);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateNotifierProvider);
      if (authState.isLoading) return null;

      final isAuthenticated = authState.user != null;
      final kvkkAccepted = authState.user?.kvkkAccepted ?? false;

      // Re-prompt KVKK when the published version differs from the one the user
      // accepted — so the accepted text always equals the live text. Fail open:
      // if the published version is unknown (loading / error / unpublished, e.g.
      // debug bypass with no Firebase auth), fall back to the accepted flag and
      // never lock the user out.
      final publishedKvkkVersion =
          ref.read(legalTextsProvider).valueOrNull?['kvkk']?.version;
      final acceptedVersion = authState.user?.kvkkVersion;
      final needsKvkk = !kvkkAccepted ||
          (publishedKvkkVersion != null &&
              publishedKvkkVersion.isNotEmpty &&
              publishedKvkkVersion != acceptedVersion);

      final loc = state.matchedLocation;

      // Fully authenticated users skip onboarding/login/kvkk → home
      if (isAuthenticated && !needsKvkk) {
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

      // Authenticated but KVKK not accepted (or outdated) → KVKK screen
      if (needsKvkk && loc != AppRoutes.kvkk) {
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
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final isPro = ref.watch(currentUserProvider)?.isPro ?? false;
            if (isPro) return const BenchmarkingScreen();
            return ProGateScreen(
              appBarTitle: 'Şirket Karşılaştırması',
              heading: 'Şirket karşılaştırması Pro\'ya özel',
              message: 'Şirketini sektör ortalaması ve diğer şirketlerle yan '
                  'yana kıyaslamak için Pro\'ya geç.',
              bullets: const [
                'Şirketini sektör ortalamasıyla karşılaştır',
                '6 şirkete kadar yan yana benchmark',
                'Son 30 / 90 gün ve tüm zaman aralıkları',
              ],
              onBack: () => context.go(AppRoutes.home),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final isPro = ref.watch(currentUserProvider)?.isPro ?? false;
            if (isPro) return const ReportsScreen();
            return ProGateScreen(
              appBarTitle: 'Raporlar',
              heading: 'Raporlar Pro\'ya özel',
              message: 'Çalışan, İK ve yönetim raporlarına ve PDF dışa '
                  'aktarmaya Pro ile eriş.',
              bullets: const [
                'Çalışan, İK ve yönetim raporları',
                '12 haftalık tarihsel trendler',
                'PDF dışa aktarma & rozetler',
              ],
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.legal,
        builder: (context, state) => LegalTextScreen(
          docKey: state.pathParameters['key'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.surveyAnswer,
        builder: (context, state) => SurveyAnswerScreen(
          surveyId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.surveyResult,
        builder: (context, state) => SurveyResultScreen(
          surveyId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.surveyLock,
        builder: (context, state) => const SurveyMinNLockScreen(),
      ),
    ],
    errorBuilder: (context, state) => ConnectionErrorWidget(
      title: 'Sayfa bulunamadı',
      message: state.error?.message ?? 'Bilinmeyen hata',
      onRetry: () => context.go(AppRoutes.home),
    ),
  );
});

/// Bridges the auth notifier and the published legal texts into a single
/// [Listenable] so GoRouter re-runs its redirect when either changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref, this._authNotifier) {
    _authNotifier.addListener(notifyListeners);
    _legalSub =
        ref.listen(legalTextsProvider, (_, __) => notifyListeners());
  }

  final Listenable _authNotifier;
  late final ProviderSubscription _legalSub;

  @override
  void dispose() {
    _authNotifier.removeListener(notifyListeners);
    _legalSub.close();
    super.dispose();
  }
}
