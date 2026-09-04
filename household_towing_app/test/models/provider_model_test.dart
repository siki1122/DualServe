import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/provider_model.dart';
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
  group('ProviderModel Tests', () {
    final now = DateTime.now();

    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('provider_1', {
        'name': 'Provider A',
        'email': 'pro@example.com',
        'phone': '123',
        'specialty': 'Towing',
        'status': 'available',
        'rating': 4.5,
        'serviceType': 'Towing Service',
        'createdAt': Timestamp.fromDate(now),
        'blockOutDates': ['2026-05-01'],
      });

      final provider = Provider.fromFirestore(doc);

      expect(provider.id, 'provider_1');
      expect(provider.name, 'Provider A');
      expect(provider.status, ProviderStatus.available);
      expect(provider.rating, 4.5);
      expect(provider.blockOutDates, ['2026-05-01']);
    });

    test('toFirestore should convert to Map correctly', () {
      final provider = Provider(
        id: 'p1',
        name: 'Provider B',
        email: 'b@example.com',
        phone: '456',
        specialty: 'Cleaning',
        serviceType: 'Cleaning Service',
        createdAt: now,
        status: ProviderStatus.busy,
      );

      final map = provider.toFirestore();

      expect(map['name'], 'Provider B');
      expect(map['status'], 'busy');
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('isBlockedOnDate logic works', () {
      final provider = Provider(
        id: 'p1',
        name: 'Provider B',
        email: 'b@example.com',
        phone: '456',
        specialty: 'Cleaning',
        serviceType: 'Cleaning Service',
        createdAt: now,
        blockOutDates: ['2026-01-01', '2026-12-25'],
      );

      expect(provider.isBlockedOnDate('2026-01-01'), true);
      expect(provider.isBlockedOnDate('2026-02-14'), false);
    });
  });
}
