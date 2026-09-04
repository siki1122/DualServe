import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:household_towing_app/utils/app_theme.dart';


enum IncidentType { congestion, accident, roadwork, hazard, closure }

class IncidentModel {
  final String id;
  final String title;
  final String description;
  final IncidentType type;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String reportedBy;

  IncidentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.reportedBy,
  });

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncidentModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: IncidentType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'hazard'),
        orElse: () => IncidentType.hazard,
      ),
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reportedBy: data['reportedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'reportedBy': reportedBy,
    };
  }

  IconData get icon {
    switch (type) {
      case IncidentType.congestion:
        return Icons.traffic;
      case IncidentType.accident:
        return Icons.car_crash;
      case IncidentType.roadwork:
        return Icons.construction;
      case IncidentType.hazard:
        return Icons.warning_amber_rounded;
      case IncidentType.closure:
        return Icons.block;
    }
  }

  Color get color {
    switch (type) {
      case IncidentType.congestion:
        return AppTheme.towingOrange;
      case IncidentType.accident:
        return Colors.red;
      case IncidentType.roadwork:
        return AppTheme.primaryBlue;
      case IncidentType.hazard:
        return Colors.amber;
      case IncidentType.closure:
        return AppTheme.textSlateDark;
    }
  }
}
