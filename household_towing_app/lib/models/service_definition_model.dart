enum ServicePricingType {
  flatRate,
  areaBased,
  subtypeBased,
}

class ServiceDefinition {
  final ServicePricingType type;

  // For flatRate
  final double? flatRatePrice;

  // For areaBased
  final double? minPrice;
  final double? pricePerSqm;
  final int? minSqm;
  final List<ServiceAddon>? addons;

  // For subtypeBased
  final List<ServiceSubtype>? subtypes;

  ServiceDefinition({
    required this.type,
    this.flatRatePrice,
    this.minPrice,
    this.pricePerSqm,
    this.minSqm,
    this.addons,
    this.subtypes,
  });

  factory ServiceDefinition.fromMap(Map<String, dynamic> map) {
    return ServiceDefinition(
      type: ServicePricingType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ServicePricingType.flatRate,
      ),
      flatRatePrice: (map['flatRatePrice'] as num?)?.toDouble(),
      minPrice: (map['minPrice'] as num?)?.toDouble(),
      pricePerSqm: (map['pricePerSqm'] as num?)?.toDouble(),
      minSqm: map['minSqm'] as int?,
      addons: map['addons'] != null
          ? List<ServiceAddon>.from(
              (map['addons'] as List).map((x) => ServiceAddon.fromMap(x)))
          : null,
      subtypes: map['subtypes'] != null
          ? List<ServiceSubtype>.from(
              (map['subtypes'] as List).map((x) => ServiceSubtype.fromMap(x)))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      if (flatRatePrice != null) 'flatRatePrice': flatRatePrice,
      if (minPrice != null) 'minPrice': minPrice,
      if (pricePerSqm != null) 'pricePerSqm': pricePerSqm,
      if (minSqm != null) 'minSqm': minSqm,
      if (addons != null) 'addons': addons!.map((x) => x.toMap()).toList(),
      if (subtypes != null) 'subtypes': subtypes!.map((x) => x.toMap()).toList(),
    };
  }
}

class ServiceAddon {
  final String name;
  final double price;
  final String pricingType; // 'fixed', 'per_sqm', 'per_hour'

  ServiceAddon({
    required this.name,
    required this.price,
    this.pricingType = 'fixed',
  });

  factory ServiceAddon.fromMap(Map<String, dynamic> map) {
    return ServiceAddon(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      pricingType: map['pricingType'] ?? 'fixed',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'pricingType': pricingType,
    };
  }
}

class ServiceSubtype {
  final String name;
  final double price;

  ServiceSubtype({
    required this.name,
    required this.price,
  });

  factory ServiceSubtype.fromMap(Map<String, dynamic> map) {
    return ServiceSubtype(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }
}
