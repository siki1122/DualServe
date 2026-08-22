import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../models/provider_model.dart';
import '../../services/booking_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pricing_constants.dart';
import '../../widgets/primary_async_button.dart';
import '../../widgets/success_dialog.dart';
import 'customer_active_bookings_screen.dart';
import 'package:intl/intl.dart';
import '../../utils/service_templates.dart';
import '../../models/service_definition_model.dart';

class BookingSummaryScreen extends StatefulWidget {
  final Booking booking;
  final Provider provider;
  final double basePrice;

  const BookingSummaryScreen({
    super.key,
    required this.booking,
    required this.provider,
    required this.basePrice,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final BookingService _bookingService = BookingService();

  Future<void> _submitBooking() async {
    try {
      await _bookingService.createBooking(widget.booking);

      if (mounted) {
        SuccessDialog.show(
          context,
          title: 'Booking Successful!',
          message: 'Your ${widget.booking.serviceType} request has been sent to the provider.',
          onPressed: () {
            Navigator.of(context).pop(); // Pop dialog
            // Navigate back to active bookings, popping everything else
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CustomerActiveBookingsScreen(),
              ),
              (route) => route.isFirst, // keep only the very first route (usually Home/Services screen)
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Recalculate surcharges based on final booking details
    double distanceSurcharge = 0;
    // We don't have the exact distance here easily, but the booking's estimatedCost 
    // already includes basePrice + distanceSurcharge + nightDiff.
    // We can back-calculate or simply use the breakdown we know.
    // To keep it simple, we just show the itemized base prices, and if estimatedCost > basePrice, we show the difference as "Surcharges"
    final surcharges = widget.booking.estimatedCost! - widget.basePrice;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('Review Booking'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Provider Details', isDark),
            const SizedBox(height: 12),
            _buildProviderCard(isDark),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Schedule & Location', isDark),
            const SizedBox(height: 12),
            _buildScheduleLocationCard(isDark),
            const SizedBox(height: 24),

            _buildSectionTitle('Service Breakdown', isDark),
            const SizedBox(height: 12),
            _buildReceiptCard(isDark, surcharges),
            const SizedBox(height: 40),

            PrimaryAsyncButton(
              text: 'Confirm & Submit Booking',
              onPressed: _submitBooking,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
      ),
    );
  }

  Widget _buildProviderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.business, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.provider.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.textSlateDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.provider.serviceArea,
                  style: const TextStyle(
                    color: AppTheme.textSlateMedium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleLocationCard(bool isDark) {
    final dateStr = DateFormat('MMM dd, yyyy').format(widget.booking.scheduledDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dateStr at ${widget.booking.scheduledTime}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textSlateDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: AppTheme.towingOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.booking.address,
                  style: TextStyle(
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(bool isDark, double surcharges) {
    final servicesMap = widget.booking.selectedSubServices ?? {};
    final detailsMap = widget.booking.serviceDetails ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Itemized Services',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          if (servicesMap.isNotEmpty) ...[
            ...servicesMap.entries.map((entry) {
              final serviceName = entry.key;
              final qty = entry.value;
              final providerData = widget.provider.offeredServices[serviceName];
              final def = ServiceTemplates.getDefinition(serviceName, providerData);
              final details = detailsMap[serviceName] as Map<String, dynamic>?;
              
              double subTotal = ServiceTemplates.calculatePrice(def, details, qty);
              if (subTotal == 0 && def.type == ServicePricingType.flatRate) {
                double unitPrice = (providerData as num?)?.toDouble() ?? PricingConfig.getBasePrice(widget.booking.serviceType);
                subTotal = unitPrice * qty;
              }
              
              List<Widget> complexDetailsWidgets = [];
              if (def.type == ServicePricingType.areaBased && details != null) {
                 final sqm = details['sqm'] ?? 0;
                 complexDetailsWidgets.add(Text('Area: ${sqm}sqm', style: const TextStyle(fontSize: 11, color: Colors.grey)));
                 if (details['addons'] is List && (details['addons'] as List).isNotEmpty) {
                    complexDetailsWidgets.add(Text('Add-ons: ${(details['addons'] as List).join(", ")}', style: const TextStyle(fontSize: 11, color: Colors.grey)));
                 }
              } else if (def.type == ServicePricingType.subtypeBased && details != null) {
                 final subtypes = details.entries.map((e) => '${e.value}x ${e.key}').join(', ');
                 if (subtypes.isNotEmpty) {
                    complexDetailsWidgets.add(Text(subtypes, style: const TextStyle(fontSize: 11, color: Colors.grey)));
                 }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${qty}x',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(serviceName),
                          if (complexDetailsWidgets.isNotEmpty) ...complexDetailsWidgets
                          else 
                            Text(
                              '@ ${PricingConfig.formatPrice(subTotal / qty)} each',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Text(PricingConfig.formatPrice(subTotal)),
                  ],
                ),
              );
            }),
          ] else if (widget.booking.specificService != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.booking.specificService!)),
                Text(PricingConfig.formatPrice(widget.basePrice)),
              ],
            ),
          ],
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Base Subtotal', style: TextStyle(color: Colors.grey)),
              ),
              Text(PricingConfig.formatPrice(widget.basePrice), style: const TextStyle(color: Colors.grey)),
            ],
          ),
          
          if (surcharges > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('Surcharges (Night / Distance)', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                Text('+ ${PricingConfig.formatPrice(surcharges)}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(thickness: 1.5),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Estimated Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Text(
                PricingConfig.formatPrice(widget.booking.estimatedCost!),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
