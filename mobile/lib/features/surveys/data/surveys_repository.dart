import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import 'survey_model.dart';

String hashUserId(String uid) =>
    sha256.convert(utf8.encode(uid)).toString();

class SurveysRepository {
  const SurveysRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

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

  // Survey IDs the current user has already answered. Read from the user's own
  // document (users/{uid}.answeredSurveyIds) — owner-only readable — so the
  // mobile app never needs to read the cross-tenant `survey_responses`
  // collection. `uid` is the live Firebase Auth uid (== request.auth.uid), which
  // the `users/{uid}` security rule (isOwner) requires.
  Stream<Set<String>> watchAnsweredSurveyIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final list = (doc.data()?['answeredSurveyIds'] as List?) ?? const [];
      return list.map((e) => e.toString()).toSet();
    });
  }

  Future<SurveyModel?> getSurvey(String surveyId) async {
    final doc = await _db.collection('surveys').doc(surveyId).get();
    if (!doc.exists) return null;
    return SurveyModel.fromFirestore(doc);
  }

  // Returns true if the current user has already answered the given survey,
  // based on their own users/{uid}.answeredSurveyIds list (no survey_responses
  // read — see watchAnsweredSurveyIds).
  Future<bool> hasResponded(String surveyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('users').doc(uid).get();
    final list = (doc.data()?['answeredSurveyIds'] as List?) ?? const [];
    return list.map((e) => e.toString()).contains(surveyId);
  }

  Future<void> submitResponse({
    required String surveyId,
    required String companyId,
    required Map<String, dynamic> answers,
  }) async {
    final uid = _auth.currentUser?.uid;

    // Record the (pseudonymous) response. This is the write that must succeed.
    // userIdHash stays derived from the live Firebase uid so server-side
    // analytics/dedup can still group a user's answers without storing a raw id.
    await _db.collection('survey_responses').add({
      'surveyId': surveyId,
      'companyId': companyId,
      'userIdHash': uid != null ? hashUserId(uid) : 'anonymous',
      'answers': answers,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Mark this survey answered on the user's OWN document so the "completed /
    // already-answered" filters can be computed without reading the (now
    // company-scoped) survey_responses collection. Best-effort: the response is
    // already saved, and this only feeds a client-side UX dedup hint.
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set(
          {'answeredSurveyIds': FieldValue.arrayUnion([surveyId])},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    // Best-effort: bump the survey's response counter. Survey docs are
    // admin/server-write-only under the deployed security rules, so a
    // permission failure here must NOT fail the submission — the response is
    // already saved and the counter can be reconciled server-side.
    try {
      await _db.collection('surveys').doc(surveyId).update({
        'responseCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }
}

final surveysRepositoryProvider = Provider<SurveysRepository>((ref) {
  return SurveysRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});
