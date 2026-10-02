import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FirebaseStorage storage = FirebaseStorage.instance;

  static Future<void> initNotifications() async {
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      // Store `token` in Firestore/user profile for push notifications.
      // ignore: avoid_print
      print('FCM token: $token');
    }
  }
}
