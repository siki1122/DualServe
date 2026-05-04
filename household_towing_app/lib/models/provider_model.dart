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
  final List<String> serviceTypes;
  final Map<String, List<String>> weeklySchedule; // Day → TimeSlots
  final List<String> blockOutDates; // ISO format: "2026-04-25"
  final int maxTasksPerDay;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;
  final String bio;
  final String licenseNumber;
  final int yearsOfExperience;
  final double totalEarnings;
  final int totalRides;
  final String? lastLocation;
  final String profileImageUrl;
  final bool documentsVerified;
  final bool backgroundCheckPassed;

  final Map<String, double> offeredServices; // Specific services and their prices: {"Flatbed": 1500.0}

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
    this.serviceTypes = const [],
    this.offeredServices = const {},
    this.weeklySchedule = const {},
    this.blockOutDates = const [],
    this.maxTasksPerDay = 10,
    required this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.bio = '',
    this.licenseNumber = '',
    this.yearsOfExperience = 0,
    this.totalEarnings = 0.0,
    this.totalRides = 0,
    this.lastLocation,
    this.profileImageUrl = '',
    this.documentsVerified = false,
    this.backgroundCheckPassed = false,
  });

  // Convert from Firestore document
  factory Provider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse weekly schedule
    final scheduleData = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
    final weeklySchedule = scheduleData.map(
      (key, value) => MapEntry(key, List<String>.from(value ?? [])),
    );

    // Parse offered services (Map of name -> price)
    final servicesData = data['offeredServices'] as Map<String, dynamic>? ?? {};
    final offeredServices = servicesData.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
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
      serviceTypes: List<String>.from(data['serviceTypes'] ?? []),
      offeredServices: offeredServices,
      weeklySchedule: weeklySchedule,
      blockOutDates: List<String>.from(data['blockOutDates'] ?? []),
      maxTasksPerDay: data['maxTasksPerDay'] as int? ?? 10,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      bio: data['bio'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      profileImageUrl: data['profileImageUrl'] ?? '',
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
      'serviceTypes': serviceTypes,
      'offeredServices': offeredServices,
      'weeklySchedule': weeklySchedule,
      'blockOutDates': blockOutDates,
      'maxTasksPerDay': maxTasksPerDay,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'bio': bio,
      'licenseNumber': licenseNumber,
      'yearsOfExperience': yearsOfExperience,
      'profileImageUrl': profileImageUrl,
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
    List<String>? serviceTypes,
    Map<String, double>? offeredServices,
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
      serviceTypes: serviceTypes ?? this.serviceTypes,
      offeredServices: offeredServices ?? this.offeredServices,
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
