import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderPricing {
  final String providerId;
  final double cleaningMultiplier; // Default 1.0
  final double towingMultiplier; // Default 1.0
  final bool useNightDifferential; // Enable/disable night differential
  final String? notes; // e.g., "Premium service", "Express service"
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  final int nightSurchargeStartHour; // Default 23 (11 PM)
  final int nightSurchargeEndHour; // Default 5 (5 AM)
  final double nightSurchargePercent; // Default 30.0 (30%)

  ProviderPricing({
    required this.providerId,
    this.cleaningMultiplier = 1.0,
    this.towingMultiplier = 1.0,
    this.useNightDifferential = true,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.nightSurchargeStartHour = 23,
    this.nightSurchargeEndHour = 5,
    this.nightSurchargePercent = 30.0,
  });

  /// Create from Firestore document
  factory ProviderPricing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderPricing(
      providerId: data['providerId'] ?? '',
      cleaningMultiplier:
          (data['cleaningMultiplier'] as num?)?.toDouble() ?? 1.0,
      towingMultiplier: (data['towingMultiplier'] as num?)?.toDouble() ?? 1.0,
      useNightDifferential: data['useNightDifferential'] ?? true,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      nightSurchargeStartHour: data['nightSurchargeStartHour'] as int? ?? 23,
      nightSurchargeEndHour: data['nightSurchargeEndHour'] as int? ?? 5,
      nightSurchargePercent: (data['nightSurchargePercent'] as num?)?.toDouble() ?? 30.0,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'cleaningMultiplier': cleaningMultiplier,
      'towingMultiplier': towingMultiplier,
      'useNightDifferential': useNightDifferential,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'nightSurchargeStartHour': nightSurchargeStartHour,
      'nightSurchargeEndHour': nightSurchargeEndHour,
      'nightSurchargePercent': nightSurchargePercent,
    };
  }

  /// Check if a given hour is within custom night time
  bool isNightTime(DateTime dateTime) {
    if (!useNightDifferential) return false;
    final hour = dateTime.hour;
    if (nightSurchargeStartHour > nightSurchargeEndHour) {
      // Overnight (e.g. 23 to 5)
      return hour >= nightSurchargeStartHour || hour < nightSurchargeEndHour;
    } else {
      // Daytime span (e.g. 8 to 17)
      return hour >= nightSurchargeStartHour && hour < nightSurchargeEndHour;
    }
  }

  /// Calculate custom night differential surcharge
  /// Applied as percentage of base price
  double calculateNightDifferential(double basePrice, DateTime serviceTime) {
    if (isNightTime(serviceTime)) {
      return basePrice * (nightSurchargePercent / 100.0);
    }
    return 0.0;
  }

  /// Get multiplier for service type
  double getMultiplier(String serviceType) {
    switch (serviceType) {
      case 'Household':
      case 'Cleaning':
        return cleaningMultiplier;
      case 'Towing':
        return towingMultiplier;
      default:
        return 1.0;
    }
  }

  /// Create a copy with modified fields
  ProviderPricing copyWith({
    String? providerId,
    double? cleaningMultiplier,
    double? towingMultiplier,
    bool? useNightDifferential,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? nightSurchargeStartHour,
    int? nightSurchargeEndHour,
    double? nightSurchargePercent,
  }) {
    return ProviderPricing(
      providerId: providerId ?? this.providerId,
      cleaningMultiplier: cleaningMultiplier ?? this.cleaningMultiplier,
      towingMultiplier: towingMultiplier ?? this.towingMultiplier,
      useNightDifferential: useNightDifferential ?? this.useNightDifferential,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nightSurchargeStartHour: nightSurchargeStartHour ?? this.nightSurchargeStartHour,
      nightSurchargeEndHour: nightSurchargeEndHour ?? this.nightSurchargeEndHour,
      nightSurchargePercent: nightSurchargePercent ?? this.nightSurchargePercent,
    );
  }

  @override
  String toString() {
    return 'ProviderPricing(provider: $providerId, cleaning: ${cleaningMultiplier}x, towing: ${towingMultiplier}x)';
  }
}
