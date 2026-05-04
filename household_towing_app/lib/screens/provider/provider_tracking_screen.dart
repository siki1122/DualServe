import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/map_utils.dart';
import '../../services/logging_service.dart';
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
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  ll.LatLng? _customerLocation;
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
    await _setupMarkers();
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

  Future<void> _setupMarkers() async {
    if (_currentPosition == null) return;

    try {
      final customerAddress = widget.bookingData['address'] ?? '';
      final locations = await LocationService.getCoordinatesFromAddress(
        customerAddress,
      );

      if (locations.isNotEmpty && mounted) {
        final customerLat = locations[0].latitude;
        final customerLng = locations[0].longitude;

        // Calculate distance and ETA
        final distanceKm = LocationService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          customerLat,
          customerLng,
        );

        final eta = LocationService.calculateETA(distanceKm);

        setState(() {
          _customerLocation = ll.LatLng(customerLat, customerLng);
          _distance = distanceKm;
          _eta = eta;
          _markers = [
            Marker(
              point: ll.LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 30,
              ),
            ),
            Marker(
              point: ll.LatLng(customerLat, customerLng),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ];

          _polylines = [
            Polyline(
              points: [
                ll.LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                _customerLocation!,
              ],
              color: AppTheme.primaryBlue,
              strokeWidth: 5,
            ),
          ];
        });
      }
    } catch (e) {
      Logger.error('Failed to setup markers', e);
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
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
              // If moving slow (< 1m/s or ~3.6km/h), only update DB every 20 seconds
              // If moving fast, update every 5 seconds
              int throttleSeconds = (position.speed < 1.0) ? 20 : 5;

              if (_lastUpdate != null &&
                  now.difference(_lastUpdate!).inSeconds < throttleSeconds) {
                return; // Skip this update to save battery
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

                // If this has been converted to a task, update the task document too
                final taskQuery = await FirebaseFirestore.instance
                    .collection('tasks')
                    .where('bookingId', isEqualTo: widget.bookingId)
                    .limit(1)
                    .get();
                
                if (taskQuery.docs.isNotEmpty) {
                  await taskQuery.docs.first.reference.update(locationData);
                }

                // Refresh markers and polyline
                await _setupMarkers();

                // Check if arrived
                final customerAddress = widget.bookingData['address'] ?? '';
                final locations =
                    await LocationService.getCoordinatesFromAddress(
                      customerAddress,
                    );

                if (locations.isNotEmpty && mounted) {
                  final isArrived = LocationService.isWithinRadius(
                    position.latitude,
                    position.longitude,
                    locations[0].latitude,
                    locations[0].longitude,
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
              if (mounted) {
                ErrorHandler.showError(context, e);
              }
            },
          );
    } catch (e) {
      Logger.error('Failed to start location updates', e);
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  void _showArrivalDialog() {
    if (!mounted) return;

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

  void _animateToLocation() {
    if (_currentPosition == null) return;

    _mapController.move(
      ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      15,
    );
  }

  @override
  void dispose() {
    // Cancel location subscription to prevent memory leaks
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: AppTheme.textSlateMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSlateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable location services and grant permissions',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSlateMedium),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _getCurrentLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: ll.LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.household_towing_app',
                    ),
                    PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textSlateMedium.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSlateMedium,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distance.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ETA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSlateMedium,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_eta min',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final customerLocation = _customerLocation;
                              if (customerLocation == null) {
                                ErrorHandler.showInfo(
                                  context,
                                  'Customer location is still loading',
                                );
                                return;
                              }
                              MapUtils.openMapWithCoords(
                                customerLocation.latitude,
                                customerLocation.longitude,
                              );
                            },
                            child: const Text(
                              'Open in Navigation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
