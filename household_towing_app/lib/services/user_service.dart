import 'package:cloud_firestore/cloud_firestore.dart';
import 'logging_service.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch user profile from 'users' collection with retry logic
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    int retryCount = 0;
    const int maxRetries = 3;
    dynamic lastError;

    while (retryCount < maxRetries) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (!doc.exists) return null;
        return doc.data();
      } catch (e) {
        lastError = e;
        if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
          retryCount++;
          Logger.warn('Firestore unavailable, retrying ($retryCount/$maxRetries) for user $uid...');
          await _firestore.enableNetwork().catchError((_) {});
          await Future.delayed(Duration(seconds: 1 * retryCount));
          continue;
        }
        Logger.error('Failed to fetch user profile for $uid', e);
        rethrow;
      }
    }
    Logger.error('Max retries reached for user profile $uid', lastError);
    throw lastError ?? Exception('Failed to fetch user profile after $maxRetries retries');
  }

  /// Fetch provider profile from 'providers' collection with retry logic
  Future<Map<String, dynamic>?> getProviderProfile(String uid) async {
    int retryCount = 0;
    const int maxRetries = 3;
    dynamic lastError;

    while (retryCount < maxRetries) {
      try {
        final doc = await _firestore.collection('providers').doc(uid).get();
        if (!doc.exists) return null;
        return doc.data();
      } catch (e) {
        lastError = e;
        if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
          retryCount++;
          Logger.warn('Firestore unavailable, retrying ($retryCount/$maxRetries) for provider $uid...');
          await _firestore.enableNetwork().catchError((_) {});
          await Future.delayed(Duration(seconds: 1 * retryCount));
          continue;
        }
        Logger.error('Failed to fetch provider profile for $uid', e);
        rethrow;
      }
    }
    Logger.error('Max retries reached for provider profile $uid', lastError);
    throw lastError ?? Exception('Failed to fetch provider profile after $maxRetries retries');
  }

  /// Fetch driver profile from 'drivers' collection with retry logic
  Future<Map<String, dynamic>?> getDriverProfile(String uid) async {
    int retryCount = 0;
    const int maxRetries = 3;
    dynamic lastError;

    while (retryCount < maxRetries) {
      try {
        final doc = await _firestore.collection('drivers').doc(uid).get();
        if (!doc.exists) return null;
        return doc.data();
      } catch (e) {
        lastError = e;
        if (e.toString().contains('unavailable') || e.toString().contains('offline')) {
          retryCount++;
          Logger.warn('Firestore unavailable, retrying ($retryCount/$maxRetries) for driver $uid...');
          await _firestore.enableNetwork().catchError((_) {});
          await Future.delayed(Duration(seconds: 1 * retryCount));
          continue;
        }
        Logger.error('Failed to fetch driver profile for $uid', e);
        rethrow;
      }
    }
    Logger.error('Max retries reached for driver profile $uid', lastError);
    throw lastError ?? Exception('Failed to fetch driver profile after $maxRetries retries');
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
      rethrow;
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
