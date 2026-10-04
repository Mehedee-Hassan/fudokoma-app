import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'config/mapbox_config.dart';
import 'models/food_cart_model.dart';
import 'models/notification_model.dart';
import 'models/user_profile_model.dart';
import 'services/backend_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
    if (firebaseOptions.apiKey.startsWith('REPLACE_WITH_') ||
        firebaseOptions.appId.startsWith('REPLACE_WITH_') ||
        firebaseOptions.projectId.startsWith('REPLACE_WITH_')) {
      throw StateError('Firebase project values are still placeholders.');
    }
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
  }

  runApp(const FolloCartApp());
}

class FolloCartApp extends StatelessWidget {
  const FolloCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follo Cart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
          primary: const Color(0xFF176B5B),
          secondary: const Color(0xFFE66D45),
          surface: const Color(0xFFF7F8F4),
        ),
        fontFamily: 'Avenir',
        useMaterial3: true,
      ),
      home: const AuthGate(child: Shell()),
    );
  }
}

enum UserRole { customer, owner, admin }

class FoodCart {
  FoodCart({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.schedule,
    required this.distance,
    required this.eta,
    required this.color,
    required this.position,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.followers,
    this.isFollowed = false,
  });

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String schedule;
  final String distance;
  final String eta;
  final Color color;
  final Offset position;
  final double latitude;
  final double longitude;
  bool isOpen;
  final int followers;
  bool isFollowed;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const defaultMapCenter = latlng.LatLng(35.6327, 140.0908);
  static const defaultMapZoom = 14.0;

