import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/asset_model.dart';
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
  group('AssetModel Tests', () {
    test('should parse from Firestore correctly', () {
      final doc = MockDocumentSnapshot('asset_123', {
        'name': 'Big Tow Truck',
        'category': 'Tow Truck',
        'type': 'vehicle',
        'status': 'active',
        'plateNumber': 'ABC-1234',
      });

      final asset = AssetModel.fromFirestore(doc);

      expect(asset.id, 'asset_123');
      expect(asset.name, 'Big Tow Truck');
      expect(asset.type, AssetType.vehicle);
      expect(asset.status, AssetStatus.active);
      expect(asset.plateNumber, 'ABC-1234');
      expect(asset.quantity, 1); // default
      expect(asset.isConsumable, false); // default
    });

    test('toFirestore should convert to Map correctly', () {
      final asset = AssetModel(
        id: '123',
        name: 'Wrench',
        category: 'Tools',
        type: AssetType.tool,
        status: AssetStatus.inUse,
        metadata: {'size': '10mm'},
      );

      final map = asset.toFirestore();

      expect(map['name'], 'Wrench');
      expect(map['category'], 'Tools');
      expect(map['type'], 'tool');
      expect(map['status'], 'inUse');
      expect(map['metadata'], {'size': '10mm'});
    });
  });

  group('AssetUsageLog Tests', () {
    test('should parse from Firestore correctly', () {
      final now = DateTime.now();
      final doc = MockDocumentSnapshot('log_1', {
        'providerId': 'prov_1',
        'providerName': 'Provider A',
        'crewCount': 2,
        'createdAt': Timestamp.fromDate(now),
      });

      final log = AssetUsageLog.fromFirestore(doc);

      expect(log.id, 'log_1');
      expect(log.providerId, 'prov_1');
      expect(log.crewCount, 2);
      expect(log.createdAt, now);
    });
  });
}
