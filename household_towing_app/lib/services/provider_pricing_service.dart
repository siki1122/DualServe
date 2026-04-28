import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/models/provider_pricing_model.dart';

class ProviderPricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _pricingCollection = 'provider_pricing';

  /// Get or create provider pricing settings
  Future<ProviderPricing> getProviderPricing(String providerId) async {
    try {
      final doc = await _firestore
          .collection(_pricingCollection)
          .doc(providerId)
          .get();

      if (doc.exists) {
        return ProviderPricing.fromFirestore(doc);
      } else {
        // Create default pricing if not exists
        final defaultPricing = ProviderPricing(
          providerId: providerId,
          cleaningMultiplier: 1.0,
          towingMultiplier: 1.0,
          useNightDifferential: true,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection(_pricingCollection)
            .doc(providerId)
            .set(defaultPricing.toFirestore());

        return defaultPricing;
      }
    } catch (e) {
      throw Exception('Error fetching provider pricing: $e');
    }
  }

  /// Update provider pricing settings
  Future<void> updateProviderPricing({
    required String providerId,
    double? cleaningMultiplier,
    double? towingMultiplier,
    bool? useNightDifferential,
    String? notes,
  }) async {
    try {
      final currentPricing = await getProviderPricing(providerId);

      final updatedPricing = currentPricing.copyWith(
        cleaningMultiplier: cleaningMultiplier,
        towingMultiplier: towingMultiplier,
        useNightDifferential: useNightDifferential,
        notes: notes,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_pricingCollection)
          .doc(providerId)
          .update(updatedPricing.toFirestore());
    } catch (e) {
      throw Exception('Error updating provider pricing: $e');
    }
  }

  /// Get provider pricing as stream
  Stream<ProviderPricing> getProviderPricingStream(String providerId) {
    return _firestore
        .collection(_pricingCollection)
        .doc(providerId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return ProviderPricing.fromFirestore(doc);
          } else {
            // Return default pricing
            return ProviderPricing(
              providerId: providerId,
              cleaningMultiplier: 1.0,
              towingMultiplier: 1.0,
              useNightDifferential: true,
              createdAt: DateTime.now(),
            );
          }
        })
        .handleError((e) {
          return ProviderPricing(
            providerId: providerId,
            createdAt: DateTime.now(),
          );
        });
  }

  /// Reset to default pricing
  Future<void> resetToDefaultPricing(String providerId) async {
    try {
      final defaultPricing = ProviderPricing(
        providerId: providerId,
        cleaningMultiplier: 1.0,
        towingMultiplier: 1.0,
        useNightDifferential: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_pricingCollection)
          .doc(providerId)
          .set(defaultPricing.toFirestore());
    } catch (e) {
      throw Exception('Error resetting provider pricing: $e');
    }
  }
}
