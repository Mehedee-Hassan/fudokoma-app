class FollowModel {
  FollowModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.followedAt,
    this.notificationsEnabled = true,
    this.proximityAlertKm = 3,
  });

  final String id;
  final String userId;
  final String cartId;
  final DateTime followedAt;
  final bool notificationsEnabled;
  final int proximityAlertKm;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'cartId': cartId,
        'followedAt': followedAt.toIso8601String(),
        'notificationsEnabled': notificationsEnabled,
        'proximityAlertKm': proximityAlertKm,
      };

  factory FollowModel.fromMap(Map<String, dynamic> map, String id) {
    final followedAt = map['followedAt'] ?? map['created_at'];
    return FollowModel(
      id: id,
      userId: map['userId'] ?? map['user_id'] ?? '',
      cartId: map['cartId'] ?? map['cart_id'] ?? '',
      followedAt: followedAt != null
          ? DateTime.parse(followedAt)
          : DateTime.now(),
      notificationsEnabled:
          map['notificationsEnabled'] ?? map['notifications_enabled'] ?? true,
      proximityAlertKm: map['proximityAlertKm'] ?? 3,
    );
  }
}
