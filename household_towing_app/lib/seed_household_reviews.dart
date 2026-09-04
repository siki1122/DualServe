import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:household_towing_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final firestore = FirebaseFirestore.instance;
  
  // Find a household provider
  final providersSnap = await firestore.collection('providers').where('serviceType', isEqualTo: 'Household').limit(1).get();
  
  if (providersSnap.docs.isEmpty) {
    print('No household provider found.');
    return;
  }
  
  final providerId = providersSnap.docs.first.id;
  
  // The reviews
  final reviews = [
    {
      'providerId': providerId,
      'customerId': 'seed_customer_1', // Non-existent, we will use customerName fallback
      'rating': 5.0,
      'comment': 'Excellent service! The house is spotless and smelling fresh.',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'providerId': providerId,
      'customerId': 'seed_customer_2',
      'rating': 5.0,
      'comment': 'Very professional and thorough cleaning. Highly recommended.',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'providerId': providerId,
      'customerId': 'seed_customer_3',
      'rating': 5.0,
      'comment': 'Arrived on time and did an amazing job with the deep cleaning.',
      'createdAt': FieldValue.serverTimestamp(),
    }
  ];
  
  final batch = firestore.batch();
  for (final review in reviews) {
    final docRef = firestore.collection('reviews').doc();
    batch.set(docRef, review);
  }
  
  // Update provider to have 5 stars
  batch.update(firestore.collection('providers').doc(providerId), {
    'rating': 5.0,
    'totalReviews': FieldValue.increment(3),
  });
  
  // Seed dummy users for the customerIds so they show up with names
  batch.set(firestore.collection('users').doc('seed_customer_1'), {
    'name': 'Sarah M.',
    'email': 'sarah@example.com',
  });
  batch.set(firestore.collection('users').doc('seed_customer_2'), {
    'name': 'Michael R.',
    'email': 'michael@example.com',
  });
  batch.set(firestore.collection('users').doc('seed_customer_3'), {
    'name': 'Jessica T.',
    'email': 'jessica@example.com',
  });
  
  await batch.commit();
  print('Successfully seeded 3 reviews for Household provider $providerId');
}
