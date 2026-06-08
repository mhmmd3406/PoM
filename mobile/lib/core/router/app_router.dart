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
import '../../features/surveys/presentation/gate_survey_screen.dart';
import '../../features/surveys/presentation/survey_answer_screen.dart';
import '../../features/surveys/presentation/surveys_screen.dart';
import '../../features/surveys/providers/gate_survey_notifier.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../widgets/connection_error_widget.dart';
import '../widgets/pro_gate.dart';

class AppRoutes {
  static const home         = '/';
  static const onboarding   = '/onboarding';
  static const login        = '/login';
  static const kvkk         = '/kvkk';
  static const gateSurvey   = '/gate-survey';
  static const checkin      = '/checkin';
  static const insights     = '/insights';
  static const surveys      = '/surveys';
  static const profile      = '/profile';
  static const wallet       = '/wallet';
  static const subscription = '/subscription';
  static const benchmarking  = '/benchmarking';
  static const reports       = '/reports';
  static const surveyAnswer  = '/survey/:id/answer';
  static const surveyLock    = '/survey/:id/lock';

  // Routes the gate survey intercepts when the survey is mandatory.
  static const _gatedRoutes = {
    home, checkin, insights, surveys, profile,
    wallet, subscription, benchmarking, reports,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider.notifier);
  final gateSurveyNotifier = ref.watch(gateSurveyNotifierProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: Listenable.merge([authNotifier, gateSurveyNotifier]),
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

        // Gate survey intercept — never redirect away from the gate itself.
        if (loc != AppRoutes.gateSurvey) {
          final gs = ref.read(gateSurveyNotifierProvider);
          if (!gs.isLoading && gs.shouldShow) {
            final isMandatory = gs.pendingSurvey?.isMandatory ?? false;
            // Mandatory: block all app screens. Non-mandatory: block only home.
            if (isMandatory
                ? AppRoutes._gatedRoutes.contains(loc)
                : loc == AppRoutes.home) {
              return AppRoutes.gateSurvey;
            }
          }
        }
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
        path: AppRoutes.gateSurvey,
        builder: (context, state) => const GateSurveyScreen(),
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
        path: AppRoutes.surveyAnswer,
        builder: (context, state) => SurveyAnswerScreen(
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
