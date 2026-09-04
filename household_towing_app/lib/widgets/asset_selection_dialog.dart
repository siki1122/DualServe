import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/booking_model.dart';
import '../models/task_model.dart';
import '../services/booking_service.dart';
import '../services/asset_service.dart';
import '../utils/app_theme.dart';

class AssetSelectionDialog extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Task? preselectedTask;
  final Booking? preselectedBooking;
  final bool isEmployeeContext;

  const AssetSelectionDialog({
    super.key,
    required this.providerId,
    required this.providerName,
    this.preselectedTask,
    this.preselectedBooking,
    this.isEmployeeContext = false,
  });

  @override
  State<AssetSelectionDialog> createState() => _AssetSelectionDialogState();
}

class _AssetSelectionDialogState extends State<AssetSelectionDialog> {
  final AssetService _assetService = AssetService();
  final BookingService _bookingService = BookingService();
  final crewController = TextEditingController(text: '1');
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String? selectedVehicleId;
  String? selectedDriverId;
  final selectedToolIds = <String>{};
  final selectedEquipmentIds = <String>{};
  final selectedCrewIds = <String>{};

  late Stream<List<AssetModel>> _assetsStream;

  @override
  void initState() {
    super.initState();
    _assetsStream = _assetService.getAssets();
    if (widget.isEmployeeContext && widget.preselectedTask != null) {
      selectedDriverId = widget.preselectedTask!.assignedDriverId;
      selectedVehicleId = widget.preselectedTask!.assignedTruckId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AssetModel>>(
      stream: _assetsStream,
      builder: (context, assetSnapshot) {
        if (assetSnapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading assets...'),
              ],
            ),
          );
        }

        final allAssets = assetSnapshot.data ?? [];
        // Show assets assigned to this provider OR unassigned active assets
        // ONLY show if active, or if already inUse BY THIS SPECIFIC TASK
        final relevantAssets = allAssets.where((asset) => 
          (asset.assignedTo == widget.providerId && (asset.status == AssetStatus.active || asset.currentTaskId == widget.preselectedTask?.id)) || 
          (asset.assignedTo == null && asset.status == AssetStatus.active && (asset.ownerId == widget.providerId || asset.ownerId == null))
        ).toList();

        // Determine if this is a household/cleaning service (no truck required)
        final serviceType = (widget.preselectedBooking?.serviceType ?? widget.preselectedTask?.serviceType ?? '').toLowerCase();
        final isTowingService = serviceType.contains('towing') || serviceType.contains('tow');

        final vehicles = relevantAssets
            .where((asset) => asset.type == AssetType.vehicle)
            .toList();
        final tools = relevantAssets
            .where((asset) => asset.type == AssetType.tool)
            .toList();
        final equipment = relevantAssets
            .where((asset) => asset.type == AssetType.equipment)
            .toList();
        final drivers = relevantAssets
            .where((asset) => asset.type == AssetType.crew && asset.category.toLowerCase() == 'driver')
            .toList();
        final helpers = relevantAssets
            .where((asset) => asset.type == AssetType.crew && asset.category.toLowerCase() != 'driver')
            .toList();

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                widget.preselectedTask != null || widget.preselectedBooking != null ? Icons.assignment_outlined : Icons.inventory_2_outlined,
                color: AppTheme.towingOrange,
              ),
              const SizedBox(width: 12),
              Text(
                widget.preselectedTask != null || widget.preselectedBooking != null ? 'Assign Assets' : 'Resource Management',
                style: TextStyle(
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.preselectedTask != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.primaryBlue.withValues(alpha: 0.1) : AppTheme.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt, color: AppTheme.primaryBlue, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.preselectedTask!.serviceType,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    widget.preselectedTask!.location,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Driver selection
                    if (isTowingService) ...[
                      if (widget.isEmployeeContext && widget.preselectedTask != null)
                        _buildReadOnlyField(
                          context,
                          label: 'Assigned Driver',
                          value: widget.preselectedTask!.assignedDriverName ?? 'No driver assigned',
                          icon: Icons.airline_seat_recline_normal,
                          isDark: isDark,
                        )
                      else
                        DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: drivers.any((d) => d.id == selectedDriverId) ? selectedDriverId : null,
                        decoration: InputDecoration(
                          labelText: 'Assigned Driver',
                          labelStyle: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                          prefixIcon: Icon(Icons.airline_seat_recline_normal, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        ),
                        hint: drivers.isEmpty
                            ? const Text('No drivers available')
                            : const Text('Select driver'),
                        items: drivers
                            .map(
                              (asset) => DropdownMenuItem(
                                value: asset.id,
                                child: Text(asset.name),
                              ),
                            )
                            .toList(),
                        onChanged: drivers.isEmpty
                            ? null
                            : (value) => setState(() => selectedDriverId = value),
                        validator: (value) => (!isTowingService || value != null) ? null : 'Please select a driver',
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Helpers selection
                    if (helpers.isNotEmpty) ...[
                      _buildAssetChecklist(
                        title: 'Assigned Crew (Helpers)',
                        assets: helpers,
                        selectedIds: selectedCrewIds,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Truck selection
                    if (isTowingService) ...[
                      if (widget.isEmployeeContext && widget.preselectedTask != null)
                        _buildReadOnlyField(
                          context,
                          label: 'Truck to use',
                          value: widget.preselectedTask!.assignedTruckName ?? 'No truck assigned',
                          icon: Icons.local_shipping_outlined,
                          isDark: isDark,
                        )
                      else
                        DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: vehicles.any((v) => v.id == selectedVehicleId) ? selectedVehicleId : null,
                        decoration: InputDecoration(
                          labelText: 'Truck to use',
                          labelStyle: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                          prefixIcon: Icon(Icons.local_shipping_outlined, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        ),
                        hint: vehicles.isEmpty
                            ? const Text('No trucks assigned to you')
                            : const Text('Select truck'),
                        items: vehicles
                            .map(
                              (asset) => DropdownMenuItem(
                                value: asset.id,
                                child: Text('${asset.name} (${asset.plateNumber ?? 'No plate'})'),
                              ),
                            )
                            .toList(),
                        onChanged: vehicles.isEmpty
                            ? null
                            : (value) => setState(() => selectedVehicleId = value),
                        validator: (value) => (!isTowingService || value != null) ? null : 'Please select a truck',
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Tools & Equipment
                    _buildAssetChecklist(
                      title: 'Tools',
                      assets: tools,
                      selectedIds: selectedToolIds,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildAssetChecklist(
                      title: 'Equipment',
                      assets: equipment,
                      selectedIds: selectedEquipmentIds,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Task Notes',
                        labelStyle: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)),
                        hintText: 'Any specific instructions or gear used...',
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final selectedTools = tools
                    .where((asset) => selectedToolIds.contains(asset.id))
                    .toList();
                final selectedEquipment = equipment
                    .where((asset) => selectedEquipmentIds.contains(asset.id))
                    .toList();
                final selectedCrew = relevantAssets
                    .where((asset) => asset.type == AssetType.crew && (selectedCrewIds.contains(asset.id) || asset.id == selectedDriverId))
                    .toList();

                try {
                  String? taskId = widget.preselectedTask?.id;
                  
                  if (widget.preselectedBooking != null) {
                    // For household services, vehicle/driver are optional
                    final AssetModel? vehicle = selectedVehicleId != null
                        ? relevantAssets.firstWhere((a) => a.id == selectedVehicleId)
                        : null;
                    final AssetModel? driver = selectedDriverId != null
                        ? relevantAssets.firstWhere((a) => a.id == selectedDriverId)
                        : null;

                    taskId = await _bookingService.acceptBooking(
                      widget.preselectedBooking!.id,
                      widget.providerId,
                      truckId: vehicle?.id,
                      truckName: vehicle?.name,
                      driverId: driver?.id,
                      driverName: driver?.name,
                    );
                  }

                  // Get optional vehicle/driver for logging (already retrieved above in booking block)
                  final AssetModel? logVehicle = selectedVehicleId != null
                      ? relevantAssets.firstWhere((a) => a.id == selectedVehicleId)
                      : null;
                  final AssetModel? logDriver = selectedDriverId != null
                      ? relevantAssets.firstWhere((a) => a.id == selectedDriverId)
                      : null;

                  await _assetService.logResourceUsage(
                    providerId: widget.providerId,
                    providerName: widget.providerName,
                    taskId: taskId,
                    bookingId: widget.preselectedTask?.bookingId ?? widget.preselectedBooking?.id,
                    taskLabel: widget.preselectedTask != null 
                        ? '${widget.preselectedTask!.serviceType} at ${widget.preselectedTask!.location}'
                        : (widget.preselectedBooking != null 
                            ? '${widget.preselectedBooking!.serviceType} at ${widget.preselectedBooking!.address}' 
                            : null),
                    driverId: logDriver?.id,
                    driverName: logDriver?.name,
                    vehicle: logVehicle,
                    tools: selectedTools,
                    equipment: selectedEquipment,
                    crew: selectedCrew,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(context, true); // Return true on success
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error logging assets: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                widget.preselectedTask != null ? 'Confirm & Save' : (widget.preselectedBooking != null ? 'Confirm & Accept Booking' : 'Log Resource Usage'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAssetChecklist({
    required String title,
    required List<AssetModel> assets,
    required Set<String> selectedIds,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (assets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'No assigned ${title.toLowerCase()}',
                style: TextStyle(
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...assets.map(
              (asset) => CheckboxListTile(
                dense: true,
                value: selectedIds.contains(asset.id),
                title: Text(asset.name),
                subtitle: Text(asset.category),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      selectedIds.add(asset.id);
                    } else {
                      selectedIds.remove(asset.id);
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(BuildContext context, {required String label, required String value, required IconData icon, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? AppTheme.textDarkSecondary : AppTheme.textSlateMedium, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