  int selectedTab = 0;
  UserRole role = UserRole.customer;
  FoodCart? selectedCart;
  bool isLocatingUser = true;
  bool isLoadingCarts = true;
  String? locationError;
  String? backendError;
  String? accountError;
  String? prototypeUserId;
  String? prototypeOwnerId;
  UserProfileModel? currentProfile;
  List<UserProfileModel> users = [];
  List<FoodCart> ownedCarts = [];
  List<NotificationModel> notifications = [];
  final pendingCartActions = <String>{};
  latlng.LatLng userLocation = defaultMapCenter;
  bool hasDeviceLocation = false;
  int _backendLoadGeneration = 0;
  final mapController = MapController();
  final backendService = BackendService();
  final carts = <FoodCart>[];
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadBackendData();
    _loadUserLocation();
    if (Firebase.apps.isNotEmpty) {
      _authSubscription = FirebaseAuth.instance.userChanges().listen((_) {
        _loadBackendData();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    backendService.close();
    super.dispose();
  }

  bool get _hasVerifiedFirebaseUser {
    if (Firebase.apps.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final requiresVerification = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    return !requiresVerification || user.emailVerified;
  }

  Future<void> _loadBackendData() async {
    final loadGeneration = ++_backendLoadGeneration;
    if (mounted) {
      setState(() {
        isLoadingCarts = true;
        backendError = null;
      });
    }
    try {
      final records = await backendService.fetchFoodCarts(
        latitude: hasDeviceLocation ? userLocation.latitude : null,
        longitude: hasDeviceLocation ? userLocation.longitude : null,
      );
      if (loadGeneration != _backendLoadGeneration) return;
      UserProfileModel? user;
      var loadedRole = UserRole.customer;
      var loadedUsers = <UserProfileModel>[];
      var loadedOwnedCarts = <FoodCart>[];
      var loadedNotifications = <NotificationModel>[];
      var loadedFollowIds = <String>{};
      String? loadedAccountError;

      if (_hasVerifiedFirebaseUser) {
        try {
          user = await backendService.fetchCurrentUser();
          loadedRole = _roleFromString(user.role);
          if (loadedRole == UserRole.admin) {
            loadedUsers = await backendService.fetchUsers();
          }
          if (loadedRole == UserRole.owner || loadedRole == UserRole.admin) {
            final ownerRecords = await backendService.fetchMyCarts();
            loadedOwnedCarts = ownerRecords.indexed.map((entry) {
              final (index, record) = entry;
              return _toMapCart(
                record,
                index,
                const Color(0xFFE66D45),
                '',
                false,
              );
            }).toList();
          }
          final follows = await backendService.fetchFollows(user.id);
          loadedFollowIds = follows.map((follow) => follow.cartId).toSet();
          loadedNotifications =
              await backendService.fetchNotifications(user.id);
        } catch (error) {
          loadedAccountError = error.toString();
        }
      }

      const colors = [
        Color(0xFFE66D45),
        Color(0xFF3C8B70),
        Color(0xFFE1A43A),
        Color(0xFFB95D3B),
        Color(0xFF8D6E3E),
        Color(0xFF5D7891),
        Color(0xFFC65B7A),
      ];
      final distance = latlng.Distance();
      final loadedCarts = records.indexed.map((entry) {
        final (index, record) = entry;
        final cartLocation = latlng.LatLng(record.latitude, record.longitude);
        final kilometers = distance.as(
            latlng.LengthUnit.Kilometer, userLocation, cartLocation);
        return _toMapCart(
          record,
          index,
          colors[index % colors.length],
          hasDeviceLocation
              ? '${kilometers.toStringAsFixed(1)} km away'
              : '${kilometers.toStringAsFixed(1)} km from map center',
          loadedFollowIds.contains(record.id),
        );
      }).toList();
      if (!mounted || loadGeneration != _backendLoadGeneration) return;
      setState(() {
        prototypeUserId = user?.id;
        prototypeOwnerId = user != null &&
                (loadedRole == UserRole.owner || loadedRole == UserRole.admin)
            ? user.id
            : null;
        currentProfile = user;
        role = loadedRole;
        accountError = loadedAccountError;
        carts
          ..clear()
          ..addAll(loadedCarts);
        ownedCarts = loadedOwnedCarts;
        users = loadedUsers;
        notifications = loadedNotifications;
        isLoadingCarts = false;
      });
    } catch (error) {
      if (!mounted || loadGeneration != _backendLoadGeneration) return;
      setState(() {
        backendError = error.toString();
        isLoadingCarts = false;
      });
    }
  }

  Future<bool> _openSignIn() async {
    if (Firebase.apps.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Browsing is available. Configure Firebase to sign in and follow carts.',
          ),
        ),
      );
      return false;
    }
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => SignInScreen(
          onSignedIn: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    if (signedIn == true && mounted) {
      await _loadBackendData();
      return prototypeUserId != null;
    }
    return false;
  }

  UserRole _roleFromString(String value) => switch (value) {
        'customer' => UserRole.customer,
        'owner' => UserRole.owner,
        'admin' => UserRole.admin,
        _ => throw FormatException('Unsupported account role: $value'),
      };

  FoodCart _toMapCart(
    FoodCartModel record,
    int index,
    Color color,
    String distance,
    bool isFollowed,
  ) {
    return FoodCart(
      id: record.id,
      ownerId: record.ownerId,
      name: record.name,
      category: record.category,
      schedule: record.schedule,
      distance: distance,
      eta: record.schedule,
      color: color,
      position: Offset(0.2 + (index % 4) * 0.2, 0.25 + (index ~/ 4) * 0.3),
      latitude: record.latitude,
      longitude: record.longitude,
      isOpen: record.isOpen,
      followers: record.followersCount,
      isFollowed: isFollowed,
    );
  }

  Future<void> _toggleFollow(FoodCart cart) async {
    if (prototypeUserId == null && !await _openSignIn()) return;
    final userId = prototypeUserId;
    if (userId == null || pendingCartActions.contains(cart.id)) return;
    final wasFollowed = cart.isFollowed;
    setState(() => pendingCartActions.add(cart.id));
    try {
      if (wasFollowed) {
        await backendService.unfollowCart(userId: userId, cartId: cart.id);
      } else {
        await backendService.followCart(
          userId: userId,
          cartId: cart.id,
          notificationsEnabled: true,
        );
      }
      if (!mounted) return;
      setState(() => cart.isFollowed = !wasFollowed);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $error')),
      );
    } finally {
      if (mounted) setState(() => pendingCartActions.remove(cart.id));
    }
  }

