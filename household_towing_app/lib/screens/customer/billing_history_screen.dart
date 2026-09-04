import 'package:flutter/material.dart';
import 'package:household_towing_app/models/transaction_model.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  late final String _customerId;
  late final BillingService _billingService;

  @override
  void initState() {
    super.initState();
    _billingService = BillingService();
    final user = FirebaseAuth.instance.currentUser;
    _customerId = user?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_customerId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view billing history')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing History'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: _billingService.getCustomerTransactions(_customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            );
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
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppTheme.textSlateLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No billing records yet',
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

          // Calculate total spent
          double totalSpent = transactions.fold(
            0,
            (sum, t) => sum + t.finalCost,
          );

          return ListView.builder(
            itemCount: transactions.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header with total
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16, top: 16),
                  child: Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Spent',
                          style: TextStyle(
                            fontSize: 14, 
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PricingConfig.formatPrice(totalSpent),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${transactions.length} completed services',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                          ),
                        ),
                      ],
                    ),
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
                  child: Container(
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.all(20.0),
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppTheme.textSlateDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              PricingConfig.formatPrice(
                                transaction.finalCost,
                              ),
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
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: 16,
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${transaction.distanceTraveled.toStringAsFixed(2)} km',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              status: transaction.paymentStatus == PaymentStatus.recorded ? 'Completed' : 'Pending',
                              size: BadgeSize.small,
                              showIcon: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Tap for details',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryBlue.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
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
                    'Transaction Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Service Type', transaction.serviceType),
              _buildDetailRow('Date & Time', formattedDate),
              _buildDetailRow(
                'Distance Traveled',
                '${transaction.distanceTraveled.toStringAsFixed(2)} km',
              ),
              const Divider(height: 24),
              const Text(
                'Cost Breakdown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Base Price',
                PricingConfig.formatPrice(transaction.basePrice),
              ),
              _buildDetailRow(
                'Distance Surcharge',
                '${(transaction.distanceTraveled > PricingConfig.minDistanceKm ? transaction.distanceTraveled - PricingConfig.minDistanceKm : 0).toStringAsFixed(2)} km (after first ${PricingConfig.minDistanceKm.toInt()}km) × ${PricingConfig.formatPrice(PricingConfig.costPerKm)}/km',
                secondLine: PricingConfig.formatPrice(
                  transaction.distanceSurcharge,
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              if (transaction.providerNotes != null &&
                  transaction.providerNotes!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Provider Notes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildDetailRow(String label, String value, {String? secondLine}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSlateMedium),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (secondLine != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              secondLine,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }
}
