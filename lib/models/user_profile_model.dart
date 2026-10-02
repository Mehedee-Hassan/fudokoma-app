class UserProfileModel {
  UserProfileModel({
    required this.id,
    required this.name,
    required this.role,
    required this.isGuest,
    this.isBlocked = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String role;
  final bool isGuest;
  final bool isBlocked;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'isGuest': isGuest,
        'isBlocked': isBlocked,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'] ?? map['created_at'];
    return UserProfileModel(
      id: id,
      name: map['name'] ?? 'Guest user',
      role: map['role'] ?? 'customer',
      isGuest: map['isGuest'] ?? map['is_guest'] ?? false,
      isBlocked: map['isBlocked'] ?? map['is_blocked'] ?? false,
      createdAt: createdAt != null
          ? DateTime.parse(createdAt)
          : DateTime.now(),
    );
  }
}
