import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import 'survey_model.dart';

String hashUserId(String uid) =>
    sha256.convert(utf8.encode(uid)).toString();

class SurveysRepository {
  const SurveysRepository(this._db);
  final FirebaseFirestore _db;

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

  // Survey IDs that the given user (by hash) has already responded to.
  Stream<Set<String>> watchMyResponseSurveyIds(String userIdHash) {
    return _db
        .collection('survey_responses')
        .where('userIdHash', isEqualTo: userIdHash)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d['surveyId'] as String).toSet());
  }

  Future<SurveyModel?> getSurvey(String surveyId) async {
    final doc = await _db.collection('surveys').doc(surveyId).get();
    if (!doc.exists) return null;
    return SurveyModel.fromFirestore(doc);
  }

  // Returns true if this user already has a response for the given survey.
  Future<bool> hasResponded(String surveyId, String userIdHash) async {
    final snap = await _db
        .collection('survey_responses')
        .where('surveyId', isEqualTo: surveyId)
        .where('userIdHash', isEqualTo: userIdHash)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> submitResponse({
    required String surveyId,
    required String companyId,
    required String userIdHash,
    required Map<String, dynamic> answers,
  }) async {
    final batch = _db.batch();

    final responseRef = _db.collection('survey_responses').doc();
    batch.set(responseRef, {
      'surveyId': surveyId,
      'companyId': companyId,
      'userIdHash': userIdHash,
      'answers': answers,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Increment response count on the survey document.
    batch.update(_db.collection('surveys').doc(surveyId), {
      'responseCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}

final surveysRepositoryProvider = Provider<SurveysRepository>((ref) {
  return SurveysRepository(ref.watch(firestoreProvider));
});
