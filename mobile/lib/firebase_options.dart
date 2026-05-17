// Generated from Firebase Console project: pomapp-c3ccc
// Web config applied. Android/iOS app IDs need google-services.json /
// GoogleService-Info.plist from Firebase Console → Project Settings → Your apps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBNj_7VEcXJ4AzS6i1q2ysupHP4FayEqiU',
    appId: '1:1049001087254:web:a4d3089ee32891198b4037',
    messagingSenderId: '1049001087254',
    projectId: 'pomapp-c3ccc',
    authDomain: 'pomapp-c3ccc.firebaseapp.com',
    storageBucket: 'pomapp-c3ccc.firebasestorage.app',
    measurementId: 'G-YWCG38N3J2',
  );

  // Android ve iOS için Firebase Console'dan ayrı uygulama eklemen gerekiyor:
  // Project Settings → Your apps → Add app → Android / iOS
  // Şimdilik web config'i kullan (emulator/test için yeterli).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWZIc0l8GJqPmgScH-jlx-W_er6wy41aU',
    appId: '1:1049001087254:android:6c7969c2a9746c378b4037',
    messagingSenderId: '1049001087254',
    projectId: 'pomapp-c3ccc',
    storageBucket: 'pomapp-c3ccc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBNj_7VEcXJ4AzS6i1q2ysupHP4FayEqiU',
    appId: '1:1049001087254:web:a4d3089ee32891198b4037',
    messagingSenderId: '1049001087254',
    projectId: 'pomapp-c3ccc',
    storageBucket: 'pomapp-c3ccc.firebasestorage.app',
    iosBundleId: 'com.pom.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBNj_7VEcXJ4AzS6i1q2ysupHP4FayEqiU',
    appId: '1:1049001087254:web:a4d3089ee32891198b4037',
    messagingSenderId: '1049001087254',
    projectId: 'pomapp-c3ccc',
    storageBucket: 'pomapp-c3ccc.firebasestorage.app',
    iosBundleId: 'com.pom.app',
  );
}
