import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:household_towing_app/providers/user_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/services/google_auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockGoogleAuthService extends Mock implements GoogleAuthService {}

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('Should display login form fields', (WidgetTester tester) async {
      final mockFirebaseAuth = MockFirebaseAuth();
      final mockGoogleAuthService = MockGoogleAuthService();
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => UserProvider(firebaseAuth: mockFirebaseAuth)
              ),
            ],
            child: LoginScreen(googleAuthService: mockGoogleAuthService),
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
