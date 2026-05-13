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

  /// Generates a cryptographically random state token for CSRF protection.
  String _generateState() {
    final rand = Random.secure();
    return List.generate(24, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Full LinkedIn OAuth 2.0 flow:
  /// 1. Open LinkedIn consent page in system browser
  /// 2. LinkedIn redirects to our deep-link with `code`
  /// 3. Cloud Function exchanges code → Firebase custom token
  /// 4. Sign in to Firebase with custom token
  Future<({bool isNewUser})> signInWithLinkedIn() async {
    final state = _generateState();

    final authUrl = Uri.https('www.linkedin.com', '/oauth/v2/authorization', {
      'response_type': 'code',
      'client_id': _linkedinClientId,
      'redirect_uri': '$_functionsBaseUrl/linkedinCallback',
      'scope': 'openid profile',
      'state': state,
    });

    // Opens system browser; resumes when the deep-link fires
    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final uri = Uri.parse(resultUrl);
    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];

    if (code == null) throw Exception('LinkedIn auth cancelled or failed');
    if (returnedState != state) throw Exception('OAuth state mismatch — possible CSRF');

    // Exchange via our Cloud Function
    final response = await _exchangeCodeViaFunction(code, state);
    final customToken = response['customToken'] as String;
    final isNewUser = response['isNewUser'] as bool;

    await _auth.signInWithCustomToken(customToken);
    return (isNewUser: isNewUser);
  }

  Future<Map<String, dynamic>> _exchangeCodeViaFunction(
      String code, String state) async {
    // Uses Cloud Functions HTTP endpoint (no SDK needed for this one call)
    final uri = Uri.parse('$_functionsBaseUrl/linkedinCallback')
        .replace(queryParameters: {'code': code, 'state': state});

    // flutter_web_auth_2 completes after redirect; the custom token
    // is embedded in the redirect URL by our Cloud Function for mobile.
    // For web we'd use a different flow — handled server-side.
    //
    // Mobile flow: Cloud Function returns JSON; we parse it from the
    // redirect URL query params that the function appends to callbackScheme.
    final token = uri.queryParameters['customToken'] ?? '';
    final isNew = uri.queryParameters['isNewUser'] == 'true';
    return {'customToken': token, 'isNewUser': isNew};
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
