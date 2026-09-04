import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/driver_model.dart';
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
  group('DriverModel Tests', () {
    final now = DateTime.now();

    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('driver_123', {
        'providerId': 'prov_abc',
        'name': 'John Doe',
        'phone': '555-1234',
        'email': 'john@example.com',
        'status': 'busy',
        'createdAt': Timestamp.fromDate(now),
      });

      final driver = Driver.fromFirestore(doc);

      expect(driver.id, 'driver_123');
      expect(driver.name, 'John Doe');
      expect(driver.status, DriverStatus.busy);
      expect(driver.createdAt, now);
    });

    test('toFirestore should convert to Map correctly', () {
      final driver = Driver(
        id: 'd1',
        providerId: 'p1',
        name: 'Jane Smith',
        phone: '555-9876',
        email: 'jane@example.com',
        status: DriverStatus.offline,
        createdAt: now,
      );

      final map = driver.toFirestore();

      expect(map['name'], 'Jane Smith');
      expect(map['status'], 'offline');
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('copyWith should update fields correctly', () {
      final driver = Driver(
        id: 'd1',
        providerId: 'p1',
        name: 'Original Name',
        phone: '111',
        email: 'test@test.com',
        createdAt: now,
      );

      final updated = driver.copyWith(name: 'New Name', status: DriverStatus.busy);

      expect(updated.id, 'd1');
      expect(updated.name, 'New Name');
      expect(updated.status, DriverStatus.busy);
      expect(updated.phone, '111');
    });
  });
}