  Future<void> _setCartStatus(FoodCart cart, bool isOpen) async {
    if (pendingCartActions.contains(cart.id)) return;
    setState(() => pendingCartActions.add(cart.id));
    try {
      await backendService.updateCartStatus(
        cartId: cart.id,
        isOpen: isOpen,
        schedule: cart.schedule,
      );
      if (!mounted) return;
      setState(() {
        cart.isOpen = isOpen;
        for (final item in [...carts, ...ownedCarts]) {
          if (item.id == cart.id) item.isOpen = isOpen;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update cart status: $error')),
      );
    } finally {
      if (mounted) setState(() => pendingCartActions.remove(cart.id));
    }
  }

  Future<void> _createOwnerCart({
    required String name,
    required String category,
    required String location,
    required String schedule,
    required bool isOpen,
    required double latitude,
    required double longitude,
  }) async {
    if (prototypeOwnerId == null) {
      throw StateError('An approved cart-owner account is required.');
    }
    await backendService.createCart(
      name: name,
      category: category,
      locationLabel: location,
      schedule: schedule,
      isOpen: isOpen,
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted) return;
    await _loadBackendData();
    mapController.move(latlng.LatLng(latitude, longitude), defaultMapZoom);
  }

  Future<void> _showCreateCartForm() async {
    if (prototypeUserId == null && !await _openSignIn()) return;
    if (!mounted) return;
    final ownerId = prototypeOwnerId;
    if (ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account needs cart-owner approval before you can publish a cart.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: 'Street food');
    final locationController =
        TextEditingController(text: 'Near Inage-Kaigan Station');
    final scheduleController =
        TextEditingController(text: '11:00 AM - 8:00 PM');
    final latitudeController =
        TextEditingController(text: defaultMapCenter.latitude.toString());
    final longitudeController =
        TextEditingController(text: defaultMapCenter.longitude.toString());
    var isOpen = true;
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add a food cart'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cartFormField(nameController, 'Cart name'),
                      _cartFormField(categoryController, 'Category'),
                      _cartFormField(locationController, 'Location / address'),
                      _cartFormField(scheduleController, 'Schedule'),
                      Row(
                        children: [
                          Expanded(
                            child: _cartFormField(
                              latitudeController,
                              'Latitude',
                              numeric: true,
                              validator: _coordinateValidator(
                                minimum: -90,
                                maximum: 90,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _cartFormField(
                              longitudeController,
                              'Longitude',
                              numeric: true,
                              validator: _coordinateValidator(
                                minimum: -180,
                                maximum: 180,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Open now'),
                        value: isOpen,
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() => isOpen = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final latitude =
                            double.parse(latitudeController.text.trim());
                        final longitude =
                            double.parse(longitudeController.text.trim());
                        setDialogState(() => isSaving = true);
                        try {
                          await _createOwnerCart(
                            name: nameController.text.trim(),
                            category: categoryController.text.trim(),
                            location: locationController.text.trim(),
                            schedule: scheduleController.text.trim(),
                            isOpen: isOpen,
                            latitude: latitude,
                            longitude: longitude,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (!mounted) return;
                          Navigator.of(this.context).maybePop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Cart saved to the backend.'),
                            ),
                          );
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Could not save cart: $error'),
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save cart'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      categoryController.dispose();
      locationController.dispose();
      scheduleController.dispose();
      latitudeController.dispose();
      longitudeController.dispose();
    }
  }

  Widget _cartFormField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: validator ??
            (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null,
      ),
    );
  }

  String? Function(String?) _coordinateValidator({
    required double minimum,
    required double maximum,
  }) {
    return (value) {
      final coordinate = double.tryParse(value?.trim() ?? '');
      if (coordinate == null || coordinate < minimum || coordinate > maximum) {
        return 'Enter $minimum to $maximum';
      }
      return null;
    };
  }

  Future<void> _setUserBlocked(
    UserProfileModel user,
    bool isBlocked,
  ) async {
    try {
      await backendService.setUserBlocked(
        userId: user.id,
        isBlocked: isBlocked,
      );
      if (!mounted) return;
      setState(() {
        users = users
            .map(
              (item) => item.id == user.id
                  ? UserProfileModel(
                      id: item.id,
                      name: item.name,
                      role: item.role,
                      isGuest: item.isGuest,
                      isBlocked: isBlocked,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update user status: $error')),
      );
    }
  }

  Future<void> _setUserRole(
    UserProfileModel user,
    String newRole,
  ) async {
    try {
      await backendService.setUserRole(userId: user.id, role: newRole);
      if (!mounted) return;
      setState(() {
        users = users
            .map(
              (item) => item.id == user.id
                  ? UserProfileModel(
                      id: item.id,
                      name: item.name,
                      role: newRole,
                      isGuest: item.isGuest,
                      isBlocked: item.isBlocked,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change user role: $error')),
      );
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are turned off.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      setState(() {
        userLocation = latlng.LatLng(position.latitude, position.longitude);
        hasDeviceLocation = true;
        isLocatingUser = false;
        locationError = null;
      });
      mapController.move(userLocation, defaultMapZoom);
      await _loadBackendData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLocatingUser = false;
        locationError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: selectedTab,
          children: [
            _buildExplore(),
            _buildFollowing(),
            _buildUpdates(),
            _buildProfile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9EEE6),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Following'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Updates'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildExplore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        currentProfile?.name ??
                            (Firebase.apps.isNotEmpty
                                ? FirebaseAuth.instance.currentUser?.displayName
                                : null) ??
                            'Welcome',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    const Text('Find your next bite',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),
              _roundIcon(Icons.tune_rounded),
              const SizedBox(width: 8),
              CircleAvatar(
                  backgroundColor: const Color(0xFF176B5B),
                  child: const Text('M',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _loadUserLocation,
                child: _roundIcon(Icons.my_location_rounded,
                    background: const Color(0xFFFFE8DE),
                    foreground: const Color(0xFFE66D45)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                hasDeviceLocation ? 'Near you now' : 'Carts around the map',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const Spacer(),
              Text('${carts.length} carts',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _mapArea()),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7E1))),
      child: const TextField(
        decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Color(0xFF176B5B)),
            hintText: 'Search food carts',
            hintStyle: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _roundIcon(IconData icon,
      {Color background = Colors.white,
      Color foreground = const Color(0xFF24342F)}) {
    return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE3E7E1))),
        child: Icon(icon, color: foreground, size: 21));
  }

  Widget _mapArea() {
    return Stack(
      children: [
        Positioned.fill(child: _realMapWidget()),
        Positioned(
            top: 18,
            left: 18,
            child: _mapPill(
              Icons.layers_outlined,
              hasDeviceLocation ? 'Near your location' : 'Inage-Kaigan area',
            )),
        if (isLocatingUser)
          Positioned(
              top: 70,
              left: 18,
              child: _mapPill(Icons.my_location_rounded, 'Finding you')),
        if (locationError != null)
          Positioned(
              top: 70, left: 18, right: 18, child: _locationFallbackBanner()),
        if (backendError != null)
          Positioned(
            top: 70,
            left: 18,
            right: 18,
            child: _backendErrorBanner(),
          ),
        if (isLoadingCarts)
          const Positioned(
            top: 70,
            left: 18,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (selectedCart != null)
          Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _cartDetail(selectedCart!)),
      ],
    );
  }

  Widget _backendErrorBanner() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: Color(0xFFE66D45), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Backend unavailable: $backendError',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _loadBackendData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _locationFallbackBanner() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined,
                color: Color(0xFFE66D45), size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    '$locationError Using the map center until location is available.',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))),
            TextButton(
                onPressed: _loadUserLocation, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _realMapWidget() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: defaultMapCenter,
        initialZoom: defaultMapZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxConfig.tileUrl,
          userAgentPackageName: 'com.example.follo_cart',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: userLocation,
              width: 30,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF176B5B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ],
        ),
        MarkerLayer(
          markers: carts
              .map(
                (cart) => Marker(
                  point: latlng.LatLng(cart.latitude, cart.longitude),
                  width: 56,
                  height: 68,
                  child: GestureDetector(
                    onTap: () => setState(() => selectedCart = cart),
                    child: _cartMarker(cart),
                  ),
                ),
              )
              .toList(),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(MapboxConfig.providerLabel),
          ],
        ),
      ],
    );
  }

  Widget _mapPill(IconData icon, String label) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 12)
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF176B5B)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
        ]));
  }

  Widget _cartMarker(FoodCart cart) {
    return Column(children: [
      Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: cart.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3)),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 23)),
      Container(width: 2, height: 7, color: cart.color)
    ]);
  }

  Widget _cartDetail(FoodCart cart) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: cart.color.withAlpha(32),
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.restaurant_rounded,
                    color: cart.color, size: 28)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(cart.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(cart.category,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 7),
                  Row(children: [
                    Icon(Icons.near_me, size: 13, color: cart.color),
                    const SizedBox(width: 4),
                    Text(cart.distance,
                        style: TextStyle(
                            color: cart.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: cart.isOpen
                                ? const Color(0xFF4AAE7D)
                                : Colors.grey,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(cart.isOpen ? 'Open now' : 'Closed',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))
                  ])
                ])),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: pendingCartActions.contains(cart.id)
                    ? null
                    : () => _toggleFollow(cart),
                style: FilledButton.styleFrom(
                    backgroundColor: cart.isFollowed
                        ? const Color(0xFFD9EEE6)
                        : const Color(0xFF176B5B),
                    foregroundColor: cart.isFollowed
                        ? const Color(0xFF176B5B)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11)),
                child: Text(cart.isFollowed ? 'Following' : 'Follow',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowing() {
    final followed = carts.where((cart) => cart.isFollowed).toList();
    return _simplePage(
        'Your followed carts',
        'Get notified when they move, open, or update their schedule.',
        prototypeUserId == null
            ? [
                const Text('Sign in to follow carts and see them here.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _openSignIn,
                  child: const Text('Sign in or create an account'),
                ),
              ]
            : followed.map((cart) => _cartListTile(cart)).toList());
  }

  Widget _buildUpdates() {
    if (prototypeUserId == null) {
      return _simplePage(
        'Latest updates',
        'Sign in to see updates from carts you follow.',
        [
          FilledButton(
            onPressed: _openSignIn,
            child: const Text('Sign in or create an account'),
          ),
        ],
      );
    }
    if (notifications.isEmpty) {
      return _simplePage(
        'Latest updates',
        'Your food cart activity in one place.',
        [
          Text(
            isLoadingCarts
                ? 'Loading updates...'
                : 'No updates yet. Follow a cart to stay in the loop.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }
    return _simplePage(
      'Latest updates',
      'Your food cart activity in one place.',
      notifications.map((notification) {
        final isNearby = notification.type == 'nearby';
        return _updateTile(
          isNearby ? Icons.near_me : Icons.notifications_outlined,
          isNearby ? const Color(0xFFE66D45) : const Color(0xFF3C8B70),
          notification.message,
          notification.createdAt.toLocal().toString(),
        );
      }).toList(),
    );
  }

  Widget _buildProfile() {
    return _simplePage('Your profile', 'Manage your Follo Cart experience.', [
      const SizedBox(height: 4),
      _accountPanel(),
      const SizedBox(height: 12),
      _roleWorkspace(),
      const SizedBox(height: 12),
      _settingTile(Icons.notifications_outlined, 'Notifications',
          'Schedule, opening status, and nearby alerts'),
      _settingTile(Icons.location_on_outlined, 'Location alerts',
          'Notify me within 5 km of followed carts'),
      _settingTile(Icons.help_outline, 'Help & feedback',
          'Tell us how to make Follo Cart better'),
    ]);
  }

  Widget _simplePage(String title, String subtitle, List<Widget> children) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 22),
          ...children
        ]);
  }

  Widget _cartListTile(FoodCart cart) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E7E1))),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: cart.color.withAlpha(32),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.restaurant_rounded, color: cart.color)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(cart.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    '${cart.distance} · ${cart.isOpen ? 'Open now' : 'Closed'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade500)
        ]));
  }

  Widget _updateTile(IconData icon, Color color, String title, String detail) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E7E1))),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              ]))
        ]));
  }

  Widget _accountPanel() {
    final user =
        Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    final signedIn = prototypeUserId != null;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7E1)),
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn
                      ? user?.displayName ?? user?.email ?? 'Signed-in user'
                      : 'Browsing as a guest',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                    signedIn
                        ? '${_roleLabel(role)} account'
                        : 'Sign in to follow carts and manage an account.',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (accountError != null)
                  Text(
                    'Account data could not load: $accountError',
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (signedIn)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
            )
          else
            FilledButton.tonal(
              onPressed: _openSignIn,
              child: const Text('Sign in'),
            ),
        ],
      ),
    );
  }

  Widget _roleWorkspace() {
    if (role == UserRole.customer) {
      return _workspaceCard(
        Icons.explore_outlined,
        'Customer view',
        'Discover nearby carts, follow favorites, and get a 5 km arrival alert.',
        'Open map',
      );
    }
    if (role == UserRole.owner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _workspaceCard(
            Icons.storefront_outlined,
            'Cart owner studio',
            'Manage your carts, opening status, and schedule.',
            'Open owner studio',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _showCreateCartForm,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add a food cart'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: const Color(0xFF176B5B),
            ),
          ),
        ],
      );
    }
    return _workspaceCard(
      Icons.admin_panel_settings_outlined,
      'Admin console',
      'Review reported accounts, moderate carts, and manage platform activity.',
      'Open console',
    );
  }

  Widget _workspaceCard(
      IconData icon, String title, String detail, String action) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7E1))),
      child: Row(
        children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFD9EEE6),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: const Color(0xFF176B5B))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.35))
              ])),
          const SizedBox(width: 8),
          IconButton(
              onPressed: () => _openRoleWorkspace(),
              tooltip: action,
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF176B5B))),
        ],
      ),
    );
  }

  Future<void> _openRoleWorkspace() async {
    if (role == UserRole.customer) {
      setState(() => selectedTab = 0);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F8F4),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: role == UserRole.owner ? _ownerWorkspace() : _adminWorkspace(),
      ),
    );
  }

  Widget _ownerWorkspace() {
    final cart = ownedCarts.isEmpty ? null : ownedCarts.first;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Cart owner studio',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
              cart == null
                  ? 'Create and publish your first food cart.'
                  : '${cart.name} · ${cart.schedule}',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 18),
          if (cart != null) ...[
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shop is open',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(cart.isOpen
                    ? 'Customers can see you are open now.'
                    : 'Customers see your shop as closed.'),
                value: cart.isOpen,
                onChanged: pendingCartActions.contains(cart.id)
                    ? null
                    : (value) => _setCartStatus(cart, value)),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: Color(0xFF176B5B)),
                title: const Text('Today\'s hours',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('11:30 AM – 9:30 PM'),
                trailing: const Icon(Icons.chevron_right)),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF176B5B)),
                title: const Text('Cart location',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${cart.latitude.toStringAsFixed(4)}, ${cart.longitude.toStringAsFixed(4)}')),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_location_alt_outlined,
                color: Color(0xFF176B5B)),
            title: const Text('Add a food cart',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Save its details and location to the API.'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showCreateCartForm,
            ),
          ),
        ]);
  }

  Widget _adminWorkspace() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Admin console',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Accounts · ${users.length}',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const Text('No user records are available from the backend.')
          else
            ...users.map(
              (user) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE8DE),
                  child: Icon(Icons.person_outline, color: Color(0xFFE66D45)),
                ),
                title: Text(user.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(user.isBlocked ? 'Blocked' : user.role),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: user.role,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text('Cart owner'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: user.id == prototypeUserId
                          ? null
                          : (value) {
                              if (value != null && value != user.role) {
                                _setUserRole(user, value);
                              }
                            },
                    ),
                    TextButton(
                      onPressed: user.id == prototypeUserId
                          ? null
                          : () => _setUserBlocked(user, !user.isBlocked),
                      child: Text(user.isBlocked ? 'Unblock' : 'Block'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
              'Role changes and account moderation require an authenticated admin account.',
              style: TextStyle(fontSize: 12, height: 1.4)),
        ]);
  }

  String _roleLabel(UserRole value) => switch (value) {
        UserRole.customer => 'Customer',
        UserRole.owner => 'Cart owner',
        UserRole.admin => 'Admin'
      };

  Widget _settingTile(IconData icon, String title, String detail) {
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: Icon(icon, color: const Color(0xFF176B5B)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right));
  }
}

