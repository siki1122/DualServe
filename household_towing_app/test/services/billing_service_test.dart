import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:mockito/mockito.dart';

class FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> mockTransactions = {
    'txn_1': {
      'customerId': 'cust1',
      'providerId': 'prov1',
      'finalCost': 1500.0,
      'status': 'completed',
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
    final id = 'new_txn_${DateTime.now().millisecondsSinceEpoch}';
    firestore.mockTransactions[id] = data;
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
    final data = firestore.mockTransactions[docId];
    return FakeDocumentSnapshot(docId, data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (firestore.mockTransactions.containsKey(docId)) {
      final stringData = data.map((key, value) => MapEntry(key.toString(), value));
      firestore.mockTransactions[docId]!.addAll(stringData);
    }
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
  group('BillingService Tests', () {
    late BillingService billingService;
    late FakeFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirestore();
      billingService = BillingService(firestore: fakeFirestore);
    });

    test('getTransaction returns data if exists', () async {
      final txn = await billingService.getTransaction('txn_1');
      expect(txn, isNotNull);
      expect(txn!.customerId, 'cust1');
      expect(txn.finalCost, 1500.0);
    });

    test('getTransaction returns null if not exists', () async {
      final txn = await billingService.getTransaction('unknown');
      expect(txn, isNull);
    });

    test('recordTransaction creates new transaction', () async {
      final id = await billingService.recordTransaction(
        taskId: 't1',
        bookingId: 'b1',
        customerId: 'cust2',
        providerId: 'prov2',
        serviceType: 'Towing',
        distanceTraveled: 10.0,
        basePrice: 1500.0,
        distanceSurcharge: 250.0,
        nightDifferential: 0.0,
        finalCost: 1750.0,
        providerNotes: 'All good',
      );

      expect(id, startsWith('new_txn_'));
      expect(fakeFirestore.mockTransactions[id], isNotNull);
      expect(fakeFirestore.mockTransactions[id]!['finalCost'], 1750.0);
    });
  });
}
