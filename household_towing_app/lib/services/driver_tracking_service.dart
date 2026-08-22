import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class DriverTrackingService {
  static final DriverTrackingService _instance = DriverTrackingService._internal();
  factory DriverTrackingService() => _instance;
  DriverTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  String? _currentDriverId;

  Future<void> startTracking(String driverId, String taskId) async {
    // Check permission
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) return; // Cannot track

    _currentDriverId = driverId;

    // Start stream
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.getLocationStream().listen((Position position) {
      _updateLocation(driverId, taskId, position);
    });
  }

  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentDriverId = null;
  }

  Future<void> _updateLocation(String driverId, String taskId, Position position) async {
    try {
      await _firestore.collection('driver_locations').doc(driverId).set({
        'driverId': driverId,
        'taskId': taskId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Failed to update driver location: $e');
    }
  }

  Stream<DocumentSnapshot> getDriverLocationStream(String driverId) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots();
  }
}
