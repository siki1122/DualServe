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
    };
  }
}
