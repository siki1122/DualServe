import 'package:flutter/material.dart';
import 'package:household_towing_app/models/transaction_model.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:household_towing_app/services/location_service.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';

class TransactionCompletionScreen extends StatefulWidget {
  final String taskId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceType;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;

  const TransactionCompletionScreen({
    super.key,
    required this.taskId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceType,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
  });

  @override
  State<TransactionCompletionScreen> createState() =>
      _TransactionCompletionScreenState();
}

class _TransactionCompletionScreenState
    extends State<TransactionCompletionScreen> {
  late final TextEditingController _notesController;
  late double _distanceTraveled;
  late double _basePrice;
  late double _adjustedBasePrice;
  late double _multiplier;
  late double _nightDifferential;
  late double _distanceSurcharge;
  late double _finalCost;
  bool _isProcessing = false;
  bool _isLoadingPricing = true;
  String? _errorMessage;
  late DateTime _completionTime;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _completionTime = DateTime.now();
    _calculateCosts();
  }

  Future<void> _calculateCosts() async {
    try {
      // Calculate distance traveled
      _distanceTraveled = LocationService.calculateDistance(
        widget.startLatitude,
        widget.startLongitude,
        widget.endLatitude,
        widget.endLongitude,
      );

      // Get provider pricing and calculate with multiplier + night differential
      final billingService = BillingService();
      final costBreakdown = await billingService
          .calculateCostWithProviderPricing(
            serviceType: widget.serviceType,
            distanceTraveled: _distanceTraveled,
            providerId: widget.providerId,
            completionTime: _completionTime,
          );

      setState(() {
        _basePrice = costBreakdown['basePrice']!;
        _adjustedBasePrice = costBreakdown['adjustedBasePrice']!;
        _multiplier = costBreakdown['multiplier']!;
        _nightDifferential = costBreakdown['nightDifferential']!;
        _distanceSurcharge = costBreakdown['distanceSurcharge']!;
        _finalCost = costBreakdown['finalCost']!;
        _isLoadingPricing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error calculating costs: $e';
        _isLoadingPricing = false;
      });
    }
  }

  Future<void> _recordTransaction() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final billingService = BillingService();

      // Record the transaction
      await billingService.recordTransaction(
        taskId: widget.taskId,
        bookingId: widget.bookingId,
        customerId: widget.customerId,
        providerId: widget.providerId,
        serviceType: widget.serviceType,
        distanceTraveled: _distanceTraveled,
        providerNotes: _notesController.text.isEmpty
            ? null
            : _notesController.text,
      );

      // Update task status to completed
      final taskService = TaskService();
      await taskService.updateTaskStatus(widget.taskId, TaskStatus.completed);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Service'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !_isProcessing,
        ),
        body: _isLoadingPricing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Service Completed',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
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
                                        'Service Type',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.serviceType,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Distance Traveled',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_distanceTraveled.toStringAsFixed(2)} km',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 24),

                      // Cost Breakdown
                      const Text(
                        'Cost Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Base price
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Base Price',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.serviceType,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    PricingConfig.formatPrice(_basePrice),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),

                              // Price multiplier (if custom)
                              if (_multiplier != 1.0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Your Price Multiplier',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_multiplier}x',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      PricingConfig.formatPrice(
                                        _adjustedBasePrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                              ],

                              // Night differential
                              if (_nightDifferential > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.nights_stay,
                                              size: 14,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Night Differential',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+${PricingConfig.getNightDifferentialPercentage()}% (11 PM - 5 AM)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      PricingConfig.formatPrice(
                                        _nightDifferential,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                              ],

                              // Distance surcharge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Distance Surcharge',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_distanceTraveled.toStringAsFixed(2)} km × ${PricingConfig.formatPrice(PricingConfig.costPerKm)}/km',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    PricingConfig.formatPrice(
                                      _distanceSurcharge,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),

                              // Total
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    PricingConfig.formatPrice(_finalCost),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Provider Notes
                      const Text(
                        'Service Notes (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        enabled: !_isProcessing,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Add any notes about the service...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProcessing ? null : _recordTransaction,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Mark as Paid (P2P)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
