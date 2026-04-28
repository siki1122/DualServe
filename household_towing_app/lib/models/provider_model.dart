import 'package:cloud_firestore/cloud_firestore.dart';

enum ProviderStatus { available, busy, offline, on_vacation }

class Provider {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String specialty;
  final ProviderStatus status;
  final double rating;
  final int jobsCompleted;
  final String serviceType;
  final Map<String, List<String>> weeklySchedule; // Day → TimeSlots
  final List<String> blockOutDates; // ISO format: "2026-04-25"
  final int maxTasksPerDay;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;

  Provider({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.specialty,
    this.status = ProviderStatus.available,
    this.rating = 0.0,
    this.jobsCompleted = 0,
    required this.serviceType,
    this.weeklySchedule = const {},
    this.blockOutDates = const [],
    this.maxTasksPerDay = 10,
    required this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
  });

  // Convert from Firestore document
  factory Provider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse weekly schedule
    final scheduleData = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
    final weeklySchedule = scheduleData.map(
      (key, value) => MapEntry(key, List<String>.from(value ?? [])),
    );

    return Provider(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      specialty: data['specialty'] ?? '',
      status:
          ProviderStatus.values.asNameMap()[data['status']] ??
          ProviderStatus.available,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      jobsCompleted: data['jobsCompleted'] as int? ?? 0,
      serviceType: data['serviceType'] ?? '',
      weeklySchedule: weeklySchedule,
      blockOutDates: List<String>.from(data['blockOutDates'] ?? []),
      maxTasksPerDay: data['maxTasksPerDay'] as int? ?? 10,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'specialty': specialty,
      'status': status.toString().split('.').last,
      'rating': rating,
      'jobsCompleted': jobsCompleted,
      'serviceType': serviceType,
      'weeklySchedule': weeklySchedule,
      'blockOutDates': blockOutDates,
      'maxTasksPerDay': maxTasksPerDay,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create a copy with modified fields
  Provider copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? specialty,
    ProviderStatus? status,
    double? rating,
    int? jobsCompleted,
    String? serviceType,
    Map<String, List<String>>? weeklySchedule,
    List<String>? blockOutDates,
    int? maxTasksPerDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Provider(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      specialty: specialty ?? this.specialty,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      jobsCompleted: jobsCompleted ?? this.jobsCompleted,
      serviceType: serviceType ?? this.serviceType,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      blockOutDates: blockOutDates ?? this.blockOutDates,
      maxTasksPerDay: maxTasksPerDay ?? this.maxTasksPerDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if provider is blocked on a specific date (ISO format)
  bool isBlockedOnDate(String dateISO) {
    return blockOutDates.contains(dateISO);
  }

  // Get availability slots for a specific day of week (e.g., "Monday")
  List<String> getAvailableSlotsForDay(String dayName) {
    return weeklySchedule[dayName] ?? [];
  }

  @override
  String toString() {
    return 'Provider(id: $id, name: $name, status: ${status.toString().split('.').last})';
  }
}
