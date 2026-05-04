import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetType { vehicle, tool, equipment }

enum AssetStatus { active, maintenance, inactive, inUse }

class AssetModel {
  final String id;
  final String name;
  final String category; // e.g., 'Tow Truck', 'Wrench Set', 'Jack'
  final AssetType type;
  final AssetStatus status;
  final String? plateNumber; // For vehicles
  final String? assignedTo; // UID of provider using it
  final String? providerName;
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;
  final int jobsCompleted;
  final Map<String, dynamic> metadata; // Extra info like capacity, brand, etc.
  final int quantity; // Total quantity available (for consumables/tools)
  final bool isConsumable;
  final String? currentTaskId;
  final String? currentTaskLabel;

  AssetModel({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.status,
    this.plateNumber,
    this.assignedTo,
    this.providerName,
    this.lastMaintenance,
    this.nextMaintenance,
    this.jobsCompleted = 0,
    this.metadata = const {},
    this.quantity = 1,
    this.isConsumable = false,
    this.currentTaskId,
    this.currentTaskLabel,
  });

  factory AssetModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AssetModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      type: AssetType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'equipment'),
        orElse: () => AssetType.equipment,
      ),
      status: AssetStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => AssetStatus.active,
      ),
      plateNumber: data['plateNumber'],
      assignedTo: data['assignedTo'],
      providerName: data['providerName'],
      lastMaintenance: data['lastMaintenance'] != null
          ? (data['lastMaintenance'] as Timestamp).toDate()
          : null,
      nextMaintenance: data['nextMaintenance'] != null
          ? (data['nextMaintenance'] as Timestamp).toDate()
          : null,
      jobsCompleted: data['jobsCompleted'] ?? 0,
      metadata: data['metadata'] ?? {},
      quantity: data['quantity'] ?? 1,
      isConsumable: data['isConsumable'] ?? false,
      currentTaskId: data['currentTaskId'],
      currentTaskLabel: data['currentTaskLabel'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'type': type.name,
      'status': status.name,
      'plateNumber': plateNumber,
      'assignedTo': assignedTo,
      'providerName': providerName,
      'lastMaintenance': lastMaintenance != null ? Timestamp.fromDate(lastMaintenance!) : null,
      'nextMaintenance': nextMaintenance != null ? Timestamp.fromDate(nextMaintenance!) : null,
      'jobsCompleted': jobsCompleted,
      'metadata': metadata,
      'quantity': quantity,
      'isConsumable': isConsumable,
      'currentTaskId': currentTaskId,
      'currentTaskLabel': currentTaskLabel,
    };
  }
}

class AssetUsageLog {
  final String id;
  final String providerId;
  final String providerName;
  final String? taskId;
  final String? taskLabel;
  final int crewCount;
  final String? vehicleAssetId;
  final String? vehicleName;
  final List<String> toolAssetIds;
  final List<String> toolNames;
  final List<String> equipmentAssetIds;
  final List<String> equipmentNames;
  final String? driverId;
  final String? driverName;
  final String? notes;
  final DateTime createdAt;

  AssetUsageLog({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.driverId,
    this.driverName,
    this.taskId,
    this.taskLabel,
    required this.crewCount,
    this.vehicleAssetId,
    this.vehicleName,
    this.toolAssetIds = const [],
    this.toolNames = const [],
    this.equipmentAssetIds = const [],
    this.equipmentNames = const [],
    this.notes,
    required this.createdAt,
  });

  factory AssetUsageLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssetUsageLog(
      id: doc.id,
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      driverId: data['driverId'],
      driverName: data['driverName'],
      taskId: data['taskId'],
      taskLabel: data['taskLabel'],
      crewCount: (data['crewCount'] as num?)?.toInt() ?? 1,
      vehicleAssetId: data['vehicleAssetId'],
      vehicleName: data['vehicleName'],
      toolAssetIds: List<String>.from(data['toolAssetIds'] ?? const []),
      toolNames: List<String>.from(data['toolNames'] ?? const []),
      equipmentAssetIds: List<String>.from(
        data['equipmentAssetIds'] ?? const [],
      ),
      equipmentNames: List<String>.from(data['equipmentNames'] ?? const []),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
