import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:household_towing_app/services/routing_service.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

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
  group('RoutingService Tests', () {
    late RoutingService routingService;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      routingService = RoutingService(client: mockHttpClient);
    });

    test('decodePolyline decodes correctly', () {
      final polyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final decoded = RoutingService.decodePolyline(polyline);
      
      expect(decoded.length, greaterThan(0));
      expect(decoded.first.latitude, closeTo(38.5, 0.1));
    });

    test('getRoute handles successful OSRM response', () async {
      final mockResponse = {
        'code': 'Ok',
        'routes': [
          {
            'distance': 15000.0,
            'duration': 1200.0,
            'geometry': {
              'coordinates': [
                [-122.4194, 37.7749],
                [-122.4195, 37.7750]
              ]
            }
          }
        ]
      };

      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => http.Response(json.encode(mockResponse), 200)
      );

      final route = await routingService.getRoute(
        LatLng(37.7749, -122.4194),
        LatLng(37.7750, -122.4195),
      );

      expect(route, isNotNull);
      expect(route!['distance'], 15000.0);
      expect(route['duration'], 1200.0);
      expect((route['points'] as List).length, 2);
    });

    test('getRoute handles failed response', () async {
      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => http.Response('Error', 500)
      );

      final route = await routingService.getRoute(
        LatLng(0, 0),
        LatLng(1, 1),
      );

      expect(route, isNull);
    });
  });
}
