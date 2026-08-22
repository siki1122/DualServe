import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'in_app_notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Message>> getMessages(String bookingId) {
    return _firestore
        .collection('messages')
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  Future<void> sendMessage(Message message) async {
    await _firestore.collection('messages').add(message.toFirestore());

    // Fetch sender name for the notification
    String senderName = 'Someone';
    String senderRole = 'Provider';
    try {
      final userDoc = await _firestore.collection('users').doc(message.senderId).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'Provider';
        senderRole = userDoc.data()?['role'] ?? 'Provider';
      } else {
        final provDoc = await _firestore.collection('providers').doc(message.senderId).get();
        if (provDoc.exists) {
          senderName = provDoc.data()?['name'] ?? 'Provider';
          senderRole = 'provider';
        }
      }
    } catch (e) {}

    // We no longer strictly send to receiverId. Instead, we can notify participants
    // For now, if receiverId is provided, we use it for targeted notifications,
    // otherwise we would fetch the booking and notify all participants.
    if (message.receiverId.isNotEmpty) {
      await InAppNotificationService().sendNotification(
        userId: message.receiverId,
        title: 'New Message from $senderName',
        message: message.imageUrl != null ? 'Sent an image' : message.text,
        type: 'message',
        actionData: {
          'bookingId': message.bookingId,
          'senderId': message.senderId,
          'senderName': senderName,
        },
      );
    }
  }

  Future<void> markMessagesAsRead(String bookingId, String currentUserId) async {
    // Read messages not sent by current user
    final unreadMessages = await _firestore
        .collection('messages')
        .where('bookingId', isEqualTo: bookingId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      final data = doc.data();
      if (data['senderId'] != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
