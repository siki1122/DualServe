import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  unassigned,
  assigned,
  inProgress,
  completed,
  cancelled,
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

class TaskMilestone {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;

  TaskMilestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
  });

  factory TaskMilestone.fromMap(Map<String, dynamic> map) {
    return TaskMilestone(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  TaskMilestone copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return TaskMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class Task {
  final String id;
  final String customerId;
  final String? assignedProviderId;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String serviceType;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime scheduledDate;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? estimatedCost;
  final double? finalCost;
  final int? estimatedDurationMinutes;
  final String? bookingId; // Links to original booking if created from booking
  final String? completedImageUrl;
  final DateTime? completedAt;

  // New fields for address & issue details
  final String? barangay;
  final String? zone;
  final String? landmarkDescription;
  final String? problemCategory;
  final String? issueCategory;
  final double? adminFee;

  // New fields for asset management
  final String? assignedTruckId;
  final String? assignedTruckName;
  final List<String> assignedPersonnelIds;
  final List<String> assignedPersonnelNames;
  final Map<String, int> assignedAssets;
  final Map<String, int>? selectedSubServices;
  final Map<String, dynamic>? serviceDetails;
  final List<String> preTowPhotoUrls;
  final String? customerSignatureUrl;

  // Progress Tracking
  final List<TaskMilestone> milestones;
  final double progress; // Overall progress percentage (0.0 to 1.0)

  Task({
    required this.id,
    required this.customerId,
    this.assignedProviderId,
    this.assignedDriverId,
    this.assignedDriverName,
    required this.serviceType,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.scheduledDate,
    this.description,
    this.status = TaskStatus.unassigned,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.updatedAt,
    this.estimatedCost,
    this.finalCost,
    this.estimatedDurationMinutes,
    this.bookingId,
    this.completedImageUrl,
    this.completedAt,
    this.barangay,
    this.zone,
    this.landmarkDescription,
    this.problemCategory,
    this.issueCategory,
    this.adminFee,
    this.assignedTruckId,
    this.assignedTruckName,
    this.assignedPersonnelIds = const [],
    this.assignedPersonnelNames = const [],
    this.assignedAssets = const {},
    this.selectedSubServices,
    this.serviceDetails,
    this.preTowPhotoUrls = const [],
    this.customerSignatureUrl,
    List<TaskMilestone>? milestones,
    double? progress,
  }) : milestones = milestones ?? defaultMilestones(serviceType),
       progress = progress ?? _calculateProgress(milestones ?? defaultMilestones(serviceType));

  static double _calculateProgress(List<TaskMilestone> milestones) {
    if (milestones.isEmpty) return 0.0;
    final completed = milestones.where((m) => m.isCompleted).length;
    return completed / milestones.length;
  }

  static List<TaskMilestone> defaultMilestones(String serviceType) {
    if (serviceType.toLowerCase().contains('towing')) {
      return [
        TaskMilestone(id: 'assigned', title: 'Provider Assigned', isCompleted: true),
        TaskMilestone(id: 'en_route', title: 'En Route'),
        TaskMilestone(id: 'arrived', title: 'Arrived at Scene'),
        TaskMilestone(id: 'loaded', title: 'Vehicle Loaded'),
        TaskMilestone(id: 'completed', title: 'Delivered'),
      ];
    } else {
      return [
        TaskMilestone(id: 'dispatched', title: 'Team Dispatched'),
        TaskMilestone(id: 'setup', title: 'Arrival & Setup'),
        TaskMilestone(id: 'in_progress', title: 'Service Underway'),
        TaskMilestone(id: 'inspection', title: 'Final Inspection'),
        TaskMilestone(id: 'completed', title: 'Completed'),
      ];
    }
  }

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      assignedProviderId: data['assignedProviderId'],
      assignedDriverId: data['assignedDriverId'],
      assignedDriverName: data['assignedDriverName'],
      serviceType: data['serviceType'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      status: TaskStatus.values.asNameMap()[data['status']] ?? TaskStatus.unassigned,
      priority: TaskPriority.values.asNameMap()[data['priority']] ?? TaskPriority.medium,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble(),
      finalCost: (data['finalCost'] as num?)?.toDouble(),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] as int?,
      bookingId: data['bookingId'],
      completedImageUrl: data['completedImageUrl'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      barangay: data['barangay'],
      zone: data['zone'],
      landmarkDescription: data['landmarkDescription'],
      problemCategory: data['problemCategory'],
      issueCategory: data['issueCategory'],
      adminFee: (data['adminFee'] as num?)?.toDouble(),
      assignedTruckId: data['assignedTruckId'],
      assignedTruckName: data['assignedTruckName'],
      assignedPersonnelIds: data['assignedPersonnelIds'] is List 
          ? List<String>.from(data['assignedPersonnelIds']) 
          : [],
      assignedPersonnelNames: data['assignedPersonnelNames'] is List 
          ? List<String>.from(data['assignedPersonnelNames']) 
          : [],
      assignedAssets: data['assignedAssets'] is Map
          ? (data['assignedAssets'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            )
          : {},
      selectedSubServices: data['selectedSubServices'] is Map
          ? (data['selectedSubServices'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            )
          : null,
      serviceDetails: data['serviceDetails'] as Map<String, dynamic>?,
      preTowPhotoUrls: data['preTowPhotoUrls'] != null ? List<String>.from(data['preTowPhotoUrls']) : [],
      customerSignatureUrl: data['customerSignatureUrl'],
      milestones: (data['milestones'] as List?)
              ?.map((m) => TaskMilestone.fromMap(m as Map<String, dynamic>))
              .toList(),
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      if (assignedProviderId != null) 'assignedProviderId': assignedProviderId,
      if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
      if (assignedDriverName != null) 'assignedDriverName': assignedDriverName,
      'serviceType': serviceType,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'estimatedCost': estimatedCost,
      'finalCost': finalCost,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'bookingId': bookingId,
      'completedImageUrl': completedImageUrl,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'barangay': barangay,
      'zone': zone,
      'landmarkDescription': landmarkDescription,
      'problemCategory': problemCategory,
      'issueCategory': issueCategory,
      'adminFee': adminFee,
      'assignedTruckId': assignedTruckId,
      'assignedTruckName': assignedTruckName,
      'assignedPersonnelIds': assignedPersonnelIds,
      'assignedPersonnelNames': assignedPersonnelNames,
      'assignedAssets': assignedAssets,
      'selectedSubServices': selectedSubServices,
      'serviceDetails': serviceDetails,
      'preTowPhotoUrls': preTowPhotoUrls,
      'customerSignatureUrl': customerSignatureUrl,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'progress': progress,
    };
  }

  Task copyWith({
    String? id,
    String? customerId,
    String? assignedProviderId,
    String? assignedDriverId,
    String? assignedDriverName,
    String? serviceType,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? scheduledDate,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? estimatedCost,
    double? finalCost,
    int? estimatedDurationMinutes,
    String? bookingId,
    String? completedImageUrl,
    DateTime? completedAt,
    String? barangay,
    String? zone,
    String? landmarkDescription,
    String? problemCategory,
    String? issueCategory,
    double? adminFee,
    String? assignedTruckId,
    String? assignedTruckName,
    List<String>? assignedPersonnelIds,
    List<String>? assignedPersonnelNames,
    Map<String, int>? assignedAssets,
    Map<String, int>? selectedSubServices,
    Map<String, dynamic>? serviceDetails,
    List<String>? preTowPhotoUrls,
    String? customerSignatureUrl,
    List<TaskMilestone>? milestones,
    double? progress,
  }) {
    return Task(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      assignedProviderId: assignedProviderId ?? this.assignedProviderId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      serviceType: serviceType ?? this.serviceType,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      finalCost: finalCost ?? this.finalCost,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      bookingId: bookingId ?? this.bookingId,
      completedImageUrl: completedImageUrl ?? this.completedImageUrl,
      completedAt: completedAt ?? this.completedAt,
      barangay: barangay ?? this.barangay,
      zone: zone ?? this.zone,
      landmarkDescription: landmarkDescription ?? this.landmarkDescription,
      problemCategory: problemCategory ?? this.problemCategory,
      issueCategory: issueCategory ?? this.issueCategory,
      adminFee: adminFee ?? this.adminFee,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
      assignedTruckName: assignedTruckName ?? this.assignedTruckName,
      assignedPersonnelIds: assignedPersonnelIds ?? this.assignedPersonnelIds,
      assignedPersonnelNames: assignedPersonnelNames ?? this.assignedPersonnelNames,
      assignedAssets: assignedAssets ?? this.assignedAssets,
      selectedSubServices: selectedSubServices ?? this.selectedSubServices,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      preTowPhotoUrls: preTowPhotoUrls ?? this.preTowPhotoUrls,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
      milestones: milestones ?? this.milestones,
      progress: progress ?? this.progress,
    );
  }
}
