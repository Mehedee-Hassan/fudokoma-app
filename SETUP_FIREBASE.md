# Firebase setup for Follo Cart

This project is prepared with a Firebase-ready seam so you can replace the placeholders with your real Firebase configuration.

## 1. Create a Firebase project

1. Open Firebase Console.
2. Create a new project.
3. Add Android, iOS, and Web apps.
4. Copy the generated values into `lib/firebase_options.dart`.

## 2. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

## 3. Configure FlutterFire

Run:

```bash
flutterfire configure
```

This will generate the final Firebase config files automatically for your project.

## 4. Replace placeholders

Update these files with your real Firebase values:

- `lib/firebase_options.dart`
- `android/app/build.gradle.kts`
- `ios/Runner/Info.plist`
- `google-services.json` for Android
- `GoogleService-Info.plist` for iOS

## 5. Enable Firebase services

Turn on these Firebase features in the Firebase console:

- Authentication
- Firestore Database
- Storage
- Cloud Messaging

## 6. Suggested app architecture

- `auth`: customer / cart owner / admin accounts
- `carts`: shop profile, status, location, schedule, photos
- `follows`: user-to-cart follow relationship
- `notifications`: notification logs and FCM delivery
- `reports`: admin moderation queue

## 7. Important production notes

- Do not commit real API keys to public repos.
- Use Firebase Security Rules.
- Keep app IDs, bundle IDs, and SHA-1 fingerprints aligned with Firebase project settings.
- Use environment variables or CI secrets for release builds.

## 8. Next integration steps

- Replace demo data with Firestore queries.
- Add auth login/signup screens.
- Add image upload to Firebase Storage.
- Add live map integration.
- Add push notifications and location-triggered alerts.
