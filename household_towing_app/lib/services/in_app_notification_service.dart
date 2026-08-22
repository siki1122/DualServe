import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new notification in the 'notifications' collection
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // e.g., 'message', 'booking_update', 'system'
    Map<String, dynamic>? actionData, // e.g., {'bookingId': '123'} or {'chatId': '456'}
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        if (actionData != null) 'actionData': actionData,
      });
    } catch (e) {
      print('Error sending in-app notification: $e');
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
