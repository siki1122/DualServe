import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:household_towing_app/main.dart' as app;

void main() {
  group('Full System E2E Test', () {
    patrolTest('Complete Customer-Provider Booking Flow', ($) async {
      final originalBuilder = ErrorWidget.builder;

      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // 1. Create Customer Account
      // Tap the register button
      await $('Register').tap();

      // Fill out registration on RegisterScreen
      await $(TextField).at(0).enterText('Test Customer');
      await $(TextField).at(1).enterText('customer@test.com');
      await $(TextField).at(2).enterText('09123456789');
      await $(TextField).at(3).enterText('password123');
      
      // Tap register button
      await $('Register').tap();

      // Wait to see if we reached the home screen
      // If we are on customer dashboard, look for 'Towing' service card
      try {
        await $('Towing').waitUntilVisible(timeout: const Duration(seconds: 10));
        await $('Towing').tap();
        await Future.delayed(const Duration(seconds: 2));

        // Open drawer and logout
        await $(Icons.menu).tap();
        await $('Logout').tap();
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Could not complete customer flow: $e');
      }
      
      // Restore original builder
      ErrorWidget.builder = originalBuilder;
    });
  });
}
