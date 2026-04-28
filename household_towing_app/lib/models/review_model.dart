import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String bookingId;
  final String customerId;
  final String providerId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
