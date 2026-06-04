import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/survey_model.dart';
import '../data/surveys_repository.dart';

export '../data/survey_model.dart';
export '../data/surveys_repository.dart' show hashUserId, surveysRepositoryProvider;

// Surveys (and survey_responses) require a Firebase auth session — the deployed
// rules gate reads on `request.auth != null`. In debug-bypass mode the visible
// user is a fake in-memory persona, so we wait for the anonymous Firebase
// session (signed in from main()) to land before querying; otherwise the read
// is rejected with permission-denied or returns an empty offline snapshot.
// authStateChanges emits the current user immediately on subscribe, so once the
// session exists these providers re-run automatically and load live data.

// All surveys visible to the current user (admin + company), unfiltered by status.
final _eligibleSurveysProvider = StreamProvider<List<SurveyModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final firebaseReady = ref.watch(authStateProvider).valueOrNull != null;
  if (!firebaseReady) return Stream.value(const <SurveyModel>[]);
  return ref
      .watch(surveysRepositoryProvider)
      .watchEligibleSurveys(user.companyId);
});

// Set of surveyIds the current user has already responded to.
final myResponseSurveyIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value({});
  final firebaseReady = ref.watch(authStateProvider).valueOrNull != null;
  if (!firebaseReady) return Stream.value(<String>{});
  return ref.watch(surveysRepositoryProvider).watchAnsweredSurveyIds();
});

// Active surveys the user hasn't answered yet.
final pendingSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final responseIds = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    final answered = responseIds.valueOrNull ?? {};
    return list
        .where((s) =>
            s.status == SurveyStatus.active && !answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// Surveys the current user has already responded to.
final completedSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final responseIds = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    final answered = responseIds.valueOrNull ?? {};
    return list
        .where((s) => answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// First active gate survey the current user hasn't responded to (null if none).
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
