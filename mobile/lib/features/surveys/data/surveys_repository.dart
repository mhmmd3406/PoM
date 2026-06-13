import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import 'survey_model.dart';

class SurveysRepository {
  const SurveysRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // All surveys the user is eligible to see (their company + platform-wide).
  // Status filtering is done client-side to avoid composite index requirements.
  Stream<List<SurveyModel>> watchEligibleSurveys(String? companyId) {
    final List<String> whereIn =
        companyId != null ? [companyId, '__admin__'] : ['__admin__'];
    return _db
        .collection('surveys')
        .where('companyId', whereIn: whereIn)
        .snapshots()
        .map((snap) => snap.docs.map(SurveyModel.fromFirestore).toList());
  }

  Future<SurveyModel?> getSurvey(String surveyId) async {
    final doc = await _db.collection('surveys').doc(surveyId).get();
    if (!doc.exists) return null;
    return SurveyModel.fromFirestore(doc);
  }

  /// Submits a survey response via the `submitSurveyResponse` Cloud Function.
  /// The server derives the pseudonymous userIdHash from the caller's uid, reads
  /// companyId from the survey, enforces one-response-per-user, and writes the
  /// response + responseCount + the owner's answeredSurveyIds/surveyAnswers
  /// atomically. The client no longer writes `survey_responses` directly
  /// (firestore.rules now forbid it), which closes the arbitrary-userIdHash and
  /// ballot-stuffing gaps.
  Future<void> submitResponse({
    required String surveyId,
    required Map<String, dynamic> answers,
  }) async {
    final callable = _functions.httpsCallable('submitSurveyResponse');
    await callable.call<Map<String, dynamic>>({
      'surveyId': surveyId,
      'answers': answers,
    });
  }
}

final surveysRepositoryProvider = Provider<SurveysRepository>((ref) {
  return SurveysRepository(
    ref.watch(firestoreProvider),
    ref.watch(cloudFunctionsProvider),
  );
});
