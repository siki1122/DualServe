import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/models/provider_model.dart';
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/services/provider_service.dart';
import 'package:household_towing_app/services/location_service.dart';
import 'package:household_towing_app/services/logging_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:household_towing_app/utils/pricing_constants.dart';
import '../../widgets/success_dialog.dart';

class BookingScreen extends StatefulWidget {
  final String serviceType;
  final String? preSelectedProviderId;
  const BookingScreen({
    super.key,
    required this.serviceType,
    this.preSelectedProviderId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final BookingService _bookingService = BookingService();
  final ProviderService _providerService = ProviderService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;
  double _estimatedCost = 0;
  String? _selectedProviderId;
  List<Provider> _availableProviders = [];
  bool _loadingProviders = true;
  double? _userLat;
  double? _userLng;

  // Geocoding optimization
  Timer? _geocodingTimer;
  int _geocodingRequestCount = 0;
  static const int _maxGeocodingRequests = 5; // Max 5 requests per minute
  static const Duration _geocodingThrottle = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    // Use Today for Towing, Tomorrow for Cleaning by default
    if (widget.serviceType == 'Towing') {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    // Initial price calculation
    _estimatedCost = PricingConfig.getBasePrice(widget.serviceType);

    _loadAvailableProviders();
    _detectCurrentLocation();

    // Re-calculate price whenever address changes (if we can geocode it)
    _addressController.addListener(() {
      _debounceGeocoding();
    });
  }

  @override
  void dispose() {
    _geocodingTimer?.cancel();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _debounceGeocoding() {
    // Cancel previous timer to avoid multiple requests
    _geocodingTimer?.cancel();

    // Rate limit: max 5 requests per minute
    if (_geocodingRequestCount >= _maxGeocodingRequests) {
      return;
    }

    // Restart debounce timer (2 seconds of inactivity before geocoding)
    _geocodingTimer = Timer(const Duration(seconds: 2), () async {
      if (_addressController.text.length > 10 && mounted) {
        _geocodingRequestCount++;

        try {
          final locations = await LocationService.getCoordinatesFromAddress(
            _addressController.text,
          );
          if (locations.isNotEmpty && mounted) {
            setState(() {
              _userLat = locations[0].latitude;
              _userLng = locations[0].longitude;
            });
            _updateEstimatedPrice();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Address not found. Please check and try again.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          Logger.error('Geocoding failed for address', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Address lookup failed. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // Reset rate limit counter after 1 minute
        Future.delayed(_geocodingThrottle, () {
          _geocodingRequestCount = 0;
        });
      }
    });
  }

  Future<void> _detectCurrentLocation() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            _addressController.text = address;
            _userLat = position.latitude;
            _userLng = position.longitude;
          });
          _updateEstimatedPrice();
        }
      }
    } catch (e) {
      Logger.error('Location detection failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not detect your location. Please enter address manually.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _updateEstimatedPrice() {
    double distance = 0;

    // 1. Check if we have both user and provider locations to calculate distance surcharge
    if (_userLat != null && _userLng != null && _selectedProviderId != null) {
      try {
        final provider = _availableProviders.firstWhere(
          (p) => p.id == _selectedProviderId,
        );
        if (provider.latitude != null && provider.longitude != null) {
          distance = LocationService.calculateDistance(
            _userLat!,
            _userLng!,
            provider.latitude!,
            provider.longitude!,
          );
          Logger.debug(
            'Calculated distance: ${distance.toStringAsFixed(2)} km',
          );
        }
      } catch (e) {
        Logger.warn('Distance calculation failed, using 0 km', e);
        // Continue with distance = 0, which is already set
      }
    }

    // 2. Use the specialized PricingConfig to get the final cost
    // This handles: Base Price (Service specific) + Night Differential + Distance Surcharge
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      _estimatedCost = PricingConfig.calculateTotalCost(
        widget.serviceType,
        distance,
        scheduledDateTime,
      );
    });
  }

  Future<void> _loadAvailableProviders() async {
    try {
      final providers = await _providerService.getProvidersByServiceType(
        widget.serviceType,
      );
      setState(() {
        _availableProviders = providers
            .where((p) => p.status == ProviderStatus.available)
            .toList();
        if (widget.preSelectedProviderId != null) {
          _selectedProviderId = widget.preSelectedProviderId;
        } else if (_availableProviders.isNotEmpty) {
          _selectedProviderId = _availableProviders[0].id;
        }
        _loadingProviders = false;
      });
      _updateEstimatedPrice();
    } catch (e) {
      setState(() => _loadingProviders = false);
    }
  }

  Future<void> _submitBooking() async {
    if (_addressController.text.isEmpty || _selectedProviderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all details')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final timeStr = DateFormat('hh:mm a').format(dt).toUpperCase();

      final booking = Booking(
        id: '',
        customerId: uid,
        assignedProviderId: _selectedProviderId,
        serviceType: widget.serviceType,
        status: BookingStatus.pending,
        scheduledDate: _selectedDate,
        scheduledTime: timeStr,
        address: _addressController.text,
        estimatedCost: _estimatedCost,
        notes: _notesController.text,
        createdAt: DateTime.now(),
      );

      await _bookingService.createBooking(booking);

      if (mounted) {
        SuccessDialog.show(
          context,
          title: 'Booking Successful!',
          message:
              'A ${widget.serviceType} request has been sent to the provider.',
          onPressed: () {
            Navigator.of(context).pop(); // Pop dialog
            Navigator.of(context).pop(); // Pop booking screen
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: Text('Book ${widget.serviceType}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceHeader(),
            const SizedBox(height: 32),
            _buildSectionTitle('Choose a Provider', isDark),
            const SizedBox(height: 12),
            _buildProviderSelector(isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('Service Location', isDark),
            const SizedBox(height: 12),
            _buildAddressField(isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('Preferred Schedule', isDark),
            const SizedBox(height: 12),
            _buildDateTimePicker(isDark),
            const SizedBox(height: 40),
            _buildPricingBreakdown(isDark),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
      ),
    );
  }

  Widget _buildServiceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            widget.serviceType == 'Towing'
                ? Icons.car_repair
                : Icons.cleaning_services,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.serviceType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Professional & Reliable',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(bool isDark) {
    if (_loadingProviders) return const LinearProgressIndicator();
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProviderId,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
          onChanged: (val) {
            setState(() => _selectedProviderId = val);
            _updateEstimatedPrice();
          },
          items: _availableProviders
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 18,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        p.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textSlateDark,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildAddressField(bool isDark) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: TextField(
        controller: _addressController,
        style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark),
        decoration: InputDecoration(
          hintText: 'Detecting location...',
          prefixIcon: const Icon(
            Icons.location_on,
            color: AppTheme.primaryBlue,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (d != null) {
                setState(() => _selectedDate = d);
                _updateEstimatedPrice();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(DateFormat('MMM dd').format(_selectedDate)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (t != null) {
                setState(() => _selectedTime = t);
                _updateEstimatedPrice();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(_selectedTime.format(context)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingBreakdown(bool isDark) {
    final basePrice = PricingConfig.getBasePrice(widget.serviceType);
    final surcharge = _estimatedCost - basePrice;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Base Rate (${widget.serviceType})',
                style: const TextStyle(fontSize: 14),
              ),
              Text('₱${basePrice.toStringAsFixed(2)}'),
            ],
          ),
          if (surcharge > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distance Surcharge',
                  style: TextStyle(fontSize: 14),
                ),
                Text('+ ₱${surcharge.toStringAsFixed(2)}'),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '₱${_estimatedCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitBooking,
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
                'Confirm Booking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
