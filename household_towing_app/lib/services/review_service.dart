import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReview(Review review) async {
    // Check for existing review
    final existingReviews = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: review.bookingId)
        .get();
        
    if (existingReviews.docs.isNotEmpty) {
      throw Exception('This booking has already been reviewed.');
    }

    final providerRef = _firestore.collection('providers').doc(review.providerId);
    
    await _firestore.runTransaction((transaction) async {
      // 1. Get provider data to recalculate average (Must be done BEFORE writes)
      final providerDoc = await transaction.get(providerRef);
      if (!providerDoc.exists) return;

      // 2. Save the review
      final reviewRef = _firestore.collection('reviews').doc();
      transaction.set(reviewRef, review.toFirestore());

      // 3. Update the booking status to show it was reviewed
      final bookingRef = _firestore.collection('bookings').doc(review.bookingId);
      transaction.update(bookingRef, {'isReviewed': true});

      // 4. Update provider rating
      final data = providerDoc.data() as Map<String, dynamic>;
      final double currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final int totalReviews = (data['totalReviews'] as num?)?.toInt() ?? 0;
      
      // New Average = ((Old Avg * Total) + New Rating) / (Total + 1)
      final double newRating = ((currentRating * totalReviews) + review.rating) / (totalReviews + 1);

      transaction.update(providerRef, {
        'rating': newRating,
        'totalReviews': totalReviews + 1,
      });
    });
  }
}
