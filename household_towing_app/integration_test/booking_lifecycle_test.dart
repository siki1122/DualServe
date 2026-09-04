import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/main.dart' as app;
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/models/booking_model.dart';

void main() {
  group('Full Booking Lifecycle E2E', () {
    patrolTest('Provider accepts customer booking', ($) async {
      final originalBuilder = ErrorWidget.builder;
      
      // 1. Programmatically Setup Test Data in Emulator
      // We bypass the UI registration since we already proved it works in full_system_test.dart
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'e2e_provider@test.com',
          password: 'password123',
        );
        final providerId = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(providerId).set({
          'name': 'E2E Provider',
          'email': 'e2e_provider@test.com',
          'role': 'provider',
          'phone': '0999',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('providers').doc(providerId).set({
          'userId': providerId,
          'name': 'E2E Provider',
          'status': 'available',
          'offeredServices': {'Towing': 1500},
          'rating': 5.0,
        });
        
        await FirebaseAuth.instance.signOut();

        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'e2e_customer@test.com',
          password: 'password123',
        );
        final customerId = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(customerId).set({
          'name': 'E2E Customer',
          'email': 'e2e_customer@test.com',
          'role': 'customer',
          'phone': '0888',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create the booking programmatically
        final booking = Booking(
          id: '',
          customerId: customerId,
          serviceType: 'Towing',
          status: BookingStatus.pending,
          scheduledDate: DateTime.now(),
          scheduledTime: '10:00 AM',
          address: '123 Fake Street, Test City',
          estimatedCost: 1500.0,
          createdAt: DateTime.now(),
        );
        await BookingService().createBooking(booking);
        
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print("Setup error: $e");
      }

      // 2. Start UI and Log In as Provider
      await app.main();
      
      // Wait for login screen
      await $.pumpAndSettle();

      await $(TextField).at(0).enterText('e2e_provider@test.com');
      await $(TextField).at(1).enterText('password123');
      
      await $('Login').tap();

      // Patrol's tap automatically waits for the widget to be visible and hittable,
      // so we can just tell it to tap 'Accept'.
      // However, since it might take time to login and load the stream,
      // we'll explicitly wait until 'Accept' is visible.
      await $('Accept').waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Accept').tap();
      
      // Allow time to observe the booking status change
      await Future.delayed(const Duration(seconds: 3));
      
      // Restore
      ErrorWidget.builder = originalBuilder;
    });
  });
}
