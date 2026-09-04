import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/in_app_notification_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'logging_service.dart';

class BookingService {
  final FirebaseFirestore _firestore;

  BookingService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;
  static const String _bookingsCollection = 'bookings';
  static const String _tasksCollection = 'tasks';
  static const int _pageSize = 20; // Pagination size

  Future<void> cleanupExpiredBookings({int timeoutMinutes = 15}) async {
    try {
      final now = DateTime.now();
      final threshold = now.subtract(Duration(minutes: timeoutMinutes));

      final snapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(threshold))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        Logger.info('Cleaned up ${snapshot.docs.length} expired pending bookings.');
      }
    } catch (e) {
      Logger.error('Failed to cleanup expired bookings', e);
    }
  }

  // CREATE - Add new booking
  Future<String> createBooking(Booking booking) async {
    try {
      Logger.debug('Creating booking with status: ${booking.status}');
      final bookingData = booking
          .copyWith(createdAt: DateTime.now())
          .toFirestore();

      Logger.debug('Booking data prepared: ${bookingData.keys.join(', ')}');

      String newBookingId = '';

      if (booking.assignedProviderId != null && booking.assignedProviderId!.isNotEmpty) {
        // Run as transaction to atomic-lock the time slot
        final String slotId = '${booking.assignedProviderId}_${booking.scheduledDate.toIso8601String().split('T')[0]}_${booking.scheduledTime}';
        final slotRef = _firestore.collection('provider_slots').doc(slotId);
        final bookingRef = _firestore.collection(_bookingsCollection).doc();
        newBookingId = bookingRef.id;

        await _firestore.runTransaction((transaction) async {
          final slotSnap = await transaction.get(slotRef);
          if (slotSnap.exists) {
            throw Exception('This time slot was just booked by someone else. Please choose a different time.');
          }



          // Write slot lock and booking
          transaction.set(slotRef, {
            'bookedAt': Timestamp.now(),
            'customerId': booking.customerId,
            'providerId': booking.assignedProviderId,
            'scheduledDate': Timestamp.fromDate(booking.scheduledDate),
            'scheduledTime': booking.scheduledTime,
          });

          transaction.set(bookingRef, bookingData);
        });
      } else {
        // No assigned provider (unassigned pool booking)
        final docRef = await _firestore
            .collection(_bookingsCollection)
            .add(bookingData);
        newBookingId = docRef.id;
      }

      Logger.info('Booking created with ID: $newBookingId');
      return newBookingId;
    } catch (e) {
      Logger.error('Error creating booking', e);
      throw Exception('Error creating booking: $e');
    }
  }

  // READ - Get booking by ID
  Future<Booking?> getBooking(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching booking: $e');
    }
  }

  // READ - Get all customer bookings
  Stream<List<Booking>> getCustomerBookings(String customerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  // READ - Get all provider bookings (pending + accepted)
  Stream<List<Booking>> getProviderBookings(String providerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('assignedProviderId', isEqualTo: providerId)
        .where('status', whereIn: ['pending', 'accepted'])
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  // READ - Get pending bookings (not yet accepted by any provider)
  Stream<List<Booking>> getPendingBookings() {
    return _firestore
        .collection(_bookingsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList(),
        );
  }

  // READ - Get bookings for specific date range
  Future<List<Booking>> getBookingsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .orderBy('scheduledDate')
          .get();

      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching bookings by date range: $e');
    }
  }

  // UPDATE - Accept booking by provider
  Future<String> acceptBooking(
    String bookingId, 
    String providerId, {
    String? truckId,
    String? truckName,
    String? driverId,
    String? driverName,
  }) async {
    try {
      String? innerErrorDetails;
      String? createdTaskId;
      await _firestore.runTransaction((transaction) async {
        try {
          final bookingRef = _firestore
              .collection(_bookingsCollection)
              .doc(bookingId);
          final bookingSnapshot = await transaction.get(bookingRef);

          if (!bookingSnapshot.exists) {
            throw Exception('Booking not found');
          }

          final status = bookingSnapshot.get('status');
          if (status != 'pending') {
            throw Exception(
              'Booking is no longer pending (current status: $status)',
            );
          }

          // 1. Prepare task data
          final booking = Booking.fromFirestore(bookingSnapshot);
          final taskRef = _firestore.collection(_tasksCollection).doc();

          final task = Task(
            id: taskRef.id,
            customerId: booking.customerId,
            assignedProviderId: providerId,
            assignedDriverId: driverId, // Assigned to specific driver
            assignedDriverName: driverName,
            serviceType: booking.serviceType,
            location: booking.address,
            latitude: booking.latitude ?? 0.0,
            longitude: booking.longitude ?? 0.0,
            scheduledDate: booking.scheduledDate,
            description: booking.notes,
            priority: TaskPriority.medium,
            status: TaskStatus.assigned,
            createdAt: DateTime.now(),
            estimatedCost: booking.estimatedCost,
            estimatedDurationMinutes: booking.estimatedDurationMinutes,
            bookingId: bookingId,
            assignedTruckId: truckId ?? booking.assignedTruckId,
            assignedTruckName: truckName ?? booking.assignedTruckName,
            assignedPersonnelIds: driverId != null ? [driverId] : booking.assignedPersonnelIds,
            assignedPersonnelNames: driverName != null ? [driverName] : booking.assignedPersonnelNames,
            assignedAssets: booking.assignedAssets,
            landmarkDescription: booking.landmarkDescription,
            barangay: booking.barangay,
            zone: booking.zone,
          );

          // 2. Create task document
          transaction.set(taskRef, task.toFirestore());

          // 3. Update booking status to converted_to_task IN ONE GO
          transaction.update(bookingRef, {
            'assignedProviderId': providerId,
            'status': 'converted_to_task',
            'acceptedAt': Timestamp.now(),
            'taskId': taskRef.id,
          });

          // 4. Update the assigned truck's asset status to inUse if a truck was selected
          if (truckId != null && driverId != null) {
            final assetRef = _firestore.collection('assets').doc(truckId);
            transaction.update(assetRef, {
              'assignedTo': driverId,
              'providerName': driverName, // Name of the person holding the asset
              'status': 'inUse',
              'currentTaskId': taskRef.id,
              'currentTaskLabel': booking.serviceType,
            });
          }

          Logger.info(
            'Transaction: Booking $bookingId accepted and converted to task ${taskRef.id}',
          );
          createdTaskId = taskRef.id;
        } catch (innerE, innerStack) {
          innerErrorDetails = 'INNER EXCEPTION: $innerE\n$innerStack';
        }
      });
      
      if (innerErrorDetails != null) {
        throw Exception(innerErrorDetails);
      }

      // Send notification to customer
      try {
        final docAfter = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
        if (docAfter.exists) {
          final customerId = docAfter.data()?['customerId'] as String?;
          if (customerId != null) {
            final InAppNotificationService notificationService = InAppNotificationService();
            await notificationService.sendNotification(
              userId: customerId,
              title: 'Booking Accepted',
              message: 'Your booking request has been accepted by the provider.',
              type: 'booking_update',
              actionData: {'bookingId': bookingId, 'taskId': createdTaskId},
            );
          }
        }
      } catch (notifE) {
        Logger.error('Failed to send acceptance notification', notifE);
      }

      return createdTaskId!;
    } catch (e, stack) {
      Logger.error('Error in acceptBooking transaction', e, stack);
      throw Exception('Error accepting booking: $e\nStack: $stack');
    }
  }

  // HELPER - Release provider slot lock
  Future<void> _freeProviderSlot(String? providerId, DateTime? date, String? time) async {
    if (providerId == null || providerId.isEmpty || date == null || time == null || time.isEmpty) return;
    try {
      final slotId = '${providerId}_${date.toIso8601String().split('T')[0]}_$time';
      await _firestore.collection('provider_slots').doc(slotId).delete();
      Logger.info('Released provider slot lock: $slotId');
    } catch (e) {
      Logger.error('Failed to release provider slot lock', e);
    }
  }

  // UPDATE - Reject booking
  Future<void> rejectBooking(String bookingId) async {
    try {
      final doc = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final providerId = data['assignedProviderId'] as String?;
        final Timestamp? scheduledDateStamp = data['scheduledDate'] as Timestamp?;
        final String? scheduledTime = data['scheduledTime'] as String?;
        
        if (providerId != null && scheduledDateStamp != null && scheduledTime != null) {
          await _freeProviderSlot(providerId, scheduledDateStamp.toDate(), scheduledTime);
        }
      }

      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'rejected',
      });

      // Send notification to customer
      final docAfter = await _firestore.collection(_bookingsCollection).doc(bookingId).get();
      if (docAfter.exists) {
         final customerId = docAfter.data()?['customerId'] as String?;
         if (customerId != null) {
           final InAppNotificationService notificationService = InAppNotificationService();
           await notificationService.sendNotification(
             userId: customerId,
             title: 'Booking Declined',
             message: 'Your booking request has been declined by the provider.',
             type: 'booking_update',
             actionData: {'bookingId': bookingId},
           );
         }
      }
    } catch (e) {
      throw Exception('Error rejecting booking: $e');
    }
  }

  // UPDATE - Cancel booking with Protection Fee logic
  Future<void> cancelBooking(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!doc.exists) throw Exception('Booking not found');

      final data = doc.data() as Map<String, dynamic>;
      final acceptedAt = data['acceptedAt'] as Timestamp?;
      final providerId = data['assignedProviderId'] as String?;

      bool applyFee = false;
      if (acceptedAt != null && providerId != null) {
        final elapsedMinutes = DateTime.now()
            .difference(acceptedAt.toDate())
            .inMinutes;
        if (elapsedMinutes >= PricingConfig.cancellationGracePeriodMinutes) {
          applyFee = true;
        }
      }

      final Map<String, dynamic> updateData = {
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
      };

      if (applyFee) {
        updateData['cancellationFee'] = PricingConfig.cancellationFee;
        Logger.info(
          'Applying ${PricingConfig.formatPrice(PricingConfig.cancellationFee)} cancellation fee to booking $bookingId',
        );
      }

      // Release slot lock
      if (providerId != null && data['scheduledDate'] != null && data['scheduledTime'] != null) {
        final DateTime scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
        final String scheduledTime = data['scheduledTime'] as String;
        await _freeProviderSlot(providerId, scheduledDate, scheduledTime);
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .update(updateData);
      Logger.info('Booking $bookingId cancelled. Fee applied: $applyFee');
    } catch (e) {
      throw Exception('Error cancelling booking: $e');
    }
  }

  // UPDATE - Reschedule booking to new date/time
  Future<void> rescheduleBooking(
    String bookingId,
    DateTime newDate,
    String newTime,
  ) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'scheduledDate': Timestamp.fromDate(newDate),
        'scheduledTime': newTime,
      });
      Logger.info('Booking $bookingId rescheduled to $newDate at $newTime');
    } catch (e) {
      Logger.error('Error rescheduling booking', e);
      throw Exception('Error rescheduling booking: $e');
    }
  }

  // CONVERT - Convert accepted booking to task
  Future<String> convertBookingToTask(String bookingId) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking == null) throw Exception('Booking not found');

      if (booking.status != BookingStatus.accepted) {
        throw Exception('Can only convert accepted bookings to tasks');
      }

      // Create task from booking
      final task = Task(
        id: '', // Firestore generates ID
        customerId: booking.customerId,
        assignedProviderId: booking.assignedProviderId,
        serviceType: booking.serviceType,
        location: booking.address,
        latitude: booking.latitude ?? 0.0,
        longitude: booking.longitude ?? 0.0,
        scheduledDate: booking.scheduledDate,
        description: booking.notes,
        priority: TaskPriority.medium, // Default priority
        status: TaskStatus.assigned, // Already assigned (booking was accepted)
        createdAt: DateTime.now(),
        estimatedCost: booking.estimatedCost,
        estimatedDurationMinutes: booking.estimatedDurationMinutes,
        assignedTruckId: booking.assignedTruckId,
        assignedTruckName: booking.assignedTruckName,
        assignedPersonnelIds: booking.assignedPersonnelIds,
        assignedPersonnelNames: booking.assignedPersonnelNames,
        assignedAssets: booking.assignedAssets,
        bookingId: bookingId,
      );

      // Save task to Firestore
      final taskRef = await _firestore
          .collection(_tasksCollection)
          .add(task.toFirestore());

      // Update booking status to converted
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'converted_to_task',
      });

      Logger.info('Booking $bookingId converted to task ${taskRef.id}');
      return taskRef.id;
    } catch (e) {
      throw Exception('Error converting booking to task: $e');
    }
  }

  // ANALYTICS - Get bookings count for date
  Future<int> getBookingCountForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(_bookingsCollection)
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
      Logger.error('Error getting booking count for date', e);
      return 0;
    }
  }

  // ANALYTICS - Get provider's accepted bookings for date
  Future<int> getProviderBookingCountForDate(
    String providerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('assignedProviderId', isEqualTo: providerId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .where('status', whereIn: ['accepted', 'converted_to_task'])
          .get();

      return snapshot.size;
    } catch (e) {
      Logger.error('Error getting provider booking count', e);
      return 0;
    }
  }

  // ANALYTICS - Get provider's earnings for date
  Future<double> getProviderEarningsForDate(
    String providerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('assignedProviderId', isEqualTo: providerId)
          .where(
            'scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .where(
            'status',
            whereIn: ['accepted', 'converted_to_task', 'completed'],
          )
          .get();

      double totalEarnings = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final costToUse = (data['finalCost'] as num?) ?? (data['estimatedCost'] as num?) ?? 0.0;
        totalEarnings += costToUse.toDouble();
        totalEarnings += (data['cancellationFee'] as num? ?? 0.0).toDouble();
      }
      return totalEarnings;
    } catch (e) {
      Logger.error('Error getting provider earnings', e);
      return 0.0;
    }
  }

  // STREAM - Get real-time stats for provider dashboard (Optimized)
  Stream<Map<String, dynamic>> getProviderDashboardStats(String providerId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // We stream all bookings for this provider, but we'll be more efficient
    // in processing them. For a production app with huge history,
    // you would add a .where('createdAt', isGreaterThan: startOfMonth) filter here.
    return _firestore
        .collection(_bookingsCollection)
        .where('assignedProviderId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          int pending = 0;
          int active = 0;
          double todayEarnings = 0;
          int todayJobs = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'];
            final Timestamp? scheduledTimestamp =
                data['scheduledDate'] as Timestamp?;
            if (scheduledTimestamp == null) continue;

            final date = scheduledTimestamp.toDate();
            final isToday =
                date.year == startOfDay.year &&
                date.month == startOfDay.month &&
                date.day == startOfDay.day;

            if (status == 'pending') {
              pending++;
            } else if (status == 'accepted' || status == 'converted_to_task') {
              active++;
            }

            if (isToday) {
              if (status == 'completed') {
                todayJobs++;
                final costToUse = (data['finalCost'] as num?) ?? (data['estimatedCost'] as num?) ?? 0.0;
                todayEarnings += costToUse.toDouble();
              } else if (['accepted', 'converted_to_task'].contains(status)) {
                todayJobs++;
              }
              todayEarnings += (data['cancellationFee'] as num? ?? 0.0).toDouble();
            }
          }

          return {
            'pending': pending,
            'active': active,
            'todayEarnings': todayEarnings,
            'todayJobs': todayJobs,
          };
        });
  }

  // DELETE - Delete booking (admin only, if pending)
  Future<void> deleteBooking(String bookingId) async {
    try {
      final booking = await getBooking(bookingId);
      if (booking != null && booking.status == BookingStatus.pending) {
        await _firestore
            .collection(_bookingsCollection)
            .doc(bookingId)
            .delete();
      } else {
        throw Exception('Can only delete pending bookings');
      }
    } catch (e) {
      throw Exception('Error deleting booking: $e');
    }
  }

  // ============ PAGINATION METHODS ============

  /// Get customer bookings with pagination
  Future<List<Booking>> getCustomerBookingsPaginated(
    String customerId, {
    DocumentSnapshot? lastDocument,
    int limit = _pageSize,
  }) async {
    try {
      var query = _firestore
          .collection(_bookingsCollection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('scheduledDate', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      Logger.error('Error fetching customer bookings (paginated)', e);
      throw Exception('Error fetching bookings: $e');
    }
  }

  /// Get provider bookings with pagination
  Future<List<Booking>> getProviderBookingsPaginated(
    String providerId, {
    DocumentSnapshot? lastDocument,
    int limit = _pageSize,
  }) async {
    try {
      var query = _firestore
          .collection(_bookingsCollection)
          .where('assignedProviderId', isEqualTo: providerId)
          .where(
            'status',
            whereIn: ['pending', 'accepted', 'converted_to_task'],
          )
          .orderBy('scheduledDate')
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      Logger.error('Error fetching provider bookings (paginated)', e);
      throw Exception('Error fetching bookings: $e');
    }
  }

  /// Get pending bookings with pagination (for admin dashboard)
  Future<List<Booking>> getPendingBookingsPaginated({
    DocumentSnapshot? lastDocument,
    int limit = _pageSize,
  }) async {
    try {
      var query = _firestore
          .collection(_bookingsCollection)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      Logger.error('Error fetching pending bookings (paginated)', e);
      throw Exception('Error fetching pending bookings: $e');
    }
  }

  // ============ BOOKING TIMEOUT LOGIC ============

  /// Auto-reject pending bookings older than timeout period
  /// Call this periodically from admin dashboard or cloud function
  Future<int> autoRejectExpiredBookings({int timeoutMinutes = 30}) async {
    try {
      final cutoffTime = DateTime.now().subtract(
        Duration(minutes: timeoutMinutes),
      );
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      int rejectedCount = 0;
      for (var doc in snapshot.docs) {
        try {
          await _firestore.collection(_bookingsCollection).doc(doc.id).update({
            'status': 'expired',
            'expiredAt': Timestamp.now(),
          });
          rejectedCount++;
          Logger.info('Auto-rejected expired booking ${doc.id}');
        } catch (e) {
          Logger.error('Error rejecting booking ${doc.id}', e);
        }
      }

      Logger.info('Auto-rejected $rejectedCount expired bookings');
      return rejectedCount;
    } catch (e) {
      Logger.error('Error in autoRejectExpiredBookings', e);
      return 0;
    }
  }
}
