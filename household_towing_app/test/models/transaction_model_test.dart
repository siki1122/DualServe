import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/transaction_model.dart' as app_models;
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
  group('TransactionModel Tests', () {
    final now = DateTime.now();

    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('txn_1', {
        'taskId': 't1',
        'bookingId': 'b1',
        'customerId': 'c1',
        'providerId': 'p1',
        'serviceType': 'Towing',
        'basePrice': 1500.0,
        'distanceTraveled': 10.0,
        'costPerKm': 25.0,
        'distanceSurcharge': 250.0,
        'finalCost': 1750.0,
        'status': 'completed',
        'paymentStatus': 'recorded',
        'createdAt': Timestamp.fromDate(now),
        'completedAt': Timestamp.fromDate(now),
      });

      final transaction = app_models.Transaction.fromFirestore(doc);

      expect(transaction.id, 'txn_1');
      expect(transaction.taskId, 't1');
      expect(transaction.finalCost, 1750.0);
      expect(transaction.status, app_models.TransactionStatus.completed);
      expect(transaction.paymentStatus, app_models.PaymentStatus.recorded);
    });

    test('toFirestore should convert to Map correctly', () {
      final transaction = app_models.Transaction(
        id: 'txn_2',
        taskId: 't2',
        bookingId: 'b2',
        customerId: 'c2',
        providerId: 'p2',
        serviceType: 'Cleaning',
        basePrice: 500.0,
        distanceTraveled: 0.0,
        costPerKm: 0.0,
        distanceSurcharge: 0.0,
        finalCost: 500.0,
        completedAt: now,
        createdAt: now,
        status: app_models.TransactionStatus.pending,
      );

      final map = transaction.toFirestore();

      expect(map['taskId'], 't2');
      expect(map['finalCost'], 500.0);
      expect(map['status'], 'pending');
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });
  });
}
