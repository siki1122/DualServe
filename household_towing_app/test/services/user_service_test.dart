import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/user_service.dart';

class FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> mockUsers = {
    'user1': {'name': 'Alice', 'role': 'customer'},
  };
  final Map<String, Map<String, dynamic>> mockProviders = {
    'prov1': {'name': 'Bob', 'role': 'provider'},
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
    return FakeDocumentReference(this.path, path!, firestore);
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
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    Map<String, dynamic>? data;
    if (collectionPath == 'users') {
      data = firestore.mockUsers[docId];
    } else if (collectionPath == 'providers') {
      data = firestore.mockProviders[docId];
    }
    return FakeDocumentSnapshot(data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (collectionPath == 'providers') {
      if (firestore.mockProviders.containsKey(docId)) {
         final stringData = data.map((key, value) => MapEntry(key.toString(), value));
         firestore.mockProviders[docId]!.addAll(stringData);
      } else {
         final stringData = data.map((key, value) => MapEntry(key.toString(), value));
         firestore.mockProviders[docId] = Map<String, dynamic>.from(stringData);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


void main() {
  group('UserService Tests', () {
    late UserService userService;
    late FakeFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirestore();
      userService = UserService(firestore: fakeFirestore);
    });

    test('getUserProfile returns data if exists', () async {
      final profile = await userService.getUserProfile('user1');
      expect(profile, isNotNull);
      expect(profile!['name'], 'Alice');
    });

    test('getUserProfile returns null if not exists', () async {
      final profile = await userService.getUserProfile('unknown');
      expect(profile, isNull);
    });

    test('getProviderProfile returns data if exists', () async {
      final profile = await userService.getProviderProfile('prov1');
      expect(profile, isNotNull);
      expect(profile!['role'], 'provider');
    });

    test('updateProviderAvailability updates data', () async {
      await userService.updateProviderAvailability('prov1', true);
      expect(fakeFirestore.mockProviders['prov1']!['isAvailable'], true);
    });

    test('updateProviderRating updates rating', () async {
      await userService.updateProviderRating('prov1', 4.5);
      expect(fakeFirestore.mockProviders['prov1']!['rating'], 4.5);
    });

    test('updateProviderRating throws on invalid rating', () async {
      expect(
        () => userService.updateProviderRating('prov1', 6.0),
        throwsException,
      );
    });
  });
}
