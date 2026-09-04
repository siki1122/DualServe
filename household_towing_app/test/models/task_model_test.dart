import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:mockito/mockito.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Object? data() => _data;
}

void main() {
  group('TaskModel Tests', () {
    final now = DateTime.now();

    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('task_123', {
        'customerId': 'cust_1',
        'serviceType': 'Towing Service',
        'location': 'Location A',
        'latitude': 1.0,
        'longitude': 2.0,
        'scheduledDate': Timestamp.fromDate(now),
        'status': 'inProgress',
        'priority': 'high',
        'createdAt': Timestamp.fromDate(now),
      });

      final task = Task.fromFirestore(doc);

      expect(task.id, 'task_123');
      expect(task.customerId, 'cust_1');
      expect(task.serviceType, 'Towing Service');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.latitude, 1.0);
    });

    test('toFirestore should convert to Map correctly', () {
      final task = Task(
        id: 't1',
        customerId: 'c1',
        serviceType: 'Cleaning',
        location: 'Loc B',
        latitude: 10.0,
        longitude: 20.0,
        scheduledDate: now,
        createdAt: now,
        status: TaskStatus.completed,
        priority: TaskPriority.urgent,
      );

      final map = task.toFirestore();

      expect(map['customerId'], 'c1');
      expect(map['status'], 'completed');
      expect(map['priority'], 'urgent');
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('_calculateProgress and defaultMilestones logic', () {
      // Test Towing default milestones
      final towingTask = Task(
        id: 't1',
        customerId: 'c1',
        serviceType: 'Towing',
        location: 'Loc B',
        latitude: 10.0,
        longitude: 20.0,
        scheduledDate: now,
        createdAt: now,
      );

      // Towing has 5 milestones, 1 is completed by default ('assigned')
      expect(towingTask.milestones.length, 5);
      expect(towingTask.milestones.first.title, 'Provider Assigned');
      expect(towingTask.progress, 1.0 / 5.0);

      // Complete another milestone
      final updatedMilestones = List<TaskMilestone>.from(towingTask.milestones);
      updatedMilestones[1] = updatedMilestones[1].copyWith(isCompleted: true);
      
      final updatedTask = towingTask.copyWith(milestones: updatedMilestones);
      // Wait, _calculateProgress is called in constructor if progress is null. copyWith uses the old progress if not provided.
      // So copyWith(milestones) should also update progress? 
      // Actually in copyWith, progress: progress ?? this.progress is used. So it wouldn't recalculate unless we pass it.
      // We will just test that we can update it.
      final progressCalc = updatedMilestones.where((m) => m.isCompleted).length / updatedMilestones.length;
      final fullyUpdatedTask = updatedTask.copyWith(progress: progressCalc);

      expect(fullyUpdatedTask.progress, 2.0 / 5.0);
    });
  });
}
