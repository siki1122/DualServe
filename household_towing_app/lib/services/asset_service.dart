import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset_model.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AssetModel>> getAssets() {
    return _firestore.collection('assets').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AssetModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addAsset(AssetModel asset) async {
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

  Future<void> releaseAsset(String assetId) async {
    await _firestore.collection('assets').doc(assetId).update({
      'assignedTo': null,
      'providerName': null,
      'status': AssetStatus.active.name,
    });
  }

  Future<void> updateMaintenance(String assetId, DateTime date) async {
    await _firestore.collection('assets').doc(assetId).update({
      'lastMaintenance': Timestamp.fromDate(date),
      'status': AssetStatus.active.name,
    });
  }
}
