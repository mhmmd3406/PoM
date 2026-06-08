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
    // NOT an atomic batch on purpose. The response write is the only critical,
    // always-permitted operation; the two follow-ups can legitimately be denied
    // (e.g. the users/{uid} write when uid != the caller's auth uid in
    // debug-bypass) and must NOT roll back the saved response.

    // 1) Critical: the pseudonymous response. Keys must EXACTLY match the
    //    firestore.rules create allow-list (surveyId, companyId, userIdHash,
    //    answers, created_at) — any extra key fails the rule.
    await _db.collection('survey_responses').add({
      'surveyId': surveyId,
      'companyId': companyId,
      'userIdHash': userIdHash,
      'answers': answers,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2) Best-effort: bump the survey's response counter (rules cap authed
    //    users to a +1 increment). Non-fatal.
    try {
      await _db.collection('surveys').doc(surveyId).update({
        'responseCount': FieldValue.increment(1),
      });
    } catch (_) {/* non-fatal */}

    // 3) Best-effort: record "answered" on the user's own doc (owner-writable).
    //    Only succeeds when uid == the caller's auth uid (real LinkedIn user);
    //    denied in debug-bypass (test uid != anonymous session uid). Non-fatal —
    //    the response is already saved.
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set(
          {'answeredSurveyIds': FieldValue.arrayUnion([surveyId])},
          SetOptions(merge: true),
        );
      } catch (_) {/* non-fatal */}
    }
  }
}

final surveysRepositoryProvider = Provider<SurveysRepository>((ref) {
  return SurveysRepository(ref.watch(firestoreProvider));
});
