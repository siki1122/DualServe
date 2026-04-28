import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:household_towing_app/services/task_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/utils/form_validators.dart';
import 'package:household_towing_app/utils/error_handler.dart';
import 'package:household_towing_app/services/logging_service.dart';
import 'customer_service_tracking_screen.dart';

class RequestServiceScreen extends StatefulWidget {
  const RequestServiceScreen({super.key});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final TaskService _taskService = TaskService();
  final _formKey = GlobalKey<FormState>();

  String _serviceType = 'Towing';
  String? _location;
  double? _latitude;
  double? _longitude;
  String? _vehicleType;
  String? _description;
  TaskPriority _priority = TaskPriority.medium;

  bool _isLoading = false;
  bool _detectingLocation = false;

  final List<String> _serviceTypes = [
    'Towing',
    'Jump Start',
    'Lockout',
    'Fuel Delivery',
    'Tire Change',
    'Battery Replacement',
  ];

  final List<String> _vehicleTypes = [
    'Car',
    'SUV',
    'Truck',
    'Van',
    'Motorcycle',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _detectLocationAutomatically();
  }

  Future<void> _detectLocationAutomatically() async {
    setState(() => _detectingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _location =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      Logger.error('Failed to get location', e);
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Location Error');
      }
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  Future<void> _requestService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null || _latitude == null || _longitude == null) {
      ErrorHandler.showInfo(context, 'Please enable location services and try again');
      return;
    }

    if (_vehicleType == null) {
      ErrorHandler.showInfo(context, 'Please select a vehicle type');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ErrorHandler.showError(context, Exception('User not logged in'));
        return;
      }

      final task = Task(
        id: '', // Firestore generates
        customerId: user.uid,
        serviceType: _serviceType,
        location: _location!,
        latitude: _latitude!,
        longitude: _longitude!,
        scheduledDate: DateTime.now(), // Immediate service
        description: 'Vehicle: $_vehicleType\n${_description ?? 'No description'}',
        priority: _priority,
        status: TaskStatus.unassigned,
        createdAt: DateTime.now(),
      );

      final taskId = await _taskService.createTask(task);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Service requested successfully!');

        // Navigate to tracking screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CustomerServiceTrackingScreen(taskId: taskId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Failed to request service');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: const Text('Request Service'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fill in your details to request service',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Service Type
              const Text(
                'What service do you need?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSlateLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  value: _serviceType,
                  onChanged: (value) =>
                      setState(() => _serviceType = value ?? 'Towing'),
                  items: _serviceTypes
                      .map(
                        (service) => DropdownMenuItem(
                          value: service,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(service),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle Type
              const Text(
                'Vehicle Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSlateLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Select vehicle type'),
                  ),
                  value: _vehicleType,
                  onChanged: (value) => setState(() => _vehicleType = value),
                  items: _vehicleTypes
                      .map(
                        (vehicle) => DropdownMenuItem(
                          value: vehicle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(vehicle),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Location
              const Text(
                'Your Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSlateLight),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _location ?? 'Detecting location...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textSlateDark,
                            ),
                          ),
                          if (_detectingLocation)
                            const SizedBox(
                              height: 4,
                              child: Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Getting your GPS location...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSlateMedium,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_detectingLocation)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _detectLocationAutomatically,
                        tooltip: 'Refresh location',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Priority
              const Text(
                'How urgent is this?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: TaskPriority.values.map((priority) {
                  final isSelected = _priority == priority;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = priority),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getPriorityColor(priority)
                              : (isDark ? AppTheme.surfaceDark : Colors.white),
                          border: Border.all(
                            color: _getPriorityColor(priority),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priority.toString().split('.').last[0].toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSlateMedium,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Describe the issue (optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlateDark,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., Engine won\'t start, flat tire, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                onChanged: (value) => _description = value,
              ),
              const SizedBox(height: 24),

              // Request Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    disabledBackgroundColor: AppTheme.textSlateMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading ? const SizedBox() : const Icon(Icons.send),
                  label: _isLoading
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
                          'Request Service Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A provider will be assigned shortly. You\'ll receive a notification with their details.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textSlateMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return AppTheme.primaryBlue;
      case TaskPriority.medium:
        return AppTheme.towingOrange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.red.shade900;
    }
  }
}
