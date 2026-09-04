import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/screens/customer/booking_screen.dart';
import 'package:household_towing_app/screens/customer/household_service_selection_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../utils/app_theme.dart';
import 'booking_screen.dart';
import 'provider_profile_screen.dart';
import '../../widgets/compass_overlay.dart';

class TowingMapScreen extends StatefulWidget {
  final String serviceType;
  const TowingMapScreen({super.key, this.serviceType = 'Towing'});

  @override
  State<TowingMapScreen> createState() => _TowingMapScreenState();
}

class _TowingMapScreenState extends State<TowingMapScreen> {
  Color get _themeColor => widget.serviceType == 'Towing' ? AppTheme.towingOrange : AppTheme.householdBlue;
  IconData get _themeIcon => widget.serviceType == 'Towing' ? Icons.local_shipping : Icons.cleaning_services;

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Position? _currentPosition;
  bool _isLoading = true;
  Map<String, dynamic>? _selectedProvider;
  double? _selectedDistance;
  String? _noProvidersMessage;
  List<Map<String, dynamic>> _availableProvidersData = [];
  List<LatLng> _routePoints = [];
  final RoutingService _routingService = RoutingService();

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
        
        // Center map on user - wrap in try-catch to avoid issues if map is not ready
        try {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            14.0,
          );
        } catch (e) {
          // Map might not be ready yet
        }
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
          .where('serviceType', isEqualTo: widget.serviceType)
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
          _availableProvidersData = [];
          _noProvidersMessage =
              'No ${widget.serviceType.toLowerCase()} providers available in your area right now. Please try again later.';
        });
      } else {
        setState(() {
          _availableProvidersData = providers;
          _noProvidersMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _noProvidersMessage = 'Error: ${e.toString()}';
      });
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
      _routePoints = []; // clear old route
    });

    _fetchRoute(provider);
    _showProviderDetails();
  }

  Future<void> _fetchRoute(Map<String, dynamic> provider) async {
    if (_currentPosition == null) return;
    
    final customerLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final providerLatLng = LatLng(provider['latitude'], provider['longitude']);
    
    final routeData = await _routingService.getRoute(customerLatLng, providerLatLng);
    if (routeData != null && mounted) {
      setState(() {
        _routePoints = routeData['points'];
      });
      
      try {
        final bounds = LatLngBounds.fromPoints([customerLatLng, providerLatLng, ..._routePoints]);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(80.0),
          ),
        );
      } catch (e) {
        // Map controller might not be ready
      }
    }
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
                            (_selectedProvider!['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
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
                    color: _themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedDistance?.toStringAsFixed(1)} km away',
                    style: TextStyle(
                      color: _themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.serviceType.toLowerCase() == 'household' || widget.serviceType.toLowerCase() == 'cleaning') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HouseholdServiceSelectionScreen(
                          preSelectedProviderId: _selectedProvider!['id'],
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(
                          serviceType: widget.serviceType,
                          preSelectedProviderId: _selectedProvider!['id'],
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColor,
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(10.6667, 122.9500),
                    initialZoom: 14.0,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(9.0, 122.3),
                        const LatLng(11.1, 123.6),
                      ),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.dualserve.app',
                    ),
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.my_location,
                              color: AppTheme.primaryBlue,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: <Polyline<Object>>[
                          Polyline<Object>(
                            points: _routePoints,
                            color: _themeColor,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _availableProvidersData.map((p) {
                        return Marker(
                          point: LatLng(p['latitude'], p['longitude']),
                          width: 80,
                          height: 80,
                          child: GestureDetector(
                            onTap: () => _onProviderSelected(p),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _themeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.textSlateDark.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _themeIcon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                            color: AppTheme.textSlateDark.withValues(alpha: 0.1),
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
                            'To find the nearest towing services, we need access to your location.',
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
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Retry Access'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_currentPosition != null && _noProvidersMessage != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textSlateDark.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: _themeColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _noProvidersMessage!,
                              style: const TextStyle(color: AppTheme.textSlateMedium),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_availableProvidersData.isNotEmpty && _currentPosition != null)
                  _buildDraggableProviderList(),
                
                // Compass Overlay
                Positioned(
                  top: 90,
                  right: 16,
                  child: CompassOverlay(
                    onTap: () {
                      if (_currentPosition != null) {
                        _mapController.move(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          14.0,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              14.0,
            );
          }
        },
        child: const Icon(Icons.my_location, color: AppTheme.primaryBlue),
      ),
    );
  }

  Widget _buildDraggableProviderList() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textSlateDark.withValues(alpha: 0.12),
                blurRadius: 25,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (_sheetController.isAttached) {
                    if (_sheetController.size > 0.20) {
                      _sheetController.animateTo(0.18, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else {
                      _sheetController.animateTo(0.35, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 10),
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.textSlateLight,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.serviceType} providers found',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSlateDark,
                                ),
                              ),
                              Text(
                                '${_availableProvidersData.length} available nearby',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSlateMedium,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.expand_more, color: AppTheme.textSlateMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _availableProvidersData.length,
                  itemBuilder: (context, index) {
                    final p = _availableProvidersData[index];
                    final distance = LocationService.calculateDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      p['latitude'],
                      p['longitude'],
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textSlateDark.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _mapController.move(
                              LatLng(p['latitude'], p['longitude']),
                              15.0,
                            );
                            _onProviderSelected(p);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    _themeIcon,
                                    color: _themeColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textSlateDark,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${distance.toStringAsFixed(1)} km',
                                              style: const TextStyle(
                                                color: AppTheme.primaryBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            ((p['jobsCompleted'] as num?)?.toInt() ?? 0) == 0 
                                                ? '0.0' 
                                                : ((p['rating'] as num?)?.toStringAsFixed(1) ?? '0.0'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: AppTheme.textSlateDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProviderProfileScreen(
                                          providerId: p['id'],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
