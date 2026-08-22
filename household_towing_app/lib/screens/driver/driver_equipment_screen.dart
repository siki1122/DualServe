import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asset_model.dart';
import '../../providers/user_provider.dart';
import '../../services/asset_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverEquipmentScreen extends StatefulWidget {
  const DriverEquipmentScreen({super.key});

  @override
  State<DriverEquipmentScreen> createState() => _DriverEquipmentScreenState();
}

class _DriverEquipmentScreenState extends State<DriverEquipmentScreen> {
  final AssetService _assetService = AssetService();

  Future<void> _checkoutAsset(AssetModel asset, String driverId, String driverName) async {
    try {
      await _assetService.assignAsset(asset.id, driverId, driverName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checked out ${asset.name}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _returnAsset(AssetModel asset) async {
    try {
      await FirebaseFirestore.instance.collection('assets').doc(asset.id).update({
        'assignedTo': null,
        'providerName': null,
        'status': AssetStatus.active.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Returned ${asset.name}'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error returning asset: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final driverId = userProvider.uid;
    final driverName = userProvider.driverProfile?['name'] ?? 'Driver';
    final providerId = userProvider.driverProfile?['providerId'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (providerId == null) {
      return const Center(child: Text('Company data not found.'));
    }

    return StreamBuilder<List<AssetModel>>(
      stream: _assetService.getAssets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ShimmerLoading.cardPlaceholder(count: 3, isDark: isDark),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final allAssets = snapshot.data ?? [];
        
        // Filter assets for this provider
        final companyAssets = allAssets.where((a) => a.ownerId == providerId).toList();
        
        // My Equipment
        final myEquipment = companyAssets.where((a) => a.assignedTo == driverId && a.type != AssetType.crew).toList();
        
        // Available Equipment (excluding crew)
        final availableAssets = companyAssets.where((a) => 
          a.status == AssetStatus.active && 
          a.assignedTo == null && 
          a.type != AssetType.crew
        ).toList();

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                child: TabBar(
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryBlue,
                  tabs: [
                    Tab(text: 'My Equipment (${myEquipment.length})'),
                    Tab(text: 'Available (${availableAssets.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEquipmentList(myEquipment, isDark, true, driverId, driverName),
                    _buildEquipmentList(availableAssets, isDark, false, driverId, driverName),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEquipmentList(List<AssetModel> assets, bool isDark, bool isMine, String driverId, String driverName) {
    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              isMine ? 'You haven\'t checked out any equipment' : 'No available equipment right now',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        final icon = _getAssetIcon(asset.type);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isMine ? AppTheme.primaryBlue.withValues(alpha: 0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isMine 
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isMine ? AppTheme.primaryBlue : Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppTheme.textSlateDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        asset.category + (asset.plateNumber?.isNotEmpty == true ? ' • ${asset.plateNumber}' : ''),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                isMine
                  ? ElevatedButton(
                      onPressed: () => _returnAsset(asset),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                        foregroundColor: Colors.orange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Return'),
                    )
                  : ElevatedButton(
                      onPressed: () => _checkoutAsset(asset, driverId, driverName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Checkout'),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getAssetIcon(AssetType type) {
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
}
