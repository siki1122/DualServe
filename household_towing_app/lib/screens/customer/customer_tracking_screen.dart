import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/location_service.dart';
import '../chat/chat_screen.dart';

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

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  double _distance = 0;
  int _eta = 0;
  ll.LatLng? _customerLocation;
  ll.LatLng? _providerLocation;
  double _pulseRadius = 0;
  Timer? _pulseTimer;
  double _bearing = 0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startPulse();
  }

  void _startPulse() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _pulseRadius = (_pulseRadius + 5) % 300;
        });
        _updateMap();
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
        setState(() {
          _customerLocation = ll.LatLng(
            locations[0].latitude,
            locations[0].longitude,
          );
        });
      }
    }
    _listenToProviderLocation();
  }

  void _listenToProviderLocation() {
    FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final providerLocation = data['providerLocation'];
            if (providerLocation != null) {
              final newLat = (providerLocation['latitude'] as num).toDouble();
              final newLng = (providerLocation['longitude'] as num).toDouble();
              final newProviderLocation = ll.LatLng(newLat, newLng);

              if (_providerLocation != null) {
                _bearing = LocationService.calculateBearing(
                  _providerLocation!.latitude,
                  _providerLocation!.longitude,
                  newLat,
                  newLng,
                );
              }

              setState(() {
                _providerLocation = newProviderLocation;
                _updateMap();
              });

              // Initial fit bounds when both are available
              if (_customerLocation != null && _mapController != null) {
                _fitBounds();
              }
            }

            final status = data['status'];
            if (status == 'completed') {
              _showCompletionDialog();
            }
          }
        });
  }

  void _fitBounds() {
    if (_customerLocation == null || _providerLocation == null) return;

    final bounds = LatLngBounds.fromPoints([
      _customerLocation!,
      _providerLocation!,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
    );
  }

  void _showCompletionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Service Completed!'),
        content: const Text(
          'Your provider has successfully completed the requested service. Thank you for using DualServe!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Pop the dialog
              Navigator.pop(context);
              // Pop the tracking screen back to home
              Navigator.pop(context);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _updateMap() {
    if (_providerLocation == null) return;
    final List<Marker> newMarkers = [];

    // Provider Marker
    newMarkers.add(
      Marker(
        point: _providerLocation!,
        width: 40,
        height: 40,
        child: Transform.rotate(
          angle: _bearing * (3.14159 / 180),
          child: const Icon(Icons.navigation, color: Colors.blue, size: 30),
        ),
      ),
    );

    // Pulse Marker (Custom)
    newMarkers.add(
      Marker(
        point: _providerLocation!,
        width: _pulseRadius / 2,
        height: _pulseRadius / 2,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15 * (1 - (_pulseRadius / 300))),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    if (_customerLocation != null) {
      newMarkers.add(
        Marker(
          point: _customerLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });

    if (_customerLocation != null) {
      final distanceKm = LocationService.calculateDistance(
        _providerLocation!.latitude,
        _providerLocation!.longitude,
        _customerLocation!.latitude,
        _customerLocation!.longitude,
      );
      final eta = LocationService.calculateETA(distanceKm);
      setState(() {
        _distance = distanceKm;
        _eta = eta;
        _polylines = [
          Polyline(
            points: [_providerLocation!, _customerLocation!],
            color: Colors.blue,
            strokeWidth: 5,
          ),
        ];
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Provider')),
      body: _providerLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _providerLocation!,
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
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
                                const Text(
                                  'Distance',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '${_distance.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'ETA',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '$_eta min',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Provider phone number is unavailable',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.call),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        bookingId: widget.bookingId,
                                        receiverId:
                                            widget
                                                .bookingData['assignedProviderId'] ??
                                            '',
                                        receiverName: 'Service Provider',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.message),
                                label: const Text('Message'),
                              ),
                            ),
                          ],
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
