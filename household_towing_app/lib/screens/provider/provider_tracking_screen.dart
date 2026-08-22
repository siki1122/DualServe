import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/map_utils.dart';
import '../../services/logging_service.dart';
import '../../services/task_service.dart';
import 'dart:async';

class ProviderTrackingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const ProviderTrackingScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<ProviderTrackingScreen> createState() => _ProviderTrackingScreenState();
}

class _ProviderTrackingScreenState extends State<ProviderTrackingScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  LatLng? _customerLocation;
  double _distance = 0;
  int _eta = 0;
  bool _isLoading = true;

  // Stream subscription for location updates
  StreamSubscription<Position>? _locationSubscription;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  void _initializeTracking() async {
    await _getCurrentLocation();
    await _setupCustomerLocation();
    _startLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(
          context,
          Exception('Location permission denied or services disabled'),
        );
      }
    } catch (e) {
      Logger.error('Failed to get current location', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _setupCustomerLocation() async {
    try {
      final customerAddress = widget.bookingData['address'] ?? '';
      final locations = await LocationService.getCoordinatesFromAddress(
        customerAddress,
      );

      if (locations.isNotEmpty && mounted) {
        final customerLat = locations[0].latitude;
        final customerLng = locations[0].longitude;

        setState(() {
          _customerLocation = LatLng(customerLat, customerLng);
        });
        
        _updateDistanceAndETA();
      }
    } catch (e) {
      Logger.error('Failed to setup customer location', e);
    }
  }

  void _updateDistanceAndETA() {
    if (_currentPosition == null || _customerLocation == null) return;

    final distanceKm = LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _customerLocation!.latitude,
      _customerLocation!.longitude,
    );

    final eta = LocationService.calculateETA(distanceKm);

    setState(() {
      _distance = distanceKm;
      _eta = eta;
    });
  }

  void _startLocationUpdates() {
    try {
      _locationSubscription = LocationService()
          .getLocationStream(intervalInSeconds: 5, distanceFilter: 10)
          .listen(
            (Position position) async {
              if (!mounted) return;

              final now = DateTime.now();

              // Smart Throttling Logic:
              int throttleSeconds = (position.speed < 1.0) ? 20 : 5;

              if (_lastUpdate != null &&
                  now.difference(_lastUpdate!).inSeconds < throttleSeconds) {
                return;
              }

              _lastUpdate = now;

              setState(() {
                _currentPosition = position;
              });

              try {
                // Update location in Firestore
                final Map<String, dynamic> locationData = {
                  'providerLocation': {
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                    'speed': position.speed,
                    'timestamp': FieldValue.serverTimestamp(),
                  },
                };

                // Update Booking
                await FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(widget.bookingId)
                    .update(locationData);

                // Update Task document if it exists
                final taskQuery = await FirebaseFirestore.instance
                    .collection('tasks')
                    .where('bookingId', isEqualTo: widget.bookingId)
                    .limit(1)
                    .get();
                
                if (taskQuery.docs.isNotEmpty) {
                  await taskQuery.docs.first.reference.update(locationData);
                }

                _updateDistanceAndETA();

                // Check for arrival
                if (_customerLocation != null) {
                  final isArrived = LocationService.isWithinRadius(
                    position.latitude,
                    position.longitude,
                    _customerLocation!.latitude,
                    _customerLocation!.longitude,
                    100, // 100 meters radius
                  );

                  if (isArrived) {
                    _showArrivalDialog();
                  }
                }
              } catch (e) {
                Logger.error('Failed to update location', e);
              }
            },
            onError: (e) {
              Logger.error('Location stream error', e);
            },
          );
    } catch (e) {
      Logger.error('Failed to start location updates', e);
    }
  }

  void _showArrivalDialog() {
    if (!mounted) return;
    // Basic dialog to avoid multiple triggers
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Arrived at Location'),
        content: const Text('You have arrived at the customer location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    if (!mounted) return;
    
    String reason = 'Breakdown';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Emergency Abort', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you need to abort this job? This will cancel the task and notify the customer.'),
              const SizedBox(height: 16),
              const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: reason,
                isExpanded: true,
                items: ['Breakdown', 'Accident', 'Severe Traffic', 'Customer Unresponsive', 'Other'].map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => reason = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _executeEmergencyAbort(reason);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Abort Job'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeEmergencyAbort(String reason) async {
    setState(() => _isLoading = true);
    try {
      final taskQuery = await FirebaseFirestore.instance
          .collection('tasks')
          .where('bookingId', isEqualTo: widget.bookingId)
          .limit(1)
          .get();
      
      if (taskQuery.docs.isNotEmpty) {
        final taskId = taskQuery.docs.first.id;
        await TaskService().cancelTask(taskId, bookingId: widget.bookingId, reason: reason);
        
        if (mounted) {
          ErrorHandler.showSuccess(context, 'Job safely aborted. Assets released.');
          Navigator.pop(context); // Go back to tasks screen
        }
      } else {
        throw Exception('Active task not found');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, e, title: 'Failed to abort job');
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('En Route to Customer'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
          ? _buildLocationRequired()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.dualserve.app',
                    ),
                    if (_customerLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              _customerLocation!,
                            ],
                            color: AppTheme.primaryBlue,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Provider Marker
                        Marker(
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppTheme.primaryBlue,
                            size: 32,
                          ),
                        ),
                        // Customer Marker
                        if (_customerLocation != null)
                          Marker(
                            point: _customerLocation!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildInfoCard(isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildLocationRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Location Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Enable location services to track your route', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _getCurrentLocation,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Distance', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('${_distance.toStringAsFixed(1)} km', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ETA', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('$_eta min', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (_customerLocation != null) {
                  MapUtils.openMapWithCoords(
                    _customerLocation!.latitude,
                    _customerLocation!.longitude,
                  );
                }
              },
              child: const Text('Open in Navigation', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _showCancelDialog,
            icon: const Icon(Icons.warning_rounded, color: Colors.red),
            label: const Text('Emergency Abort', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}
