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
          .copyWith(
            createdAt: DateTime.now(), 
            updatedAt: DateTime.now(),
          )
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
            // Sort in memory by createdAt descending to show newest tasks first
            tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return tasks;
          },
        );
  }

  // READ - Get tasks assigned to a driver by specific status
  Stream<List<Task>> getDriverTasksByStatus(
    String driverId,
    TaskStatus status,
  ) {
    final statusStr = status.toString().split('.').last;
    return _firestore
        .collection(_tasksCollection)
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', isEqualTo: statusStr)
        .orderBy('scheduledDate') // Always ascending to match existing Firestore index
        .snapshots()
        .map(
          (snapshot) {
            var tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
            // Sort in memory by createdAt descending to show newest tasks first
            tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
  Future<void> updateTaskCompletion(String taskId, {String? imageUrl, String? bookingId, double? finalCost}) async {
    try {
      // 1. Find Booking ID if not provided
      String? finalBookingId = bookingId;
      final taskDoc = await _firestore.collection(_tasksCollection).doc(taskId).get();
      if (!taskDoc.exists) throw Exception('Task not found');
      
      final taskData = taskDoc.data() as Map<String, dynamic>;
      finalBookingId ??= taskData['bookingId'];

      // 2. Perform PRIMARY Updates (Task & Booking)
      // We do these first as they are the most critical for the user
      final batch = _firestore.batch();
      
      final updateData = <String, dynamic>{
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      if (imageUrl != null) updateData['completedImageUrl'] = imageUrl;
      if (finalCost != null) updateData['finalCost'] = finalCost;
      
      batch.update(_firestore.collection(_tasksCollection).doc(taskId), updateData);

      if (finalBookingId != null) {
        final bookingUpdate = <String, dynamic>{
          'status': 'completed',
          'completedAt': Timestamp.now(),
        };
        if (finalCost != null) bookingUpdate['finalCost'] = finalCost;
        batch.update(_firestore.collection('bookings').doc(finalBookingId), bookingUpdate);
      }

      await batch.commit();
      Logger.info('Task $taskId and Booking $finalBookingId marked as completed.');

      // 3. Perform SECONDARY Updates (Assets)
      // These are wrapped in a try-catch so permission errors don't block the user
      try {
        final assignedAssets = <String, int>{};
        if (taskData['assignedAssets'] is Map) {
          (taskData['assignedAssets'] as Map).forEach((key, value) {
            if (value is num) assignedAssets[key.toString()] = value.toInt();
          });
        }

        final truckId = taskData['assignedTruckId'];

        // Release the Truck
        if (truckId != null && truckId.toString().isNotEmpty) {
          final truckRef = _firestore.collection('assets').doc(truckId);
          final truckSnap = await truckRef.get();
          if (truckSnap.exists) {
            final truckData = truckSnap.data() as Map<String, dynamic>;
            final isProviderAsset = truckData['metadata']?['registeredBy'] == 'provider';
            
            await truckRef.update({
              'status': 'active',
              'currentTaskId': FieldValue.delete(),
              'currentTaskLabel': FieldValue.delete(),
              if (!isProviderAsset) 'assignedTo': null,
              if (!isProviderAsset) 'providerName': null,
            });
          }
        }

        // Release the Crew/Driver
        final List<dynamic> personnelIds = taskData['assignedPersonnelIds'] ?? [];
        final driverId = taskData['assignedDriverId'];
        final Set<String> crewToRelease = {};
        
        for (var id in personnelIds) {
          if (id != null) crewToRelease.add(id.toString());
        }
        if (driverId != null) crewToRelease.add(driverId.toString());

        for (var crewId in crewToRelease) {
          if (crewId.isNotEmpty) {
            await _firestore.collection('assets').doc(crewId).update({
              'status': 'active',
              'currentTaskId': FieldValue.delete(),
              'currentTaskLabel': FieldValue.delete(),
            });
          }
        }

        // Release/Restock other assets
        for (var entry in assignedAssets.entries) {
          final assetRef = _firestore.collection('assets').doc(entry.key);
          final assetSnap = await assetRef.get();
          if (assetSnap.exists) {
            final data = assetSnap.data() as Map<String, dynamic>;
            final isConsumable = data['isConsumable'] ?? false;
            if (!isConsumable) {
              final currentQuantity = (data['quantity'] as num?)?.toInt() ?? 0;
              await assetRef.update({
                'quantity': currentQuantity + entry.value,
                'status': 'active', // Ensure it's active if it was marked inUse
              });
            }
          }
        }
      } catch (e) {
        Logger.warn('Asset auto-release encountered an issue (likely permissions): $e');
        // We don't throw here because the Task is already marked as completed
      }
      
    } catch (e) {
      Logger.error('Critical error in task completion', e);
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
  Future<void> cancelTask(String taskId, {String? bookingId, String? reason}) async {
    try {
      final taskDoc = await _firestore.collection(_tasksCollection).doc(taskId).get();
      if (!taskDoc.exists) throw Exception('Task not found');
      final taskData = taskDoc.data() as Map<String, dynamic>;
      final bId = bookingId ?? taskData['bookingId'];

      final batch = _firestore.batch();
      batch.update(_firestore.collection(_tasksCollection).doc(taskId), {
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': Timestamp.now(),
      });

      if (bId != null) {
        batch.update(_firestore.collection('bookings').doc(bId), {
          'status': 'cancelled',
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();

      // Release assets so they aren't locked forever
      try {
        final truckId = taskData['assignedTruckId'];
        if (truckId != null && truckId.toString().isNotEmpty) {
          final truckRef = _firestore.collection('assets').doc(truckId);
          final truckSnap = await truckRef.get();
          if (truckSnap.exists) {
            final truckData = truckSnap.data() as Map<String, dynamic>;
            final isProviderAsset = truckData['metadata']?['registeredBy'] == 'provider';
            await truckRef.update({
              'status': 'active',
              'currentTaskId': FieldValue.delete(),
              'currentTaskLabel': FieldValue.delete(),
              if (!isProviderAsset) 'assignedTo': null,
              if (!isProviderAsset) 'providerName': null,
            });
          }
        }
        
        final assignedAssets = <String, int>{};
        if (taskData['assignedAssets'] is Map) {
          (taskData['assignedAssets'] as Map).forEach((key, value) {
            if (value is num) assignedAssets[key.toString()] = value.toInt();
          });
        }
        
        for (var entry in assignedAssets.entries) {
          final assetRef = _firestore.collection('assets').doc(entry.key);
          final assetSnap = await assetRef.get();
          if (assetSnap.exists) {
            final data = assetSnap.data() as Map<String, dynamic>;
            final isConsumable = data['isConsumable'] ?? false;
            if (!isConsumable) {
              final currentQuantity = (data['quantity'] as num?)?.toInt() ?? 0;
              await assetRef.update({
                'quantity': currentQuantity + entry.value,
                'status': 'active',
              });
            }
          }
        }
      } catch (e) {
        Logger.warn('Asset auto-release failed on cancel: $e');
      }
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

  // UPDATE - Update specific milestone and recalculate progress
  Future<void> updateTaskMilestone(String taskId, String milestoneId, bool isCompleted) async {
    try {
      final task = await getTask(taskId);
      if (task == null) throw Exception('Task not found');

      final updatedMilestones = task.milestones.map((m) {
        if (m.id == milestoneId) {
          return m.copyWith(
            isCompleted: isCompleted,
            completedAt: isCompleted ? DateTime.now() : null,
          );
        }
        return m;
      }).toList();

      // Calculate progress
      final completedCount = updatedMilestones.where((m) => m.isCompleted).length;
      final double progress = updatedMilestones.isEmpty ? 0.0 : completedCount / updatedMilestones.length;

      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'milestones': updatedMilestones.map((m) => m.toMap()).toList(),
        'progress': progress,
        'updatedAt': Timestamp.now(),
      });
      
      // If any milestone is started, make sure status is inProgress
      if (progress > 0.0 && task.status == TaskStatus.assigned) {
        await updateTaskStatus(taskId, TaskStatus.inProgress);
      }
      
    } catch (e) {
      Logger.error('Error updating task milestone', e);
      throw Exception('Error updating task milestone: $e');
    }
  }

  // HELPER - Get default milestones based on service type
  List<TaskMilestone> _getDefaultMilestones(String serviceType) {
    if (serviceType.toLowerCase().contains('towing')) {
      return [
        TaskMilestone(id: 'assigned', title: 'Provider Assigned', isCompleted: true),
        TaskMilestone(id: 'en_route', title: 'En Route'),
        TaskMilestone(id: 'arrived', title: 'Arrived at Scene'),
        TaskMilestone(id: 'loaded', title: 'Vehicle Loaded'),
        TaskMilestone(id: 'completed', title: 'Delivered'),
      ];
    } else {
      // Default for Household or other services
      return [
        TaskMilestone(id: 'dispatched', title: 'Team Dispatched'),
        TaskMilestone(id: 'setup', title: 'Arrival & Setup'),
        TaskMilestone(id: 'in_progress', title: 'Service Underway'),
        TaskMilestone(id: 'inspection', title: 'Final Inspection'),
        TaskMilestone(id: 'completed', title: 'Completed'),
      ];
    }
  }
}
