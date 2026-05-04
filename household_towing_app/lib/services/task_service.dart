import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'logging_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tasksCollection = 'tasks';

  // CREATE - Add new task
  Future<String> createTask(Task task) async {
    try {
      Logger.debug('Creating task with status: ${task.status}');
      final taskData = task
          .copyWith(createdAt: DateTime.now(), updatedAt: DateTime.now())
          .toFirestore();

      Logger.debug('Task data prepared: ${taskData.keys.join(', ')}');

      final docRef = await _firestore
          .collection(_tasksCollection)
          .add(taskData);

      Logger.info('Task created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Logger.error('Error creating task', e);
      throw Exception('Error creating task: $e');
    }
  }

  // READ - Get task by ID
  Future<Task?> getTask(String taskId) async {
    try {
      final doc = await _firestore
          .collection(_tasksCollection)
          .doc(taskId)
          .get();
      if (doc.exists) {
        return Task.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching task: $e');
    }
  }

  // READ - Get all unassigned tasks
  Stream<List<Task>> getUnassignedTasks() {
    return _firestore
        .collection(_tasksCollection)
        .where('status', isEqualTo: 'unassigned')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
        })
        .handleError((e) {
          Logger.error('Unassigned tasks query error', e);
          return [];
        });
  }

  // READ - Get tasks assigned to a provider by specific status
  Stream<List<Task>> getProviderTasksByStatus(
    String providerId,
    TaskStatus status,
  ) {
    final statusStr = status.toString().split('.').last;
    return _firestore
        .collection(_tasksCollection)
        .where('assignedProviderId', isEqualTo: providerId)
        .where('status', isEqualTo: statusStr)
        .orderBy('scheduledDate') // Always ascending to match existing Firestore index
        .snapshots()
        .map(
          (snapshot) {
            var tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
            if (status == TaskStatus.completed) {
              return tasks.reversed.toList(); // Reverse in memory to show newest first
            }
            return tasks;
          },
        );
  }

  // READ - Get all active tasks for a provider (Assigned or In Progress)
  Stream<List<Task>> getProviderTasks(String providerId) {
    return _firestore
        .collection(_tasksCollection)
        .where('assignedProviderId', isEqualTo: providerId)
        .where('status', whereIn: ['assigned', 'inProgress'])
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(),
        );
  }

  // READ - Get customer's tasks
  Stream<List<Task>> getCustomerTasks(String customerId) {
    return _firestore
        .collection(_tasksCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(),
        );
  }

  // READ - Get tasks for a date range
  Stream<List<Task>> getTasksByDateRange(DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(_tasksCollection)
        .where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where(
          'scheduledDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        )
        .orderBy('scheduledDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(),
        );
  }

  // UPDATE - Assign task to provider (with Transaction to prevent race conditions)
  Future<void> assignTask(String taskId, String providerId) async {
    final taskRef = _firestore.collection(_tasksCollection).doc(taskId);

    return _firestore
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(taskRef);

          if (!snapshot.exists) {
            throw Exception('Task does not exist!');
          }

          final status = snapshot.data()?['status'];
          if (status != 'unassigned' && status != 'pending') {
            throw Exception('Task has already been taken by someone else!');
          }

          transaction.update(taskRef, {
            'assignedProviderId': providerId,
            'status': 'assigned',
            'updatedAt': Timestamp.now(),
          });
        })
        .catchError((e) {
          Logger.error('Task assignment transaction failed', e);
          throw e;
        });
  }

  // UPDATE - Mark task as completed using a Transaction for atomic inventory updates
  Future<void> updateTaskCompletion(String taskId, {String? imageUrl, String? bookingId}) async {
    try {
      // 0. Find Booking ID before transaction if not provided
      String? finalBookingId = bookingId;
      if (finalBookingId == null) {
        final taskDoc = await _firestore.collection(_tasksCollection).doc(taskId).get();
        if (taskDoc.exists) {
          finalBookingId = taskDoc.data()?['bookingId'];
        }
        
        if (finalBookingId == null) {
          final bookingQuery = await _firestore
              .collection('bookings')
              .where('taskId', isEqualTo: taskId)
              .limit(1)
              .get();
          if (bookingQuery.docs.isNotEmpty) {
            finalBookingId = bookingQuery.docs.first.id;
          }
        }
      }

      // CRITICAL: Firestore transactions MUST do all READS before any WRITES.
      await _firestore.runTransaction((transaction) async {
        final taskRef = _firestore.collection(_tasksCollection).doc(taskId);
        final taskDoc = await transaction.get(taskRef);
        if (!taskDoc.exists) throw Exception('Task not found');
        final taskData = taskDoc.data() as Map<String, dynamic>;

        // --- 1. ALL READS FIRST ---
        
        // Read Booking
        DocumentSnapshot? bookingDoc;
        if (finalBookingId != null) {
          final bookingRef = _firestore.collection('bookings').doc(finalBookingId);
          bookingDoc = await transaction.get(bookingRef);
        }
        final bookingData = bookingDoc?.data() as Map<String, dynamic>?;

        // Collect asset quantities
        final assignedAssets = <String, int>{};
        void parseAssets(dynamic source) {
          if (source is Map) {
            source.forEach((key, value) {
              if (value is num) {
                assignedAssets[key.toString()] = (assignedAssets[key.toString()] ?? 0) + value.toInt();
              }
            });
          }
        }
        parseAssets(bookingData?['assignedAssets']);
        parseAssets(taskData['assignedAssets']);

        // Read all Asset documents
        final assetSnapshots = <String, DocumentSnapshot>{};
        for (var assetId in assignedAssets.keys) {
          final assetRef = _firestore.collection('assets').doc(assetId);
          assetSnapshots[assetId] = await transaction.get(assetRef);
        }

        // Read Truck document
        final truckId = taskData['assignedTruckId'] ?? bookingData?['assignedTruckId'];
        DocumentSnapshot? truckDoc;
        if (truckId != null && truckId.toString().isNotEmpty) {
          final truckRef = _firestore.collection('assets').doc(truckId);
          truckDoc = await transaction.get(truckRef);
        }

        // --- 2. ALL WRITES SECOND ---
        
        // Update Task Status
        final updateData = <String, dynamic>{
          'status': 'completed',
          'completedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };
        if (imageUrl != null) updateData['completedImageUrl'] = imageUrl;
        transaction.update(taskRef, updateData);

        // Update Booking Status
        if (bookingDoc != null && bookingDoc.exists) {
          transaction.update(bookingDoc.reference, {
            'status': 'completed',
            'completedAt': Timestamp.now(),
          });
        }

        // Update Asset Inventories
        for (var entry in assignedAssets.entries) {
          final assetDoc = assetSnapshots[entry.key];
          if (assetDoc != null && assetDoc.exists) {
            final data = assetDoc.data() as Map<String, dynamic>;
            final isConsumable = data['isConsumable'] ?? false;
            if (!isConsumable) {
              final rawQty = data['quantity'];
              final int currentQuantity = (rawQty is num) ? rawQty.toInt() : 0;
              transaction.update(assetDoc.reference, {
                'quantity': currentQuantity + entry.value,
              });
            }
          }
        }

        // Update Truck Status
        if (truckDoc != null && truckDoc.exists) {
          final truckData = truckDoc.data() as Map<String, dynamic>;
          final isProviderAsset = truckData['metadata']?['registeredBy'] == 'provider';
          
          transaction.update(truckDoc.reference, {
            'status': 'active',
            'currentTaskId': FieldValue.delete(),
            'currentTaskLabel': FieldValue.delete(),
            if (!isProviderAsset) 'assignedTo': null,
            if (!isProviderAsset) 'providerName': null,
          });
        }
      });
      
      Logger.info('Task $taskId completed successfully via transaction.');
    } catch (e) {
      Logger.error('Error completing task via transaction', e);
      throw Exception('Error completing task: $e');
    }
  }

  // UPDATE - Update task status
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error updating task status: $e');
    }
  }

  // UPDATE - Reschedule task
  Future<void> rescheduleTask(String taskId, DateTime newDate) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'scheduledDate': Timestamp.fromDate(newDate),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error rescheduling task: $e');
    }
  }

  // UPDATE - Update task priority
  Future<void> updateTaskPriority(String taskId, TaskPriority priority) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'priority': priority.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error updating task priority: $e');
    }
  }

  // DELETE - Cancel task
  Future<void> cancelTask(String taskId) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error cancelling task: $e');
    }
  }

  // DELETE - Delete task (only if unassigned)
  Future<void> deleteTask(String taskId) async {
    try {
      final task = await getTask(taskId);
      if (task != null && task.status == TaskStatus.unassigned) {
        await _firestore.collection(_tasksCollection).doc(taskId).delete();
      } else {
        throw Exception('Can only delete unassigned tasks');
      }
    } catch (e) {
      throw Exception('Error deleting task: $e');
    }
  }

  // ANALYTICS - Get provider availability for a date
  Future<bool> isProviderAvailable(String providerId, DateTime date) async {
    try {
      final doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (!doc.exists) return true;

      final data = doc.data() as Map<String, dynamic>;
      final weeklySchedule = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
      
      // Check if date is blocked
      final blockOutDates = List<String>.from(data['blockOutDates'] ?? []);
      final dateISO = date.toIso8601String().split('T')[0];
      if (blockOutDates.contains(dateISO)) return false;

      final dayName = _getDayName(date.weekday);
      final availableSlots = weeklySchedule[dayName] as List? ?? [];
      return availableSlots.isNotEmpty;
    } catch (e) {
      Logger.error('Error checking provider availability', e);
      return true; // Default to available on error to not block operations
    }
  }

  // ANALYTICS - Get provider task count for a date
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
          .get();

      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Helper - Convert weekday number to day name
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
}
