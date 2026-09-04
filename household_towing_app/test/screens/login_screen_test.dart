import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:household_towing_app/providers/user_provider.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('Should display login form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => UserProvider()),
            ],
            child: const LoginScreen(),
          ),
        ),
      );

      // Welcome text
      expect(find.text('Welcome Back!'), findsOneWidget);

      // Text fields
      expect(find.byType(TextField), findsWidgets);
      
      // Buttons
      expect(find.byType(ElevatedButton), findsWidgets);
      
      // Google Sign-In button
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
