import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset_model.dart';
import 'logging_service.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AssetModel>> getAssets() {
    return _firestore.collection('assets').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AssetModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<AssetModel>> getProviderAssignedAssets(String providerId) {
    return _firestore
        .collection('assets')
        .where('assignedTo', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AssetModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<AssetUsageLog>> getProviderUsageLogs(String providerId) {
    return _firestore
        .collection('asset_usage')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs
          .map((doc) => AssetUsageLog.fromFirestore(doc))
          .toList();
      logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return logs;
    });
  }

  Future<void> addAsset(AssetModel asset) async {
    await _firestore.collection('assets').add(asset.toFirestore());
  }

  Future<void> addProviderAsset({
    required String providerId,
    required String providerName,
    required String name,
    required String category,
    required AssetType type,
    String? plateNumber,
  }) async {
    final asset = AssetModel(
      id: '',
      name: name,
      category: category,
      type: type,
      status: AssetStatus.active,
      plateNumber: type == AssetType.vehicle ? plateNumber : null,
      assignedTo: providerId,
      providerName: providerName,
       jobsCompleted: 0,
       metadata: {'registeredBy': 'provider'},
       ownerId: providerId,
     );

    await _firestore.collection('assets').add(asset.toFirestore());
  }

  Future<void> updateAsset(AssetModel asset) async {
    await _firestore.collection('assets').doc(asset.id).update(asset.toFirestore());
  }

  Future<void> deleteAsset(String id) async {
    await _firestore.collection('assets').doc(id).delete();
  }

  Future<void> assignAsset(String assetId, String providerId, String providerName) async {
    await _firestore.collection('assets').doc(assetId).update({
      'assignedTo': providerId,
      'providerName': providerName,
      'status': AssetStatus.inUse.name,
    });
  }

  Future<void> claimAssetForProvider(
    String assetId,
    String providerId,
    String providerName,
  ) async {
    final assetRef = _firestore.collection('assets').doc(assetId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(assetRef);
      if (!snapshot.exists) {
        throw Exception('Asset does not exist');
      }

      final data = snapshot.data() ?? {};
      final assignedTo = data['assignedTo'];
      final status = data['status'];
      if (assignedTo != null || status != AssetStatus.active.name) {
        throw Exception('Asset is no longer available');
      }

      transaction.update(assetRef, {
        'assignedTo': providerId,
        'providerName': providerName,
        'status': AssetStatus.inUse.name,
      });
    });
  }

  Future<void> releaseAsset(String assetId) async {
    await _firestore.collection('assets').doc(assetId).update({
      'assignedTo': null,
      'providerName': null,
      'status': AssetStatus.active.name,
      'currentTaskId': FieldValue.delete(),
      'currentTaskLabel': FieldValue.delete(),
    });
  }

  Future<void> releaseProviderAsset(String assetId, String providerId) async {
    final assetRef = _firestore.collection('assets').doc(assetId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(assetRef);
      if (!snapshot.exists) {
        throw Exception('Asset does not exist');
      }

      if (snapshot.data()?['assignedTo'] != providerId) {
        throw Exception('This asset is not assigned to you');
      }

      transaction.update(assetRef, {
        'assignedTo': null,
        'providerName': null,
        'status': AssetStatus.active.name,
        'currentTaskId': FieldValue.delete(),
        'currentTaskLabel': FieldValue.delete(),
      });
    });
  }

  Future<void> logResourceUsage({
    required String providerId,
    required String providerName,
    String? driverId,
    String? driverName,
    String? taskId,
    String? bookingId,
    String? taskLabel,
    int? crewCount,
    AssetModel? vehicle,
    List<AssetModel> tools = const [],
    List<AssetModel> equipment = const [],
    List<AssetModel> crew = const [],
    Map<String, int>? assetQuantities,
    String? notes,
  }) async {
    final quantities = assetQuantities ?? {};

    // 1. Update the Task/Booking FIRST (Most critical for the workflow)
    final assignmentData = {
      'assignedTruckId': vehicle?.id,
      'assignedTruckName': vehicle?.name,
      'assignedDriverId': driverId,
      'assignedDriverName': driverName,
      'assignedPersonnelIds': crew.isNotEmpty 
          ? crew.map((c) => c.id).toList() 
          : (driverId != null ? [driverId] : []),
      'assignedPersonnelNames': crew.isNotEmpty 
          ? crew.map((c) => c.name).toList() 
          : (driverName != null ? [driverName] : []),
      'assignedAssets': Map.fromEntries([
        ...tools.map((a) => MapEntry(a.id, quantities[a.id] ?? 1)),
        ...equipment.map((a) => MapEntry(a.id, quantities[a.id] ?? 1)),
      ]),
      'resourceNotes': notes,
    };

    if (taskId != null) {
      await _firestore.collection('tasks').doc(taskId).update(assignmentData);
    } else if (bookingId != null) {
      await _firestore.collection('bookings').doc(bookingId).update(assignmentData);
    }

    // 2. Create the usage log (Providers should always have permission here)
    await _firestore.collection('asset_usage').add({
      'providerId': providerId,
      'providerName': providerName,
      'driverId': driverId,
      'driverName': driverName,
      'taskId': taskId,
      'bookingId': bookingId,
      'taskLabel': taskLabel,
      'crewCount': crewCount ?? (crew.isNotEmpty ? crew.length : 1),
      'vehicleAssetId': vehicle?.id,
      'vehicleName': vehicle?.name,
      'toolAssetIds': tools.map((asset) => asset.id).toList(),
      'toolNames': tools.map((asset) => asset.name).toList(),
      'equipmentAssetIds': equipment.map((asset) => asset.id).toList(),
      'equipmentNames': equipment.map((asset) => asset.name).toList(),
      'crewAssetIds': crew.map((asset) => asset.id).toList(),
      'crewNames': crew.map((asset) => asset.name).toList(),
      'assetQuantities': quantities,
      'notes': notes,
      'createdAt': Timestamp.now(),
    });

    // 3. Update Asset Status (Wrapped in try/catch to ignore permission issues on shared fleet)
    try {
      if (vehicle != null) {
        await _firestore.collection('assets').doc(vehicle.id).update({
          'jobsCompleted': FieldValue.increment(1),
          'status': 'inUse',
          'currentTaskId': taskId,
          'currentTaskLabel': taskLabel,
        });
      }

      for (final asset in [...tools, ...equipment]) {
        final qty = quantities[asset.id] ?? 1;
        final doc = await _firestore.collection('assets').doc(asset.id).get();
        if (doc.exists) {
          final currentQty = (doc['quantity'] as num?)?.toInt() ?? 0;
          await _firestore.collection('assets').doc(asset.id).update({
            'jobsCompleted': FieldValue.increment(1),
            'quantity': currentQty - qty >= 0 ? currentQty - qty : 0,
            if (currentQty - qty <= 0) 'status': 'inUse',
          });
        }
      }

      for (final asset in crew) {
        await _firestore.collection('assets').doc(asset.id).update({
          'jobsCompleted': FieldValue.increment(1),
          'status': 'inUse',
          'currentTaskId': taskId,
          'currentTaskLabel': taskLabel,
        });
      }
    } catch (e) {
      // Log error but don't fail the whole operation
      // This happens if the provider doesn't have write access to global asset inventory
      Logger.warn('Could not update global asset status', e);
    }
  }

  Future<void> updateMaintenance(String assetId, DateTime date) async {
    await _firestore.collection('assets').doc(assetId).update({
      'lastMaintenance': Timestamp.fromDate(date),
      'status': AssetStatus.active.name,
    });
  }
}