class MapPainter extends CustomPainter {
  MapPainter({required this.carts});
  final List<FoodCart> carts;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFFEAF0E9);
    canvas.drawRect(Offset.zero & size, base);
    final blocks = Paint()
      ..color = const Color(0xFFDCE7DC)
      ..style = PaintingStyle.fill;
    final roads = Paint()
      ..color = const Color(0xFFF7F8F4)
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    final roadLines = Paint()
      ..color = const Color(0xFFD5DDD2)
      ..strokeWidth = 1.3;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.08 + i * 0.17);
      canvas.drawRect(
          Rect.fromLTWH(
              x, size.height * 0.08, size.width * 0.10, size.height * 0.22),
          blocks);
      canvas.drawRect(
          Rect.fromLTWH(x + 20, size.height * 0.66, size.width * 0.13,
              size.height * 0.18),
          blocks);
    }
    final path = Path()
      ..moveTo(-20, size.height * .62)
      ..cubicTo(size.width * .3, size.height * .4, size.width * .55,
          size.height * .84, size.width + 20, size.height * .26);
    canvas.drawPath(path, roads);
    canvas.drawPath(path, roadLines);
    final cross = Path()
      ..moveTo(size.width * .12, -20)
      ..cubicTo(size.width * .42, size.height * .25, size.width * .30,
          size.height * .62, size.width * .84, size.height + 20);
    canvas.drawPath(cross, roads);
    canvas.drawPath(cross, roadLines);
    final park = Paint()..color = const Color(0xFFC9E0C7);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .55, size.height * .12, size.width * .28,
                size.height * .16),
            const Radius.circular(24)),
        park);
    final you = Offset(size.width * .44, size.height * .49);
    canvas.drawCircle(you, 22, Paint()..color = const Color(0x33176B5B));
    canvas.drawCircle(you, 8, Paint()..color = const Color(0xFF176B5B));
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => false;
}

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner dashboard'),
        backgroundColor: const Color(0xFFF7F8F4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Momo House',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Riverside Park • Street food',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          _ownerMetricCard(
              'Current status', 'Open now', const Color(0xFF3C8B70)),
          const SizedBox(height: 12),
          _ownerMetricCard(
              'Today\'s hours', '11:30 AM – 9:30 PM', const Color(0xFF176B5B)),
          const SizedBox(height: 12),
          _ownerMetricCard('Followers', '248', const Color(0xFFE66D45)),
          const SizedBox(height: 18),
          const Text('Manage your cart',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.photo_library_outlined,
                color: Color(0xFF176B5B)),
            title: const Text('Upload photos'),
            subtitle: const Text('Add menu shots and cart branding'),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.location_on_outlined,
                color: Color(0xFF176B5B)),
            title: const Text('Set next stop'),
            subtitle: const Text('Oak Street • Tomorrow • 12:00 PM'),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.notifications_active_outlined,
                color: Color(0xFF176B5B)),
            title: const Text('Push notifications'),
            subtitle: const Text(
                'Followers receive open, close, and schedule alerts'),
          ),
        ],
      ),
    );
  }

  Widget _ownerMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.storefront_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        backgroundColor: const Color(0xFFF7F8F4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Moderation center',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Review reports and protect the marketplace',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          _adminReportCard('Spam report', 'Chef Nabil',
              'Auto-suspend candidate', const Color(0xFFE66D45)),
          const SizedBox(height: 12),
          _adminReportCard('Fake listing', 'Green Bites', 'Pending review',
              const Color(0xFFE1A43A)),
          const SizedBox(height: 12),
          _adminReportCard('Location abuse', 'Momo House', 'Flagged by 3 users',
              const Color(0xFF3C8B70)),
          const SizedBox(height: 18),
          const Text('Platform stats',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child:
                    _statTile('Active carts', '128', const Color(0xFF176B5B))),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _statTile('Followers', '12.4k', const Color(0xFFE66D45))),
          ]),
        ],
      ),
    );
  }

  Widget _adminReportCard(
      String title, String subject, String note, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.flag_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subject,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Text(note,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(80))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
