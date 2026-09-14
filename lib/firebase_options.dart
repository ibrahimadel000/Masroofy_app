// File generated for Mizaan - Yemen Wallets Aggregator & Expense Tracker
// Matches configuration from google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDNUEzUKR17xIyVsMF-R-wzpvNX_2L3dH8',
    appId: '1:771594672611:android:0ead40fe418f41a943e8d6',
    messagingSenderId: '771594672611',
    projectId: 'mizaan-app-3f9a2',
    storageBucket: 'mizaan-app-3f9a2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDNUEzUKR17xIyVsMF-R-wzpvNX_2L3dH8',
    appId: '1:771594672611:ios:0ead40fe418f41a943e8d6',
    messagingSenderId: '771594672611',
    projectId: 'mizaan-app-3f9a2',
    storageBucket: 'mizaan-app-3f9a2.firebasestorage.app',
    iosBundleId: 'com.mizaan.app',
  );
}
