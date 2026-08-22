import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverStatus { available, busy, offline }

class Driver {
  final String id;
  final String providerId; // The company they are linked to
  final String name;
  final String phone;
  final String email;
  final DriverStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Driver({
    required this.id,
    required this.providerId,
    required this.name,
    required this.phone,
    required this.email,
    this.status = DriverStatus.available,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Driver(
      id: doc.id,
      providerId: data['providerId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      status: DriverStatus.values.asNameMap()[data['status']] ?? DriverStatus.available,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Driver copyWith({
    String? id,
    String? providerId,
    String? name,
    String? phone,
    String? email,
    DriverStatus? status,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return Driver(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
