import 'package:flutter/material.dart';
import 'package:household_towing_app/models/transaction_model.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class EarningsHistoryScreen extends StatefulWidget {
  const EarningsHistoryScreen({super.key});

  @override
  State<EarningsHistoryScreen> createState() => _EarningsHistoryScreenState();
}

class _EarningsHistoryScreenState extends State<EarningsHistoryScreen> {
  late final String _providerId;
  late final BillingService _billingService;

  @override
  void initState() {
    super.initState();
    _billingService = BillingService();
    final user = FirebaseAuth.instance.currentUser;
    _providerId = user?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_providerId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view earnings'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings History'),
        backgroundColor: AppTheme.statusCompletedText,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: _billingService.getProviderTransactions(_providerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money_outlined,
                      size: 64, color: AppTheme.textSlateLight),
                  const SizedBox(height: 16),
                  const Text(
                    'No earnings yet',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSlateMedium),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completed services will appear here',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSlateMedium),
                  ),
                ],
              ),
            );
          }

          // Calculate total earnings
          double totalEarnings =
              transactions.fold(0, (sum, t) => sum + t.finalCost);

          return ListView.builder(
            itemCount: transactions.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header with total earnings
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade400, AppTheme.statusCompletedText],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Earnings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                PricingConfig.formatPrice(totalEarnings),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Completed Tasks',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${transactions.length}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Avg Earning',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        PricingConfig.formatPrice(
                                          totalEarnings / transactions.length,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Completed Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final transaction = transactions[index - 1];
              final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
              final formattedDate = dateFormat.format(transaction.completedAt);

              return GestureDetector(
                onTap: () => _showTransactionDetails(context, transaction),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.serviceType,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSlateMedium,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                PricingConfig.formatPrice(transaction.finalCost),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.statusCompletedText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_car,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${transaction.distanceTraveled.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSlateMedium,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _getPaymentStatusColor(transaction.paymentStatus),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getPaymentStatusLabel(
                                    transaction.paymentStatus,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Tap for details',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    Transaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final dateFormat = DateFormat('MMMM dd, yyyy • HH:mm');
        final formattedDate = dateFormat.format(transaction.completedAt);

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Earnings Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Service Type', transaction.serviceType),
              _buildDetailRow(
                'Date & Time',
                formattedDate,
              ),
              _buildDetailRow(
                'Distance Traveled',
                '${transaction.distanceTraveled.toStringAsFixed(2)} km',
              ),
              const Divider(height: 24),
              const Text(
                'Earnings Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Base Price',
                PricingConfig.formatPrice(transaction.basePrice),
              ),
              _buildDetailRow(
                'Distance Surcharge',
                '${transaction.distanceTraveled.toStringAsFixed(2)} km × ${PricingConfig.formatPrice(PricingConfig.costPerKm)}/km',
                secondLine:
                    PricingConfig.formatPrice(transaction.distanceSurcharge),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Earned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    PricingConfig.formatPrice(transaction.finalCost),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.statusCompletedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(transaction.paymentStatus),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getPaymentStatusLabel(transaction.paymentStatus),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (transaction.providerNotes != null &&
                  transaction.providerNotes!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Your Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.providerNotes!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    String? secondLine,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSlateMedium,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (secondLine != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              secondLine,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.recorded:
        return AppTheme.statusCompletedText;
      case PaymentStatus.pending:
        return AppTheme.towingOrange;
    }
  }

  String _getPaymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.recorded:
        return 'Received';
      case PaymentStatus.pending:
        return 'Awaiting Payment';
    }
  }
}
