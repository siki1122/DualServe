import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/provider_pricing_model.dart';

void main() {
  group('ProviderPricing Model Tests (White Box Testing)', () {
    late DateTime createdAt;

    setUp(() {
      createdAt = DateTime(2026, 5, 10, 10, 0);
    });

    // ============================================================
    // CONSTRUCTOR
    // ============================================================

    test('should create ProviderPricing with default values', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.providerId, 'prov_123');
      expect(pricing.cleaningMultiplier, 1.0);
      expect(pricing.towingMultiplier, 1.0);
      expect(pricing.useNightDifferential, true);
      expect(pricing.notes, isNull);
      expect(pricing.updatedAt, isNull);
      expect(pricing.nightSurchargeStartHour, 23);
      expect(pricing.nightSurchargeEndHour, 5);
      expect(pricing.nightSurchargePercent, 30.0);
    });

    // ============================================================
    // getMultiplier()
    // ============================================================

    test('getMultiplier should return cleaning multiplier for Household', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.5,
        towingMultiplier: 2.0,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.getMultiplier('Household'), 1.5);
    });

    test('getMultiplier should return cleaning multiplier for Cleaning', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.5,
        towingMultiplier: 2.0,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.getMultiplier('Cleaning'), 1.5);
    });

    test('getMultiplier should return towing multiplier for Towing', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.5,
        towingMultiplier: 2.0,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.getMultiplier('Towing'), 2.0);
    });

    test('getMultiplier should return 1.0 for unknown service type', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.5,
        towingMultiplier: 2.0,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.getMultiplier('UnknownService'), 1.0);
    });

    // ============================================================
    // isNightTime()
    // ============================================================

    test(
      'isNightTime should return false when night differential is disabled',
      () {
        final pricing = ProviderPricing(
          providerId: 'prov_123',
          useNightDifferential: false,
          createdAt: createdAt,
          updatedAt: null,
        );

        expect(pricing.isNightTime(DateTime(2026, 5, 10, 23)), false);
      },
    );

    test(
      'isNightTime should return true after start hour for overnight span',
      () {
        final pricing = ProviderPricing(
          providerId: 'prov_123',
          nightSurchargeStartHour: 23,
          nightSurchargeEndHour: 5,
          useNightDifferential: true,
          createdAt: createdAt,
          updatedAt: null,
        );

        expect(pricing.isNightTime(DateTime(2026, 5, 10, 23)), true);
      },
    );

    test(
      'isNightTime should return true before end hour for overnight span',
      () {
        final pricing = ProviderPricing(
          providerId: 'prov_123',
          nightSurchargeStartHour: 23,
          nightSurchargeEndHour: 5,
          useNightDifferential: true,
          createdAt: createdAt,
          updatedAt: null,
        );

        expect(pricing.isNightTime(DateTime(2026, 5, 10, 2)), true);
      },
    );

    test(
      'isNightTime should return false during daytime for overnight span',
      () {
        final pricing = ProviderPricing(
          providerId: 'prov_123',
          nightSurchargeStartHour: 23,
          nightSurchargeEndHour: 5,
          useNightDifferential: true,
          createdAt: createdAt,
          updatedAt: null,
        );

        expect(pricing.isNightTime(DateTime(2026, 5, 10, 8)), false);
      },
    );

    test('isNightTime should handle daytime span correctly', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        nightSurchargeStartHour: 8,
        nightSurchargeEndHour: 17,
        useNightDifferential: true,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.isNightTime(DateTime(2026, 5, 10, 10)), true);
    });

    test('isNightTime should return false outside daytime span', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        nightSurchargeStartHour: 8,
        nightSurchargeEndHour: 17,
        useNightDifferential: true,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(pricing.isNightTime(DateTime(2026, 5, 10, 18)), false);
    });

    // ============================================================
    // calculateNightDifferential()
    // ============================================================

    test(
      'calculateNightDifferential should apply custom surcharge percent',
      () {
        final pricing = ProviderPricing(
          providerId: 'prov_123',
          nightSurchargeStartHour: 20,
          nightSurchargeEndHour: 6,
          nightSurchargePercent: 40.0,
          useNightDifferential: true,
          createdAt: createdAt,
          updatedAt: null,
        );

        final diff = pricing.calculateNightDifferential(
          1000.0,
          DateTime(2026, 5, 10, 21),
        );

        expect(diff, 400.0);
      },
    );

    test('calculateNightDifferential should return zero during daytime', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        nightSurchargeStartHour: 20,
        nightSurchargeEndHour: 6,
        nightSurchargePercent: 40.0,
        useNightDifferential: true,
        createdAt: createdAt,
        updatedAt: null,
      );

      final diff = pricing.calculateNightDifferential(
        1000.0,
        DateTime(2026, 5, 10, 12),
      );

      expect(diff, 0.0);
    });

    // ============================================================
    // copyWith()
    // ============================================================

    test('copyWith should update specified fields', () {
      final original = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.2,
        towingMultiplier: 1.5,
        useNightDifferential: true,
        notes: 'Original',
        createdAt: createdAt,
        updatedAt: null,
        nightSurchargeStartHour: 23,
        nightSurchargeEndHour: 5,
        nightSurchargePercent: 30.0,
      );

      final updated = original.copyWith(
        providerId: 'prov_456',
        cleaningMultiplier: 2.0,
        towingMultiplier: 2.5,
        useNightDifferential: false,
        notes: 'Updated',
        nightSurchargeStartHour: 20,
        nightSurchargeEndHour: 6,
        nightSurchargePercent: 40.0,
      );

      expect(updated.providerId, 'prov_456');
      expect(updated.cleaningMultiplier, 2.0);
      expect(updated.towingMultiplier, 2.5);
      expect(updated.useNightDifferential, false);
      expect(updated.notes, 'Updated');
      expect(updated.nightSurchargeStartHour, 20);
      expect(updated.nightSurchargeEndHour, 6);
      expect(updated.nightSurchargePercent, 40.0);
    });

    test(
      'copyWith should preserve original fields when no changes are supplied',
      () {
        final original = ProviderPricing(
          providerId: 'prov_123',
          cleaningMultiplier: 1.2,
          towingMultiplier: 1.5,
          useNightDifferential: true,
          notes: 'Original',
          createdAt: createdAt,
          updatedAt: null,
          nightSurchargeStartHour: 23,
          nightSurchargeEndHour: 5,
          nightSurchargePercent: 30.0,
        );

        final copied = original.copyWith();

        expect(copied.providerId, original.providerId);
        expect(copied.cleaningMultiplier, original.cleaningMultiplier);
        expect(copied.towingMultiplier, original.towingMultiplier);
        expect(copied.useNightDifferential, original.useNightDifferential);
        expect(copied.notes, original.notes);
        expect(copied.createdAt, original.createdAt);
        expect(copied.updatedAt, original.updatedAt);
        expect(
          copied.nightSurchargeStartHour,
          original.nightSurchargeStartHour,
        );
        expect(copied.nightSurchargeEndHour, original.nightSurchargeEndHour);
        expect(copied.nightSurchargePercent, original.nightSurchargePercent);
      },
    );

    // ============================================================
    // toFirestore()
    // ============================================================

    test('toFirestore should convert pricing to Firestore data', () {
      final created = DateTime(2026, 5, 10, 10, 0);
      final updated = DateTime(2026, 5, 11, 12, 0);

      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.5,
        towingMultiplier: 2.0,
        useNightDifferential: true,
        notes: 'Premium service',
        createdAt: created,
        updatedAt: updated,
        nightSurchargeStartHour: 20,
        nightSurchargeEndHour: 6,
        nightSurchargePercent: 40.0,
      );

      final data = pricing.toFirestore();

      expect(data['providerId'], 'prov_123');
      expect(data['cleaningMultiplier'], 1.5);
      expect(data['towingMultiplier'], 2.0);
      expect(data['useNightDifferential'], true);
      expect(data['notes'], 'Premium service');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['nightSurchargeStartHour'], 20);
      expect(data['nightSurchargeEndHour'], 6);
      expect(data['nightSurchargePercent'], 40.0);
    });

    test('toFirestore should store null when updatedAt is null', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        createdAt: createdAt,
        updatedAt: null,
      );

      final data = pricing.toFirestore();

      expect(data['updatedAt'], isNull);
    });

    // ============================================================
    // toString()
    // ============================================================

    test('toString should return formatted string representation', () {
      final pricing = ProviderPricing(
        providerId: 'prov_123',
        cleaningMultiplier: 1.2,
        towingMultiplier: 1.5,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(
        pricing.toString(),
        'ProviderPricing(provider: prov_123, cleaning: 1.2x, towing: 1.5x)',
      );
    });
  });
}
