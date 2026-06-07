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

  Future<SurveyModel?> getSurvey(String surveyId) async {
    final doc = await _db.collection('surveys').doc(surveyId).get();
    if (!doc.exists) return null;
    return SurveyModel.fromFirestore(doc);
  }

  /// Writes a pseudonymous survey response and records the survey as answered
  /// on the user's own document. The response doc stays keyed by [userIdHash]
  /// (no PII); only the owner-readable user doc learns which surveys were
  /// answered, so the app never needs to read `survey_responses` (which
  /// firestore.rules restrict to admins / company members).
  Future<void> submitResponse({
    required String surveyId,
    required String companyId,
    required String userIdHash,
    required String? uid,
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

    // Record the survey as answered on the user's own doc (owner-writable) —
    // the app's source of truth for "already answered".
    if (uid != null) {
      batch.set(
        _db.collection('users').doc(uid),
        {
          'answeredSurveyIds': FieldValue.arrayUnion([surveyId]),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}

final surveysRepositoryProvider = Provider<SurveysRepository>((ref) {
  return SurveysRepository(ref.watch(firestoreProvider));
});
