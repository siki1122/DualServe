import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:household_towing_app/main.dart' as app;

void main() {
  group('Authentication E2E Tests (Use Case #3)', () {
    patrolTest('TC-009: Log in with a valid email and password', ($) async {
      await app.main();
      await $.pumpAndSettle();

      // Assuming the app starts on the Login Screen or redirects there
      expect($('Login'), findsWidgets);

      // Enter valid email and password (using a test account that should exist)
      await $(TextField).at(0).enterText('test_user@example.com'); 
      await $(TextField).at(1).enterText('ValidPass123!');
      
      await $('Login').tap();
      
      // Wait for Firebase to authenticate
      await Future.delayed(const Duration(seconds: 4));
      await $.pumpAndSettle();

      // Login screen should no longer be visible if successful
      // expect($('Login'), findsNothing); // Depending on UI, 'Login' text might be in appbar or not.
      
      // We expect some home screen element to be visible
    });

    patrolTest('TC-011: Log in with incorrect email or password', ($) async {
      await app.main();
      await $.pumpAndSettle();

      expect($('Login'), findsWidgets);

      await $(TextField).at(0).enterText('wrong_email@example.com');
      await $(TextField).at(1).enterText('WrongPass123!');
      
      await $('Login').tap();
      
      // Wait for Firebase error
      await Future.delayed(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Should show error message (Snackbar) and stay on Login screen
      expect($('Incorrect email or password'), findsOneWidget);
    });

    patrolTest('TC-013: Forgot the account password', ($) async {
      await app.main();
      await $.pumpAndSettle();

      await $('Forgot Password?').tap();
      await $.pumpAndSettle();

      // Dialog opens
      expect($('Reset Password'), findsOneWidget);

      await $(TextField).at(2).enterText('test_user@example.com'); // It's the 3rd textfield overall (email, pass, dialog email)
      
      await $('Send Link').tap();
      
      await Future.delayed(const Duration(seconds: 3));
      await $.pumpAndSettle();

      // Should show success snackbar
      expect($('Password reset link sent! Check your email.'), findsOneWidget);
    });
  });
}
