# Follo Cart

A Flutter prototype for discovering and following mobile food carts.

## Run

```bash
flutter pub get
flutter run -d chrome
```



The app opens with a map-first Explore screen. It requests the user's location, centers the map when permission is granted, and draws a 5 km radius around the user. If location access is unavailable, the app shows the demo area and provides a retry action.

<img width="504" height="934" alt="Screenshot from 2026-09-12 02-08-38" src="https://github.com/user-attachments/assets/a34decef-6273-4e09-bb10-bd0a40b64301" />

## Map setup

The map uses [`flutter_map`](https://pub.dev/packages/flutter_map).

## Connect Flutter to the local backend

Start the API and its MySQL/Redis dependencies from `backend/` with
`docker compose up -d --build`. The API listens on `http://localhost:18000`
in the checked-in local environment. Run Flutter with
`flutter run --dart-define=API_BASE_URL=http://localhost:18000` for web or
desktop. For the Android emulator, use
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:18000`. A physical
device needs the computer's LAN address instead.

The map loads carts and follow status from `/api/v1/carts` and the current
prototype user from `/api/v1/users`. Cart status, follows, and moderation
updates are persisted through the same API. These unauthenticated prototype
endpoints are disabled when the backend runs with `APP_ENV=production`; do not
expose a development backend to the public internet.

To save another cart from Flutter, open **Profile → Cart owner → Manage my
cart → Add a food cart**. Enter the cart details and coordinates, then select
**Save cart**. The map refreshes to the newly saved location. The local owner
prototype account is created automatically if it does not already exist.

For a physical device, set `API_BIND_ADDRESS` to `0.0.0.0` in the backend's
local `.env`, replace `localhost` in `API_BASE_URL` with your development
computer's LAN IP, and add that IP to `TRUSTED_HOSTS`. This exposes the
unauthenticated development API to your LAN; use it only on a trusted network.

- Without a Mapbox token, the app uses OpenStreetMap tiles for development preview.
- To use Mapbox streets, replace `YOUR_MAPBOX_ACCESS_TOKEN` in `lib/config/mapbox_config.dart` with a valid public token.
- The map includes attribution for the active tile provider.
- The 5 km map radius and proximity service use the user's latitude and longitude.

For production, use an approved tile provider and follow its usage and attribution requirements. The public OpenStreetMap tile server should not be treated as a production tile service.

## Current features

- Guest-friendly map exploration without login.
- Seven coordinate-based demo food carts.
- Cart markers with selection details and open/closed status.
- Follow and unfollow carts.
- Following and Updates tabs.
- Customer, Cart Owner, and Admin role previews.
- 5 km proximity threshold with a 10-minute check interval in `lib/services/proximity_service.dart`.
- Firebase-ready models and service seams.

## Validation

```bash
flutter analyze
flutter test
```

Both commands currently pass.

## Project structure

- `lib/main.dart` contains the current app shell, map, markers, and prototype workflows.
- `lib/config/mapbox_config.dart` contains map provider configuration and fallback behavior.
- `lib/models/` contains cart, user, follow, notification, and proximity alert models.
- `lib/services/proximity_service.dart` calculates distance and creates nearby-cart alerts.
- `lib/services/firestore_service.dart` is the Firebase/Firestore integration seam.
- `SETUP_FIREBASE.md` documents Firebase setup.
- `txt.md` contains the detailed current status and remaining limitations.

## Production work remaining

- Add a real Mapbox token and production tile configuration.
- Connect Firestore, Firebase Authentication, Firebase Storage, and FCM.
- Persist users, carts, follows, schedules, and updates.
- Add live cart-owner location publishing.
- Implement background location checks and OS-level push notifications.
- Replace role previews with protected workflows.
- Complete Android and iOS permission configuration and device testing.
