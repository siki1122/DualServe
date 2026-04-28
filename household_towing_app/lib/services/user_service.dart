import 'package:cloud_firestore/cloud_firestore.dart';
import 'logging_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch user profile from 'users' collection
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      Logger.error('Failed to fetch user profile for $uid', e);
      return null;
    }
  }

  /// Fetch provider profile from 'providers' collection
  Future<Map<String, dynamic>?> getProviderProfile(String uid) async {
    try {
      final doc = await _firestore.collection('providers').doc(uid).get();
      return doc.data();
    } catch (e) {
      Logger.error('Failed to fetch provider profile for $uid', e);
      return null;
    }
  }

  /// Update availability status for provider
  Future<void> updateProviderAvailability(String uid, bool isAvailable) async {
    try {
      await _firestore.collection('providers').doc(uid).update({
        'isAvailable': isAvailable,
        'lastActive': FieldValue.serverTimestamp(),
      });
      Logger.info('Updated availability for provider $uid: $isAvailable');
    } catch (e) {
      Logger.error('Failed to update provider availability', e);
      throw e;
    }
  }

  /// Update provider rating
  Future<void> updateProviderRating(String uid, double newRating) async {
    try {
      if (newRating < 0 || newRating > 5) {
        throw Exception('Rating must be between 0 and 5');
      }
      await _firestore.collection('providers').doc(uid).update({
        'rating': newRating,
      });
      Logger.info('Updated rating for provider $uid: $newRating');
    } catch (e) {
      Logger.error('Failed to update provider rating for $uid', e);
      rethrow;
    }
  }
}
