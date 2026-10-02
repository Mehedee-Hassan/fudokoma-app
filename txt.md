# Follo Cart Current Status

Updated: 2026-09-12

## Currently working

- Flutter web app runs in Chrome.
- Explore opens on a map-first screen.
- The map uses `flutter_map` with real tile data.
- OpenStreetMap tiles are used when no Mapbox token is configured.
- Mapbox streets can be enabled by adding a token in `lib/config/mapbox_config.dart`.
- The app requests the user's location and centers the map when permission is granted.
- A 5 km radius is drawn around the user's location.
- The location button retries location detection.
- A demo-area fallback is shown when location services or permission are unavailable.
- Seven sample food carts appear as coordinate-based map markers.
- Users can select carts and follow or unfollow them.
- Followed carts appear in the Following tab.
- Updates appear in the Updates tab.
- Customer, Cart Owner, and Admin role previews are available.
- Proximity checks use a 5 km threshold and a 10-minute check interval.
- Firebase service seams and data models are present for future backend integration.
- Flutter analysis passes and the test suite passes.

## Current limitations

This is still a functional prototype, not a production release.

- The cart data is local demo data and does not come from Firestore.
- Follow state is temporary and is lost when the app closes.
- The Mapbox token is still a placeholder by default.
- OpenStreetMap public tiles are suitable for development preview only; production should use an approved tile provider.
- Location permission and GPS behavior depend on the browser or device environment.
- The 10-minute proximity logic is implemented as a tested service, but background scheduling and OS-level notifications are not live yet.
- Firebase configuration files contain placeholders until a real Firebase project is connected.
- There is no real authentication, registration, or persistent user account flow.
- Customer, cart owner, and admin roles are UI previews only.
- Cart owner updates, photo uploads, schedules, and live location publishing are not connected to a backend.
- Push notifications and real Firestore writes are not enabled.
- Admin moderation actions are demo interactions only.
- iOS build testing requires macOS and Xcode.

## Next development phase

1. Add a real Mapbox token and approved production tile configuration.
2. Connect Firestore for carts, users, follows, schedules, and updates.
3. Add Firebase Authentication and enforce user roles.
4. Connect cart-owner GPS publishing and live cart status.
5. Add background location scheduling and FCM push notifications for 5 km alerts.
6. Add photo uploads through Firebase Storage.
7. Replace role previews with protected customer, owner, and admin workflows.
8. Add production permissions, privacy messaging, error handling, and device testing.
