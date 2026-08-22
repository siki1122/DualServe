import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/driver_tracking_service.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';

class LiveTrackingMap extends StatefulWidget {
  final Task task;
  final Map<String, dynamic>? providerLocationData;

  const LiveTrackingMap({super.key, required this.task, this.providerLocationData});

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  final DriverTrackingService _trackingService = DriverTrackingService();
  LatLng? _currentLocation;
  late LatLng _destinationLocation;
  bool _hasFittedBounds = false;

  @override
  void initState() {
    super.initState();
    _destinationLocation = LatLng(widget.task.latitude, widget.task.longitude);
    _updateProviderLocation();
  }

  @override
  void didUpdateWidget(LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.assignedDriverId == null && widget.providerLocationData != null) {
      _updateProviderLocation();
    }
  }

  void _updateProviderLocation() {
    if (widget.providerLocationData != null) {
      final lat = widget.providerLocationData!['latitude'];
      final lng = widget.providerLocationData!['longitude'];
      if (lat != null && lng != null) {
        setState(() {
          _currentLocation = LatLng(lat, lng);
        });
        if (!_hasFittedBounds) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitBounds();
            _hasFittedBounds = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.assignedDriverId == null && widget.providerLocationData == null) {
      return const Center(child: Text('Waiting for location updates...'));
    }

    if (widget.task.assignedDriverId != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: _trackingService.getDriverLocationStream(widget.task.assignedDriverId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            _currentLocation = LatLng(data['latitude'], data['longitude']);
            
            if (!_hasFittedBounds) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fitBounds();
                _hasFittedBounds = true;
              });
            }
          }
          return _buildMap();
        },
      );
    } else {
      return _buildMap();
    }
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _destinationLocation,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.dualserve.app',
          ),
          MarkerLayer(
            markers: [
              // Destination Marker
              Marker(
                point: _destinationLocation,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
              // Current Location Marker
              if (_currentLocation != null)
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.task.serviceType.toLowerCase().contains('tow') 
                          ? Icons.local_shipping 
                          : Icons.person_pin_circle, 
                      color: Colors.white, 
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          if (_currentLocation != null)
            PolylineLayer(
              polylines: [
                Polyline<Object>(
                  points: [_currentLocation!, _destinationLocation],
                  strokeWidth: 4.0,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_currentLocation == null || !mounted) return;
    
    try {
      final bounds = LatLngBounds.fromPoints([_currentLocation!, _destinationLocation]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50.0),
        ),
      );
    } catch (e) {
      // Ignore if map is not ready
    }
  }
}
