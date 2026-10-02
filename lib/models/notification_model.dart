class NotificationModel {
  NotificationModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String cartId;
  final String type;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'cartId': cartId,
        'type': type,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'] ?? map['created_at'];
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? map['user_id'] ?? '',
      cartId: map['cartId'] ?? map['cart_id'] ?? '',
      type: map['type'] ?? 'schedule',
      message: map['message'] ?? 'New update',
      createdAt: createdAt != null ? DateTime.parse(createdAt) : DateTime.now(),
      isRead: map['isRead'] ?? map['is_read'] ?? false,
    );
  }
}
