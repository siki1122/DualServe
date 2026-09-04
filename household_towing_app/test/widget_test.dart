import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';

void main() {
  test('pricing supports canonical and legacy household service names', () {
    expect(PricingConfig.normalizeServiceType('Cleaning'), 'Household');
    expect(PricingConfig.getBasePrice('Household'), 500);
    expect(PricingConfig.getBasePrice('Cleaning'), 500);
    expect(PricingConfig.getBasePrice('Towing'), 1500);
  });

  test('price formatting is stable ASCII text', () {
    expect(PricingConfig.formatPrice(1250), '₱1250.00');
  });
}
