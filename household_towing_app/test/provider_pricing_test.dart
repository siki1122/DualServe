import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/models/provider_pricing_model.dart';

void main() {
  group('ProviderPricing Model Tests (White Box Testing)', () {
    test('getMultiplier should return correct multiplier for Towing', () {
      // Arrange
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        towingMultiplier: 1.5,
        cleaningMultiplier: 1.2,
        createdAt: DateTime.now(),
      );

      // Act
      final multiplier = pricing.getMultiplier('Towing');

      // Assert
      expect(multiplier, 1.5);
    });

    test('getMultiplier should return correct multiplier for Cleaning', () {
      // Arrange
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        towingMultiplier: 1.5,
        cleaningMultiplier: 1.2,
        createdAt: DateTime.now(),
      );

      // Act
      final multiplier = pricing.getMultiplier('Cleaning');

      // Assert
      expect(multiplier, 1.2);
    });

    test('getMultiplier should return 1.0 for unknown service type', () {
      // Arrange
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        towingMultiplier: 1.5,
        cleaningMultiplier: 1.2,
        createdAt: DateTime.now(),
      );

      // Act
      final multiplier = pricing.getMultiplier('UnknownService');

      // Assert
      expect(multiplier, 1.0);
    });
    
    test('copyWith should only update specified fields', () {
      // Arrange
      final original = ProviderPricing(
        providerId: 'prov_123',
        towingMultiplier: 1.0,
        createdAt: DateTime.now(),
      );

      // Act
      final updated = original.copyWith(towingMultiplier: 2.0);

      // Assert
      expect(updated.towingMultiplier, 2.0);
      expect(updated.providerId, 'prov_123'); // Should remain unchanged
    });

    test('isNightTime should work with overnight span (e.g. 23 to 5)', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        nightSurchargeStartHour: 23,
        nightSurchargeEndHour: 5,
        useNightDifferential: true,
        createdAt: DateTime.now(),
      );

      // 11:30 PM should be night time
      expect(pricing.isNightTime(DateTime(2026, 5, 10, 23, 30)), isTrue);
      // 2:00 AM should be night time
      expect(pricing.isNightTime(DateTime(2026, 5, 10, 2, 0)), isTrue);
      // 8:00 AM should NOT be night time
      expect(pricing.isNightTime(DateTime(2026, 5, 10, 8, 0)), isFalse);
    });

    test('calculateNightDifferential should apply custom surcharge percent', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        nightSurchargeStartHour: 20, // 8 PM
        nightSurchargeEndHour: 6,   // 6 AM
        nightSurchargePercent: 40.0, // 40%
        useNightDifferential: true,
        createdAt: DateTime.now(),
      );

      final diff = pricing.calculateNightDifferential(1000.0, DateTime(2026, 5, 10, 21, 0)); // 9 PM
      expect(diff, 400.0); // 40% of 1000.0
    });
  });
}
