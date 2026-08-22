import 'package:flutter/material.dart';
import 'package:household_towing_app/models/provider_pricing_model.dart';
import 'package:household_towing_app/services/provider_pricing_service.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class ProviderPricingSettingsScreen extends StatefulWidget {
  const ProviderPricingSettingsScreen({super.key});

  @override
  State<ProviderPricingSettingsScreen> createState() =>
      _ProviderPricingSettingsScreenState();
}

class _ProviderPricingSettingsScreenState
    extends State<ProviderPricingSettingsScreen> {
  final ProviderPricingService _pricingService = ProviderPricingService();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  // Local state for live preview
  double? _tempCleaningMultiplier;
  double? _tempTowingMultiplier;
  bool? _tempUseNightDifferential;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providerId = userProvider.uid;

    if (providerId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    // Get the provider's actual specialization (from their profile)
    final profile = userProvider.providerProfile ?? {};
    final bool providesTowing =
        profile['serviceType'] == 'Towing' || profile['serviceType'] == 'Both';
    final bool providesHousehold =
        profile['serviceType'] == 'Household' ||
        profile['serviceType'] == 'Cleaning' ||
        profile['serviceType'] == 'Both';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('Pricing & Rates'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppTheme.textSlateDark,
      ),
      body: StreamBuilder<ProviderPricing>(
        stream: _pricingService.getProviderPricingStream(providerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _tempCleaningMultiplier == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final pricing = snapshot.data;
          if (pricing == null) {
            return const Center(child: Text('No pricing data found'));
          }

          // Initialize local state if not set
          _tempCleaningMultiplier ??= pricing.cleaningMultiplier;
          _tempTowingMultiplier ??= pricing.towingMultiplier;
          _tempUseNightDifferential ??= pricing.useNightDifferential;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(isDark),
                const SizedBox(height: 32),

                if (providesTowing) ...[
                  _buildSectionTitle('Towing Rates', isDark),
                  const SizedBox(height: 12),
                  _buildMultiplierCard(
                    'Towing Multiplier',
                    _tempTowingMultiplier!,
                    AppTheme.towingOrange,
                    (val) => setState(() => _tempTowingMultiplier = val),
                    isDark,
                  ),
                  const SizedBox(height: 24),
                ],

                if (providesHousehold) ...[
                  _buildSectionTitle('Household Rates', isDark),
                  const SizedBox(height: 12),
                  _buildMultiplierCard(
                    'Household Multiplier',
                    _tempCleaningMultiplier!,
                    AppTheme.primaryBlue,
                    (val) => setState(() => _tempCleaningMultiplier = val),
                    isDark,
                  ),
                  const SizedBox(height: 24),
                ],

                _buildSectionTitle('Preferences', isDark),
                const SizedBox(height: 12),
                _buildNightDifferentialCard(isDark),
                const SizedBox(height: 32),

                _buildLivePreview(providesTowing, providesHousehold, isDark),
                const SizedBox(height: 40),

                _buildSaveButton(pricing, providerId),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppTheme.textSlateDark,
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your final price to the customer is: (Base Rate × Multiplier) + Distance Surcharge.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : AppTheme.textSlateMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierCard(
    String label,
    double value,
    Color color,
    Function(double) onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}x',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: value,
            min: 0.8,
            max: 2.0,
            divisions: 12,
            activeColor: color,
            onChanged: onChanged,
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Economy',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                'Standard',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                'Premium',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNightDifferentialCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Night Surcharge',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '11 PM - 5 AM (+30%)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Switch(
            value: _tempUseNightDifferential!,
            onChanged: (val) => setState(() => _tempUseNightDifferential = val),
            activeThumbColor: AppTheme.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(bool towing, bool cleaning, bool isDark) {
    final baseTowing = PricingConfig.basePrices['Towing']!;
    final baseHousehold =
        PricingConfig.basePrices[PricingConfig.householdService]!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Price Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (towing)
            _buildPreviewRow(
              'Towing (Base)',
              baseTowing * _tempTowingMultiplier!,
            ),
          if (towing && cleaning) const Divider(height: 24),
          if (cleaning)
            _buildPreviewRow(
              'Household (Base)',
              baseHousehold * _tempCleaningMultiplier!,
            ),
          const SizedBox(height: 12),
          const Text(
            '*Excludes distance and night surcharges',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          '₱${price.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ProviderPricing pricing, String providerId) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveSettings(pricing, providerId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Pricing Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _saveSettings(ProviderPricing pricing, String providerId) async {
    setState(() => _isLoading = true);
    try {
      await _pricingService.updateProviderPricing(
        providerId: providerId,
        cleaningMultiplier: _tempCleaningMultiplier,
        towingMultiplier: _tempTowingMultiplier,
        useNightDifferential: _tempUseNightDifferential,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pricing updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
