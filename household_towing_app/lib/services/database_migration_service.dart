import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/logging_service.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> runFullMigration() async {
    try {
      Logger.info('Starting Full Database Migration...');
      
      await _migrateBookings();
      await _migrateTasks();
      await _migrateProviders();
      
      Logger.info('Full Database Migration Completed Successfully!');
    } catch (e, stack) {
      Logger.error('Migration failed', e, stack);
      throw Exception('Migration failed: $e');
    }
  }

  Future<void> _migrateBookings() async {
    final snapshot = await _firestore.collection('bookings').get();
    final batch = _firestore.batch();
    int updatedCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      bool needsUpdate = false;
      final updates = <String, dynamic>{};

      if (data['serviceType'] == null) {
        updates['serviceType'] = 'Towing';
        needsUpdate = true;
      }
      if (data['assignedPersonnelIds'] == null) {
        updates['assignedPersonnelIds'] = [];
        needsUpdate = true;
      }
      if (data['assignedPersonnelNames'] == null) {
        updates['assignedPersonnelNames'] = [];
        needsUpdate = true;
      }
      if (data['assignedAssets'] == null) {
        updates['assignedAssets'] = {};
        needsUpdate = true;
      }
      if (data['isReviewed'] == null) {
        updates['isReviewed'] = false;
        needsUpdate = true;
      }

      if (needsUpdate) {
        batch.update(doc.reference, updates);
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      Logger.info('Migrated $updatedCount bookings.');
    }
  }

  Future<void> _migrateTasks() async {
    final snapshot = await _firestore.collection('tasks').get();
    final batch = _firestore.batch();
    int updatedCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      bool needsUpdate = false;
      final updates = <String, dynamic>{};

      if (data['serviceType'] == null) {
        updates['serviceType'] = 'Towing';
        needsUpdate = true;
      }
      if (data['assignedPersonnelIds'] == null) {
        updates['assignedPersonnelIds'] = [];
        needsUpdate = true;
      }
      if (data['assignedPersonnelNames'] == null) {
        updates['assignedPersonnelNames'] = [];
        needsUpdate = true;
      }
      if (data['assignedAssets'] == null) {
        updates['assignedAssets'] = {};
        needsUpdate = true;
      }

      if (needsUpdate) {
        batch.update(doc.reference, updates);
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      Logger.info('Migrated $updatedCount tasks.');
    }
  }

  Future<void> _migrateProviders() async {
    final snapshot = await _firestore.collection('providers').get();
    final batch = _firestore.batch();
    int updatedCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      bool needsUpdate = false;
      final updates = <String, dynamic>{};

      if (data['serviceTypes'] == null) {
        updates['serviceTypes'] = ['Towing'];
        needsUpdate = true;
      }
      if (data['offeredServices'] == null) {
        updates['offeredServices'] = {};
        needsUpdate = true;
      }
      if (data['serviceAreas'] == null) {
        updates['serviceAreas'] = {};
        needsUpdate = true;
      }
      if (data['serviceType'] == null) {
        updates['serviceType'] = 'Towing';
        needsUpdate = true;
      }

      if (needsUpdate) {
        batch.update(doc.reference, updates);
        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      Logger.info('Migrated $updatedCount providers.');
    }
  }
}
