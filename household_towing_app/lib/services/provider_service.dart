import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/provider_model.dart';
import 'logging_service.dart';

class ProviderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _providersCollection = 'providers';
  static const String _tasksCollection = 'tasks';

  // READ - Get provider by ID
  Future<Provider?> getProvider(String providerId) async {
    try {
      final doc = await _firestore
          .collection(_providersCollection)
          .doc(providerId)
          .get();
      if (doc.exists) {
        return Provider.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching provider: $e');
    }
  }

  // READ - Get all providers
  Future<List<Provider>> getAllProviders() async {
    try {
      final snapshot = await _firestore.collection(_providersCollection).get();
      return snapshot.docs.map((doc) => Provider.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching providers: $e');
    }
  }

  // READ - Get providers by service type
  Future<List<Provider>> getProvidersByServiceType(String serviceType) async {
    try {
      final snapshot = await _firestore
          .collection(_providersCollection)
          .where('serviceType', isEqualTo: serviceType)
          .get();
      return snapshot.docs.map((doc) => Provider.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching providers by service type: $e');
    }
  }

  // UPDATE - Update provider weekly availability
  Future<void> updateProviderAvailability(
    String providerId,
    Map<String, List<String>> weeklySchedule,
  ) async {
    try {
      await _firestore.collection(_providersCollection).doc(providerId).update({
        'weeklySchedule': weeklySchedule,
      });
      Logger.info('Updated availability for provider $providerId');
    } catch (e) {
      Logger.error('Error updating provider availability', e);
      throw Exception('Error updating provider availability: $e');
    }
  }

  // UPDATE - Add block-out date (vacation, day off)
  Future<void> addBlockOutDate(String providerId, DateTime date) async {
    try {
      final dateISO = date.toIso8601String().split(
        'T',
      )[0]; // Format: YYYY-MM-DD

      final provider = await getProvider(providerId);
      if (provider == null) throw Exception('Provider not found');

      final updatedBlockOutDates = [...provider.blockOutDates, dateISO];

      await _firestore.collection(_providersCollection).doc(providerId).update({
        'blockOutDates': updatedBlockOutDates,
      });
      Logger.info('Added block-out date $dateISO for provider $providerId');
    } catch (e) {
      Logger.error('Error adding block-out date', e);
      throw Exception('Error adding block-out date: $e');
    }
  }

  // UPDATE - Remove block-out date
  Future<void> removeBlockOutDate(String providerId, DateTime date) async {
    try {
      final dateISO = date.toIso8601String().split('T')[0];

      final provider = await getProvider(providerId);
      if (provider == null) throw Exception('Provider not found');

      final updatedBlockOutDates = provider.blockOutDates
          .where((d) => d != dateISO)
          .toList();

      await _firestore.collection(_providersCollection).doc(providerId).update({
        'blockOutDates': updatedBlockOutDates,
      });
      Logger.info('Removed block-out date $dateISO for provider $providerId');
    } catch (e) {
      Logger.error('Error removing block-out date', e);
      throw Exception('Error removing block-out date: $e');
    }
  }

  // UPDATE - Update provider status
  Future<void> updateProviderStatus(
    String providerId,
    ProviderStatus status,
  ) async {
    try {
      await _firestore.collection(_providersCollection).doc(providerId).update({
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error updating provider status: $e');
    }
  }

  // CHECK - Is provider available on specific date at specific time?
  Future<bool> isProviderAvailable(
    String providerId,
    DateTime date,
    String time, // Format: "HH:MM"
  ) async {
    try {
      final provider = await getProvider(providerId);
      if (provider == null) return false;

      // Check if date is blocked
      final dateISO = date.toIso8601String().split('T')[0];
      if (provider.isBlockedOnDate(dateISO)) {
        Logger.debug('Provider $providerId is blocked on $dateISO');
        return false;
      }

      // Get day name (e.g., "Monday")
      final dayName = _getDayName(date.weekday);
      final availableSlots = provider.getAvailableSlotsForDay(dayName);

      // Normalize input time (ensure HH:MM format)
      String normalizedTime = time;
      if (time.contains(' ')) {
        // If input is "08:00 AM", convert to "08:00" (or handle as needed)
        // Actually, it's easier to normalize both to a comparable format.
        normalizedTime = _normalizeTime(time);
      }

      bool found = false;
      for (var slot in availableSlots) {
        if (_normalizeTime(slot) == normalizedTime) {
          found = true;
          break;
        }
      }

      if (!found) {
        Logger.debug('Provider $providerId has no slot at $time ($normalizedTime) on $dayName. Available: $availableSlots');
        return false;
      }

      // Check capacity (not already at max tasks)
      final taskCount = await getProviderTaskCountForDate(providerId, date);
      final bookingCount = await getProviderBookingCountForDate(
        providerId,
        date,
      );
      final totalCapacity = taskCount + bookingCount;

      if (totalCapacity >= provider.maxTasksPerDay) {
        Logger.debug(
          'Provider $providerId is at capacity ($totalCapacity/${provider.maxTasksPerDay}) on $dateISO',
        );
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('Error checking provider availability', e);
      return false;
    }
  }

  // GET - Get available providers for date/time
  Future<List<Provider>> getAvailableProvidersForDateTime(
    String serviceType,
    DateTime date,
    String time,
  ) async {
    try {
      final providers = await getProvidersByServiceType(serviceType);
      final availableProviders = <Provider>[];

      for (final provider in providers) {
        final isAvailable = await isProviderAvailable(provider.id, date, time);
        if (isAvailable) {
          availableProviders.add(provider);
        }
      }

      return availableProviders;
    } catch (e) {
      throw Exception('Error getting available providers: $e');
    }
  }

  // ANALYTICS - Count provider's assigned tasks for date
  Future<int> getProviderTaskCountForDate(
    String providerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(_tasksCollection)
          .where('assignedProviderId', isEqualTo: providerId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .where('status', whereIn: ['assigned', 'inProgress'])
          .get();

      return snapshot.size;
    } catch (e) {
      Logger.error('Error getting provider task count', e);
      return 0;
    }
  }

  // ANALYTICS - Count provider's accepted bookings for date
  Future<int> getProviderBookingCountForDate(
    String providerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('bookings')
          .where('assignedProviderId', isEqualTo: providerId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .where('status', isEqualTo: 'accepted')
          .get();

      return snapshot.size;
    } catch (e) {
      Logger.error('Error getting provider booking count', e);
      return 0;
    }
  }

  // GET - Remaining capacity for provider on date
  Future<int> getRemainingCapacity(String providerId, DateTime date) async {
    try {
      final provider = await getProvider(providerId);
      if (provider == null) return 0;

      final taskCount = await getProviderTaskCountForDate(providerId, date);
      final bookingCount = await getProviderBookingCountForDate(
        providerId,
        date,
      );
      final used = taskCount + bookingCount;

      return (provider.maxTasksPerDay - used).clamp(0, provider.maxTasksPerDay);
    } catch (e) {
      Logger.error('Error getting remaining capacity', e);
      return 0;
    }
  }

  // HELPER - Normalize time string to "HH:mm" 24h format for comparison
  String _normalizeTime(String timeStr) {
    try {
      timeStr = timeStr.trim();
      if (timeStr.isEmpty) return "";

      // Handle "08:00 AM" or "8:00 AM" or "14:00"
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      if (parts.length > 1) {
        final isPM = parts[1].toUpperCase() == 'PM';
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr; // Fallback to original
    }
  }

  // HELPER - Get day name from weekday (1=Monday, 7=Sunday)
  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }

  Future<void> submitVerificationDocuments(
    String providerId,
    String businessPermitUrl,
    String governmentIdUrl,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Update Provider Document (use set with merge to ensure it exists)
      final providerRef = _firestore.collection(_providersCollection).doc(providerId);
      batch.set(providerRef, {
        'businessPermitUrl': businessPermitUrl,
        'governmentIdUrl': governmentIdUrl,
        'location': null,
        'isApproved': true, // Auto-approve
        'rating': 0.0,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // 2. Update User Document Role to 'pending_provider'
      final userRef = _firestore.collection('users').doc(providerId);
      batch.update(userRef, {
        'role': 'pending_provider',
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
      Logger.info('Submitted verification documents and updated role for provider $providerId');
    } catch (e) {
      Logger.error('Error submitting verification documents', e);
      throw Exception('Error submitting verification documents: $e');
    }
  }
}
