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

class Task {
  final String id;
  final String customerId;
  final String? assignedProviderId;
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
  final int? estimatedDurationMinutes;
  final String? bookingId; // Links to original booking if created from booking
  final String? completedImageUrl;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.customerId,
    this.assignedProviderId,
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
    this.estimatedDurationMinutes,
    this.bookingId,
    this.completedImageUrl,
    this.completedAt,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      assignedProviderId: data['assignedProviderId'],
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
      estimatedDurationMinutes: data['estimatedDurationMinutes'] as int?,
      bookingId: data['bookingId'],
      completedImageUrl: data['completedImageUrl'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'assignedProviderId': assignedProviderId,
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
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'bookingId': bookingId,
      'completedImageUrl': completedImageUrl,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  Task copyWith({
    String? id,
    String? customerId,
    String? assignedProviderId,
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
    int? estimatedDurationMinutes,
    String? bookingId,
    String? completedImageUrl,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      assignedProviderId: assignedProviderId ?? this.assignedProviderId,
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
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      bookingId: bookingId ?? this.bookingId,
      completedImageUrl: completedImageUrl ?? this.completedImageUrl,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
