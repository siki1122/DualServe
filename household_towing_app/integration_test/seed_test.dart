import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:household_towing_app/seed_household_reviews.dart' as seed;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Seed household reviews', (tester) async {
    await seed.main();
  });
}
