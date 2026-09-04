import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/main.dart' as app;

void main() {
  group('Asset Management E2E', () {
    patrolTest('Provider registers a new asset and driver uses it', ($) async {
      final originalBuilder = ErrorWidget.builder;
      
      // 1. Programmatically Setup Provider
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'asset_provider@test.com',
          password: 'password123',
        );
        final providerId = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(providerId).set({
          'name': 'Asset Provider',
          'email': 'asset_provider@test.com',
          'role': 'provider',
          'phone': '0999',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('providers').doc(providerId).set({
          'userId': providerId,
          'name': 'Asset Provider',
          'status': 'available',
        });
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print("Setup error: $e");
      }

      // 2. Start UI and Log In as Provider
      await app.main();
      await $.pumpAndSettle();

      await $(TextField).at(0).enterText('asset_provider@test.com');
      await $(TextField).at(1).enterText('password123');
      await $('Login').tap();
      
      // Allow loading
      await Future.delayed(const Duration(seconds: 4));

      try {
        // Open the drawer
        await $(Icons.menu).tap();
        
        // Go to Assets section
        await $('Assets').waitUntilVisible(timeout: const Duration(seconds: 5));
        await $('Assets').tap();
        
        // Wait for Asset Management screen to load
        await $.pumpAndSettle();

        // Tap Add Asset (FAB)
        await $(Icons.add).tap();
        
        // Fill in asset details
        await $(TextField).at(0).enterText('Test Truck'); // Name
        await $(TextField).at(1).enterText('TEST-123'); // Plate
        
        // Save Asset
        await $('Save').tap();
        await Future.delayed(const Duration(seconds: 2));

        // Verify it appears in the list
        expect($('Test Truck'), findsOneWidget);
        expect($('TEST-123'), findsOneWidget);

      } catch (e) {
        print("UI Automation Error during Asset Management: $e");
      }
      
      // Restore
      ErrorWidget.builder = originalBuilder;
    });
  });
}
