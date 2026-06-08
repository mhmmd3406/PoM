import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../providers/gate_survey_notifier.dart';
import 'survey_answer_screen.dart';

/// Full-screen intercept shown on app launch when the current user has an
/// unanswered active gate survey (isGate == true). Non-mandatory gates expose a
/// "Atla" (skip) action; mandatory gates can only be dismissed by completing.
class GateSurveyScreen extends ConsumerWidget {
  const GateSurveyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gateSurveyNotifierProvider);

    if (gs.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final survey = gs.pendingSurvey;
    if (survey == null) {
      // Survey no longer pending (completed or no active gate survey) → home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return SurveyAnswerScreen(
      key: ValueKey(survey.id),
      surveyId: survey.id,
      canClose: !survey.isMandatory,
      showSkip: !survey.isMandatory,
      onSkip: () {
        ref.read(gateSurveyNotifierProvider.notifier).dismiss();
        context.go(AppRoutes.home);
      },
    );
  }
}
