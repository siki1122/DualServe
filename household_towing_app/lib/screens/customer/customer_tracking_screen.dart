import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  double _distance = 0;
  int _eta = 0;
  LatLng? _customerLocation;
  LatLng? _providerLocation;
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
      final locations = await LocationService.getCoordinatesFromAddress(customerAddress);
      if (locations.isNotEmpty) {
        setState(() {
          _customerLocation = LatLng(locations[0].latitude, locations[0].longitude);
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
          final newProviderLocation = LatLng(newLat, newLng);
          
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
        }
      }
    });
  }

  void _updateMap() {
    if (_providerLocation == null) return;
    final Set<Marker> newMarkers = {};
    newMarkers.add(Marker(
      markerId: const MarkerId('provider'),
      position: _providerLocation!,
      rotation: _bearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    if (_customerLocation != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    final Set<Circle> newCircles = {};
    newCircles.add(Circle(
      circleId: const CircleId('pulse'),
      center: _providerLocation!,
      radius: _pulseRadius,
      fillColor: Colors.blue.withOpacity(0.15 * (1 - (_pulseRadius / 300))),
      strokeWidth: 0,
    ));

    setState(() {
      _markers = newMarkers;
      _circles = newCircles;
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
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_providerLocation!, _customerLocation!],
            color: Colors.blue,
            width: 5,
          ),
        };
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_customerLocation != null && _providerLocation != null) {
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(_calculateBounds(), 100));
    }
  }

  LatLngBounds _calculateBounds() {
    double minLat = _customerLocation!.latitude < _providerLocation!.latitude ? _customerLocation!.latitude : _providerLocation!.latitude;
    double maxLat = _customerLocation!.latitude > _providerLocation!.latitude ? _customerLocation!.latitude : _providerLocation!.latitude;
    double minLng = _customerLocation!.longitude < _providerLocation!.longitude ? _customerLocation!.longitude : _providerLocation!.longitude;
    double maxLng = _customerLocation!.longitude > _providerLocation!.longitude ? _customerLocation!.longitude : _providerLocation!.longitude;
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    mapController?.dispose();
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
                GoogleMap(
                  cloudMapId: 'd80a93f8c224576ddf5af450',
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _providerLocation!, zoom: 15),
                  markers: _markers,
                  polylines: _polylines,
                  circles: _circles,
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
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
                                const Text('Distance', style: TextStyle(color: Colors.grey)),
                                Text('${_distance.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('ETA', style: TextStyle(color: Colors.grey)),
                                Text('$_eta min', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.call),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                                    bookingId: widget.bookingId,
                                    receiverId: widget.bookingData['assignedProviderId'] ?? '',
                                    receiverName: 'Service Provider',
                                  )));
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
