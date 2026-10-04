# Follo Cart

A Flutter prototype for discovering and following mobile food carts.

## Run

```bash
flutter pub get
flutter run -d chrome
```



The app opens with a map-first Explore screen. It requests the user's location and centers the map when permission is granted. If location access is unavailable, the app shows the demo area and provides a retry action.

<img width="504" height="934" alt="Screenshot from 2026-09-12 02-08-38" src="https://github.com/user-attachments/assets/a34decef-6273-4e09-bb10-bd0a40b64301" />

## Map setup

The map uses [`flutter_map`](https://pub.dev/packages/flutter_map).

## Connect Flutter to the local backend

Android builds use the deployed HTTPS API at
`https://srv1518746.hstgr.cloud` by default, so an emulator or physical device
can connect without a local network address. The public API health check is
`https://srv1518746.hstgr.cloud/api/v1/ready`. This uses the deployed backend
and its database; actions performed by signed-in accounts affect that service.

For local development, start the API and its MySQL/Redis dependencies from
`backend/` with `docker compose up -d --build`. Override the API address with
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:18000` on an Android
emulator. A physical Android device should use the development computer's LAN
IP instead. Web and desktop default to `http://localhost:18000`.

The map loads carts from `/api/v1/carts`; signed-in users authenticate with
Firebase and send ID tokens to the backend. Cart follows and account data are
scoped to the authenticated account. Cart-owner and admin permissions come
from the backend user record, not a client-side role selector.

The app opens in guest mode so visitors can browse public carts without an
account. After device location permission is granted, it requests carts within
5 km from `/api/v1/carts?latitude=...&longitude=...&radius_km=5`; if location is
unavailable it shows the default map area and its carts. Signing in is required
to follow carts or access account features. The native Android and iOS Firebase
configuration must be completed before authentication is available.

To save another cart from Flutter, open **Profile → Cart owner → Manage my
cart → Add a food cart**. Enter the cart details and coordinates, then select
**Save cart**. The map refreshes to the newly saved location. The local owner
prototype account is created automatically if it does not already exist.

The web admin dashboard is available at `http://localhost:18000/admin` in
development and uses Firebase email/Google sign-in when configured. Only
verified accounts with the `admin` role in MySQL can access it. A local
username/password can be configured for development; a separate optional
username/password dashboard fallback is documented for production. For an
HTTPS VPS deployment, see
[backend/README.md](backend/README.md#production-deployment-hostinger-vps).
For the first production admin bootstrap, see [docs/add-admin.md](docs/add-admin.md).

When connecting a physical device to your own local backend, set
`API_BIND_ADDRESS` to `0.0.0.0` in the backend's local `.env`, use the
development computer's LAN IP in `API_BASE_URL`, and add that IP to
`TRUSTED_HOSTS`. Expose the development API only on a trusted network.

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

## Further product work

- Configure a real Mapbox token and review production tile usage.
- Connect Firebase Storage and FCM for image uploads and push notifications.
- Add live cart-owner location publishing.
- Implement background location checks and OS-level push notifications.
- Complete Android and iOS permission configuration and device testing.
- Establish production backups, monitoring, privacy policy, and incident procedures.
