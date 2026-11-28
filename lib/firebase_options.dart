// Android config from the Firebase console (google-services.json).
// iOS is still a placeholder: while apiKey is 'REPLACE_ME' that platform shows a setup screen.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static bool get isConfigured => currentPlatform.apiKey != 'REPLACE_ME';

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC39mlmdsjCXM0MVNO98pkXzao0QN32m-s',
    appId: '1:653236850488:android:35c901b3bbbb38479a3bcd',
    messagingSenderId: '653236850488',
    projectId: 'attendance-app-73f76',
    storageBucket: 'attendance-app-73f76.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    iosBundleId: 'com.buildbymeet.attendanceApp',
  );
}
