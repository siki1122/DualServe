import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' hide Provider;

import '../../models/asset_model.dart';
import '../../models/provider_model.dart';
import '../../models/task_model.dart';
import '../../providers/user_provider.dart';
import '../../services/asset_service.dart';
import '../../services/task_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/provider_drawer.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:household_towing_app/widgets/status_badge.dart';

class AssetListScreen extends StatefulWidget {
  final String initialFilter;

  const AssetListScreen({super.key, required this.initialFilter});

  @override
  State<AssetListScreen> createState() =>
      _AssetListScreenState();
}

class _AssetListScreenState
    extends State<AssetListScreen> {
  final AssetService _assetService = AssetService();
  final TaskService _taskService = TaskService();
  late String _filter;
  List<Provider> _teamMembers = [];
  bool _isLoadingTeam = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoadingTeam = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final providerDoc =
          await FirebaseFirestore.instance.collection('providers').doc(uid).get();
      
      List<Provider> personnel = [];
      
      // Always add the current provider to the list
      final userProvider = context.read<UserProvider>();
      final providerProfile = userProvider.providerProfile ?? userProvider.userProfile;
      personnel.add(Provider(
        id: uid,
        name: providerProfile?['name'] ?? 'You (Primary)',
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        phone: providerProfile?['phone'] ?? '',
        specialty: providerProfile?['specialty'] ?? 'Provider',
        serviceType: providerProfile?['serviceType'] ?? '',
        createdAt: DateTime.now(),
      ));

      if (providerDoc.exists) {
        final personnelIds =
            List<String>.from(providerDoc.data()?['teamMembers'] ?? []);

        for (String memberId in personnelIds) {
          if (memberId == uid) continue; // Skip if already added
          final memberDoc =
              await FirebaseFirestore.instance.collection('users').doc(memberId).get();
          if (memberDoc.exists) {
            final data = memberDoc.data()!;
            personnel.add(Provider(
              id: memberId,
              name: data['name'] ?? 'Unknown',
              email: data['email'] ?? '',
              phone: data['phone'] ?? '',
              specialty: data['specialty'] ?? '',
              serviceType: data['serviceType'] ?? '',
              createdAt: DateTime.now(),
            ));
          }
        }
      }
      
      // Sync drivers to assets for backwards compatibility
      try {
        final driversSnap = await FirebaseFirestore.instance
            .collection('drivers')
            .where('providerId', isEqualTo: uid)
            .get();
            
        for (var doc in driversSnap.docs) {
          final driverId = doc.id;
          final assetDoc = await FirebaseFirestore.instance.collection('assets').doc(driverId).get();
          if (!assetDoc.exists) {
            await FirebaseFirestore.instance.collection('assets').doc(driverId).set({
              'name': doc.data()['name'] ?? 'Driver',
              'category': 'Driver',
              'type': 'crew',
              'status': 'active',
              'ownerId': uid,
              'quantity': 1,
              'isConsumable': false,
              'jobsCompleted': 0,
              'metadata': {
                'email': doc.data()['email'],
                'phone': doc.data()['phone'],
              }
            });
          }
          
          // Add driver to personnel list for assignment
          if (!personnel.any((p) => p.id == driverId)) {
            personnel.add(Provider(
              id: driverId,
              name: doc.data()['name'] ?? 'Driver',
              email: doc.data()['email'] ?? '',
              phone: doc.data()['phone'] ?? '',
              specialty: 'Driver',
              serviceType: 'Towing',
              createdAt: DateTime.now(),
            ));
          }
        }
      } catch (e) {
        debugPrint('Error syncing drivers: $e');
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
    final providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userProvider = context.watch<UserProvider>();
    final providerName = _getProviderName(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      body: StreamBuilder<List<AssetModel>>(
        stream: _assetService.getAssets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load assets:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final assets = snapshot.data ?? [];
          
          // Ownership filter: Only show assets belonging to this provider or assigned to them
          final myPool = assets.where((asset) {
            return asset.ownerId == providerId || 
                   asset.assignedTo == providerId ||
                   (asset.ownerId == null && asset.providerName != null && asset.assignedTo == providerId);
          }).toList();

          final assignedAssets = myPool
              .where((asset) => asset.assignedTo == providerId)
              .toList();
          final visibleAssets = _filterAssets(myPool, providerId);

          return Column(
            children: [
              AppBar(
                backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
                elevation: 0,
                iconTheme: IconThemeData(
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                ),
                title: Text(
                  '${_filter[0].toUpperCase()}${_filter.substring(1)} Assets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                  ),
                ),
              ),
              Expanded(
                child: _buildInventoryTab(
                  myPool,
                  visibleAssets,
                  assignedAssets,
                  providerId,
                  providerName,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    List<AssetModel> myPool,
    List<AssetModel> assignedAssets,
    String providerId,
    String providerName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Updated filters for accurate metrics
    final availableCount = myPool.where((a) => a.status == AssetStatus.active && a.assignedTo == null).length;
    final assignedCount = assignedAssets.length;
    final truckCount = myPool.where((a) => a.type == AssetType.vehicle).length;
    final equipmentCount = myPool.where((a) => a.type == AssetType.equipment).length;
    final toolsCount = myPool.where((a) => a.type == AssetType.tool).length;
    final driverCount = myPool.where((a) => a.type == AssetType.crew && a.category == 'Driver').length;
    final crewCount = myPool.where((a) => a.type == AssetType.crew && a.category != 'Driver').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitor trucks, tools, equipment, and crew usage',
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openRegisterAssetDialog(providerId, providerName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openUsageDialog(providerId, providerName, assignedAssets),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                    foregroundColor: AppTheme.primaryBlue,
                    elevation: 0,
                    side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.assignment_add, size: 20),
                  label: const Text('Log Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              _buildMetricCard('Available', availableCount.toString(), Icons.inventory_2_outlined, Colors.green),
              _buildMetricCard('Vehicles', truckCount.toString(), Icons.local_shipping_outlined, AppTheme.towingOrange),
              _buildMetricCard('Drivers', driverCount.toString(), Icons.airline_seat_recline_normal, Colors.teal),
              _buildMetricCard('Crew', crewCount.toString(), Icons.engineering_outlined, Colors.purple),
              _buildMetricCard('Equipment', equipmentCount.toString(), Icons.construction, Colors.indigo),
              _buildMetricCard('Tools', toolsCount.toString(), Icons.handyman_outlined, Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine width based on screen size to keep it looking like a nice 2-column grid on mobile
    // but without becoming massive on desktop. Max width of 165 per card.
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 400 ? (screenWidth - 32 - 12) / 2 : 165.0;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: isDark
                  ? AppTheme.textDarkPrimary
                  : AppTheme.textSlateDark,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(
    List<AssetModel> allAssets,
    List<AssetModel> visibleAssets,
    List<AssetModel> assignedAssets,
    String providerId,
    String providerName,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (visibleAssets.isEmpty)
            _buildEmptyState(
              Icons.inventory_2_outlined,
              'No assets found',
              'Try a different filter or ask an admin to register assets.',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: visibleAssets.length,
              itemBuilder: (context, index) {
                final asset = visibleAssets[index];
                return _buildAssetCard(asset, providerId, providerName);
              },
            ),
        ],
      ),
    );
  }


  Widget _buildAssetCard(
    AssetModel asset,
    String providerId,
    String providerName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = asset.assignedTo == providerId;
    final isAvailable =
        asset.status == AssetStatus.active && asset.assignedTo == null;
    final statusInfo = _statusInfo(asset, providerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_assetIcon(asset.type), color: statusInfo.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : AppTheme.textSlateDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _assetSubtitle(asset),
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(statusInfo),
                if (asset.ownerId == providerId || asset.assignedTo == providerId) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Asset',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDeleteAsset(asset),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildDetailPill(
                    Icons.person_outline,
                    isMine
                        ? 'Assigned to you'
                        : asset.providerName ?? 'Unassigned',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDetailPill(
                    Icons.task_alt,
                    '${asset.jobsCompleted} uses',
                  ),
                ),
              ],
            ),
            if (asset.status == AssetStatus.inUse && asset.currentTaskLabel != null) ...[
              const SizedBox(height: 8),
              _buildDetailPill(
                Icons.assignment_ind_outlined,
                'Task: ${asset.currentTaskLabel}',
                color: AppTheme.towingOrange,
              ),
            ],
            if (asset.lastMaintenance != null ||
                asset.nextMaintenance != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (asset.lastMaintenance != null)
                    Expanded(
                      child: _buildDetailPill(
                        Icons.build_outlined,
                        'Last ${DateFormat('MMM d').format(asset.lastMaintenance!)}',
                      ),
                    ),
                  if (asset.lastMaintenance != null &&
                      asset.nextMaintenance != null)
                    const SizedBox(width: 8),
                  if (asset.nextMaintenance != null)
                    Expanded(
                      child: _buildDetailPill(
                        Icons.event_outlined,
                        'Next ${DateFormat('MMM d').format(asset.nextMaintenance!)}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openAssignPersonnelDialog(AssetModel asset) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Assign ${asset.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _teamMembers.length,
              itemBuilder: (context, index) {
                final person = _teamMembers[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  title: Text(person.name),
                  subtitle: Text(person.specialty),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await _assetService.assignAsset(
                        asset.id,
                        person.id,
                        person.name,
                      );
                      _showSnackBar('${asset.name} assigned to ${person.name}');
                    } catch (e) {
                      _showSnackBar('Assignment failed: $e', isError: true);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPill(IconData icon, String label, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = color ?? _secondaryTextColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color != null 
          ? color.withValues(alpha: isDark ? 0.1 : 0.05)
          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color != null 
            ? color.withValues(alpha: 0.3)
            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: displayColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: displayColor,
                fontSize: 12,
                fontWeight: color != null ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(_AssetStatusInfo statusInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusInfo.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        statusInfo.label,
        style: TextStyle(
          color: statusInfo.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUsageLogsTab(String providerId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<AssetUsageLog>>(
      stream: _assetService.getProviderUsageLogs(providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
          );
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return _buildEmptyState(
            Icons.assignment_outlined,
            'No resource usage logged',
            'Use Log Usage to record crew, truck, tools, and equipment per job.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          itemCount: logs.length,
          itemBuilder: (context, index) => _buildUsageLogCard(logs[index]),
        );
      },
    );
  }

  Widget _buildUsageLogCard(AssetUsageLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.taskLabel?.isNotEmpty == true
                          ? log.taskLabel!
                          : 'Resource usage report',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textDarkPrimary
                            : AppTheme.textSlateDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy - h:mm a').format(log.createdAt),
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCrewBadge(log.crewCount),
            ],
          ),
          const SizedBox(height: 14),
          if (log.driverName != null)
            _buildUsageLine(Icons.person_outline, 'Driver', log.driverName!),
          _buildUsageLine(Icons.local_shipping_outlined, 'Truck',
              log.vehicleName ?? 'No truck recorded'),
          _buildUsageLine(
            Icons.handyman_outlined,
            'Tools',
            _formatAssetNames(log.toolNames),
          ),
          _buildUsageLine(
            Icons.construction_outlined,
            'Equipment',
            _formatAssetNames(log.equipmentNames),
          ),
          _buildUsageLine(
            Icons.groups_outlined,
            'Crew',
            _formatAssetNames(log.crewNames),
          ),
          if (log.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              log.notes!,
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrewBadge(int crewCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.towingOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 16, color: AppTheme.towingOrange),
          const SizedBox(width: 4),
          Text(
            '$crewCount',
            style: const TextStyle(
              color: AppTheme.towingOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _secondaryTextColor(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textDarkPrimary
                    : AppTheme.textSlateDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: _secondaryTextColor(context).withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textDarkPrimary
                    : AppTheme.textSlateDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryTextColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimAsset(
    AssetModel asset,
    String providerId,
    String providerName,
  ) async {
    try {
      await _assetService.claimAssetForProvider(asset.id, providerId, providerName);
      _showSnackBar('${asset.name} assigned to you');
    } catch (e) {
      _showSnackBar('Unable to assign asset: $e', isError: true);
    }
  }

  Future<void> _releaseAsset(AssetModel asset, String providerId) async {
    try {
      await _assetService.releaseProviderAsset(asset.id, providerId);
      _showSnackBar('${asset.name} released');
    } catch (e) {
      _showSnackBar('Unable to release asset: $e', isError: true);
    }
  }

  void _confirmDeleteAsset(AssetModel asset) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Asset'),
          content: Text('Are you sure you want to delete "${asset.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _assetService.deleteAsset(asset.id);
                  _showSnackBar('${asset.name} deleted successfully');
                } catch (e) {
                  _showSnackBar('Unable to delete asset: $e', isError: true);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openRegisterAssetDialog(String providerId, String providerName) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final plateController = TextEditingController();
    AssetType selectedType = AssetType.vehicle;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Register Asset', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<AssetType>(
                          isExpanded: true,
                          initialValue: selectedType,
                          decoration: AppTheme.textFieldDecoration(
                            label: 'Asset type',
                            prefixIcon: Icons.category_outlined,
                            isDark: isDark,
                          ),
                          items: AssetType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_assetTypeLabel(type)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedType = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          decoration: AppTheme.textFieldDecoration(
                            label: selectedType == AssetType.vehicle
                                ? 'Vehicle name / unit'
                                : selectedType == AssetType.crew
                                    ? 'Crew name'
                                    : 'Asset name',
                            prefixIcon: _assetIcon(selectedType),
                            isDark: isDark,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter an asset name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: categoryController,
                          decoration: AppTheme.textFieldDecoration(
                            label: selectedType == AssetType.vehicle
                                ? 'Vehicle type'
                                : selectedType == AssetType.crew
                                    ? 'Role / Position'
                                    : 'Category',
                            hint: selectedType == AssetType.vehicle
                                ? 'Flatbed, wheel-lift, service truck'
                                : selectedType == AssetType.crew
                                    ? 'Driver, Helper, Mechanic'
                                    : 'Hand tool, safety gear, diagnostic kit',
                            prefixIcon: Icons.merge_type_outlined,
                            isDark: isDark,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a category';
                            }
                            return null;
                          },
                        ),
                        if (selectedType == AssetType.vehicle) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: AppTheme.textFieldDecoration(
                              label: 'Plate number',
                              prefixIcon: Icons.confirmation_number_outlined,
                              isDark: isDark,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter the vehicle plate number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: _secondaryTextColor(context),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      await _assetService.addProviderAsset(
                        providerId: providerId,
                        providerName: providerName,
                        name: nameController.text.trim(),
                        category: categoryController.text.trim(),
                        type: selectedType,
                        plateNumber: plateController.text.trim().isEmpty
                            ? null
                            : plateController.text.trim().toUpperCase(),
                      );
                    } catch (e) {
                      _showSnackBar('Unable to register asset: $e', isError: true);
                      return;
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      _showSnackBar('${_assetTypeLabel(selectedType)} registered');
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUsageDialog(
    String providerId,
    String providerName,
    List<AssetModel> currentAssignedAssets,
  ) {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? selectedTaskId;
    String? selectedTaskLabel;
    String? selectedVehicleId;
    final selectedToolIds = <String>{};
    final selectedEquipmentIds = <String>{};
    final selectedCrewIds = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StreamBuilder<List<AssetModel>>(
          stream: _assetService.getProviderAssignedAssets(providerId),
          builder: (context, assetSnapshot) {
            final assignedAssets =
                assetSnapshot.data ?? currentAssignedAssets;
            final vehicles = assignedAssets
                .where((asset) => asset.type == AssetType.vehicle)
                .toList();
            final tools = assignedAssets
                .where((asset) => asset.type == AssetType.tool)
                .toList();
            final equipment = assignedAssets
                .where((asset) => asset.type == AssetType.equipment)
                .toList();
            final crew = assignedAssets
                .where((asset) => asset.type == AssetType.crew)
                .toList();

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return AlertDialog(
                  backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('Log Resource Usage', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textSlateDark)),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StreamBuilder<List<Task>>(
                              stream: _taskService.getProviderTasks(providerId),
                              builder: (context, taskSnapshot) {
                                final tasks = taskSnapshot.data ?? [];
                                return DropdownButtonFormField<String>(
                          isExpanded: true,
                                  initialValue: selectedTaskId,
                                  decoration: AppTheme.textFieldDecoration(
                                    label: 'Related active task',
                                    prefixIcon: Icons.assignment_outlined,
                                    isDark: isDark,
                                  ),
                                  hint: const Text('Optional'),
                                  items: tasks
                                      .map(
                                        (task) => DropdownMenuItem(
                                          value: task.id,
                                          child: Text(
                                            '${task.serviceType} - ${task.location}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTaskId = value;
                                      selectedTaskLabel =
                                          _taskLabelFor(tasks, value);
                                    });
                                  },
                                );
                              },
                            ),
                            _buildAssetChecklist(
                              title: 'Assigned Crew',
                              assets: crew,
                              selectedIds: selectedCrewIds,
                              setDialogState: setDialogState,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                          isExpanded: true,
                              initialValue: selectedVehicleId,
                              decoration: AppTheme.textFieldDecoration(
                                label: 'Truck used',
                                prefixIcon: Icons.local_shipping_outlined,
                                isDark: isDark,
                              ),
                              hint: vehicles.isEmpty
                                  ? const Text('No truck assigned')
                                  : const Text('Select truck'),
                              items: vehicles
                                  .map(
                                    (asset) => DropdownMenuItem(
                                      value: asset.id,
                                      child: Text(_assetSubtitle(asset)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: vehicles.isEmpty
                                  ? null
                                  : (value) => setDialogState(
                                        () => selectedVehicleId = value,
                                      ),
                            ),
                            const SizedBox(height: 14),
                            _buildAssetChecklist(
                              title: 'Tools used',
                              assets: tools,
                              selectedIds: selectedToolIds,
                              setDialogState: setDialogState,
                            ),
                            const SizedBox(height: 12),
                            _buildAssetChecklist(
                              title: 'Equipment used',
                              assets: equipment,
                              selectedIds: selectedEquipmentIds,
                              setDialogState: setDialogState,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: notesController,
                              maxLines: 3,
                              decoration: AppTheme.textFieldDecoration(
                                label: 'Notes',
                                prefixIcon: Icons.edit_note_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        foregroundColor: _secondaryTextColor(context),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final vehicle =
                            _findAssetById(assignedAssets, selectedVehicleId);
                        final selectedTools = tools
                            .where((asset) => selectedToolIds.contains(asset.id))
                            .toList();
                        final selectedEquipment = equipment
                            .where(
                              (asset) => selectedEquipmentIds.contains(asset.id),
                            )
                            .toList();
                        final selectedCrew = crew
                            .where(
                              (asset) => selectedCrewIds.contains(asset.id),
                            )
                            .toList();

                        try {
                          await _assetService.logResourceUsage(
                            providerId: providerId,
                            providerName: providerName,
                            taskId: selectedTaskId,
                            taskLabel: selectedTaskLabel,
                            vehicle: vehicle,
                            tools: selectedTools,
                            equipment: selectedEquipment,
                            crew: selectedCrew,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            _showSnackBar('Resource usage logged');
                          }
                        } catch (e) {
                          _showSnackBar('Unable to log usage: $e', isError: true);
                        }
                      },
                      child: const Text('Save Log'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAssetChecklist({
    required String title,
    required List<AssetModel> assets,
    required Set<String> selectedIds,
    required void Function(void Function()) setDialogState,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
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
                style: const TextStyle(
                  color: AppTheme.textSlateMedium,
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
                secondary: Icon(_assetIcon(asset.type)),
                onChanged: (selected) {
                  setDialogState(() {
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

  List<AssetModel> _filterAssets(List<AssetModel> myPool, String providerId) {
    final filtered = myPool.where((asset) {
      switch (_filter) {
        case 'mine':
          return asset.assignedTo == providerId;
        case 'available':
          return asset.status == AssetStatus.active && asset.assignedTo == null;
        case 'vehicles':
          return asset.type == AssetType.vehicle;
        case 'tools':
          return asset.type == AssetType.tool;
        case 'equipment':
          return asset.type == AssetType.equipment;
        case 'drivers':
          return asset.type == AssetType.crew && asset.category == 'Driver';
        case 'crew':
          return asset.type == AssetType.crew && asset.category != 'Driver';
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      final aMine = a.assignedTo == providerId ? 0 : 1;
      final bMine = b.assignedTo == providerId ? 0 : 1;
      final mineCompare = aMine.compareTo(bMine);
      if (mineCompare != 0) return mineCompare;

      final statusCompare = a.status.index.compareTo(b.status.index);
      if (statusCompare != 0) return statusCompare;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  AssetModel? _findAssetById(List<AssetModel> assets, String? assetId) {
    if (assetId == null) return null;
    for (final asset in assets) {
      if (asset.id == assetId) return asset;
    }
    return null;
  }

  String? _taskLabelFor(List<Task> tasks, String? taskId) {
    if (taskId == null) return null;
    for (final task in tasks) {
      if (task.id == taskId) {
        return '${task.serviceType} at ${task.location}';
      }
    }
    return null;
  }

  _AssetStatusInfo _statusInfo(AssetModel asset, String providerId) {
    if (asset.status == AssetStatus.maintenance) {
      return _AssetStatusInfo('Maintenance', Colors.orange);
    }
    if (asset.status == AssetStatus.inactive) {
      return _AssetStatusInfo('Inactive', Colors.red);
    }
    if (asset.status == AssetStatus.inUse) {
      return _AssetStatusInfo('In Use', Colors.blueGrey);
    }
    if (asset.assignedTo == providerId) {
      return _AssetStatusInfo('Available', Colors.green);
    }
    return _AssetStatusInfo('Available', Colors.green);
  }

  IconData _assetIcon(AssetType type) {
    switch (type) {
      case AssetType.vehicle:
        return Icons.local_shipping_outlined;
      case AssetType.tool:
        return Icons.handyman_outlined;
      case AssetType.equipment:
        return Icons.construction_outlined;
      case AssetType.crew:
        return Icons.person_outline;
    }
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.vehicle:
        return 'Vehicle';
      case AssetType.tool:
        return 'Tool';
      case AssetType.equipment:
        return 'Equipment';
      case AssetType.crew:
        return 'Crew Member';
    }
  }

  String _assetSubtitle(AssetModel asset) {
    final parts = [
      asset.category,
      if (asset.plateNumber?.trim().isNotEmpty == true) asset.plateNumber!,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' - ');
  }

  String _formatAssetNames(List<String> names) {
    if (names.isEmpty) return 'None recorded';
    return names.join(', ');
  }

  String _getProviderName(UserProvider userProvider) {
    final profile = userProvider.providerProfile ?? userProvider.userProfile;
    final name = profile?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return FirebaseAuth.instance.currentUser?.email ?? 'Provider';
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppTheme.textDarkSecondary
        : AppTheme.textSlateMedium;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

class _AssetStatusInfo {
  final String label;
  final Color color;

  const _AssetStatusInfo(this.label, this.color);
}
