import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'REPLACE_WITH_YOUR_WEB_API_KEY',
        appId: 'REPLACE_WITH_YOUR_WEB_APP_ID',
        messagingSenderId: 'REPLACE_WITH_YOUR_WEB_MESSAGING_SENDER_ID',
        projectId: 'REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID',
        authDomain: 'REPLACE_WITH_YOUR_AUTH_DOMAIN',
        storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
        measurementId: 'REPLACE_WITH_YOUR_MEASUREMENT_ID',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'REPLACE_WITH_YOUR_ANDROID_API_KEY',
          appId: 'REPLACE_WITH_YOUR_ANDROID_APP_ID',
          messagingSenderId: 'REPLACE_WITH_YOUR_ANDROID_MESSAGING_SENDER_ID',
          projectId: 'REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID',
          storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
          appId: 'REPLACE_WITH_YOUR_IOS_APP_ID',
          messagingSenderId: 'REPLACE_WITH_YOUR_IOS_MESSAGING_SENDER_ID',
          projectId: 'REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID',
          storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
          iosBundleId: 'com.example.follo_cart',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }
}
