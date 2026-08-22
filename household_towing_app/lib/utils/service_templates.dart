import '../models/service_definition_model.dart';

class ServiceTemplates {
  // Predefined structure for Deep Cleaning
  static ServiceDefinition get deepCleaningTemplate {
    return ServiceDefinition(
      type: ServicePricingType.areaBased,
      minPrice: 3500.0, // Default recommended, provider can override
      pricePerSqm: 60.0,
      minSqm: 58,
      addons: [
        ServiceAddon(name: 'Refrigerator Cleaning', price: 200.0, pricingType: 'fixed'),
        ServiceAddon(name: 'Rangehood Cleaning', price: 200.0, pricingType: 'per_sqm'), // Assuming sqm means size of rangehood or kitchen, let's treat it as fixed or unit based. Actually let's just use fixed for now or define per unit.
        ServiceAddon(name: 'Cabinet Organizing / Clothes Folding', price: 200.0, pricingType: 'per_hour'),
      ],
    );
  }

  // Predefined structure for Aircon Cleaning
  static ServiceDefinition get airconCleaningTemplate {
    return ServiceDefinition(
      type: ServicePricingType.subtypeBased,
      subtypes: [
        ServiceSubtype(name: 'Window type (non-inverter)', price: 700.0),
        ServiceSubtype(name: 'Window type (inverter)', price: 700.0),
        ServiceSubtype(name: 'Split type', price: 1800.0),
      ],
    );
  }

  // Fallback for flat rate services
  static ServiceDefinition flatRateTemplate(double price) {
    return ServiceDefinition(
      type: ServicePricingType.flatRate,
      flatRatePrice: price,
    );
  }

  // Map of service names to their default templates
  static final Map<String, ServiceDefinition> defaultTemplates = {
    'Deep Cleaning': deepCleaningTemplate,
    'Aircon Cleaning': airconCleaningTemplate,
    // Add other complex services here...
  };

  /// Helper to get the structured definition for a service.
  /// If the provider has customized the pricing (stored as a Map), it uses that.
  /// If the provider just has a double (old format), it creates a flatRate definition.
  /// If the provider hasn't set it up but we have a default template, we return the template.
  static ServiceDefinition getDefinition(String serviceName, dynamic providerData) {
    if (providerData is Map<String, dynamic>) {
      // Provider has customized the complex pricing
      return ServiceDefinition.fromMap(providerData);
    } else if (providerData is num) {
      // Provider has a simple flat rate
      return flatRateTemplate(providerData.toDouble());
    } else {
      // Fallback to default template if exists, else flat rate of 0
      return defaultTemplates[serviceName] ?? flatRateTemplate(0.0);
    }
  }

  /// Calculates the price for a specific service based on its definition and user's selected details
  static double calculatePrice(ServiceDefinition def, Map<String, dynamic>? details, int quantity) {
    if (def.type == ServicePricingType.flatRate) {
      return (def.flatRatePrice ?? 0.0) * quantity;
    } else if (def.type == ServicePricingType.areaBased) {
      if (details == null) return def.minPrice ?? 0.0;
      double total = 0.0;
      double sqm = (details['sqm'] as num?)?.toDouble() ?? 0.0;
      double base = def.minPrice ?? 0.0;
      if (def.pricePerSqm != null && def.minSqm != null && sqm > def.minSqm!) {
         base = (sqm * def.pricePerSqm!);
         if (base < (def.minPrice ?? 0.0)) base = def.minPrice!;
      }
      total += base;
      
      // Addons
      if (details['addons'] is List) {
        final selectedAddonNames = List<String>.from(details['addons']);
        for (var addonName in selectedAddonNames) {
           final addonDef = def.addons?.firstWhere((a) => a.name == addonName, orElse: () => ServiceAddon(name: '', price: 0));
           if (addonDef != null) {
              if (addonDef.pricingType == 'fixed') {
                 total += addonDef.price;
              } else {
                 int qty = (details['addon_qty_$addonName'] as num?)?.toInt() ?? 1;
                 total += addonDef.price * qty;
              }
           }
        }
      }
      return total * quantity; // Usually area based quantity is 1
    } else if (def.type == ServicePricingType.subtypeBased) {
       if (details == null) return 0.0;
       double total = 0.0;
       // details stores { "SubtypeName": quantity }
       details.forEach((key, val) {
          final subtypeDef = def.subtypes?.firstWhere((s) => s.name == key, orElse: () => ServiceSubtype(name: '', price: 0));
          if (subtypeDef != null && val is num) {
             total += subtypeDef.price * val.toInt();
          }
       });
       return total * quantity; // Usually quantity here is 1
    }
    return 0.0;
  }
}
