// GENERATED — do not edit manually.
// Re-generate with: flutterfire configure
//
// How to set up:
//   1. Install FlutterFire CLI: dart pub global activate flutterfire_cli
//   2. Run: flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//   3. Commit the generated file (it contains no secrets).
//
// The values below are PLACEHOLDERS. Replace by running flutterfire configure.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS     => ios,
      _ => throw UnsupportedError(
          'DefaultFirebaseOptions not configured for this platform.'),
    };
  }

  // ── Replace these values after running `flutterfire configure` ──

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'REPLACE_WITH_ANDROID_API_KEY',
    appId:             'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId:         'REPLACE_WITH_PROJECT_ID',
    storageBucket:     'REPLACE_WITH_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'REPLACE_WITH_IOS_API_KEY',
    appId:             'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId:         'REPLACE_WITH_PROJECT_ID',
    storageBucket:     'REPLACE_WITH_PROJECT_ID.appspot.com',
    iosClientId:       'REPLACE_WITH_IOS_CLIENT_ID',
    iosBundleId:       'com.pom.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'REPLACE_WITH_WEB_API_KEY',
    appId:             'REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId:         'REPLACE_WITH_PROJECT_ID',
    storageBucket:     'REPLACE_WITH_PROJECT_ID.appspot.com',
    authDomain:        'REPLACE_WITH_PROJECT_ID.firebaseapp.com',
  );
}
