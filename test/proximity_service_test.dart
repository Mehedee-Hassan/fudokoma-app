import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/config/mapbox_config.dart';
import 'package:follo_cart/services/proximity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nearby alert is triggered when a food cart is within 5 km', () {
    final alerts = ProximityService.checkForNearbyCarts(
      userLat: 23.8103,
      userLng: 90.4125,
      carts: [
        FoodCartModel(
          id: 'cart-1',
          name: 'Momo House',
          category: 'Nepali street food',
          locationLabel: 'Riverside Park',
          schedule: '11:30 AM – 9:30 PM',
          photoUrl: '',
          isOpen: true,
          ownerId: 'owner-1',
          latitude: 23.8125,
          longitude: 90.4160,
          followersCount: 248,
          updatedAt: DateTime.now(),
          isFeatured: true,
        ),
      ],
      userId: 'user-1',
    );

    expect(alerts, isNotEmpty);
    expect(alerts.first.cartName, 'Momo House');
    expect(alerts.first.distanceKm, lessThanOrEqualTo(ProximityService.proximityThresholdKm));
  });

  test('outside-range alert is not triggered when cart is farther than 5 km', () {
    final alerts = ProximityService.checkForNearbyCarts(
      userLat: 23.8103,
      userLng: 90.4125,
      carts: [
        FoodCartModel(
          id: 'cart-far',
          name: 'Far Cart',
          category: 'Street food',
          locationLabel: 'Far away',
          schedule: 'Open today',
          photoUrl: '',
          isOpen: true,
          ownerId: 'owner-3',
          latitude: 23.9000,
          longitude: 90.5000,
          followersCount: 20,
          updatedAt: DateTime.now(),
          isFeatured: false,
        ),
      ],
      userId: 'user-1',
    );

    expect(alerts, isEmpty);
  });

  test('notification text says within 5 km', () {
    final text = ProximityService.notificationMessage('Momo House', 2.9);

    expect(text, contains('within 5.0 km'));
    expect(text, contains('Momo House'));
  });

  test('periodic check repeats after 10 minutes', () {
    const intervalMinutes = ProximityService.checkIntervalMinutes;

    expect(intervalMinutes, 10);
    expect(intervalMinutes > 0, isTrue);
  });

  test('mapbox style url is ready for a real map widget', () {
    final url = MapboxConfig.buildStyleUrl();

    expect(url, startsWith('https://api.mapbox.com/'));
    expect(url, contains('access_token='));
  });

  test('map has a visible development tile fallback without a Mapbox token', () {
    expect(MapboxConfig.tileUrl, MapboxConfig.openStreetMapTileUrl);
    expect(MapboxConfig.providerLabel, 'OpenStreetMap preview');
  });
}
