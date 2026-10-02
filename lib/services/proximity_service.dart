import 'dart:math' as math;

import '../models/food_cart_model.dart';
import '../models/proximity_alert_model.dart';

class ProximityService {
  static const double proximityThresholdKm = 5.0;
  static const int checkIntervalMinutes = 10;
  static const double appLabelDistanceKm = 5.0;

  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static List<ProximityAlertModel> checkForNearbyCarts({
    required double userLat,
    required double userLng,
    required List<FoodCartModel> carts,
    required String userId,
  }) {
    final alerts = <ProximityAlertModel>[];

    for (final cart in carts) {
      final distance = calculateDistanceKm(
        lat1: userLat,
        lon1: userLng,
        lat2: cart.latitude,
        lon2: cart.longitude,
      );

      if (distance <= proximityThresholdKm) {
        alerts.add(
          ProximityAlertModel(
            id: '$userId-${cart.id}-${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            cartId: cart.id,
            cartName: cart.name,
            distanceKm: distance,
            triggeredAt: DateTime.now(),
          ),
        );
      }
    }

    return alerts;
  }

  static String notificationMessage(String cartName, double distanceKm) {
    final displayDistance = distanceKm < appLabelDistanceKm
        ? appLabelDistanceKm
        : distanceKm;
    return '$cartName is within ${displayDistance.toStringAsFixed(1)} km. You may want to check the cart now.';
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
