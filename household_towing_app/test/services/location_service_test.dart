import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:household_towing_app/services/location_service.dart';

class MockHttpClient extends Mock implements http.Client {
  @override
  Future<http.Response> get(Uri? url, {Map<String, String>? headers}) async {
    return super.noSuchMethod(
      Invocation.method(#get, [url], {#headers: headers}),
      returnValue: Future<http.Response>.value(http.Response('', 200)),
    );
  }
}

void main() {
  group('LocationService Tests', () {
    test('calculateDistance returns distance in km', () {
      // Example coordinates: San Francisco to Los Angeles (roughly 559 km)
      final distance = LocationService.calculateDistance(
        37.7749, -122.4194, // SF
        34.0522, -118.2437, // LA
      );
      
      expect(distance, greaterThan(500.0));
      expect(distance, lessThan(600.0));
    });

    test('isWithinRadius returns true if within radius', () {
      final isWithin = LocationService.isWithinRadius(
        37.7749, -122.4194,
        37.7750, -122.4195, // Very close
        1000.0, // 1km radius
      );
      
      expect(isWithin, true);
    });

    test('isWithinRadius returns false if outside radius', () {
      final isWithin = LocationService.isWithinRadius(
        37.7749, -122.4194,
        34.0522, -118.2437, // SF to LA
        1000.0, // 1km radius
      );
      
      expect(isWithin, false);
    });

    test('calculateETA returns reasonable minutes', () {
      final eta = LocationService.calculateETA(40.0, speedKmh: 40.0);
      expect(eta, 60); // 40km at 40km/h should be 60 mins
    });
  });
}
