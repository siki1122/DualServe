import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import 'booking_screen.dart';

class TowingMapScreen extends StatefulWidget {
  const TowingMapScreen({super.key});

  @override
  State<TowingMapScreen> createState() => _TowingMapScreenState();
}

class _TowingMapScreenState extends State<TowingMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  Map<String, dynamic>? _selectedProvider;
  double? _selectedDistance;
  String? _noProvidersMessage;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final position = await LocationService().getCurrentLocation();
    if (position != null) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        _fetchProviders();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('providers')
          .where('serviceType', isEqualTo: 'Towing')
          .where('status', isEqualTo: 'available')
          .get();

      final List<Map<String, dynamic>> providers = [];

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['latitude'] != null && data['longitude'] != null) {
            providers.add({
              'id': doc.id,
              ...data,
              'latitude': data['latitude'],
              'longitude': data['longitude'],
            });
          }
        }
      }

      if (providers.isEmpty) {
        setState(() {
          _noProvidersMessage =
              'No towing providers available in your area right now. Please try again later.';
        });
      } else {
        _createMarkers(providers);
      }
    } catch (e) {
      setState(() {
        _noProvidersMessage = 'Error loading providers. Please try again.';
      });
    }
  }

  void _createMarkers(List<Map<String, dynamic>> providers) {
    final markers = providers.map((p) {
      return Marker(
        markerId: MarkerId(p['id']),
        position: LatLng(p['latitude'], p['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: p['name'],
          snippet: 'Available for Towing',
        ),
        onTap: () => _onProviderSelected(p),
      );
    }).toSet();

    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  void _onProviderSelected(Map<String, dynamic> provider) {
    if (_currentPosition == null) return;

    final distance = LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      provider['latitude'],
      provider['longitude'],
    );

    setState(() {
      _selectedProvider = provider;
      _selectedDistance = distance;
    });

    _showProviderDetails();
  }

  void _showProviderDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProvider!['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedProvider!['rating']}',
                            style: const TextStyle(
                              color: AppTheme.textSlateMedium,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.towingOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedDistance?.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      color: AppTheme.towingOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone),
                    label: const Text('Contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSlateMedium,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(
                            serviceType: 'Towing',
                            preSelectedProviderId: _selectedProvider!['id'],
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.towingOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textSlateDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  cloudMapId: 'd80a93f8c224576ddf5af450',
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : const LatLng(10.6667, 122.9500), // Default to Bacolod
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                if (_currentPosition == null && !_isLoading)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Location Access Required',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'To find the nearest towing services, we need access to your location. Please enable location permissions in your settings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSlateMedium,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _initLocation();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry Access',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Geolocator.openAppSettings(),
                            child: const Text(
                              'Open App Settings',
                              style: TextStyle(
                                color: AppTheme.textSlateMedium,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          if (_currentPosition != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              ),
            );
          }
        },
        child: const Icon(Icons.my_location, color: AppTheme.primaryBlue),
      ),
    );
  }
}
