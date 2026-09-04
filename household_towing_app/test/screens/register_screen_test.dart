import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/screens/auth/register_screen.dart';
import 'package:provider/provider.dart';
import 'package:household_towing_app/providers/user_provider.dart';

void main() {
  group('RegisterScreen Widget Tests (White Box)', () {
    testWidgets('Should display registration form fields', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => UserProvider()),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      // Verify that the title is present
      expect(find.text('Create Account'), findsWidgets);
      
      // Verify text fields are present
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify role selection exists
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);

      // Verify register button
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
