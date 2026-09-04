import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:household_towing_app/models/asset_model.dart';
import 'package:household_towing_app/models/provider_model.dart';
import 'package:household_towing_app/models/driver_model.dart';
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/services/asset_service.dart';
import 'package:household_towing_app/providers/user_provider.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:household_towing_app/utils/app_theme.dart';
import 'package:household_towing_app/utils/error_handler.dart';
import 'package:household_towing_app/models/task_model.dart';
import 'package:intl/intl.dart';

class BookingAssetAssignmentScreen extends StatefulWidget {
  final Booking booking;

  const BookingAssetAssignmentScreen({super.key, required this.booking});

  @override
  State<BookingAssetAssignmentScreen> createState() =>
      _BookingAssetAssignmentScreenState();
}

class _BookingAssetAssignmentScreenState
    extends State<BookingAssetAssignmentScreen> {
  final BookingService _bookingService = BookingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TruckType? _selectedTruckType;
  String? _selectedTruckId;
  final List<String> _selectedCrewIds = [];
  final Map<String, int> _selectedAssets = {};
  String? _selectedDriverId;
  List<AssetModel> _availableTrucks = [];
  List<AssetModel> _availableCrew = [];
  List<AssetModel> _availableAssets = [];
  List<Driver> _availableDrivers = [];
  Map<String, List<Task>> _driverSchedules = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableAssets();
  }

  Future<void> _loadAvailableAssets() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Load trucks
      // Show trucks that are either unassigned or assigned to this provider
      final trucksSnapshot = await _firestore
          .collection('assets')
          .where('type', isEqualTo: 'vehicle')
          .where('status', whereIn: ['active', 'inUse']).get();

      final trucks = trucksSnapshot.docs
          .map((doc) => AssetModel.fromFirestore(doc))
          .where((asset) => asset.assignedTo == uid || (asset.assignedTo == null && (asset.ownerId == uid || asset.ownerId == null)))
          .toList();

      // Load other assets (tools, equipment, crew)
      final assetsSnapshot = await _firestore
          .collection('assets')
          .where('type', whereIn: ['tool', 'equipment', 'crew'])
          .where('status', whereIn: ['active', 'inUse']).get();

      final assets = assetsSnapshot.docs
          .map((doc) => AssetModel.fromFirestore(doc))
          .where((asset) => asset.assignedTo == uid || (asset.assignedTo == null && (asset.ownerId == uid || asset.ownerId == null)))
          .toList();

      // Load drivers
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('providerId', isEqualTo: uid)
          .where('status', isEqualTo: 'available')
          .get();
      
      final drivers = driversSnapshot.docs
          .map((doc) => Driver.fromFirestore(doc))
          .toList();

      // Load active tasks for these drivers to show their schedule
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignedProviderId', isEqualTo: uid)
          .where('status', whereNotIn: ['completed', 'cancelled'])
          .get();
          
      final Map<String, List<Task>> schedules = {};
      for (var doc in tasksSnapshot.docs) {
        final task = Task.fromFirestore(doc);
        if (task.assignedDriverId != null && task.assignedDriverId!.isNotEmpty) {
          schedules.putIfAbsent(task.assignedDriverId!, () => []).add(task);
        }
      }

      if (mounted) {
        setState(() {
          _availableTrucks = trucks;
          _availableAssets = assets;
          _availableDrivers = drivers;
          _driverSchedules = schedules;
          _availableCrew = assets.where((a) => a.type == AssetType.crew).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e,
            title: 'Failed to load assets');
        setState(() => _isLoading = false);
      }
    }
  }

  final AssetService _assetService = AssetService();
  
  Future<void> _submitAssignment() async {
    if (_selectedTruckType == null) {
      ErrorHandler.showError(context, Exception('Please select a truck type'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final List<AssetModel> selectedTools = _availableAssets
          .where((a) => _selectedAssets.containsKey(a.id))
          .toList();
      final List<AssetModel> selectedCrew = _availableCrew
          .where((p) => _selectedCrewIds.contains(p.id))
          .toList();
      final AssetModel? selectedTruck = _selectedTruckId != null
          ? _availableTrucks.firstWhere((a) => a.id == _selectedTruckId)
          : null;

      // Get provider name from provider state
      final userProvider = provider_pkg.Provider.of<UserProvider>(context, listen: false);
      final providerName = userProvider.userProfile?['name'] ?? 'Provider';

      // Use AssetService to handle logging, inventory deduction and parent update
      await _assetService.logResourceUsage(
        providerId: FirebaseAuth.instance.currentUser!.uid,
        providerName: providerName,
        bookingId: widget.booking.id,
        taskLabel: '${widget.booking.serviceType} at ${widget.booking.address}',
        vehicle: selectedTruck,
        tools: selectedTools.where((a) => a.type == AssetType.tool).toList(),
        equipment: selectedTools.where((a) => a.type == AssetType.equipment).toList(),
        crew: selectedCrew,
        assetQuantities: _selectedAssets,
      );

      // Save the driver ID directly to the booking
      if (_selectedDriverId != null) {
        await _firestore.collection('bookings').doc(widget.booking.id).update({
          'assignedDriverId': _selectedDriverId,
        });
      }

      if (mounted) {
        ErrorHandler.showSuccess(context, '✓ Assets assigned successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, title: 'Failed to assign assets');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assign Assets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Assign Assets & Personnel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSlateDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Select Truck Type'),
            const SizedBox(height: 12),
            _buildTruckTypeSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Select Truck Vehicle'),
            const SizedBox(height: 12),
            _buildTruckSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Assign App Driver (Optional)'),
            const SizedBox(height: 12),
            _buildDriverSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Assign Extra Personnel'),
            const SizedBox(height: 12),
            _buildPersonnelSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Select Equipment & Tools'),
            const SizedBox(height: 12),
            _buildAssetSelector(),
            const SizedBox(height: 32),
            _buildSummary(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.towingOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirm Assignment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSlateDark,
      ),
    );
  }

  Widget _buildTruckTypeSelector() {
    return Wrap(
      spacing: 8,
      children: TruckType.values.map((type) {
        final isSelected = _selectedTruckType == type;
        return FilterChip(
          selected: isSelected,
          label: Text(
            type.name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSlateMedium,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          backgroundColor: Colors.white,
          selectedColor: AppTheme.towingOrange,
          onSelected: (selected) {
            setState(() => _selectedTruckType = selected ? type : null);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTruckSelector() {
    if (_availableTrucks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No trucks available'),
      );
    }

    return Column(
      children: _availableTrucks.map((truck) {
        final isSelected = _selectedTruckId == truck.id;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedTruckId = isSelected ? null : truck.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.towingOrange.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppTheme.towingOrange : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => setState(
                      () => _selectedTruckId = value! ? truck.id : null),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (truck.plateNumber != null)
                        Text(
                          'Plate: ${truck.plateNumber}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonnelSelector() {
    if (_availableCrew.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No crew available'),
      );
    }

    return Column(
      children: _availableCrew.map((person) {
        final isSelected = _selectedCrewIds.contains(person.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCrewIds.remove(person.id);
              } else {
                _selectedCrewIds.add(person.id);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value!) {
                        _selectedCrewIds.add(person.id);
                      } else {
                        _selectedCrewIds.remove(person.id);
                      }
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        person.category, // Assuming category stores the role
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDriverSelector() {
    if (_availableDrivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No drivers available online'),
      );
    }

    return Column(
      children: _availableDrivers.map((driver) {
        final isSelected = _selectedDriverId == driver.id;
        final schedule = _driverSchedules[driver.id] ?? [];
        final hasConflict = schedule.any((t) => 
          t.scheduledDate.year == widget.booking.scheduledDate.year &&
          t.scheduledDate.month == widget.booking.scheduledDate.month &&
          t.scheduledDate.day == widget.booking.scheduledDate.day
        );

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDriverId = isSelected ? null : driver.id;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : (hasConflict ? Colors.red.shade300 : Colors.grey.shade300),
                width: isSelected || hasConflict ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<String?>(
                  value: driver.id,
                  groupValue: _selectedDriverId,
                  onChanged: (value) {
                    setState(() {
                      _selectedDriverId = value;
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            driver.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (hasConflict)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Has booking on this day',
                                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                        ],
                      ),
                      Text(
                        'Phone: ${driver.phone}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                      ),
                      if (schedule.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Upcoming Schedule:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSlateDark),
                        ),
                        const SizedBox(height: 4),
                        ...schedule.take(3).map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: AppTheme.textSlateMedium),
                              const SizedBox(width: 4),
                              Text(
                                '${DateFormat('MMM d').format(t.scheduledDate)} at ${DateFormat('h:mm a').format(t.scheduledDate)} - ${t.status.name.toUpperCase()}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSlateMedium),
                              ),
                            ],
                          ),
                        )),
                        if (schedule.length > 3)
                          Text(
                            '+ ${schedule.length - 3} more tasks',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontStyle: FontStyle.italic),
                          )
                      ] else ...[
                         const SizedBox(height: 8),
                         const Text(
                           'No upcoming tasks assigned.',
                           style: TextStyle(fontSize: 12, color: Colors.green, fontStyle: FontStyle.italic),
                         ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssetSelector() {
    if (_availableAssets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No assets available'),
      );
    }

    return Column(
      children: _availableAssets.map((asset) {
        final selectedQty = _selectedAssets[asset.id] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selectedQty > 0 ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.white,
            border: Border.all(
              color: selectedQty > 0 ? AppTheme.primaryBlue : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Available: ${asset.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSlateMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: selectedQty > 0
                        ? () {
                            setState(() {
                              if (_selectedAssets[asset.id]! > 1) {
                                _selectedAssets[asset.id] =
                                    _selectedAssets[asset.id]! - 1;
                              } else {
                                _selectedAssets.remove(asset.id);
                              }
                            });
                          }
                        : null,
                  ),
                  Text(
                    selectedQty.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: selectedQty < asset.quantity
                        ? () {
                            setState(() {
                              _selectedAssets[asset.id] =
                                  (selectedQty) + 1;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assignment Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textSlateDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'Truck Type',
            _selectedTruckType?.name.toUpperCase() ?? 'Not selected',
          ),
          _buildSummaryItem(
            'Truck',
            _selectedTruckId != null
                ? (_availableTrucks
                    .firstWhere((t) => t.id == _selectedTruckId)
                    .name)
                : 'Not selected',
          ),
          _buildSummaryItem(
            'App Driver',
            _selectedDriverId != null
                ? (_availableDrivers
                    .firstWhere((d) => d.id == _selectedDriverId)
                    .name)
                : 'None assigned',
          ),
          _buildSummaryItem(
            'Extra Crew',
            _selectedCrewIds.isEmpty
                ? 'None'
                : '${_selectedCrewIds.length} selected',
          ),
          _buildSummaryItem(
            'Equipment',
            _selectedAssets.isEmpty
                ? 'None'
                : '${_selectedAssets.length} types selected',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSlateMedium),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textSlateDark,
            ),
          ),
        ],
      ),
    );
  }
}
