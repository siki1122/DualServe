import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/booking_model.dart';
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
  group('BookingModel Tests', () {
    final now = DateTime.now();

    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('booking_123', {
        'customerId': 'cust_1',
        'serviceType': 'Towing',
        'address': '123 Main St',
        'scheduledDate': Timestamp.fromDate(now),
        'scheduledTime': '14:00',
        'status': 'accepted',
        'createdAt': Timestamp.fromDate(now),
        'assignedTruckType': 'medium',
      });

      final booking = Booking.fromFirestore(doc);

      expect(booking.id, 'booking_123');
      expect(booking.customerId, 'cust_1');
      expect(booking.serviceType, 'Towing');
      expect(booking.status, BookingStatus.accepted);
      expect(booking.scheduledDate, now);
      expect(booking.assignedTruckType, TruckType.medium);
    });

    test('toFirestore should convert to Map correctly', () {
      final booking = Booking(
        id: 'b1',
        customerId: 'c1',
        serviceType: 'Cleaning',
        address: '456 Oak Ave',
        scheduledDate: now,
        scheduledTime: '10:00',
        createdAt: now,
        status: BookingStatus.completed,
      );

      final map = booking.toFirestore();

      expect(map['customerId'], 'c1');
      expect(map['serviceType'], 'Cleaning');
      expect(map['status'], 'completed');
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('copyWith should update fields correctly', () {
      final booking = Booking(
        id: 'b1',
        customerId: 'c1',
        serviceType: 'Towing',
        address: 'Addr',
        scheduledDate: now,
        scheduledTime: '10:00',
        createdAt: now,
      );

      final updated = booking.copyWith(status: BookingStatus.cancelled, notes: 'Cancelled by user');

      expect(updated.id, 'b1');
      expect(updated.status, BookingStatus.cancelled);
      expect(updated.notes, 'Cancelled by user');
      expect(updated.serviceType, 'Towing');
    });
  });
}
