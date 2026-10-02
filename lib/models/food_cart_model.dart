class FoodCartModel {
  FoodCartModel({
    required this.id,
    required this.name,
    required this.category,
    required this.locationLabel,
    required this.schedule,
    required this.photoUrl,
    required this.isOpen,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.followersCount,
    required this.updatedAt,
    required this.isFeatured,
    this.isFollowed = false,
  });

  final String id;
  final String name;
  final String category;
  final String locationLabel;
  final String schedule;
  final String photoUrl;
  final bool isOpen;
  final String ownerId;
  final double latitude;
  final double longitude;
  final int followersCount;
  final DateTime updatedAt;
  final bool isFeatured;
  bool isFollowed;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'locationLabel': locationLabel,
        'schedule': schedule,
        'photoUrl': photoUrl,
        'isOpen': isOpen,
        'ownerId': ownerId,
        'latitude': latitude,
        'longitude': longitude,
        'followersCount': followersCount,
        'updatedAt': updatedAt.toIso8601String(),
        'isFeatured': isFeatured,
      };

  factory FoodCartModel.fromMap(Map<String, dynamic> map, String id) {
    return FoodCartModel(
      id: id,
      name: map['name'] ?? 'Food cart',
      category: map['category'] ?? 'Street food',
      locationLabel: map['locationLabel'] ?? map['description'] ?? 'City center',
      schedule: map['schedule'] ?? 'Open today',
      photoUrl: map['photoUrl'] ?? map['image_url'] ?? '',
      isOpen: map['isOpen'] ?? map['is_open'] ?? false,
      ownerId: map['ownerId'] ?? map['owner_id'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      followersCount: map['followersCount'] ?? map['followers_count'] ?? 0,
      updatedAt: (map['updatedAt'] ?? map['updated_at']) != null
          ? DateTime.parse(map['updatedAt'] ?? map['updated_at'])
          : DateTime.now(),
      isFeatured: map['isFeatured'] ?? false,
      isFollowed: map['isFollowed'] ?? false,
    );
  }

  static List<FoodCartModel> demoCarts() {
    return [
      FoodCartModel(
        id: 'cart-1',
        name: 'Momo House',
        category: 'Nepali street food',
        locationLabel: 'Riverside Park',
        schedule: '11:30 AM – 9:30 PM',
        photoUrl: '',
        isOpen: true,
        ownerId: 'owner-1',
        latitude: 23.8103,
        longitude: 90.4125,
        followersCount: 248,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        isFeatured: true,
        isFollowed: true,
      ),
      FoodCartModel(
        id: 'cart-2',
        name: 'The Green Bowl',
        category: 'Fresh salads & bowls',
        locationLabel: 'Oak Street',
        schedule: '11:30 AM – 2:00 PM',
        photoUrl: '',
        isOpen: false,
        ownerId: 'owner-2',
        latitude: 23.8125,
        longitude: 90.4160,
        followersCount: 121,
        updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
        isFeatured: false,
      ),
      FoodCartModel(
        id: 'cart-3',
        name: 'Chai Chapter',
        category: 'Tea, coffee & bites',
        locationLabel: 'City Center',
        schedule: '8:00 AM – 7:00 PM',
        photoUrl: '',
        isOpen: true,
        ownerId: 'owner-3',
        latitude: 23.8065,
        longitude: 90.4099,
        followersCount: 86,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        isFeatured: true,
      ),
    ];
  }
}
