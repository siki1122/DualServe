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

class ProviderAssetInventoryScreen extends StatefulWidget {
  const ProviderAssetInventoryScreen({super.key});

  @override
  State<ProviderAssetInventoryScreen> createState() =>
      _ProviderAssetInventoryScreenState();
}

class _ProviderAssetInventoryScreenState
    extends State<ProviderAssetInventoryScreen> {
  final AssetService _assetService = AssetService();
  final TaskService _taskService = TaskService();
  String _filter = 'all';
  List<Provider> _teamMembers = [];
  bool _isLoadingTeam = false;

  @override
  void initState() {
    super.initState();
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
      drawer: const ProviderDrawer(),
      body: StreamBuilder<List<AssetModel>>(
        stream: _assetService.getAssets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
          final assignedAssets = assets
              .where((asset) => asset.assignedTo == providerId)
              .toList();
          final visibleAssets = _filterAssets(assets, providerId);

          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    title: Text(
                      'Asset Inventory',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textDarkPrimary : AppTheme.textSlateDark,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Register asset',
                        onPressed: () => _openRegisterAssetDialog(providerId, providerName),
                        icon: const Icon(Icons.add_box_outlined),
                      ),
                      IconButton(
                        tooltip: 'Log resource usage',
                        onPressed: () => _openUsageDialog(providerId, providerName, const []),
                        icon: const Icon(Icons.assignment_add),
                      ),
                    ],
                    bottom: TabBar(
                      labelColor: isDark
                          ? AppTheme.textDarkPrimary
                          : AppTheme.textSlateDark,
                      unselectedLabelColor: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textSlateMedium,
                      indicatorColor: AppTheme.towingOrange,
                      tabs: const [
                        Tab(text: 'Inventory'),
                        Tab(text: 'Usage Logs'),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildHeader(assets, assignedAssets, providerId, providerName),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildInventoryTab(
                    assets,
                    visibleAssets,
                    assignedAssets,
                    providerId,
                    providerName,
                  ),
                  _buildUsageLogsTab(providerId),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    List<AssetModel> assets,
    List<AssetModel> assignedAssets,
    String providerId,
    String providerName,
  ) {
    final availableCount = assets
        .where(
          (asset) => asset.status == AssetStatus.active && asset.assignedTo == null,
        )
        .length;
    final truckCount = assets
        .where(
          (asset) =>
              asset.type == AssetType.vehicle &&
              (asset.assignedTo == providerId ||
                  (asset.status == AssetStatus.active &&
                      asset.assignedTo == null)),
        )
        .length;
    final toolsAndEquipmentCount = assets
        .where(
          (asset) =>
              asset.type != AssetType.vehicle &&
              (asset.assignedTo == providerId ||
                  (asset.status == AssetStatus.active &&
                      asset.assignedTo == null)),
        )
        .length;

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
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openRegisterAssetDialog(providerId, providerName),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Register'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openUsageDialog(providerId, providerName, assignedAssets),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textSlateDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('Log Usage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.25,
            children: [
              _buildMetricCard(
                'Available',
                availableCount.toString(),
                Icons.inventory_2_outlined,
                Colors.green,
              ),
              _buildMetricCard(
                'Assigned',
                assignedAssets.length.toString(),
                Icons.assignment_ind_outlined,
                AppTheme.primaryBlue,
              ),
              _buildMetricCard(
                'Trucks',
                truckCount.toString(),
                Icons.local_shipping_outlined,
                AppTheme.towingOrange,
              ),
              _buildMetricCard(
                'Tools/Equipment',
                toolsAndEquipmentCount.toString(),
                Icons.handyman_outlined,
                Colors.purple,
              ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textDarkPrimary
                        : AppTheme.textSlateDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 11,
                  ),
                ),
              ],
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
    return Column(
      children: [
        _buildFilterBar(allAssets, providerId),
        Expanded(
          child: visibleAssets.isEmpty
              ? _buildEmptyState(
                  Icons.inventory_2_outlined,
                  'No assets found',
                  'Try a different filter or ask an admin to register assets.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: visibleAssets.length,
                  itemBuilder: (context, index) {
                    final asset = visibleAssets[index];
                    return _buildAssetCard(asset, providerId, providerName);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(List<AssetModel> allAssets, String providerId) {
    final filters = [
      ('all', 'All', allAssets.length),
      ('mine', 'Mine', allAssets.where((a) => a.assignedTo == providerId).length),
      ('available', 'Available', allAssets.where((a) => a.status == AssetStatus.active && a.assignedTo == null).length),
      ('vehicles', 'Trucks', allAssets.where((a) => a.type == AssetType.vehicle).length),
      ('tools', 'Tools', allAssets.where((a) => a.type == AssetType.tool).length),
      ('equipment', 'Equipment', allAssets.where((a) => a.type == AssetType.equipment).length),
      ('maintenance', 'Maintenance', allAssets.where((a) => a.status == AssetStatus.maintenance).length),
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _filter == filter.$1;

          return ChoiceChip(
            label: Text('${filter.$2} (${filter.$3})'),
            selected: selected,
            onSelected: (_) => setState(() => _filter = filter.$1),
            selectedColor: AppTheme.towingOrange.withOpacity(0.15),
            labelStyle: TextStyle(
              color: selected ? AppTheme.towingOrange : _secondaryTextColor(context),
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected
                  ? AppTheme.towingOrange
                  : _secondaryTextColor(context).withOpacity(0.25),
            ),
          );
        },
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
                    color: statusInfo.color.withOpacity(isDark ? 0.18 : 0.12),
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
            const SizedBox(height: 14),
            Row(
              children: [
                if (isAvailable) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _claimAsset(asset, providerId, providerName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Claim'),
                    ),
                  ),
                  if (_teamMembers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openAssignPersonnelDialog(asset),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.towingOrange,
                          side: const BorderSide(color: AppTheme.towingOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('Assign'),
                      ),
                    ),
                  ],
                ] else if (isMine && asset.status != AssetStatus.inUse)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _releaseAsset(asset, providerId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: const BorderSide(color: AppTheme.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Release Asset'),
                    ),
                  )
                else if (isMine && asset.status == AssetStatus.inUse)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_clock_outlined, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            'Locked (On Task)',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: Text(statusInfo.label),
                    ),
                  ),
              ],
            ),
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
          ? color.withOpacity(isDark ? 0.1 : 0.05)
          : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color != null 
            ? color.withOpacity(0.3)
            : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
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
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusInfo.color.withOpacity(0.35)),
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
    return StreamBuilder<List<AssetUsageLog>>(
      stream: _assetService.getProviderUsageLogs(providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                  color: AppTheme.primaryBlue.withOpacity(isDark ? 0.18 : 0.1),
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
        color: AppTheme.towingOrange.withOpacity(0.12),
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
            Icon(icon, size: 60, color: _secondaryTextColor(context).withOpacity(0.35)),
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
            return AlertDialog(
              title: const Text('Register Asset'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<AssetType>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Asset type',
                            border: OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: selectedType == AssetType.vehicle
                                ? 'Truck name / unit'
                                : 'Asset name',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(_assetIcon(selectedType)),
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
                          decoration: InputDecoration(
                            labelText: selectedType == AssetType.vehicle
                                ? 'Truck type'
                                : 'Category',
                            hintText: selectedType == AssetType.vehicle
                                ? 'Flatbed, wheel-lift, service truck'
                                : 'Hand tool, safety gear, diagnostic kit',
                            border: const OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'Plate number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter the truck plate number';
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        _showSnackBar('${_assetTypeLabel(selectedType)} registered');
                      }
                    } catch (e) {
                      _showSnackBar('Unable to register asset: $e', isError: true);
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
    final crewController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? selectedTaskId;
    String? selectedTaskLabel;
    String? selectedVehicleId;
    String? selectedDriverId;
    String? selectedDriverName;
    final selectedToolIds = <String>{};
    final selectedEquipmentIds = <String>{};

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

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Log Resource Usage'),
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
                                  value: selectedTaskId,
                                  decoration: const InputDecoration(
                                    labelText: 'Related active task',
                                    border: OutlineInputBorder(),
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
                            const SizedBox(height: 14),
                            if (_teamMembers.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                value: selectedDriverId,
                                decoration: const InputDecoration(
                                  labelText: 'Primary driver',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                hint: const Text('Select team member'),
                                items: _teamMembers
                                    .map(
                                      (person) => DropdownMenuItem(
                                        value: person.id,
                                        child: Text(person.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedDriverId = value;
                                    selectedDriverName = _teamMembers
                                        .firstWhere((p) => p.id == value)
                                        .name;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: crewController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'How many people/crew members?',
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
                            DropdownButtonFormField<String>(
                              value: selectedVehicleId,
                              decoration: const InputDecoration(
                                labelText: 'Truck used',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.local_shipping_outlined),
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
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder(),
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
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
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

                        try {
                          await _assetService.logResourceUsage(
                            providerId: providerId,
                            providerName: providerName,
                            driverId: selectedDriverId,
                            driverName: selectedDriverName,
                            taskId: selectedTaskId,
                            taskLabel: selectedTaskLabel,
                            crewCount: int.parse(crewController.text),
                            vehicle: vehicle,
                            tools: selectedTools,
                            equipment: selectedEquipment,
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

  List<AssetModel> _filterAssets(List<AssetModel> assets, String providerId) {
    final filtered = assets.where((asset) {
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
        case 'maintenance':
          return asset.status == AssetStatus.maintenance;
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
    if (asset.assignedTo == providerId) {
      return _AssetStatusInfo('Assigned', AppTheme.primaryBlue);
    }
    if (asset.status == AssetStatus.inUse) {
      return _AssetStatusInfo('In Use', Colors.blueGrey);
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
    }
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.vehicle:
        return 'Truck / Vehicle';
      case AssetType.tool:
        return 'Tool';
      case AssetType.equipment:
        return 'Equipment';
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
