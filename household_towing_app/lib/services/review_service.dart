import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReview(Review review) async {
    final providerRef = _firestore.collection('providers').doc(review.providerId);
    
    await _firestore.runTransaction((transaction) async {
      // 1. Save the review
      final reviewRef = _firestore.collection('reviews').doc();
      transaction.set(reviewRef, review.toFirestore());

      // 2. Update the booking status to show it was reviewed
      final bookingRef = _firestore.collection('bookings').doc(review.bookingId);
      transaction.update(bookingRef, {'isReviewed': true});

      // 3. Get provider data to recalculate average
      final providerDoc = await transaction.get(providerRef);
      if (!providerDoc.exists) return;

      final data = providerDoc.data() as Map<String, dynamic>;
      final double currentRating = (data['rating'] ?? 5.0).toDouble();
      final int jobsCompleted = (data['jobsCompleted'] ?? 0);
      
      // New Average = ((Old Avg * Jobs) + New Rating) / (Jobs + 1)
      final double newRating = ((currentRating * jobsCompleted) + review.rating) / (jobsCompleted + 1);

      transaction.update(providerRef, {
        'rating': newRating,
        'jobsCompleted': jobsCompleted + 1,
      });
    });
  }
}
