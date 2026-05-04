import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset_model.dart';
import '../models/provider_model.dart';
import '../models/task_model.dart';
import '../services/asset_service.dart';
import '../utils/app_theme.dart';

class AssetSelectionDialog extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Task? preselectedTask;

  const AssetSelectionDialog({
    super.key,
    required this.providerId,
    required this.providerName,
    this.preselectedTask,
  });

  @override
  State<AssetSelectionDialog> createState() => _AssetSelectionDialogState();
}

class _AssetSelectionDialogState extends State<AssetSelectionDialog> {
  final AssetService _assetService = AssetService();
  final crewController = TextEditingController(text: '1');
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String? selectedVehicleId;
  String? selectedDriverId;
  String? selectedDriverName;
  final selectedToolIds = <String>{};
  final selectedEquipmentIds = <String>{};
  List<Provider> _teamMembers = [];
  bool _isLoadingTeam = true;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      List<Provider> personnel = [];

      // Always add the current provider to the list
      personnel.add(Provider(
        id: widget.providerId,
        name: widget.providerName,
        email: '', // Not needed for selection
        phone: '',
        specialty: 'Primary Provider',
        serviceType: '',
        createdAt: DateTime.now(),
      ));

      if (providerDoc.exists) {
        final personnelIds =
            List<String>.from(providerDoc.data()?['teamMembers'] ?? []);

        for (String memberId in personnelIds) {
          if (memberId == widget.providerId) continue;
          final memberDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(memberId)
              .get();
          if (memberDoc.exists) {
            final data = memberDoc.data()!;
            personnel.add(Provider(
              id: memberId,
              name: data['name'] ?? 'Unknown',
              email: data['email'] ?? '',
              phone: data['phone'] ?? '',
              specialty: data['specialty'] ?? 'Team Member',
              serviceType: data['serviceType'] ?? '',
              createdAt: DateTime.now(),
            ));
          }
        }
      }
      if (mounted) {
        setState(() {
          _teamMembers = personnel;
          _isLoadingTeam = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team: $e');
      if (mounted) setState(() => _isLoadingTeam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AssetModel>>(
      stream: _assetService.getAssets(),
      builder: (context, assetSnapshot) {
        if (assetSnapshot.connectionState == ConnectionState.waiting && _isLoadingTeam) {
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
        final relevantAssets = allAssets.where((asset) => 
          asset.assignedTo == widget.providerId || 
          (asset.assignedTo == null && asset.status == AssetStatus.active)
        ).toList();

        final vehicles = relevantAssets
            .where((asset) => asset.type == AssetType.vehicle)
            .toList();
        final tools = relevantAssets
            .where((asset) => asset.type == AssetType.tool)
            .toList();
        final equipment = relevantAssets
            .where((asset) => asset.type == AssetType.equipment)
            .toList();

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                widget.preselectedTask != null ? Icons.assignment_outlined : Icons.inventory_2_outlined,
                color: AppTheme.towingOrange,
              ),
              const SizedBox(width: 12),
              Text(
                widget.preselectedTask != null ? 'Assign Assets' : 'Resource Management',
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.towingOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.towingOrange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt, color: AppTheme.towingOrange, size: 20),
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
                    if (_teamMembers.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedDriverId,
                        decoration: const InputDecoration(
                          labelText: 'Primary driver',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        hint: const Text('Select driver'),
                        items: _teamMembers
                            .map(
                              (person) => DropdownMenuItem(
                                value: person.id,
                                child: Text(person.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDriverId = value;
                            selectedDriverName = _teamMembers
                                .firstWhere((p) => p.id == value)
                                .name;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a driver' : null,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Crew count
                    TextFormField(
                      controller: crewController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Crew count',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      validator: (value) {
                        final count = int.tryParse(value ?? '');
                        if (count == null || count < 1) {
                          return 'Enter at least 1 crew member';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Truck selection
                    DropdownButtonFormField<String>(
                      value: selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Truck to use',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping_outlined),
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
                      validator: (value) => value == null ? 'Please select a truck' : null,
                    ),
                    const SizedBox(height: 14),

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
                      decoration: const InputDecoration(
                        labelText: 'Task Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Any specific instructions or gear used...',
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final vehicle = relevantAssets.firstWhere((a) => a.id == selectedVehicleId);
                final selectedTools = tools
                    .where((asset) => selectedToolIds.contains(asset.id))
                    .toList();
                final selectedEquipment = equipment
                    .where((asset) => selectedEquipmentIds.contains(asset.id))
                    .toList();

                try {
                  await _assetService.logResourceUsage(
                    providerId: widget.providerId,
                    providerName: widget.providerName,
                    driverId: selectedDriverId,
                    driverName: selectedDriverName,
                    taskId: widget.preselectedTask?.id,
                    bookingId: widget.preselectedTask?.bookingId,
                    taskLabel: widget.preselectedTask != null 
                        ? '${widget.preselectedTask!.serviceType} at ${widget.preselectedTask!.location}'
                        : null,
                    crewCount: int.parse(crewController.text),
                    vehicle: vehicle,
                    tools: selectedTools,
                    equipment: selectedEquipment,
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
                backgroundColor: AppTheme.towingOrange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                widget.preselectedTask != null ? 'Confirm & Save' : 'Log Resource Usage',
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
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
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
}
