import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Shop Location'),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _pickedLocation),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            cloudMapId: 'd80a93f8c224576ddf5af450',
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation ?? const LatLng(10.6667, 122.9500),
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) {
              setState(() {
                _pickedLocation = location;
              });
            },
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                    ),
                  },
          ),
          if (_pickedLocation == null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tap on the map to set your shop location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: _pickedLocation == null
                  ? null
                  : () => Navigator.pop(context, _pickedLocation),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
