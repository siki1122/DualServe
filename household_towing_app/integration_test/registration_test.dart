import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:household_towing_app/main.dart' as app;

void main() {
  group('Registration E2E Tests (Use Case #1)', () {
    patrolTest('TC-003: Submit registration with a required field left empty', ($) async {
      await app.main();
      await $.pumpAndSettle();

      // Tap Register to go to Registration Screen
      await $('Register').tap();
      await $.pumpAndSettle();

      // Only enter email and leave name empty
      await $(TextField).at(1).enterText('test_missing@test.com');
      await $(TextField).at(2).enterText('09123456789');
      await $(TextField).at(3).enterText('ValidPass123!');
      
      // Tap Create Account
      await $('Create Account').tap();
      await $.pumpAndSettle();

      // Should show error for missing name (either dialog or snackbar or inline validation)
      // Since it prevents submission, we should still be on the Create Account screen.
      expect($('Create Account'), findsOneWidget);
    });

    patrolTest('TC-004: Register with an invalid password', ($) async {
      await app.main();
      await $.pumpAndSettle();

      await $('Register').tap();
      await $.pumpAndSettle();

      await $(TextField).at(0).enterText('John Doe');
      await $(TextField).at(1).enterText('test_invalid_pass@test.com');
      await $(TextField).at(2).enterText('09123456789');
      
      // Invalid password (no special character, no number, etc.)
      await $(TextField).at(3).enterText('weakpassword');
      
      await $('Create Account').tap();
      await $.pumpAndSettle();

      // Should show validation error and prevent submission
      expect($('Create Account'), findsOneWidget);
    });

    patrolTest('TC-002: Register with an email that is already in use', ($) async {
      await app.main();
      await $.pumpAndSettle();

      await $('Register').tap();
      await $.pumpAndSettle();

      // Assuming 'admin@example.com' or another known email is already registered in the system
      await $(TextField).at(0).enterText('Existing User');
      await $(TextField).at(1).enterText('admin@example.com'); 
      await $(TextField).at(2).enterText('09123456789');
      await $(TextField).at(3).enterText('ValidPass123!');
      
      await $('Create Account').tap();
      
      // Wait for Firebase error to come back (usually takes a moment)
      await Future.delayed(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Should show error message that email is in use
      expect($('Create Account'), findsOneWidget);
    });

    patrolTest('TC-001: Register as a customer with valid details', ($) async {
      final originalBuilder = ErrorWidget.builder;
      
      await app.main();
      await $.pumpAndSettle();

      await $('Register').tap();
      await $.pumpAndSettle();

      // Generate a unique email so it succeeds every time
      final uniqueEmail = 'test_new_user_${DateTime.now().millisecondsSinceEpoch}@test.com';

      await $(TextField).at(0).enterText('Test Customer');
      await $(TextField).at(1).enterText(uniqueEmail);
      await $(TextField).at(2).enterText('09123456789');
      await $(TextField).at(3).enterText('ValidPass123!');
      
      // Select Customer role (it's the default, but we can explicitly tap it if needed)
      // await $('Customer').tap();
      
      await $('Create Account').tap();
      
      // Wait for Firebase to create account and navigate
      await Future.delayed(const Duration(seconds: 5));
      await $.pumpAndSettle();

      // Expected Result: Account is created successfully, user should be redirected 
      // away from Register screen (usually to Login or Home)
      expect($('Create Account'), findsNothing);
      
      // Restore error widget builder
      ErrorWidget.builder = originalBuilder;
    });
  });
}
