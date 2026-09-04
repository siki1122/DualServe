import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'logging_service.dart';

class RoutingService {
  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';
  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches a route between two points using OSRM
  /// Returns a list of LatLng points for the polyline, distance in meters, and duration in seconds
  Future<Map<String, dynamic>?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=true';
      
      final response = await _client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final routes = data['routes'];
          final primaryRoute = routes[0];
          
          // Parse coordinates
          final List<dynamic> coords = primaryRoute['geometry']['coordinates'];
          final List<LatLng> points = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          
          return {
            'points': points,
            'distance': primaryRoute['distance'], // in meters
            'duration': primaryRoute['duration'], // in seconds
            'allRoutes': routes, // in case we want to show alternatives
          };
        }
      }
      Logger.warn('OSRM routing failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      Logger.error('Error fetching route from OSRM', e);
      return null;
    }
  }

  /// Decode polyline if OSRM is set to 'polyline' instead of 'geojson'
  static List<LatLng> decodePolyline(String str, {int precision = 5}) {
    List<LatLng> points = [];
    int index = 0, len = str.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
