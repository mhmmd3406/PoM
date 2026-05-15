import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
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

  /// Exchanges the authorization code for a Firebase custom token via a
  /// Cloud Function, then signs in to Firebase.
  Future<UserModel> signInWithLinkedInCode(String authorizationCode) async {
    // Call the Cloud Function
    final callable = _functions.httpsCallable('linkedinAuth');
    final result = await callable.call<Map<String, dynamic>>({
      'code': authorizationCode,
      'redirectUri': AppConstants.linkedInRedirectUri,
    });

    final data = result.data;
    final customToken = data['customToken'] as String;
    final linkedinId = data['linkedinId'] as String;
    final displayName = data['displayName'] as String?;
    final avatarUrl = data['avatarUrl'] as String?;
    final email = data['email'] as String?;

    // Hash the LinkedIn ID for privacy
    final linkedinHash = _hmacSha256(linkedinId);

    // Sign in with the custom token
    final credential = await _auth.signInWithCustomToken(customToken);
    final uid = credential.user!.uid;

    // Upsert the user document in Firestore
    final userRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid);

    final snapshot = await userRef.get();
    UserModel user;

    if (!snapshot.exists) {
      user = UserModel(
        uid: uid,
        linkedinHash: linkedinHash,
        displayName: displayName,
        avatarUrl: avatarUrl,
        email: email,
        role: AppConstants.planFree,
        kvkkAccepted: false,
        creditBalance: 0,
        createdAt: DateTime.now(),
      );
      await userRef.set(user.toFirestore());
    } else {
      user = UserModel.fromFirestore(snapshot);
      // Keep profile data fresh
      await userRef.update({
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (email != null) 'email': email,
      });
    }

    return user;
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

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _hmacSha256(String data) {
    // NOTE: In production the secret key should come from a secure config, not
    // be hardcoded. This is a placeholder pattern.
    const secret = 'pom-linkedin-hash-secret-REPLACE_ME';
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }
}

// ─── Riverpod provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(cloudFunctionsProvider),
  );
});
