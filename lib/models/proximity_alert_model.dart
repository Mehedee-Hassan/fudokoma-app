class ProximityAlertModel {
  ProximityAlertModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.cartName,
    required this.distanceKm,
    required this.triggeredAt,
    this.isDelivered = false,
  });

  final String id;
  final String userId;
  final String cartId;
  final String cartName;
  final double distanceKm;
  final DateTime triggeredAt;
  final bool isDelivered;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'cartId': cartId,
        'cartName': cartName,
        'distanceKm': distanceKm,
        'triggeredAt': triggeredAt.toIso8601String(),
        'isDelivered': isDelivered,
      };

  factory ProximityAlertModel.fromMap(Map<String, dynamic> map, String id) {
    return ProximityAlertModel(
      id: id,
      userId: map['userId'] ?? '',
      cartId: map['cartId'] ?? '',
      cartName: map['cartName'] ?? 'Food cart',
      distanceKm: (map['distanceKm'] ?? 0.0).toDouble(),
      triggeredAt: map['triggeredAt'] != null
          ? DateTime.parse(map['triggeredAt'])
          : DateTime.now(),
      isDelivered: map['isDelivered'] ?? false,
    );
  }
}
