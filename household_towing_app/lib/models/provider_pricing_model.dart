import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderPricing {
  final String providerId;
  final double cleaningMultiplier; // Default 1.0
  final double towingMultiplier; // Default 1.0
  final bool useNightDifferential; // Enable/disable night differential
  final String? notes; // e.g., "Premium service", "Express service"
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProviderPricing({
    required this.providerId,
    this.cleaningMultiplier = 1.0,
    this.towingMultiplier = 1.0,
    this.useNightDifferential = true,
    this.notes,
    required this.createdAt,
    this.updatedAt,
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
    };
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
  }) {
    return ProviderPricing(
      providerId: providerId ?? this.providerId,
      cleaningMultiplier: cleaningMultiplier ?? this.cleaningMultiplier,
      towingMultiplier: towingMultiplier ?? this.towingMultiplier,
      useNightDifferential: useNightDifferential ?? this.useNightDifferential,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProviderPricing(provider: $providerId, cleaning: ${cleaningMultiplier}x, towing: ${towingMultiplier}x)';
  }
}
