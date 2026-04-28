/// Centralized pricing configuration for the household towing app
class PricingConfig {
  // Base prices by service type (in Philippine Pesos)
  static const Map<String, double> basePrices = {
    'Cleaning': 500.0,
    'Towing': 1500.0,
  };

  // Cost per kilometer surcharge
  static const double costPerKm = 15.0;

  // Cancellation fee (applied if cancelled after 5 minutes of acceptance)
  static const double cancellationFee = 100.0;
  static const int cancellationGracePeriodMinutes = 5;

  // Minimum distance threshold (no surcharge within this radius, in km)
  static const double minDistanceKm = 0.5;

  // Night differential rate multiplier (11 PM - 5 AM)
  static const double nightDifferentialMultiplier = 1.3; // 30% increase

  // Night time hours (24-hour format)
  static const int nightStartHour = 23; // 11 PM
  static const int nightEndHour = 5; // 5 AM

  /// Check if a given hour is within night time
  static bool isNightTime(DateTime dateTime) {
    final hour = dateTime.hour;
    // Night time: 11 PM (23) to 5 AM (5)
    return hour >= nightStartHour || hour < nightEndHour;
  }

  /// Get base price for a service type
  /// Returns 0.0 if service type not found
  static double getBasePrice(String serviceType) {
    return basePrices[serviceType] ?? 0.0;
  }

  /// Calculate distance surcharge
  /// Distance less than minDistanceKm is free
  static double calculateDistanceSurcharge(double distanceKm) {
    if (distanceKm <= minDistanceKm) {
      return 0.0;
    }
    return (distanceKm - minDistanceKm) * costPerKm;
  }

  /// Calculate night differential surcharge
  /// Applied as percentage of base price
  static double calculateNightDifferential(
    double basePrice,
    DateTime serviceTime,
  ) {
    if (isNightTime(serviceTime)) {
      return basePrice * (nightDifferentialMultiplier - 1.0);
    }
    return 0.0;
  }

  /// Calculate total cost for a service with all factors
  /// totalCost = (basePrice * providerMultiplier)
  ///           + nightDifferential
  ///           + distanceSurcharge
  static double calculateTotalCost(
    String serviceType,
    double distanceKm,
    DateTime serviceTime, {
    double providerMultiplier = 1.0,
  }) {
    final basePrice = getBasePrice(serviceType);
    final adjustedBasePrice = basePrice * providerMultiplier;
    final nightDifferential = calculateNightDifferential(
      adjustedBasePrice,
      serviceTime,
    );
    final surcharge = calculateDistanceSurcharge(distanceKm);
    return adjustedBasePrice + nightDifferential + surcharge;
  }

  /// Format price as Philippine Peso string
  static String formatPrice(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Get night differential percentage
  static int getNightDifferentialPercentage() {
    return ((nightDifferentialMultiplier - 1.0) * 100).toInt();
  }
}
