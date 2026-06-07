import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/user_model.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  // ─── LinkedIn OAuth ─────────────────────────────────────────────────────────

  /// Opens the LinkedIn OAuth consent screen in the browser.
  /// The deep-link callback (https://app.pom.app/auth/callback?code=...) is
  /// handled at the router level; call [signInWithLinkedInCode] with the code.
  Future<void> launchLinkedInOAuth() async {
    final uri = Uri.parse(
      '${AppConstants.linkedInAuthBaseUrl}'
      '?response_type=code'
      '&client_id=${AppConstants.linkedInClientId}'
      '&redirect_uri=${Uri.encodeComponent(AppConstants.linkedInRedirectUri)}'
      '&scope=${AppConstants.linkedInScope}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('LinkedIn OAuth URL açılamadı');
    }
  }

  /// Exchanges the authorization code for a Firebase custom token via the
  /// `linkedinAuth` Cloud Function, then signs in to Firebase.
  ///
  /// The Cloud Function is the SINGLE writer of the user document (one canonical
  /// camelCase schema, also read by the admin portal). After sign-in we simply
  /// read that document back — no client-side upsert or hashing.
  Future<UserModel> signInWithLinkedInCode(String authorizationCode) async {
    final callable = _functions.httpsCallable('linkedinAuth');
    final result = await callable.call<Map<String, dynamic>>({
      'code': authorizationCode,
      'redirectUri': AppConstants.linkedInRedirectUri,
    });

    final customToken = result.data['customToken'] as String;
    final credential = await _auth.signInWithCustomToken(customToken);
    final uid = credential.user!.uid;

    // The function committed the user/wallet/subscription docs before returning,
    // so this read sees them. Fall back to a minimal model only if the document
    // is unexpectedly missing.
    final user = await getUser(uid);
    return user ?? UserModel(uid: uid, linkedinHash: '');
  }

  // ─── KVKK ───────────────────────────────────────────────────────────────────

  Future<void> acceptKvkk(String uid, String version) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'kvkkAccepted': true,
      'kvkkVersion': version,
      'kvkkAcceptedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ─── User stream ─────────────────────────────────────────────────────────────

  Stream<UserModel?> watchUser(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    return snap.exists ? UserModel.fromFirestore(snap) : null;
  }

  // ─── Platform config (KVKK version, thresholds) ──────────────────────────────

  Future<Map<String, dynamic>> getPlatformConfig() async {
    final snap = await _firestore
        .collection(AppConstants.platformConfigCollection)
        .doc('thresholds')
        .get();
    return snap.exists ? snap.data()! : {};
  }

  // ─── Sign out ────────────────────────────────────────────────────────────────

  Future<void> signOut() => _auth.signOut();
}

// ─── Riverpod provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(cloudFunctionsProvider),
  );
});
