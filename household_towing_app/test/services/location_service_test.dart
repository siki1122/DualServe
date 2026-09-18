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
    late Stopwatch stopwatch;

    setUp(() {
      // start timing the test
      stopwatch = Stopwatch()..start();
    });

    tearDown(() {
      stopwatch.stop();
      // log how long the test took to run
      print('Duration: ${stopwatch.elapsedMilliseconds} ms');
    });

    test('should correctly calculate distance between SF and LA in km', () {
      // coords for SF and LA
      const sfLat = 37.7749;
      const sfLon = -122.4194;
      const laLat = 34.0522;
      const laLon = -118.2437;
      
      final distance = LocationService.calculateDistance(sfLat, sfLon, laLat, laLon);
      
      // the actual distance is roughly 559 km
      expect(distance, greaterThan(500.0));
      expect(distance, lessThan(600.0));
    });

    test('should return true when locations are very close to each other', () {
      final isWithin = LocationService.isWithinRadius(
        37.7749, -122.4194, // point A
        37.7750, -122.4195, // slightly off from point A
        1000.0, // search radius in meters
      );
      
      expect(isWithin, isTrue);
    });

    test('should return false when location is way outside the search radius', () {
      final isWithin = LocationService.isWithinRadius(
        37.7749, -122.4194, // SF
        34.0522, -118.2437, // LA
        1000.0, // small radius
      );
      
      expect(isWithin, isFalse);
    });

    test('calculates correct ETA given distance and speed', () {
      // if distance is 40km and we're going 40km/h, it takes 1 hour (60 mins)
      final eta = LocationService.calculateETA(40.0, speedKmh: 40.0);
      expect(eta, equals(60));
    });
  });
}
