import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class LocationPickerResult {
  final LatLng position;
  final String address;

  LocationPickerResult({required this.position, required this.address});
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? serviceType;

  const LocationPickerScreen({super.key, this.initialLocation, this.serviceType});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = 'Loading address...';
  bool _isDragging = false;
  bool _isResolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation ?? const LatLng(10.6692, 122.9510); // Bacolod default
    if (widget.initialLocation != null) {
      _resolveAddress(_currentCenter);
    } else {
      _getUserLocation();
    }
  }

  CameraConstraint get _cameraConstraint {
    if (widget.serviceType == 'Towing') {
      // Negros Island roughly
      return CameraConstraint.contain(
        bounds: LatLngBounds(
          const LatLng(9.0, 122.3),
          const LatLng(11.1, 123.6),
        ),
      );
    } else if (widget.serviceType == 'Household') {
      // Negros Occidental roughly
      return CameraConstraint.contain(
        bounds: LatLngBounds(
          const LatLng(9.4, 122.3),
          const LatLng(11.1, 123.5),
        ),
      );
    }
    return const CameraConstraint.unconstrained();
  }

  Future<void> _getUserLocation() async {
    final pos = await LocationService().getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _currentCenter = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentCenter, 15);
      _resolveAddress(_currentCenter);
    }
  }

  Future<void> _resolveAddress(LatLng pos) async {
    setState(() => _isResolvingAddress = true);
    final address = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() {
        _currentAddress = address;
        _isResolvingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15,
              cameraConstraint: _cameraConstraint,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentCenter = position.center;
                    _isDragging = true;
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  setState(() => _isDragging = false);
                  _resolveAddress(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.dualserve.household_towing_app',
              ),
            ],
          ),
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Adjust for pin tail
              child: Icon(
                Icons.location_pin,
                color: AppTheme.towingOrange,
                size: 50,
                shadows: [
                  Shadow(
                    color: AppTheme.textSlateDark.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
            ),
          ),
          // Bottom Info Box
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textSlateDark.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Location',
                    style: TextStyle(
                      color: AppTheme.textSlateMedium,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_isResolvingAddress || _isDragging)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.location_on, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isDragging ? 'Moving map...' : _currentAddress,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isDragging || _isResolvingAddress) ? null : () {
                        Navigator.pop(context, LocationPickerResult(
                          position: _currentCenter,
                          address: _currentAddress,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
