import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'logging_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  http.Client? _client;

  factory LocationService({http.Client? client}) {
    if (client != null) {
      _instance._client = client;
    }
    return _instance;
  }

  LocationService._internal();

  /// Request location permissions and return current position
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      return null;
    }
  }

  /// Start continuous location updates
  Stream<Position> getLocationStream({
    int intervalInSeconds = 5,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
        timeLimit: Duration(seconds: intervalInSeconds),
      ),
    );
  }

  /// Calculate distance between two coordinates in km
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000; // Convert meters to kilometers
  }

  /// Calculate bearing between two coordinates
  static double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      if (kIsWeb) {
        return await _getAddressFromWeb(latitude, longitude);
      }

      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        return '${p.street}, ${p.locality}, ${p.administrativeArea}';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  static Future<String> _getAddressFromWeb(double lat, double lng) async {
    try {
      final client = _instance._client ?? http.Client();
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Accept-Language': 'en',
          'User-Agent':
              'HouseholdTowingApp/1.0', // Required by Nominatim policy
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'];
        }
      }

      // Fallback to a simplified coordinate string if geocoding fails
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
    } catch (e) {
      return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
    }
  }

  /// Get coordinates from address
  static Future<List<geocoding.Location>> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      if (kIsWeb) {
        return await _getCoordinatesFromWeb(address);
      }
      return await geocoding.locationFromAddress(address);
    } catch (e) {
      return [];
    }
  }

  static Future<List<geocoding.Location>> _getCoordinatesFromWeb(String address) async {
    try {
      final client = _instance._client ?? http.Client();
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1';

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Accept-Language': 'en',
          'User-Agent': 'HouseholdTowingApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          return [
            geocoding.Location(
              latitude: double.parse(first['lat']),
              longitude: double.parse(first['lon']),
              timestamp: DateTime.now(),
            )
          ];
        }
      }
      return [];
    } catch (e) {
      Logger.error('Web forward geocoding failed', e);
      return [];
    }
  }

  /// Calculate ETA in minutes based on distance and average speed
  static int calculateETA(double distanceInKm, {double speedKmh = 40}) {
    return ((distanceInKm / speedKmh) * 60).toInt();
  }

  /// Check if user is within a certain radius
  static bool isWithinRadius(
    double userLat,
    double userLng,
    double targetLat,
    double targetLng,
    double radiusInMeters,
  ) {
    final distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      targetLat,
      targetLng,
    );
    return distanceInMeters <= radiusInMeters;
  }
}
