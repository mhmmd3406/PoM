import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

const _linkedinClientId = String.fromEnvironment('LINKEDIN_CLIENT_ID');
const _callbackScheme = 'com.pom.app';
const _functionsBaseUrl = String.fromEnvironment('FUNCTIONS_BASE_URL');

class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String _generateState() {
    final rand = Random.secure();
    return List.generate(24, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// LinkedIn OAuth 2.0 flow (server-side exchange):
  /// 1. Open LinkedIn consent page
  /// 2. LinkedIn → Cloud Function (exchanges code, creates Firebase user)
  /// 3. Cloud Function → deep-link redirect (com.pom.app://callback?customToken=...)
  /// 4. FlutterWebAuth2 captures redirect → sign in with customToken
  Future<({bool isNewUser})> signInWithLinkedIn() async {
    final state = _generateState();

    final authUrl = Uri.https('www.linkedin.com', '/oauth/v2/authorization', {
      'response_type': 'code',
      'client_id': _linkedinClientId,
      'redirect_uri': '$_functionsBaseUrl/linkedinCallback',
      'scope': 'openid profile',
      'state': state,
    });

    late final Uri resultUri;
    try {
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackScheme,
      );
      resultUri = Uri.parse(resultUrl);
    } on Exception catch (e) {
      // FlutterWebAuth2 throws when user closes the browser / cancels
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('dismiss') || msg.contains('usercancel')) {
        throw Exception('Login cancelled');
      }
      rethrow;
    }

    // Cloud Function encodes errors as ?error= in the redirect
    final error = resultUri.queryParameters['error'];
    if (error != null) {
      final desc = resultUri.queryParameters['error_description'] ?? error;
      if (error == 'access_denied') throw Exception('Login cancelled');
      throw Exception('LinkedIn error: $desc');
    }

    // CSRF validation — state is echoed back by the Cloud Function
    final returnedState = resultUri.queryParameters['state'];
    if (returnedState != state) {
      throw Exception('OAuth state mismatch — possible CSRF attack');
    }

    final customToken = resultUri.queryParameters['customToken'] ?? '';
    final isNewUser = resultUri.queryParameters['isNewUser'] == 'true';

    if (customToken.isEmpty) {
      throw Exception('Authentication failed — no token received');
    }

    await _auth.signInWithCustomToken(customToken);
    return (isNewUser: isNewUser);
  }

  Future<void> signOut() => _auth.signOut();
}

// Riverpod providers
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(firebaseAuthProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.read(authServiceProvider).authStateChanges,
);
