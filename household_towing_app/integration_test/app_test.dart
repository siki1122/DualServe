import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:household_towing_app/main.dart' as app;

void main() {
  patrolTest(
    'Verify App Launches and Simulates User Interaction with Patrol',
    ($) async {
      final originalBuilder = ErrorWidget.builder;
      
      // Launch the app
      await app.main();
      
      // Wait for the app to settle and the login screen to appear
      await $.pumpAndSettle();

      // Enter text into the email and password fields using Patrol's $ finder
      await $(TextField).at(0).enterText('test@example.com');
      await $(TextField).at(1).enterText('password123');

      // Tap the login button
      await $('Login').tap();
      
      // Allow time to observe the animation
      await Future.delayed(const Duration(seconds: 2));
      
      ErrorWidget.builder = originalBuilder;
    },
  );
}
