import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:household_towing_app/models/transaction_model.dart';
import 'package:household_towing_app/services/location_service.dart';
import 'package:household_towing_app/services/provider_pricing_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'logging_service.dart';

class BillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _transactionsCollection = 'transactions';

  /// Calculate estimated cost based on service type and distance
  ///
  /// Uses LocationService to calculate distance, then applies pricing formula:
  /// totalCost = basePrice + (max(0, distanceKm - minDistanceKm) * costPerKm)
  double estimateCost(
    String serviceType,
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final distanceKm = LocationService.calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return PricingConfig.calculateTotalCost(
      serviceType,
      distanceKm,
      DateTime.now(),
    );
  }

  /// Calculate cost with provider pricing and night differential
  Future<Map<String, double>> calculateCostWithProviderPricing({
    required String serviceType,
    required double distanceTraveled,
    required String providerId,
    required DateTime completionTime,
  }) async {
    try {
      final pricingService = ProviderPricingService();
      final providerPricing = await pricingService.getProviderPricing(
        providerId,
      );

      final multiplier = providerPricing.getMultiplier(serviceType);
      final basePrice = PricingConfig.getBasePrice(serviceType);
      final adjustedBasePrice = basePrice * multiplier;

      // Calculate night differential only if enabled
      double nightDifferential = 0;
      if (providerPricing.useNightDifferential) {
        nightDifferential = PricingConfig.calculateNightDifferential(
          adjustedBasePrice,
          completionTime,
        );
      }

      final distanceSurcharge = PricingConfig.calculateDistanceSurcharge(
        distanceTraveled,
      );
      final finalCost =
          adjustedBasePrice + nightDifferential + distanceSurcharge;

      return {
        'basePrice': basePrice,
        'adjustedBasePrice': adjustedBasePrice,
        'multiplier': multiplier,
        'nightDifferential': nightDifferential,
        'distanceSurcharge': distanceSurcharge,
        'finalCost': finalCost,
      };
    } catch (e) {
      Logger.error('Failed to calculate cost with provider pricing', e);
      throw Exception('Error calculating cost: $e');
    }
  }

  /// Create a transaction record when a service is completed
  ///
  /// This creates a new transaction document in Firestore with:
  /// - Cost breakdown (base price + distance surcharge)
  /// - Provider notes
  /// - Completion timestamp
  /// - Payment status (initially pending)
  Future<String> recordTransaction({
    required String taskId,
    required String bookingId,
    required String customerId,
    required String providerId,
    required String serviceType,
    required double distanceTraveled,
    required double basePrice,
    required double distanceSurcharge,
    required double nightDifferential,
    required double finalCost,
    required String? providerNotes,
  }) async {
    try {
      final transaction = Transaction(
        id: '', // Will be set by Firestore
        taskId: taskId,
        bookingId: bookingId,
        customerId: customerId,
        providerId: providerId,
        serviceType: serviceType,
        basePrice: basePrice,
        distanceTraveled: distanceTraveled,
        costPerKm: PricingConfig.costPerKm,
        distanceSurcharge: distanceSurcharge,
        finalCost: finalCost,
        status: TransactionStatus.completed,
        paymentStatus: PaymentStatus.pending,
        providerNotes: providerNotes,
        completedAt: DateTime.now(),
        recordedAt: null,
        createdAt: DateTime.now(),
      );

      // Create transaction document
      final docRef = await _firestore
          .collection(_transactionsCollection)
          .add(transaction.toFirestore());

      Logger.info(
        'Transaction created with ID: ${docRef.id}, amount: ₱$finalCost',
      );
      return docRef.id;
    } catch (e) {
      Logger.error('Failed to record transaction', e);
      throw Exception('Error recording transaction: $e');
    }
  }

  /// Get all transactions for a customer (with proper access control)
  ///
  /// Returns a stream of transactions where customerId matches
  /// Ordered by completedAt in descending order (newest first)
  Stream<List<Transaction>> getCustomerTransactions(String customerId) {
    return _firestore
        .collection(_transactionsCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Transaction.fromFirestore(doc))
              .toList();
        })
        .handleError((e) {
          Logger.error('Failed to fetch customer transactions', e);
          return [];
        });
  }

  /// Get all transactions for a provider (with proper access control)
  ///
  /// Returns a stream of transactions where providerId matches
  /// Ordered by completedAt in descending order (newest first)
  Stream<List<Transaction>> getProviderTransactions(String providerId) {
    return _firestore
        .collection(_transactionsCollection)
        .where('providerId', isEqualTo: providerId)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Transaction.fromFirestore(doc))
              .toList();
        })
        .handleError((e) {
          Logger.error('Failed to fetch provider transactions', e);
          return [];
        });
  }

  /// Get all transactions (admin only)
  ///
  /// Note: This should be called only after verifying admin status in the UI layer
  /// Returns all transactions ordered by completedAt in descending order
  Stream<List<Transaction>> getAllTransactions() {
    return _firestore
        .collection(_transactionsCollection)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Transaction.fromFirestore(doc))
              .toList();
        })
        .handleError((e) {
          Logger.error('Failed to fetch all transactions', e);
          return [];
        });
  }

  /// Get a single transaction by ID
  Future<Transaction?> getTransaction(String transactionId) async {
    try {
      final doc = await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .get();
      if (doc.exists) {
        return Transaction.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      Logger.error('Failed to fetch transaction', e);
      throw Exception('Error fetching transaction: $e');
    }
  }

  /// Update payment status to "recorded" (P2P payment confirmed)
  ///
  /// Only the provider who completed the task can update this
  Future<void> updatePaymentStatus(
    String transactionId,
    PaymentStatus paymentStatus,
  ) async {
    try {
      await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .update({
            'paymentStatus': paymentStatus.toString().split('.').last,
            'recordedAt': paymentStatus == PaymentStatus.recorded
                ? Timestamp.now()
                : FieldValue.delete(),
          });
      Logger.info(
        'Transaction $transactionId payment status updated to $paymentStatus',
      );
    } catch (e) {
      Logger.error('Failed to update payment status', e);
      throw Exception('Error updating payment status: $e');
    }
  }

  /// Get total earnings for a provider
  ///
  /// Calculates sum of all finalCost values for completed transactions
  Future<double> getProviderTotalEarnings(String providerId) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['finalCost'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      Logger.error('Failed to calculate provider earnings', e);
      return 0.0;
    }
  }

  /// Get transaction statistics for a date range
  Future<Map<String, dynamic>> getTransactionStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'completedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .get();

      double totalRevenue = 0.0;
      int transactionCount = snapshot.docs.length;
      double averageTransactionValue = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalRevenue += (data['finalCost'] as num?)?.toDouble() ?? 0.0;
      }

      if (transactionCount > 0) {
        averageTransactionValue = totalRevenue / transactionCount;
      }

      return {
        'totalRevenue': totalRevenue,
        'transactionCount': transactionCount,
        'averageTransactionValue': averageTransactionValue,
      };
    } catch (e) {
      Logger.error('Failed to get transaction stats', e);
      return {
        'totalRevenue': 0.0,
        'transactionCount': 0,
        'averageTransactionValue': 0.0,
      };
    }
  }
}
