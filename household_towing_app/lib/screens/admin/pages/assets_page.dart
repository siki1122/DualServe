import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/asset_stat_card.dart';
import '../../../models/asset_model.dart';
import '../../../services/asset_service.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> with SingleTickerProviderStateMixin {
  final AssetService _assetService = AssetService();
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asset & Resource Management',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor vehicles, service tools, and equipment utilization',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddAssetDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add New Asset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Real-time Stats
          StreamBuilder<List<AssetModel>>(
            stream: _assetService.getAssets(),
            builder: (context, snapshot) {
              final assets = snapshot.data ?? [];
              final activeCount = assets.where((a) => a.status == AssetStatus.active || a.status == AssetStatus.inUse).length;
              final maintenanceCount = assets.where((a) => a.status == AssetStatus.maintenance).length;
              final equipmentCount = assets.where((a) => a.type != AssetType.vehicle).length;
              
              return Row(
                children: [
                  Expanded(
                    child: AssetStatCard(
                      value: '${assets.length}',
                      title: 'Total Inventory',
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AssetStatCard(
                      value: '$activeCount',
                      title: 'Available/In-Use',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AssetStatCard(
                      value: '$maintenanceCount',
                      title: 'Under Maintenance',
                      icon: Icons.build,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AssetStatCard(
                      value: '$equipmentCount',
                      title: 'Tools & Equipment',
                      icon: Icons.handyman,
                      color: Colors.purple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Main Content with Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.black,
                        tabs: const [
                          Tab(text: 'Service Vehicles'),
                          Tab(text: 'Tools & Equipment'),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search by name or plate...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssetList(AssetType.vehicle),
                      _buildAssetList(null), // Everything else
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetList(AssetType? filterType) {
    return StreamBuilder<List<AssetModel>>(
      stream: _assetService.getAssets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        var list = snapshot.data ?? [];
        
        // Filter by tab type
        if (filterType == AssetType.vehicle) {
          list = list.where((a) => a.type == AssetType.vehicle).toList();
        } else {
          list = list.where((a) => a.type != AssetType.vehicle).toList();
        }

        // Filter by search
        if (_searchQuery.isNotEmpty) {
          list = list.where((a) => 
            a.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
            (a.plateNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
          ).toList();
        }

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No assets found in this category', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 24,
            columnSpacing: 40,
            columns: const [
              DataColumn(label: Text('Asset Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Utilization')),
              DataColumn(label: Text('Last Maint.')),
              DataColumn(label: Text('Actions')),
            ],
            rows: list.map((asset) => DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      Icon(
                        asset.type == AssetType.vehicle ? Icons.local_shipping : Icons.handyman,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (asset.plateNumber != null)
                            Text(asset.plateNumber!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(Text(asset.category)),
                DataCell(_buildStatusBadge(asset.status)),
                DataCell(
                  asset.assignedTo != null 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('In Use By:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(asset.providerName ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : const Text('Available', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                DataCell(Text(
                  asset.lastMaintenance != null 
                    ? DateFormat('MMM dd, yyyy').format(asset.lastMaintenance!)
                    : 'N/A'
                )),
                DataCell(
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                      const PopupMenuItem(value: 'maintenance', child: Text('Log Maintenance')),
                      const PopupMenuItem(value: 'utilization', child: Text('View History')),
                      const PopupMenuItem(value: 'delete', child: Text('Remove Asset', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') _showDeleteConfirm(asset);
                      if (value == 'maintenance') _showMaintenanceDialog(asset);
                    },
                  ),
                ),
              ],
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(AssetStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case AssetStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case AssetStatus.maintenance:
        color = Colors.orange;
        label = 'Maintenance';
        break;
      case AssetStatus.inUse:
        color = Colors.blue;
        label = 'In Use';
        break;
      case AssetStatus.inactive:
        color = Colors.red;
        label = 'Inactive';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final plateController = TextEditingController();
    AssetType selectedType = AssetType.vehicle;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register New Asset'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AssetType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Asset Type', border: OutlineInputBorder()),
                  items: AssetType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name / Model', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: selectedType == AssetType.vehicle ? 'Vehicle Type (e.g. Flatbed)' : 'Category (e.g. Power Tool)',
                    border: const OutlineInputBorder()
                  ),
                ),
                if (selectedType == AssetType.vehicle) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: plateController,
                    decoration: const InputDecoration(labelText: 'Plate Number', border: OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final asset = AssetModel(
                  id: '',
                  name: nameController.text,
                  category: categoryController.text,
                  type: selectedType,
                  status: AssetStatus.active,
                  plateNumber: selectedType == AssetType.vehicle ? plateController.text : null,
                );
                await _assetService.addAsset(asset);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Asset'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(AssetModel asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Maintenance: ${asset.name}'),
        content: const Text('Has the maintenance for this asset been completed today? This will reset the maintenance status to Active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              await _assetService.updateMaintenance(asset.id, DateTime.now());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Yes, Completed'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(AssetModel asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset?'),
        content: Text('Are you sure you want to remove ${asset.name} from the inventory? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _assetService.deleteAsset(asset.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
