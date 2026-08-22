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
import 'customer_active_bookings_screen.dart';
import 'package:household_towing_app/utils/service_templates.dart';
import 'complex_service_sheet.dart';

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
  final _barangayController = TextEditingController();
  final _zoneController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();
  String? _issueCategory;
  final BookingService _bookingService = BookingService();
  final ProviderService _providerService = ProviderService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;
  double _estimatedCost = 0;
  String? _selectedProviderId;
  String? _selectedSubService;
  String? _problemCategory;
  Map<String, double> _offeredServices = {};
  Map<String, dynamic> _rawOfferedServices = {};
  Map<String, dynamic>? _complexDetails;
  List<Provider> _availableProviders = [];
  bool _loadingProviders = true;
  double? _userLat;
  double? _userLng;
  late final String _serviceType;

  // Geocoding optimization
  Timer? _geocodingTimer;
  int _geocodingRequestCount = 0;
  static const int _maxGeocodingRequests = 5; // Max 5 requests per minute
  static const Duration _geocodingThrottle = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _serviceType = PricingConfig.normalizeServiceType(widget.serviceType);
    // Use today for towing and tomorrow for scheduled household services.
    if (_serviceType == PricingConfig.towingService) {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    // Initial price calculation
    _estimatedCost = PricingConfig.getBasePrice(_serviceType);

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
    _barangayController.dispose();
    _zoneController.dispose();
    _landmarkController.dispose();
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
      } else {
        throw Exception('Permission denied');
      }
    } catch (e) {
      Logger.error('Location detection failed', e);
      if (mounted) {
        String message = 'Could not detect your location. Please enter address manually.';
        if (e.toString().contains('denied')) {
          message = 'Location permissions are denied. Please enable them in settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.towingOrange,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _detectCurrentLocation,
            ),
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

    // 2. Determine base price (custom from provider OR system default)
    double baseRate = 0.0;
    final bool isComplex = ServiceTemplates.defaultTemplates.containsKey(_serviceType);

    if (isComplex) {
      final def = ServiceTemplates.getDefinition(_serviceType, _rawOfferedServices[_serviceType]);
      baseRate = ServiceTemplates.calculatePrice(def, _complexDetails, 1);
    } else {
      baseRate = PricingConfig.getBasePrice(_serviceType);
      if (_selectedSubService != null && _offeredServices.containsKey(_selectedSubService)) {
        baseRate = _offeredServices[_selectedSubService]!;
      }
    }

    // 3. Use the specialized PricingConfig to get the final cost
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      // Calculate total cost (Base + Night Diff + Distance)
      final nightDiff = PricingConfig.calculateNightDifferential(baseRate, scheduledDateTime);
      final distanceSurcharge = PricingConfig.calculateDistanceSurcharge(distance);
      
      _estimatedCost = baseRate + nightDiff + distanceSurcharge;
    });
  }

  Future<void> _loadAvailableProviders() async {
    try {
      final providers = await _providerService.getProvidersByServiceType(
        _serviceType,
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
        
        // Load offered services for the selected provider
        if (_selectedProviderId != null) {
          final selectedProv = _availableProviders.firstWhere((p) => p.id == _selectedProviderId);
          _rawOfferedServices = selectedProv.offeredServices;
          _offeredServices = {};
          selectedProv.offeredServices.forEach((k, v) {
            if (v is num) {
              _offeredServices[k] = v.toDouble();
            } else {
              _offeredServices[k] = 0.0;
            }
          });
          if (_offeredServices.isNotEmpty) {
            _selectedSubService = _offeredServices.keys.first;
          } else {
            _selectedSubService = 'General $_serviceType';
          }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all details')),
      );
      return;
    }

    if (_userLat == null || _userLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for location to be verified on the map.')),
      );
      return;
    }

    if (_isLoading) return; // Spam protection

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
        serviceType: _serviceType,
        specificService: _selectedSubService,
        serviceDetails: _complexDetails,
        status: BookingStatus.pending,
        scheduledDate: _selectedDate,
        scheduledTime: timeStr,
        address: _addressController.text,
        barangay: _barangayController.text.isNotEmpty ? _barangayController.text : null,
        zone: _zoneController.text.isNotEmpty ? _zoneController.text : null,
        landmarkDescription: _landmarkController.text.isNotEmpty ? _landmarkController.text : null,
        problemCategory: _problemCategory,
        issueCategory: _issueCategory,
        estimatedCost: _estimatedCost,
        notes: _notesController.text,
        createdAt: DateTime.now(),
      );

      await _bookingService.createBooking(booking);

      if (mounted) {
        SuccessDialog.show(
          context,
          title: 'Booking Successful!',
          message: 'A $_serviceType request has been sent to the provider.',
          onPressed: () {
            Navigator.of(context).pop(); // Pop dialog
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const CustomerActiveBookingsScreen(),
              ),
            );
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
      appBar: AppBar(title: Text('Book $_serviceType'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServiceHeader(),
                const SizedBox(height: 32),
                _buildSectionTitle('Choose a Provider', isDark),
                const SizedBox(height: 12),
                _buildProviderSelector(isDark),
                const SizedBox(height: 24),
                _buildSectionTitle('Select Specific Service', isDark),
                const SizedBox(height: 12),
                _buildSubServiceSelector(isDark),
                const SizedBox(height: 32),
                _buildSectionTitle('Service Location', isDark),
                const SizedBox(height: 12),
                _buildAddressField(isDark),
                const SizedBox(height: 12),
                _buildDetailedAddressFields(isDark),
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
            _serviceType == PricingConfig.towingService
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
                _serviceType,
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
    if (_availableProviders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Text(
          'No available $_serviceType providers right now. Please try again later.',
          style: TextStyle(
            color: isDark
                ? AppTheme.textDarkSecondary
                : AppTheme.textSlateMedium,
          ),
        ),
      );
    }
    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProviderId,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
          onChanged: (val) {
            setState(() {
              _selectedProviderId = val;
              if (val != null) {
                final selectedProv = _availableProviders.firstWhere((p) => p.id == val);
                _offeredServices = {};
                selectedProv.offeredServices.forEach((k, v) {
                  if (v is num) {
                    _offeredServices[k] = v.toDouble();
                  } else {
                    _offeredServices[k] = 0.0;
                  }
                });
                if (_offeredServices.isNotEmpty) {
                  _selectedSubService = _offeredServices.keys.first;
                } else {
                  _selectedSubService = 'General $_serviceType';
                }
              }
            });
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

  Widget _buildSubServiceSelector(bool isDark) {
    final bool isComplex = ServiceTemplates.defaultTemplates.containsKey(_serviceType);

    if (isComplex) {
      return Container(
        width: double.infinity,
        decoration: AppTheme.cardDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton.icon(
          onPressed: () async {
            final def = ServiceTemplates.getDefinition(_serviceType, _rawOfferedServices[_serviceType]);
            final details = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ComplexServiceSheet(
                serviceName: _serviceType,
                serviceDef: def,
                initialDetails: _complexDetails,
              ),
            );
            
            if (details != null && mounted) {
              setState(() {
                _complexDetails = details;
              });
              _updateEstimatedPrice();
            }
          },
          icon: const Icon(Icons.settings),
          label: Text(
            _complexDetails == null ? 'Configure Service Details' : 'Edit Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _complexDetails == null ? AppTheme.primaryBlue : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final List<String> items = _offeredServices.isEmpty 
        ? ['General $_serviceType'] 
        : _offeredServices.keys.toList();

    // Ensure current selection is in the list
    if (!items.contains(_selectedSubService)) {
      _selectedSubService = items[0];
    }

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubService,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
          onChanged: (val) {
            setState(() => _selectedSubService = val);
            _updateEstimatedPrice();
          },
          items: items
              .map(
                (service) => DropdownMenuItem(
                  value: service,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.handyman_outlined,
                        size: 18,
                        color: AppTheme.towingOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          service,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textSlateDark,
                          ),
                        ),
                      ),
                      if (_offeredServices.containsKey(service))
                        Text(
                          '₱${_offeredServices[service]?.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
          suffixIcon: _addressController.text.isNotEmpty && (_userLat == null)
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
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
    double currentBase = PricingConfig.getBasePrice(_serviceType);
    if (_selectedSubService != null && _offeredServices.containsKey(_selectedSubService)) {
      currentBase = _offeredServices[_selectedSubService]!;
    }
    final surcharge = _estimatedCost - currentBase;

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
              Expanded(
                child: Text(
                  'Base Rate (${_selectedSubService ?? _serviceType})',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(PricingConfig.formatPrice(currentBase)),
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
                Text('+ ${PricingConfig.formatPrice(surcharge)}'),
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
                PricingConfig.formatPrice(_estimatedCost),
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

  Widget _buildDetailedAddressFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _barangayController,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Barangay (Optional)',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: AppTheme.cardDecoration(context),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _zoneController,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Zone/Subdivision',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _landmarkController,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Nearby Landmarks / Description',
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text('Select Issue Category (Optional)', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 14)),
              value: _issueCategory,
              dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
              onChanged: (val) => setState(() => _issueCategory = val),
              items: ['Engine Issue', 'Flat Tire', 'Electrical', 'Plumbing', 'Cleaning', 'Other']
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark, fontSize: 14))))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text('Damaged Parts Category (Optional)', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 14)),
              value: _problemCategory,
              dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
              onChanged: (val) => setState(() => _problemCategory = val),
              items: ['Engine', 'Transmission', 'Suspension & Steering', 'Brakes', 'Electrical & Battery', 'Body & Glass', 'Tires & Wheels', 'Other']
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: TextStyle(color: isDark ? Colors.white : AppTheme.textSlateDark, fontSize: 14))))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
