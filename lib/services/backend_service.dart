import '../models/follow_model.dart';
import '../models/food_cart_model.dart';
import '../models/notification_model.dart';
import '../models/user_profile_model.dart';
import 'api_client.dart';

class BackendService {
  BackendService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  void close() => _apiClient.close();

  Future<UserProfileModel> registerUser({
    required String firebaseUid,
    required String name,
    String? email,
    String role = 'customer',
  }) async {
    final response = await _apiClient.post('users', {
      'firebase_uid': firebaseUid,
      'name': name,
      'email': email,
      'role': role,
    });
    return _userFromResponse(response);
  }

  Future<List<FoodCartModel>> fetchFoodCarts() async {
    final response = await _apiClient.get('carts');
    return _asMapList(response)
        .map((map) => FoodCartModel.fromMap(map, map['id'] as String))
        .toList();
  }

  Future<FoodCartModel> createCart({
    required String ownerId,
    required String name,
    required String category,
    required String locationLabel,
    required String schedule,
    required bool isOpen,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.post('carts', {
      'owner_id': ownerId,
      'name': name,
      'description': locationLabel,
      'category': category,
      'schedule': schedule,
      'is_open': isOpen,
      'latitude': latitude,
      'longitude': longitude,
    });
    if (response is! Map<String, dynamic> || response['id'] is! String) {
      throw const FormatException('The backend returned an invalid cart.');
    }
    return FoodCartModel.fromMap(response, response['id'] as String);
  }

  Future<List<UserProfileModel>> fetchUsers() async {
    final response = await _apiClient.get('users');
    return _asMapList(response)
        .map((map) => UserProfileModel.fromMap(map, map['id'] as String))
        .toList();
  }

  Future<void> updateCartStatus({
    required String cartId,
    required bool isOpen,
    required String schedule,
  }) async {
    await _apiClient.patch('carts/$cartId', {
      'is_open': isOpen,
      'schedule': schedule,
    });
  }

  Future<void> followCart({
    required String userId,
    required String cartId,
    required bool notificationsEnabled,
  }) async {
    await _apiClient.put(
      'users/$userId/follows/$cartId',
      {'notifications_enabled': notificationsEnabled},
    );
  }

  Future<void> unfollowCart({
    required String userId,
    required String cartId,
  }) async {
    await _apiClient.delete('users/$userId/follows/$cartId');
  }

  Future<void> blockUser({required String userId}) async {
    await _apiClient.patch('users/$userId', {'is_blocked': true});
  }

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final response = await _apiClient.get('users/$userId/notifications');
    return _asMapList(response)
        .map((map) => NotificationModel.fromMap(map, map['id'] as String))
        .toList();
  }

  Future<List<FollowModel>> fetchFollows(String userId) async {
    final response = await _apiClient.get('users/$userId/follows');
    return _asMapList(response)
        .map((map) => FollowModel.fromMap(map, map['id'] as String))
        .toList();
  }

  UserProfileModel _userFromResponse(dynamic response) {
    if (response is! Map<String, dynamic> || response['id'] is! String) {
      throw const FormatException('The backend returned an invalid user.');
    }
    return UserProfileModel.fromMap(response, response['id'] as String);
  }

  List<Map<String, dynamic>> _asMapList(dynamic response) {
    if (response is! List) {
      throw const FormatException('The backend returned an invalid list.');
    }
    return response.map((item) {
      if (item is! Map<String, dynamic> || item['id'] is! String) {
        throw const FormatException('The backend returned an invalid record.');
      }
      return item;
    }).toList();
  }
}
