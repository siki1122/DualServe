import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

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
  }
}
