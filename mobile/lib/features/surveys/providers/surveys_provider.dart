import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../data/survey_model.dart';
import '../data/surveys_repository.dart';

export '../data/survey_model.dart';
export '../data/surveys_repository.dart' show hashUserId, surveysRepositoryProvider;

// All surveys visible to the current user (admin + company), unfiltered by status.
final _eligibleSurveysProvider = StreamProvider<List<SurveyModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(surveysRepositoryProvider)
      .watchEligibleSurveys(user.companyId);
});

// Set of surveyIds the current user has already answered. Sourced from the
// user document's answeredSurveyIds (loaded at sign-in, refreshed locally after
// each submit) — NOT from a survey_responses query, which firestore.rules
// restrict to admins / company members and which caused PERMISSION_DENIED for
// platform (__admin__) surveys.
final myResponseSurveyIdsProvider = Provider<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.answeredSurveyIds.toSet() ?? <String>{};
});

// Active surveys the user hasn't answered yet.
final pendingSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final answered = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    return list
        .where((s) =>
            s.status == SurveyStatus.active && !answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// Surveys the current user has already answered.
final completedSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final answered = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    return list
        .where((s) => answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// First active gate survey the current user hasn't responded to (null if none).
// Reuses pendingSurveysProvider so the "already answered" source of truth stays
// the user document's answeredSurveyIds (no survey_responses read).
final pendingGateSurveyProvider = Provider<AsyncValue<SurveyModel?>>((ref) {
  return ref.watch(pendingSurveysProvider).whenData((list) {
    final gates = list.where((s) => s.isGate);
    return gates.isEmpty ? null : gates.first;
  });
});

// Single survey by Firestore document ID.
final surveyByIdProvider =
    FutureProvider.family<SurveyModel?, String>((ref, id) {
  return ref.watch(surveysRepositoryProvider).getSurvey(id);
});
