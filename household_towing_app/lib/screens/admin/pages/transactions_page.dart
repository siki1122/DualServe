import 'package:flutter/material.dart';
import 'package:household_towing_app/models/transaction_model.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final BillingService _billingService;
  final TextEditingController _filterController = TextEditingController();
  final String _selectedFilter = 'all'; // all, service, customer, provider

  @override
  void initState() {
    super.initState();
    _billingService = BillingService();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'All Transactions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Stats Cards
          _buildStatsRow(),
          const SizedBox(height: 24),

          // Transactions List
          const Text(
            'Transaction History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<List<Transaction>>(
      stream: _billingService.getAllTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Row(
            children: [
              _buildStatCard('Total Transactions', '0', Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Total Revenue', '₱0.00', Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Avg Transaction', '₱0.00', Colors.purple),
            ],
          );
        }

        final transactions = snapshot.data ?? [];
        double totalRevenue = 0;
        for (var t in transactions) {
          totalRevenue += t.finalCost;
        }

        double avgTransaction = transactions.isNotEmpty
            ? totalRevenue / transactions.length
            : 0;

        return Row(
          children: [
            _buildStatCard(
              'Total Transactions',
              '${transactions.length}',
              Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Total Revenue',
              PricingConfig.formatPrice(totalRevenue),
              Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Avg Transaction',
              PricingConfig.formatPrice(avgTransaction),
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<Transaction>>(
      stream: _billingService.getAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No transactions yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Service Type')),
                DataColumn(label: Text('Customer ID')),
                DataColumn(label: Text('Provider ID')),
                DataColumn(label: Text('Distance (km)')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Payment Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: transactions.map((transaction) {
                final dateFormat = DateFormat('MMM dd, HH:mm');
                final formattedDate = dateFormat.format(
                  transaction.completedAt,
                );

                return DataRow(
                  cells: [
                    DataCell(Text(formattedDate)),
                    DataCell(Text(transaction.serviceType)),
                    DataCell(
                      Text(
                        transaction.customerId.substring(0, 8),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        transaction.providerId.substring(0, 8),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(transaction.distanceTraveled.toStringAsFixed(2)),
                    ),
                    DataCell(
                      Text(
                        PricingConfig.formatPrice(transaction.finalCost),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPaymentStatusColor(
                            transaction.paymentStatus,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getPaymentStatusLabel(transaction.paymentStatus),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () =>
                            _showTransactionDetails(context, transaction),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    final dateFormat = DateFormat('MMMM dd, yyyy • HH:mm');
    final formattedDate = dateFormat.format(transaction.completedAt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Transaction ID', transaction.id),
              _buildDetailItem('Service Type', transaction.serviceType),
              _buildDetailItem('Date & Time', formattedDate),
              _buildDetailItem('Customer ID', transaction.customerId),
              _buildDetailItem('Provider ID', transaction.providerId),
              _buildDetailItem('Task ID', transaction.taskId),
              _buildDetailItem('Booking ID', transaction.bookingId),
              const Divider(height: 16),
              _buildDetailItem(
                'Base Price',
                PricingConfig.formatPrice(transaction.basePrice),
              ),
              _buildDetailItem(
                'Distance Traveled',
                '${transaction.distanceTraveled.toStringAsFixed(2)} km',
              ),
              _buildDetailItem(
                'Cost per KM',
                PricingConfig.formatPrice(transaction.costPerKm),
              ),
              _buildDetailItem(
                'Distance Surcharge',
                PricingConfig.formatPrice(transaction.distanceSurcharge),
              ),
              const Divider(height: 16),
              _buildDetailItem(
                'Total Amount',
                PricingConfig.formatPrice(transaction.finalCost),
                isBold: true,
              ),
              _buildDetailItem(
                'Payment Status',
                _getPaymentStatusLabel(transaction.paymentStatus),
              ),
              if (transaction.providerNotes != null &&
                  transaction.providerNotes!.isNotEmpty) ...[
                const Divider(height: 16),
                _buildDetailItem('Provider Notes', transaction.providerNotes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.recorded:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
    }
  }

  String _getPaymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.recorded:
        return 'Recorded';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }
}
