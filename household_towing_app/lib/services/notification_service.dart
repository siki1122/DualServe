import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service_local.dart';
import 'logging_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      Logger.info('User granted notification permissions');

      // Get the token for this device
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.debug(
          'Received foreground message: ${message.notification?.title}',
        );
        // Show notification using local notification service
        if (message.notification != null) {
          LocalNotificationService().showNotification(
            title: message.notification!.title ?? 'DualServe Notification',
            body: message.notification!.body ?? '',
            payload: message.data,
          );
        }
      });
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token, 'lastTokenUpdate': FieldValue.serverTimestamp()},
      );
    }
  }
}

// Global background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger.debug('Handling background message: ${message.messageId}');
}
