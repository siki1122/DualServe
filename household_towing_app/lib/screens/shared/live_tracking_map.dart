import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/routing_service.dart';
import '../../models/task_model.dart';
import '../../utils/app_theme.dart';

class LiveTrackingMap extends StatefulWidget {
  final Task task;
  final Map<String, dynamic>? providerLocationData;

  const LiveTrackingMap({super.key, required this.task, this.providerLocationData});

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DriverTrackingService _trackingService = DriverTrackingService();
  final RoutingService _routingService = RoutingService();
  
  late LatLng _destinationLocation;
  bool _hasFittedBounds = false;
  
  // Route state
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  // Animation state
  LatLng? _currentLocation; // Target location from backend
  LatLng? _animatedLocation; // Location currently drawn
  double _currentBearing = 0.0;
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  LatLng? _animationStartLocation;

  @override
  void initState() {
    super.initState();
    _destinationLocation = LatLng(widget.task.latitude, widget.task.longitude);
    
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1000)
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.linear);
    _animation.addListener(() {
      if (_animationStartLocation != null && _currentLocation != null) {
        setState(() {
          _animatedLocation = _interpolate(_animationStartLocation!, _currentLocation!, _animation.value);
        });
      }
    });

    _updateProviderLocation();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        _handleNewLocation(LatLng(lat, lng));
      }
    }
  }

  void _handleNewLocation(LatLng newLoc) {
    if (_currentLocation == null) {
      // First update
      _currentLocation = newLoc;
      _animatedLocation = newLoc;
      _fetchRoute();
      if (!_hasFittedBounds) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitBounds();
          _hasFittedBounds = true;
        });
      }
    } else if (newLoc.latitude != _currentLocation!.latitude || newLoc.longitude != _currentLocation!.longitude) {
      // Subsequent updates
      _animationStartLocation = _animatedLocation ?? _currentLocation;
      _currentBearing = _calculateBearing(_animationStartLocation!, newLoc);
      _currentLocation = newLoc;
      
      _animationController.forward(from: 0.0);
    }
  }
  
  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;
    setState(() => _isLoadingRoute = true);
    final routeData = await _routingService.getRoute(_currentLocation!, _destinationLocation);
    if (mounted && routeData != null) {
      setState(() {
        _routePoints = routeData['points'];
        _isLoadingRoute = false;
      });
      _fitBounds();
    } else {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  LatLng _interpolate(LatLng start, LatLng end, double fraction) {
    final lat = start.latitude + (end.latitude - start.latitude) * fraction;
    final lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (math.pi / 180.0);
    final startLng = start.longitude * (math.pi / 180.0);
    final endLat = end.latitude * (math.pi / 180.0);
    final endLng = end.longitude * (math.pi / 180.0);

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    var bearing = math.atan2(y, x);
    bearing = (bearing * 180.0 / math.pi + 360.0) % 360.0;
    return bearing * (math.pi / 180.0); 
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
            final newLoc = LatLng(data['latitude'], data['longitude']);
            
            // Handle location update post-frame to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
               _handleNewLocation(newLoc);
            });
          }
          return _buildMap();
        },
      );
    } else {
      return _buildMap();
    }
  }

  Widget _buildMap() {
    final fallbackPolyline = _animatedLocation != null 
        ? [_animatedLocation!, _destinationLocation] 
        : <LatLng>[];
        
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _destinationLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.dualserve.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline<Object>(
                    points: _routePoints.isNotEmpty ? _routePoints : fallbackPolyline,
                    strokeWidth: 4.0,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                  ),
                ],
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
                  if (_animatedLocation != null)
                    Marker(
                      point: _animatedLocation!,
                      width: 40,
                      height: 40,
                      child: Transform.rotate(
                        angle: _currentBearing,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.textSlateDark.withValues(alpha: 0.2),
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
                    ),
                ],
              ),
            ],
          ),
          if (_isLoadingRoute)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ]
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Routing...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_animatedLocation == null && _routePoints.isEmpty || !mounted) return;
    
    try {
      final points = _routePoints.isNotEmpty ? _routePoints : [_animatedLocation!, _destinationLocation];
      final bounds = LatLngBounds.fromPoints(points);
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
