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
import '../../widgets/compass_overlay.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class CustomerTrackingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const CustomerTrackingScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  
  double _distance = 0;
  int _eta = 0;
  LatLng? _customerLocation;
  LatLng? _providerLocation;
  List<LatLng> _routePoints = [];
  List<List<LatLng>> _alternativeRoutes = [];
  
  late AnimationController _pulseController;
  
  double _bearing = 0;
  StreamSubscription? _locationSubscription;
  bool _isFirstLoad = true;
  bool _isStale = false;
  DateTime? _lastProviderUpdate;
  Timer? _staleCheckTimer;

  double _taskProgress = 0.0;
  
  String? _assignedDriverId;
  String? _assignedDriverName;
  StreamSubscription? _taskSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initializeMap();
    _startStaleCheck();
    _listenToTaskProgress();
  }

  void _startStaleCheck() {
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_lastProviderUpdate != null && mounted) {
        final isStaleNow = DateTime.now().difference(_lastProviderUpdate!).inMinutes >= 2;
        if (_isStale != isStaleNow) {
          setState(() => _isStale = isStaleNow);
        }
      }
    });
  }

  void _listenToTaskProgress() {
    _taskSubscription = FirebaseFirestore.instance
        .collection('tasks')
        .where('bookingId', isEqualTo: widget.bookingId)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final taskData = snapshot.docs.first.data() as Map<String, dynamic>;
            final double progress = (taskData['progress'] as num?)?.toDouble() ?? 0.0;
            if (mounted) {
              final driverId = taskData['assignedDriverId'] as String?;
              final driverName = taskData['driverName'] as String?;
              
              setState(() {
                _taskProgress = progress;
                _assignedDriverId = driverId;
                _assignedDriverName = driverName;
              });
              
              if (driverId != null && driverId.isNotEmpty) {
                _listenToProviderLocation(driverId);
              }
            }
          }
        });
  }



  void _initializeMap() async {
    final customerAddress = widget.bookingData['address'] ?? '';
    if (customerAddress.isNotEmpty) {
      final locations = await LocationService.getCoordinatesFromAddress(
        customerAddress,
      );
      if (locations.isNotEmpty) {
        LatLng? shopLocation;
        
        // Fetch Provider's shop coordinates if no driver is assigned
        if (_assignedDriverId == null || _assignedDriverId!.isEmpty) {
          final providerId = widget.bookingData['assignedProviderId'];
          if (providerId != null && providerId.isNotEmpty) {
            try {
              final doc = await FirebaseFirestore.instance.collection('providers').doc(providerId).get();
              if (doc.exists) {
                final lat = (doc.data()?['latitude'] as num?)?.toDouble();
                final lng = (doc.data()?['longitude'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  shopLocation = LatLng(lat, lng);
                }
              }
            } catch (e) {
              // Ignore error, fallback to offset
            }
          }
        }

        if (mounted) {
          setState(() {
          _customerLocation = LatLng(
            locations[0].latitude,
            locations[0].longitude,
          );
          
          // Trigger fallback provider location if we don't have one yet (for testing)
          if (_providerLocation == null) {
            _providerLocation = shopLocation ?? LatLng(
              _customerLocation!.latitude - 0.02, 
              _customerLocation!.longitude - 0.02
            );
          }
        });
        
        // Refetch route now that we have real coordinates
        if (_providerLocation != null) {
           _fetchRealRoute();
           _fitBounds();
        }
      }
    }
  }
}

  void _listenToProviderLocation(String driverId) {
    _locationSubscription?.cancel();
    _locationSubscription = FirebaseFirestore.instance
        .collection('driver_locations')
        .doc(driverId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newLat = (data['latitude'] as num).toDouble();
            final newLng = (data['longitude'] as num).toDouble();
            final newProviderLocation = LatLng(newLat, newLng);

            if (_providerLocation != null) {
              _bearing = LocationService.calculateBearing(
                _providerLocation!.latitude,
                _providerLocation!.longitude,
                newLat,
                newLng,
              );
            }

            bool isStale = false;
            if (data['updatedAt'] != null) {
              final updateTime = (data['updatedAt'] as Timestamp).toDate();
              _lastProviderUpdate = updateTime;
              isStale = DateTime.now().difference(updateTime).inMinutes >= 2;
            }

            setState(() {
              _providerLocation = newProviderLocation;
              _isStale = isStale;
            });
          } else {
             // SIMULATION FALLBACK: If driver location does not exist in DB, 
             // generate a dummy location slightly offset from the customer.
             if (_customerLocation != null && _providerLocation == null) {
               setState(() {
                 // Offset by approx 2-3 km
                 _providerLocation = LatLng(
                   _customerLocation!.latitude - 0.02, 
                   _customerLocation!.longitude - 0.02
                 );
                 _isStale = false;
               });
             }
          }

          // Fetch REAL road route
          if (_customerLocation != null && _providerLocation != null) {
            _fetchRealRoute();
            if (_isFirstLoad) {
              _fitBounds();
              _isFirstLoad = false;
            }
          }
        });
  }

  Future<void> _fetchRealRoute() async {
    if (_customerLocation == null || _providerLocation == null) return;
    
    final routeData = await _routingService.getRoute(_providerLocation!, _customerLocation!);
    
    if (routeData != null && mounted) {
      setState(() {
        _routePoints = routeData['points'];
        _distance = (routeData['distance'] as num).toDouble() / 1000.0; // km
        _eta = (routeData['duration'] as num).toInt() ~/ 60; // minutes
        
        // Handle alternative routes if any
        final allRoutes = routeData['allRoutes'] as List;
        if (allRoutes.length > 1) {
          _alternativeRoutes = [];
          for (int i = 1; i < allRoutes.length; i++) {
             final List<dynamic> coords = allRoutes[i]['geometry']['coordinates'];
             _alternativeRoutes.add(coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList());
          }
        }
      });
    } else if (mounted) {
      // Fallback to straight line if OSRM fails
      final distMeters = LocationService.calculateDistance(
        _providerLocation!.latitude, _providerLocation!.longitude,
        _customerLocation!.latitude, _customerLocation!.longitude
      );
      setState(() {
        _routePoints = [_providerLocation!, _customerLocation!];
        _distance = distMeters / 1000.0;
        _eta = (distMeters / 1000.0 / 40.0 * 60.0).toInt(); // Assume 40 km/h average
      });
    }
  }

  void _fitBounds() {
    if (_customerLocation == null || _providerLocation == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([_customerLocation!, _providerLocation!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(120),
        ),
      );
    } catch (e) {
      // Ignore if bounds are invalid during initial load
    }
  }

  void _showCompletionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Service Completed!'),
        content: const Text('Your provider has successfully completed the requested service.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Finish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _staleCheckTimer?.cancel();
    _locationSubscription?.cancel();
    _taskSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textSlateDark,
      ),
      body: _providerLocation == null && _customerLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _providerLocation ?? _customerLocation ?? const LatLng(0, 0),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.dualserve.app',
                    ),
                    
                    if (_customerLocation != null && _providerLocation != null && _routePoints.isNotEmpty)
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
                    
                    if (_providerLocation != null)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final radius = _pulseController.value * 300;
                          return CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _providerLocation!,
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
                        // Customer Marker (Destination)
                        if (_customerLocation != null)
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
                        // Truck Marker (Driver)
                        if (_providerLocation != null)
                          Marker(
                            point: _providerLocation!,
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
                ),
                
                // Stale warning bar
                if (_isStale)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: AppTheme.textSlateDark.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Provider GPS signal is lost or delayed. Location may be outdated.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Compass Overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + (_isStale ? 70 : 10),
                  right: 16,
                  child: CompassOverlay(
                    onTap: () {
                      _fitBounds();
                    },
                  ),
                ),

                // Bottom Info Card
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomCard(context),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final displayName = (_assignedDriverName != null && _assignedDriverName!.isNotEmpty) 
        ? _assignedDriverName! 
        : (widget.bookingData['providerName'] ?? 'Service Provider');
        
    final displayId = (_assignedDriverId != null && _assignedDriverId!.isNotEmpty) 
        ? _assignedDriverId! 
        : (widget.bookingData['assignedProviderId'] ?? '');
    
    final vehiclePlate = widget.bookingData['vehiclePlate'] ?? 'On the way';
    final vehicleModel = widget.bookingData['vehicleModel'] ?? 'Tow Truck';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textSlateDark.withValues(alpha: isDark ? 0.3 : 0.1), 
            blurRadius: 20, 
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle lookalike
          Container(
            width: 40, 
            height: 4, 
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : AppTheme.textSlateLight.withValues(alpha: 0.5), 
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // ETA & Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arriving in $_eta min', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                  const SizedBox(height: 4),
                  Text('${_distance.toStringAsFixed(1)} km away • $vehicleModel', style: const TextStyle(fontSize: 14, color: AppTheme.textSlateMedium)),
                ],
              ),
              if (_taskProgress > 0)
                 Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: Text('${(_taskProgress * 100).toInt()}%', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                 ),
            ],
          ),
          
          if (_taskProgress > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _taskProgress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white10 : AppTheme.textSlateLight.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white10 : AppTheme.textSlateLight.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 20),
          
          // Driver Profile Row
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.person, size: 30, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('4.9', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700])),
                        const SizedBox(width: 8),
                        Text('• Top Rated', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white24 : AppTheme.textSlateLight)
                ),
                child: Text(vehiclePlate, style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: isDark ? Colors.white : AppTheme.textSlateDark)),
              )
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final providerId = widget.bookingData['assignedProviderId'];
                    if (providerId != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                        bookingId: widget.bookingId,
                        receiverId: providerId,
                        receiverName: widget.bookingData['providerName'] ?? 'Provider',
                      )));
                    }
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Provider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : AppTheme.surfaceLight,
                    foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_assignedDriverId != null && _assignedDriverId!.isNotEmpty) ? () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                      bookingId: widget.bookingId,
                      receiverId: _assignedDriverId!,
                      receiverName: _assignedDriverName ?? 'Driver',
                    )));
                  } : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No driver assigned yet.'), backgroundColor: AppTheme.towingOrange)
                    );
                  },
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
