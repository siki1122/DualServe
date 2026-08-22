import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logging_service.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    Logger.info('Local notifications initialized');

    _startListeningToFirestore();
  }

  void _startListeningToFirestore() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for new bookings where I am the assigned provider
    FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedProviderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              _showNotification(
                id: change.doc.id.hashCode,
                title: 'New Service Request!',
                body:
                    'You have a new ${data['serviceType']} request for ${data['scheduledTime']}.',
              );
            }
          }
        });

    // Listen for status updates on my own bookings (as a customer)
    FirebaseFirestore.instance
        .collection('bookings')
        .where('customerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data() as Map<String, dynamic>;

              // Simple logic: if status is accepted/rejected, notify
              final status = data['status'];
              if (status == 'accepted') {
                _showNotification(
                  id: change.doc.id.hashCode,
                  title: 'Booking Accepted!',
                  body:
                      'Your ${data['serviceType']} request has been accepted.',
                );
              } else if (status == 'rejected') {
                _showNotification(
                  id: change.doc.id.hashCode,
                  title: 'Booking Rejected',
                  body:
                      'Your ${data['serviceType']} request was unfortunately rejected.',
                );
              }
            }
          }
        });

    // Listen for new tasks where I am the assigned driver
    FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedDriverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              _showNotification(
                id: change.doc.id.hashCode,
                title: 'New Job Assigned!',
                body: 'You have been assigned a new ${data['serviceType'] ?? 'towing'} job at ${data['location'] ?? 'a new location'}.',
              );
            }
          }
        });
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dualserve_channel',
      'DualServe Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }

  /// Public method for showing notifications (used by FCM handler)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final id = title.hashCode;
    const androidDetails = AndroidNotificationDetails(
      'dualserve_channel',
      'DualServe Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(id, title, body, notificationDetails);
    Logger.debug('Displayed local notification: $title');
  }
}
