# Setup guide

The app is Flutter (one codebase → Android + iPhone) on a Firebase backend
(Authentication + Cloud Firestore). The free **Spark** plan is enough: selfies are stored as small
(≈40 KB) JPEG documents in Firestore, so Cloud Storage is not needed.

## 1. Tools
* Flutter 3.35 or newer (stable) – `flutter doctor` must be green for the platforms you build.
* Android: Android Studio / SDK. iPhone: a Mac with Xcode (Apple does not allow iOS builds on Windows/Linux) and an Apple Developer account to install on real devices.
* Node 18+ (only for the one-off admin seed script and optional rules tests), Firebase CLI: `npm i -g firebase-tools`.

## 2. Firebase project
1. <https://console.firebase.google.com> → *Add project*.
2. **Build → Authentication → Sign-in method** → enable **Email/Password**.
   Optional: *Templates → Password reset* to customise the reset email.
3. **Build → Firestore Database** → create (production mode, region `asia-south1`).
4. Deploy the security rules (they implement role-based access, one-record-per-day, server-time-only punches, audit log protection):
   ```
   firebase login
   firebase use --add          # pick your project
   firebase deploy --only firestore
   ```
5. Generate the app config (overwrites the placeholder `lib/firebase_options.dart`):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure       # select Android + iOS
   ```

## 3. Create the fixed Admin account (server-side, not in the app)
Admin credentials are **not** in the app and cannot be created through sign-up
(the rules only allow `role == 'employee'` for self-registration).

1. Firebase console → Project settings → *Service accounts* → *Generate new private key* (keep it secret, never commit it).
2. ```
   cd tools && npm install
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
   export ADMIN_EMAIL=admin@yourcompany.com
   export ADMIN_PASSWORD='choose-a-strong-password'
   node seed_admin.js
   ```
   Re-running resets the admin password and re-creates default settings if missing.
3. Sign in on the app's **Admin login** page. Then in *Holiday Management* tap **Load default Indian holidays** and in *Settings* set shift start / grace / weekly offs.

## 4. Run / build
```
flutter pub get
flutter run                               # device or emulator
flutter build apk --release               # Android  -> build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release         # Play Store
flutter build ios --release               # on a Mac, then archive in Xcode
```
Permissions are already configured: Android `CAMERA`, `ACCESS_FINE_LOCATION` (+ `minSdk 23`), iOS `NSCameraUsageDescription` / `NSLocationWhenInUseUsageDescription`.
For iOS, open `ios/Runner.xcworkspace` in Xcode once and set your Team / bundle id (`com.buildbymeet.attendanceApp` by default).

## 5. Testing the security rules (optional)
```
cd tools/rules-test && npm install && npm test
```
Needs Java 21+ (Firestore emulator). 50 checks cover sign-up, punching, duplicate prevention, manual approval flow, audit-log immutability and data isolation.

## Notes & known limits
* **No Cloud Functions** (Spark plan). Server-side guarantees come from Firestore Security Rules: punch times must equal the server time, the date must be today in IST, one document per employee per day, checkout only once, requests can only be decided by an admin, audit logs are append-only. Audit entries are written by the admin's app in the *same atomic batch* as the change.
* **Forgot password** uses Firebase's secure reset **link** by email (no OTP).
* Late / half-day / missing-punch / absent are *derived* from the stored server timestamps and the admin settings at read time, so they can't be faked by a client and re-calculate when settings change.
* Lunar festival dates (Holi, Diwali, Eid…) are **indicative** for 2026 and must be verified/edited by the admin; for other years only fixed-date holidays are pre-loaded.
* Maps use OpenStreetMap tiles (no API key). Please respect OSM's tile usage policy or switch to a paid tile provider for heavy use.
* Mock/fake-GPS is rejected on Android; this is best-effort only.
* Admins reset an employee's password through the employee's *Forgot password* link; email/username can't be edited after sign-up.
