import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../chat/chat_screen.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_model.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class DriverTrackingScreen extends StatefulWidget {
  final Task task;

  const DriverTrackingScreen({
    super.key,
    required this.task,
  });

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  
  double _distance = 0;
  int _eta = 0;
  LatLng? _customerLocation;
  LatLng? _driverLocation;
  List<LatLng> _routePoints = [];
  
  late AnimationController _pulseController;
  StreamSubscription? _locationSubscription;
  bool _isFirstLoad = true;
  String _customerName = 'Customer';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Initialize with task coordinates if available, but fetch from address if it's 0,0
    if (widget.task.latitude != 0.0 && widget.task.longitude != 0.0) {
      _customerLocation = LatLng(widget.task.latitude, widget.task.longitude);
    }
    
    _initializeMap();
    _fetchCustomerName();
    _listenToDriverLocation();
  }

  void _initializeMap() async {
    if (widget.task.location.isNotEmpty) {
      final locations = await LocationService.getCoordinatesFromAddress(widget.task.location);
      if (locations.isNotEmpty) {
        setState(() {
          _customerLocation = LatLng(locations[0].latitude, locations[0].longitude);
          
          // Trigger fallback driver location if we don't have one yet
          if (_driverLocation == null) {
            _driverLocation = LatLng(
              _customerLocation!.latitude - 0.02, 
              _customerLocation!.longitude - 0.02
            );
          }
        });
        
        // Refetch route now that we have real coordinates
        if (_driverLocation != null) {
           _fetchRealRoute();
           _fitBounds();
        }
      }
    }
  }

  Future<void> _fetchCustomerName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.task.customerId).get();
      if (doc.exists && mounted) {
        setState(() {
          _customerName = doc.data()?['name'] ?? 'Customer';
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _listenToDriverLocation() {
    if (widget.task.assignedDriverId == null) return;
    
    _locationSubscription = FirebaseFirestore.instance
        .collection('driver_locations')
        .doc(widget.task.assignedDriverId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newLat = (data['latitude'] as num).toDouble();
            final newLng = (data['longitude'] as num).toDouble();
            
            setState(() {
              _driverLocation = LatLng(newLat, newLng);
            });
          } else {
             // SIMULATION FALLBACK: If driver location does not exist in DB, 
             // generate a dummy location slightly offset from the customer.
             if (_customerLocation != null && _driverLocation == null) {
               setState(() {
                 // Offset by approx 2-3 km
                 _driverLocation = LatLng(
                   _customerLocation!.latitude - 0.02, 
                   _customerLocation!.longitude - 0.02
                 );
               });
             }
          }

          if (_driverLocation != null && _customerLocation != null) {
            _fetchRealRoute();
            if (_isFirstLoad) {
              _fitBounds();
              _isFirstLoad = false;
            }
          }
        });
  }

  Future<void> _fetchRealRoute() async {
    if (_customerLocation == null || _driverLocation == null) return;
    
    final routeData = await _routingService.getRoute(_driverLocation!, _customerLocation!);
    
    if (routeData != null && mounted) {
      setState(() {
        _routePoints = routeData['points'];
        _distance = (routeData['distance'] as num).toDouble() / 1000.0; // km
        _eta = (routeData['duration'] as num).toInt() ~/ 60; // minutes
      });
    } else if (mounted) {
      // Fallback to straight line if OSRM fails (e.g., testing with arbitrary coordinates)
      final distMeters = LocationService.calculateDistance(
        _driverLocation!.latitude, _driverLocation!.longitude,
        _customerLocation!.latitude, _customerLocation!.longitude
      );
      setState(() {
        _routePoints = [_driverLocation!, _customerLocation!];
        _distance = distMeters / 1000.0;
        _eta = (distMeters / 1000.0 / 40.0 * 60.0).toInt(); // Assume 40 km/h average
      });
    }
  }

  void _fitBounds() {
    if (_customerLocation == null || _driverLocation == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([_customerLocation!, _driverLocation!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(100),
        ),
      );
    } catch (e) {
      // Ignore if bounds are invalid during initial load
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Live Tracking', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSlateDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textSlateDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildBottomSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_customerLocation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverLocation ?? _customerLocation!,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.dualserve.app', // Match customer app
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Outer glow
              Polyline(
                points: _routePoints,
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              // Inner vibrant line
              Polyline(
                points: _routePoints,
                color: AppTheme.primaryBlue,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        
        if (_driverLocation != null)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final radius = _pulseController.value * 300;
              return CircleLayer(
                circles: [
                  CircleMarker(
                    point: _driverLocation!,
                    radius: radius,
                    useRadiusInMeter: true,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15 * (1 - _pulseController.value)),
                    borderStrokeWidth: 0,
                  ),
                ],
              );
            },
          ),

        MarkerLayer(
          markers: [
            // Customer Destination Marker
            Marker(
              point: _customerLocation!,
              width: 50,
              height: 50,
              child: const Column(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 40),
                ],
              ),
            ),
            // Driver (Truck) Marker
            if (_driverLocation != null)
              Marker(
                point: _driverLocation!,
                width: 80,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textSlateDark.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.local_shipping, color: AppTheme.primaryBlue, size: 30),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textSlateDark.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppTheme.textSlateLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Arriving in $_eta min',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textSlateDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_distance.toStringAsFixed(1)} km away • ${widget.task.serviceType}',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : AppTheme.textSlateMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    _customerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[400], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Customer',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : AppTheme.textSlateMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'En Route',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textSlateDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            bookingId: widget.task.bookingId ?? widget.task.id,
                            receiverId: widget.task.customerId,
                            receiverName: _customerName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 20),
                    label: const Text('Customer'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AppTheme.textSlateDark,
                      backgroundColor: AppTheme.surfaceLight,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final providerId = widget.task.assignedProviderId;
                      if (providerId == null) return;
                      
                      String providerName = 'Provider';
                      final doc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
                      if (doc.exists) {
                        providerName = doc.data()?['fullName'] ?? 'Provider';
                      }
                      
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              bookingId: widget.task.bookingId ?? widget.task.id,
                              receiverId: providerId,
                              receiverName: providerName,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.storefront_outlined, size: 20),
                    label: const Text('Provider'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppTheme.primaryBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
