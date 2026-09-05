import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/billing_service.dart';
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/services/location_service.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/screens/customer/receipt_screen.dart';
import 'package:household_towing_app/services/provider_service.dart';
import 'package:household_towing_app/models/transaction_model.dart' as tm;
import 'package:household_towing_app/utils/pricing_constants.dart';
import '../../widgets/success_dialog.dart';
import '../../utils/app_theme.dart';
import 'package:household_towing_app/services/notification_service_local.dart';
import 'package:household_towing_app/models/provider_model.dart';
import 'package:household_towing_app/models/service_definition_model.dart';
import 'package:household_towing_app/utils/service_templates.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/services/in_app_notification_service.dart';

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

class _TransactionCompletionScreenState extends State<TransactionCompletionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TextEditingController _notesController;
  late final TextEditingController _additionalCostController;
  late double _distanceTraveled;
  late double _basePrice;
  late double _adjustedBasePrice;
  late double _multiplier;
  late double _nightDifferential;
  late double _distanceSurcharge;
  late double _finalCost;
  double _additionalCost = 0.0;
  bool _isProcessing = false;
  bool _isLoadingPricing = true;
  String? _errorMessage;
  late DateTime _completionTime;
  String? _specificService;
  Map<String, int>? _selectedSubServices;
  Map<String, dynamic>? _serviceDetails;
  Provider? _provider;
  double _calculatedFinalCostWithoutSurcharge = 0.0;

  static const double MAX_BILLABLE_DISTANCE = 200.0;
  bool _isDistanceSuspicious = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _additionalCostController = TextEditingController(text: '0');
    _completionTime = DateTime.now();
    _calculateCosts();
  }

  Future<void> _calculateCosts() async {
    try {
      double startLat = widget.startLatitude;
      double startLng = widget.startLongitude;

      // Fetch the provider's registered coordinates to ensure distance calculation
      // matches the customer's booking estimate perfectly.
      Provider? provider;
      try {
        final providerService = ProviderService();
        provider = await providerService.getProvider(widget.providerId);
        if (provider != null && provider.latitude != null && provider.longitude != null) {
          startLat = provider.latitude!;
          startLng = provider.longitude!;
        }
      } catch (e) {
        debugPrint('Failed to fetch provider registered location, using current GPS coordinates: $e');
      }

      // Calculate distance traveled (from provider's base/office to the task location)
      double actualDistance = LocationService.calculateDistance(
        startLat,
        startLng,
        widget.endLatitude,
        widget.endLongitude,
      );

      _distanceTraveled = actualDistance;
      _isDistanceSuspicious = actualDistance > MAX_BILLABLE_DISTANCE;

      // For billing purposes, we cap the distance if it's suspiciously high (likely a test/GPS error)
      double billableDistance = actualDistance > MAX_BILLABLE_DISTANCE 
          ? MAX_BILLABLE_DISTANCE 
          : actualDistance;

      // Fetch booking to get specificService and selectedSubServices
      final bookingService = BookingService();
      final booking = await bookingService.getBooking(widget.bookingId);
      final specificService = booking?.specificService;
      final selectedSubServices = booking?.selectedSubServices;
      final serviceDetails = booking?.serviceDetails;

      // Get provider pricing and calculate with custom services + night differential
      final billingService = BillingService();
      final costBreakdown = await billingService
          .calculateCostWithProviderPricing(
            serviceType: widget.serviceType,
            specificService: specificService,
            selectedSubServices: selectedSubServices,
            serviceDetails: serviceDetails,
            distanceTraveled: billableDistance,
            providerId: widget.providerId,
            completionTime: _completionTime,
          );

      setState(() {
        _provider = provider;
        _specificService = specificService;
        _selectedSubServices = selectedSubServices;
        _serviceDetails = serviceDetails;
        _basePrice = costBreakdown['basePrice']!;
        _adjustedBasePrice = costBreakdown['adjustedBasePrice']!;
        _multiplier = costBreakdown['multiplier']!;
        _nightDifferential = costBreakdown['nightDifferential']!;
        _distanceSurcharge = costBreakdown['distanceSurcharge']!;
        _calculatedFinalCostWithoutSurcharge = costBreakdown['finalCost']!;
        _additionalCost = double.tryParse(_additionalCostController.text) ?? 0.0;
        _finalCost = _calculatedFinalCostWithoutSurcharge + _additionalCost;
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
      final transactionId = await billingService.recordTransaction(
        taskId: widget.taskId,
        bookingId: widget.bookingId,
        customerId: widget.customerId,
        providerId: widget.providerId,
        serviceType: widget.serviceType,
        specificService: _specificService,
        selectedSubServices: _selectedSubServices,
        serviceDetails: _serviceDetails,
        distanceTraveled: _distanceTraveled > MAX_BILLABLE_DISTANCE 
            ? MAX_BILLABLE_DISTANCE 
            : _distanceTraveled,
        basePrice: _adjustedBasePrice, // Use the adjusted one (with multiplier)
        distanceSurcharge: _distanceSurcharge,
        nightDifferential: _nightDifferential,
        finalCost: _finalCost,
        additionalCost: _additionalCost,
        providerNotes: _notesController.text.isEmpty
            ? null
            : _notesController.text,
      );

      // Update task status to completed (also sets completedAt and syncs booking)
      final taskService = TaskService();
      await taskService.updateTaskCompletion(
        widget.taskId,
        bookingId: widget.bookingId,
        finalCost: _finalCost,
      ).timeout(const Duration(seconds: 5));

      try {
        await InAppNotificationService().sendNotification(
          userId: widget.customerId,
          title: 'Service Completed',
          message: 'Your service has been completed. An e-receipt is now available.',
          type: 'booking_update',
          actionData: {'bookingId': widget.bookingId, 'taskId': widget.taskId},
        );
      } catch (e) {
        debugPrint('Failed to send e-receipt notification: $e');
      }

      if (mounted) {
        // Show beautiful success dialog instead of a small snackbar
        SuccessDialog.show(
          context,
          title: 'Job Well Done!',
          message: 'The task has been completed and the transaction is recorded in your billing history.',
          onPressed: () async {
            Navigator.of(context).pop(); // Close dialog
            
            // Fetch necessary data for receipt
            final booking = await BookingService().getBooking(widget.bookingId);
            final transactionDoc = await _firestore.collection('transactions').doc(transactionId).get();
            final transaction = tm.Transaction.fromFirestore(transactionDoc);
            
            if (mounted && booking != null) {
               // Push replacement to ReceiptScreen instead of popping back
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(
                   builder: (context) => ReceiptScreen(
                     booking: booking,
                     transaction: transaction,
                     providerName: _provider?.name ?? 'Provider',
                   ),
                 ),
               );
            } else {
               Navigator.of(context).pop(true);
            }
          },
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved offline. Will sync when connection is restored.'),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
        Navigator.of(context).pop(true); // Treat as success for UI flow
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

  void _showCashVerificationDialog() {
    final TextEditingController cashController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final double cashReceived = double.tryParse(cashController.text) ?? 0.0;
            final bool isInsufficient = cashController.text.isNotEmpty && cashReceived < _finalCost;
            final double changeDue = cashReceived >= _finalCost ? cashReceived - _finalCost : 0.0;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.backgroundDark : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Cash Amount',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total amount due is ${PricingConfig.formatPrice(_finalCost)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: cashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      onChanged: (val) {
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Cash Received (₱)',
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.payments, color: AppTheme.statusCompletedText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    if (isInsufficient) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Payment Discrepancy: Insufficient cash. Missing ${PricingConfig.formatPrice(_finalCost - cashReceived)}.',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (cashReceived >= _finalCost && cashController.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Change Due:',
                              style: TextStyle(color: AppTheme.statusCompletedText, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              PricingConfig.formatPrice(changeDue),
                              style: const TextStyle(color: AppTheme.statusCompletedText, fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (cashController.text.isEmpty || isInsufficient)
                            ? null
                            : () {
                                Navigator.pop(context); // Close bottom sheet
                                _recordTransaction(); // Proceed
                              },
                        child: const Text('Confirm Payment & Issue Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _additionalCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
        appBar: AppBar(
          title: Text(
            'Complete Service',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
          elevation: 0,
          automaticallyImplyLeading: !_isProcessing,
        ),
        body: _isLoadingPricing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        decoration: AppTheme.cardDecoration(context),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle, color: AppTheme.primaryBlue, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Service Completed',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _buildHeaderStat('Service Type', widget.serviceType, isDark),
                                  if (widget.serviceType != 'Household') ...[
                                    const Spacer(),
                                    _buildHeaderStat(
                                      'Distance', 
                                      '${_distanceTraveled.toStringAsFixed(2)} km',
                                      isDark,
                                      isWarning: _isDistanceSuspicious
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isDistanceSuspicious && widget.serviceType != 'Household') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.towingOrange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Billing capped to ${MAX_BILLABLE_DISTANCE.toInt()}km for safety.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Cost Breakdown
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'BILLING DETAILS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.textSlateMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: AppTheme.cardDecoration(context),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              if (_selectedSubServices != null && _selectedSubServices!.isNotEmpty)
                                ..._selectedSubServices!.entries.map((entry) {
                                  final serviceName = entry.key;
                                  final qty = entry.value;
                                  
                                  double subTotal = 0.0;
                                  String subtitle = '';
                                  
                                  if (_provider != null) {
                                    final providerData = _provider!.offeredServices[serviceName];
                                    final def = ServiceTemplates.getDefinition(serviceName, providerData);
                                    final details = _serviceDetails?[serviceName] as Map<String, dynamic>?;
                                    
                                    subTotal = ServiceTemplates.calculatePrice(def, details, qty);
                                    if (subTotal == 0 && def.type == ServicePricingType.flatRate) {
                                      double unitPrice = (providerData as num?)?.toDouble() ?? PricingConfig.getBasePrice(widget.serviceType);
                                      subTotal = unitPrice * qty;
                                    }
                                    
                                    if (def.type == ServicePricingType.areaBased && details != null) {
                                       subtitle = 'Area: ${details['sqm'] ?? 0}sqm';
                                       if (details['addons'] is List && (details['addons'] as List).isNotEmpty) {
                                          subtitle += ' + Add-ons';
                                       }
                                    } else if (def.type == ServicePricingType.subtypeBased && details != null) {
                                       subtitle = details.entries.map((e) => '${e.value}x ${e.key}').join(', ');
                                    }
                                  }
                                  
                                  return _buildCostRow('${qty}x $serviceName', subTotal, isDark, subValue: subtitle.isNotEmpty ? subtitle : null);
                                })
                              else
                                _buildCostRow(_specificService ?? 'Base Service', _basePrice, isDark),
                              
                              if (_selectedSubServices != null && _selectedSubServices!.isNotEmpty)
                                _buildCostRow('Base Subtotal', _basePrice, isDark, isEditable: true),

                              if (_multiplier != 1.0)
                                _buildCostRow(
                                  'Custom Rate Adjustment', 
                                  _adjustedBasePrice - _basePrice, 
                                  isDark, 
                                  subValue: '${_multiplier}x Base'
                                ),
                              if (_nightDifferential > 0)
                                _buildCostRow('Night Differential', _nightDifferential, isDark, icon: Icons.nights_stay),
                              if (widget.serviceType != 'Household')
                                _buildCostRow('Distance Surcharge', _distanceSurcharge, isDark, subValue: '${(_distanceTraveled > PricingConfig.minDistanceKm ? _distanceTraveled - PricingConfig.minDistanceKm : 0).toStringAsFixed(2)} km'),
                              _buildCostRow('Additional Cost', _additionalCost, isDark, isEditable: true),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total to Collect',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    PricingConfig.formatPrice(_finalCost),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.statusCompletedText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Custom Surcharge & Notes
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'ADJUSTMENTS & NOTES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.textSlateMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildModernTextField(
                        controller: _additionalCostController,
                        label: 'Service Surcharge (₱)',
                        hint: 'Extra costs for tools, etc.',
                        icon: Icons.add_circle_outline,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          setState(() {
                            _additionalCost = double.tryParse(value) ?? 0.0;
                            _finalCost = _calculatedFinalCostWithoutSurcharge + _additionalCost;
                          });
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _notesController,
                        label: 'Service Notes',
                        hint: 'Describe the completed task...',
                        icon: Icons.notes,
                        maxLines: 3,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 32),

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
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _isProcessing ? null : _showCashVerificationDialog,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Complete & Collect Payment',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSlateMedium,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, bool isDark, {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: label == 'Distance' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning ? AppTheme.towingOrange : (isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
          ),
        ),
      ],
    );
  }

  Widget _buildCostRow(String label, double value, bool isDark, {String? subValue, IconData? icon, bool isEditable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            PricingConfig.formatPrice(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isEditable ? FontWeight.bold : FontWeight.w600,
              color: isEditable ? AppTheme.primaryBlue : (isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
              prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryBlue),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
