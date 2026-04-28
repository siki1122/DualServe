import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  converted_to_task,
  cancelled,
}

class Booking {
  final String id;
  final String customerId;
  final String? assignedProviderId;
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

  Booking({
    required this.id,
    required this.customerId,
    this.assignedProviderId,
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
  });

  // Convert from Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      assignedProviderId: data['assignedProviderId'],
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
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'assignedProviderId': assignedProviderId,
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
    };
  }

  // Create a copy with modified fields
  Booking copyWith({
    String? id,
    String? customerId,
    String? assignedProviderId,
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
  }) {
    return Booking(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      assignedProviderId: assignedProviderId ?? this.assignedProviderId,
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
    );
  }

  @override
  String toString() {
    return 'Booking(id: $id, customer: $customerId, status: ${status.toString().split('.').last}, date: $scheduledDate)';
  }
}
