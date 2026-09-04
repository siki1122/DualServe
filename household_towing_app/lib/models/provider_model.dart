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
  final int totalReviews;
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
  final String? businessPermitUrl;
  final String? governmentIdUrl;
  final String verificationStatus; // 'pending', 'verified', 'rejected'
  final String? rejectionReason;
  final String inviteCode;

  final String serviceArea; // 'All Areas' by default, or e.g., 'Quezon City only'
  final Map<String, String> serviceAreas; // Specific service availability areas: {"Wheel lift": "Quezon City only"}
  final Map<String, dynamic> offeredServices; // Can be a double (flat rate) or a Map (complex ServiceDefinition)

  Provider({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.specialty,
    this.status = ProviderStatus.available,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.jobsCompleted = 0,
    required this.serviceType,
    this.serviceTypes = const [],
    this.offeredServices = const {},
    this.serviceAreas = const {},
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
    this.businessPermitUrl,
    this.governmentIdUrl,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.serviceArea = 'All Areas',
    this.inviteCode = '',
  });

  // Convert from Firestore document
  factory Provider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse weekly schedule
    final scheduleData = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
    final weeklySchedule = scheduleData.map(
      (key, value) => MapEntry(key, List<String>.from(value ?? [])),
    );

    // Parse offered services (Map of name -> dynamic)
    final servicesData = data['offeredServices'] as Map<String, dynamic>? ?? {};
    final offeredServices = servicesData.map(
      (key, value) {
        if (value is num) {
          return MapEntry(key, value.toDouble());
        } else if (value is Map) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        }
        return MapEntry(key, 0.0);
      },
    );

    // Parse specific service areas (Map of name -> area)
    final areasData = data['serviceAreas'] as Map<String, dynamic>? ?? {};
    final serviceAreas = areasData.map(
      (key, value) => MapEntry(key, value.toString()),
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
      totalReviews: data['totalReviews'] as int? ?? 0,
      jobsCompleted: data['jobsCompleted'] as int? ?? 0,
      serviceType: data['serviceType'] ?? '',
      serviceTypes: _parseServiceTypes(data),
      offeredServices: offeredServices,
      serviceAreas: serviceAreas,
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
      businessPermitUrl: data['businessPermitUrl'],
      governmentIdUrl: data['governmentIdUrl'],
      verificationStatus: data['verificationStatus'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      serviceArea: data['serviceArea'] ?? 'All Areas',
      inviteCode: data['inviteCode'] ?? '',
    );
  }

  static List<String> _parseServiceTypes(Map<String, dynamic> data) {
    final Set<String> types = {};
    if (data['serviceTypes'] != null) {
      types.addAll(List<String>.from(data['serviceTypes']));
    }
    if (data['services'] != null) {
      types.addAll(List<String>.from(data['services']));
    }
    if (data['serviceType'] != null && data['serviceType'].toString().isNotEmpty) {
      types.add(data['serviceType'].toString());
    }
    
    // If this is obviously a household services account but Towing was accidentally saved (e.g. from a default value bug)
    if ((data['serviceType'] == 'Household Services' || data['specialty'].toString().toLowerCase().contains('house')) && types.contains('Towing')) {
      types.remove('Towing');
    }
    if (types.isEmpty) {
      types.add('Towing'); // Fallback if completely empty
    }
    return types.toList();
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
      'totalReviews': totalReviews,
      'jobsCompleted': jobsCompleted,
      'serviceType': serviceType,
      'serviceTypes': serviceTypes,
      'offeredServices': offeredServices,
      'serviceAreas': serviceAreas,
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
      'businessPermitUrl': businessPermitUrl,
      'governmentIdUrl': governmentIdUrl,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'serviceArea': serviceArea,
      'inviteCode': inviteCode,
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
    int? totalReviews,
    int? jobsCompleted,
    String? serviceType,
    List<String>? serviceTypes,
    Map<String, dynamic>? offeredServices,
    Map<String, String>? serviceAreas,
    Map<String, List<String>>? weeklySchedule,
    List<String>? blockOutDates,
    int? maxTasksPerDay,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? businessPermitUrl,
    String? governmentIdUrl,
    String? verificationStatus,
    String? rejectionReason,
    String? serviceArea,
    String? inviteCode,
  }) {
    return Provider(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      specialty: specialty ?? this.specialty,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      jobsCompleted: jobsCompleted ?? this.jobsCompleted,
      serviceType: serviceType ?? this.serviceType,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      offeredServices: offeredServices ?? this.offeredServices,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      blockOutDates: blockOutDates ?? this.blockOutDates,
      maxTasksPerDay: maxTasksPerDay ?? this.maxTasksPerDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      businessPermitUrl: businessPermitUrl ?? this.businessPermitUrl,
      governmentIdUrl: governmentIdUrl ?? this.governmentIdUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      serviceArea: serviceArea ?? this.serviceArea,
      inviteCode: inviteCode ?? this.inviteCode,
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
