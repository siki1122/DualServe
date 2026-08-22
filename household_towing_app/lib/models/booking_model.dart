import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  converted_to_task,
  cancelled,
  completed,
}

enum TruckType {
  light,     // Light tow truck
  medium,    // Medium tow truck
  heavy,     // Heavy tow truck
  recovery,  // Recovery vehicle
}

class Booking {
  final String id;
  final String customerId;
  final String? assignedProviderId;
  final String? assignedDriverId;
  final String serviceType;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime scheduledDate;
  final String scheduledTime; // Format: "HH:MM"
  final String? notes;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? providerNotes;
  final double? estimatedCost;
  final int? estimatedDurationMinutes;
  final String? specificService; // E.g. "Flatbed", "Emergency Tow", "Jump Start"
  final Map<String, int>? selectedSubServices; // { "Deep Cleaning": 1, "Aircon Cleaning": 2 }
  final Map<String, dynamic>? serviceDetails; // Complex service configuration (e.g. sqm, selected addons)
  // New fields for address & issue details
  final String? barangay;
  final String? zone;
  final String? landmarkDescription;
  final String? problemCategory;
  final String? issueCategory;
  final double? adminFee;
  // New fields for asset management
  final TruckType? assignedTruckType;
  final String? assignedTruckId; // Asset ID of the assigned truck
  final List<String> assignedPersonnelIds; // UIDs of assigned staff
  final Map<String, int> assignedAssets; // assetId: quantity
  final String? assignedTruckName;
  final List<String> assignedPersonnelNames;
  final bool isReviewed;

  Booking({
    required this.id,
    required this.customerId,
    this.assignedProviderId,
    this.assignedDriverId,
    required this.serviceType,
    required this.address,
    this.latitude,
    this.longitude,
    required this.scheduledDate,
    required this.scheduledTime,
    this.notes,
    this.status = BookingStatus.pending,
    required this.createdAt,
    this.acceptedAt,
    this.providerNotes,
    this.estimatedCost,
    this.estimatedDurationMinutes,
    this.specificService,
    this.selectedSubServices,
    this.serviceDetails,
    this.barangay,
    this.zone,
    this.landmarkDescription,
    this.problemCategory,
    this.issueCategory,
    this.adminFee,
    this.assignedTruckType,
    this.assignedTruckId,
    this.assignedPersonnelIds = const [],
    this.assignedAssets = const {},
    this.assignedTruckName,
    this.assignedPersonnelNames = const [],
    this.isReviewed = false,
  });

  // Convert from Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      assignedProviderId: data['assignedProviderId'],
      assignedDriverId: data['assignedDriverId'],
      serviceType: data['serviceType'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledTime: data['scheduledTime'] ?? '09:00',
      notes: data['notes'],
      status: BookingStatus.values.asNameMap()[data['status']] ?? BookingStatus.pending,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      providerNotes: data['providerNotes'],
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble(),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] as int?,
      specificService: data['specificService'],
      selectedSubServices: data['selectedSubServices'] is Map
          ? (data['selectedSubServices'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : null,
      serviceDetails: data['serviceDetails'] as Map<String, dynamic>?,
      barangay: data['barangay'],
      zone: data['zone'],
      landmarkDescription: data['landmarkDescription'],
      problemCategory: data['problemCategory'],
      issueCategory: data['issueCategory'],
      adminFee: (data['adminFee'] as num?)?.toDouble(),
      assignedTruckType: data['assignedTruckType'] != null
          ? TruckType.values.asNameMap()[data['assignedTruckType']]
          : null,
      assignedTruckId: data['assignedTruckId'],
      assignedPersonnelIds: data['assignedPersonnelIds'] is List 
          ? List<String>.from(data['assignedPersonnelIds']) 
          : [],
      assignedAssets: data['assignedAssets'] is Map
          ? (data['assignedAssets'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            )
          : {},
      assignedTruckName: data['assignedTruckName'],
      assignedPersonnelNames: data['assignedPersonnelNames'] is List 
          ? List<String>.from(data['assignedPersonnelNames']) 
          : [],
      isReviewed: data['isReviewed'] ?? false,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'assignedProviderId': assignedProviderId,
      'assignedDriverId': assignedDriverId,
      'serviceType': serviceType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'scheduledTime': scheduledTime,
      'notes': notes,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'providerNotes': providerNotes,
      'estimatedCost': estimatedCost,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'specificService': specificService,
      'selectedSubServices': selectedSubServices,
      'serviceDetails': serviceDetails,
      'barangay': barangay,
      'zone': zone,
      'landmarkDescription': landmarkDescription,
      'problemCategory': problemCategory,
      'issueCategory': issueCategory,
      'adminFee': adminFee,
      'assignedTruckType': assignedTruckType?.name,
      'assignedTruckId': assignedTruckId,
      'assignedPersonnelIds': assignedPersonnelIds,
      'assignedAssets': assignedAssets,
      'assignedTruckName': assignedTruckName,
      'assignedPersonnelNames': assignedPersonnelNames,
      'isReviewed': isReviewed,
    };
  }

  // Create a copy with modified fields
  Booking copyWith({
    String? id,
    String? customerId,
    String? assignedProviderId,
    String? assignedDriverId,
    String? serviceType,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? notes,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    String? providerNotes,
    double? estimatedCost,
    int? estimatedDurationMinutes,
    String? specificService,
    Map<String, int>? selectedSubServices,
    Map<String, dynamic>? serviceDetails,
    String? barangay,
    String? zone,
    String? landmarkDescription,
    String? problemCategory,
    String? issueCategory,
    double? adminFee,
    TruckType? assignedTruckType,
    String? assignedTruckId,
    List<String>? assignedPersonnelIds,
    Map<String, int>? assignedAssets,
    String? assignedTruckName,
    List<String>? assignedPersonnelNames,
    bool? isReviewed,
  }) {
    return Booking(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      assignedProviderId: assignedProviderId ?? this.assignedProviderId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      serviceType: serviceType ?? this.serviceType,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      providerNotes: providerNotes ?? this.providerNotes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      specificService: specificService ?? this.specificService,
      selectedSubServices: selectedSubServices ?? this.selectedSubServices,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      barangay: barangay ?? this.barangay,
      zone: zone ?? this.zone,
      landmarkDescription: landmarkDescription ?? this.landmarkDescription,
      problemCategory: problemCategory ?? this.problemCategory,
      issueCategory: issueCategory ?? this.issueCategory,
      adminFee: adminFee ?? this.adminFee,
      assignedTruckType: assignedTruckType ?? this.assignedTruckType,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
      assignedPersonnelIds: assignedPersonnelIds ?? this.assignedPersonnelIds,
      assignedAssets: assignedAssets ?? this.assignedAssets,
      assignedTruckName: assignedTruckName ?? this.assignedTruckName,
      assignedPersonnelNames: assignedPersonnelNames ?? this.assignedPersonnelNames,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }

  @override
  String toString() {
    return 'Booking(id: $id, customer: $customerId, status: ${status.toString().split('.').last}, date: $scheduledDate)';
  }
}
