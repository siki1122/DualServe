import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:mockito/mockito.dart';

class FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> mockTasks = {
    'task_1': {
      'customerId': 'cust1',
      'serviceType': 'Towing',
      'status': 'unassigned',
      'location': 'somewhere',
    },
    'task_2': {
      'customerId': 'cust2',
      'serviceType': 'Cleaning',
      'status': 'assigned',
      'assignedProviderId': 'prov1',
    },
  };

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(collectionPath, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference implements CollectionReference<Map<String, dynamic>> {
  final String path;
  final FakeFirestore firestore;

  FakeCollectionReference(this.path, this.firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(this.path, path ?? 'new_id', firestore);
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) async {
    final id = 'new_task_${DateTime.now().millisecondsSinceEpoch}';
    firestore.mockTasks[id] = data;
    return FakeDocumentReference(path, id, firestore);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final String collectionPath;
  final String docId;
  final FakeFirestore firestore;

  FakeDocumentReference(this.collectionPath, this.docId, this.firestore);

  @override
  String get id => docId;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final data = firestore.mockTasks[docId];
    return FakeDocumentSnapshot(docId, data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (firestore.mockTasks.containsKey(docId)) {
      final stringData = data.map((key, value) => MapEntry(key.toString(), value));
      firestore.mockTasks[docId]!.addAll(stringData);
    }
  }

  @override
  Future<void> delete() async {
    firestore.mockTasks.remove(docId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final String _id;

  FakeDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TaskService Tests', () {
    late TaskService taskService;
    late FakeFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirestore();
      taskService = TaskService(firestore: fakeFirestore);
    });

    test('getTask returns data if exists', () async {
      final task = await taskService.getTask('task_1');
      expect(task, isNotNull);
      expect(task!.customerId, 'cust1');
      expect(task.status, TaskStatus.unassigned);
    });

    test('createTask adds new task', () async {
      final newTask = Task(
        id: '',
        customerId: 'cust3',
        serviceType: 'Cleaning',
        location: '123 Main',
        latitude: 0,
        longitude: 0,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final id = await taskService.createTask(newTask);
      expect(id, startsWith('new_task_'));
      expect(fakeFirestore.mockTasks[id], isNotNull);
    });

    test('updateTaskStatus updates status', () async {
      await taskService.updateTaskStatus('task_1', TaskStatus.assigned);
      expect(fakeFirestore.mockTasks['task_1']!['status'], 'assigned');
    });

    test('deleteTask removes unassigned task', () async {
      expect(fakeFirestore.mockTasks.containsKey('task_1'), true);
      await taskService.deleteTask('task_1');
      expect(fakeFirestore.mockTasks.containsKey('task_1'), false);
    });

    test('deleteTask throws if assigned', () async {
      expect(
        () => taskService.deleteTask('task_2'),
        throwsException,
      );
    });
  });
}
