import 'package:flutter/material.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/models/transaction_model.dart' as tm;
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'package:intl/intl.dart';
import 'package:household_towing_app/utils/service_templates.dart';
import 'package:household_towing_app/models/service_definition_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:household_towing_app/models/review_model.dart';
import 'package:household_towing_app/services/review_service.dart';

class ReceiptScreen extends StatefulWidget {
  final Booking booking;
  final tm.Transaction transaction;
  final String providerName;

  const ReceiptScreen({
    super.key,
    required this.booking,
    required this.transaction,
    required this.providerName,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late bool _isReviewed;

  @override
  void initState() {
    super.initState();
    _isReviewed = widget.booking.isReviewed;
  }

  void _showRatingDialog(BuildContext context) {
    int rating = 5;
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.backgroundDark : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rate Service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setModalState(() => rating = index + 1);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Leave a comment (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  final review = Review(
                                    id: '',
                                    bookingId: widget.booking.id,
                                    customerId: widget.booking.customerId,
                                    providerId: widget.booking.assignedProviderId ?? '',
                                    rating: rating.toDouble(),
                                    comment: commentController.text.trim(),
                                    createdAt: DateTime.now(),
                                  );
                                  await ReviewService().submitReview(review);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
                                    setState(() {
                                      _isReviewed = true;
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                                  }
                                } finally {
                                  if (mounted) setModalState(() => isSubmitting = false);
                                }
                              },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Review'),
                      ),
                    ),
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final booking = widget.booking;
    final transaction = widget.transaction;
    final providerName = widget.providerName;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Official e-Receipt',
          style: TextStyle(color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textSlateDark.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Receipt Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'PAYMENT SUCCESSFUL',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PricingConfig.formatPrice(transaction.finalCost),
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  
                  // Receipt Body
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.statusCompletedText),
                            ),
                            child: const Text(
                              'PAID IN CASH',
                              style: TextStyle(color: AppTheme.statusCompletedText, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildReceiptRow('Receipt No.', transaction.id.substring(0, 8).toUpperCase(), isDark),
                        _buildReceiptRow('Date', DateFormat('MMM dd, yyyy - hh:mm a').format(transaction.completedAt), isDark),
                        _buildReceiptRow('Provider', providerName, isDark),
                        _buildReceiptRow('Service', booking.serviceType, isDark),
                        
                        const SizedBox(height: 24),
                        _buildDashedDivider(isDark),
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Payment Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textSlateMedium),
                        ),
                        const SizedBox(height: 16),
                        
                        if (transaction.selectedSubServices != null && transaction.selectedSubServices!.isNotEmpty) ...[
                          ...transaction.selectedSubServices!.entries.map((entry) {
                            String subtitle = 'Included in Base Price';
                            if (transaction.serviceDetails != null && transaction.serviceDetails!.containsKey(entry.key)) {
                              final details = transaction.serviceDetails![entry.key];
                              if (details != null) {
                                // Simplified representation for receipt
                                if (details.containsKey('sqm')) {
                                  subtitle = 'Area: ${details['sqm']}sqm';
                                  if (details['addons'] is List && (details['addons'] as List).isNotEmpty) {
                                     subtitle += ', Add-ons: ${(details['addons'] as List).join(", ")}';
                                  }
                                } else {
                                  // Subtype
                                  subtitle = details.entries.map((e) => '${e.value}x ${e.key}').join(', ');
                                }
                              }
                            }
                            return _buildCostRow('${entry.value}x ${entry.key}', 0, isDark, subValue: subtitle);
                          }),
                          _buildCostRow('Base Rate Total', transaction.basePrice, isDark),
                        ] else ...[
                          _buildCostRow(transaction.specificService ?? 'Base Price', transaction.basePrice, isDark),
                        ],
                        if (transaction.distanceSurcharge > 0)
                          _buildCostRow('Distance Surcharge (${(transaction.distanceTraveled > PricingConfig.minDistanceKm ? transaction.distanceTraveled - PricingConfig.minDistanceKm : 0).toStringAsFixed(1)}km)', transaction.distanceSurcharge, isDark),
                        if (transaction.additionalCost > 0)
                          _buildCostRow('Additional Cost', transaction.additionalCost, isDark),
                          
                        const SizedBox(height: 24),
                        _buildDashedDivider(isDark),
                        const SizedBox(height: 24),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Paid',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                              ),
                            ),
                            Text(
                              PricingConfig.formatPrice(transaction.finalCost),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Receipt Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Thank you for using DualServe!',
                        style: TextStyle(color: AppTheme.textSlateMedium, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isReviewed) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _showRatingDialog(context),
                  icon: const Icon(Icons.star),
                  label: const Text('Rate Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _printReceipt(context),
                icon: const Icon(Icons.print),
                label: const Text('Download / Print Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('Close Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  side: BorderSide(color: isDark ? Colors.grey[800]! : AppTheme.textSlateLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    final booking = widget.booking;
    final transaction = widget.transaction;
    final providerName = widget.providerName;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('DualServe Official Receipt')),
              pw.SizedBox(height: 20),
              pw.Text('Receipt No: ${transaction.id.substring(0, 8).toUpperCase()}'),
              pw.Text('Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(transaction.completedAt)}'),
              pw.Text('Provider: $providerName'),
              pw.Text('Service: ${booking.serviceType}'),
              pw.SizedBox(height: 20),
              pw.Text('Payment Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Text('Base Price: ${PricingConfig.formatPrice(transaction.basePrice)}'),
              if (transaction.distanceSurcharge > 0)
                pw.Text('Distance Surcharge: ${PricingConfig.formatPrice(transaction.distanceSurcharge)}'),
              if (transaction.additionalCost > 0)
                pw.Text('Additional Cost: ${PricingConfig.formatPrice(transaction.additionalCost)}'),
              pw.SizedBox(height: 20),
              pw.Text('Total Paid: ${PricingConfig.formatPrice(transaction.finalCost)}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 40),
              pw.Text('Thank you for using DualServe!'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${transaction.id.substring(0, 8)}.pdf',
    );
  }

  Widget _buildReceiptRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSlateMedium, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, bool isDark, {String? subValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            PricingConfig.formatPrice(amount),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 8.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : AppTheme.textSlateLight),
              ),
            );
          }),
        );
      },
    );
  }
}
