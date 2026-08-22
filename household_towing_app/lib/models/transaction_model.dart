import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { pending, completed, cancelled }

enum PaymentStatus { pending, recorded }

class Transaction {
  final String id;
  final String taskId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceType;
  final String? specificService;
  final Map<String, int>? selectedSubServices;
  final Map<String, dynamic>? serviceDetails;
  final double basePrice;
  final double distanceTraveled; // in kilometers
  final double costPerKm;
  final double distanceSurcharge; // calculated: distanceTraveled * costPerKm
  final double finalCost; // basePrice + distanceSurcharge + additionalCost
  final double adminFee; // portion of finalCost that goes to admin
  final double additionalCost;
  final TransactionStatus status;
  final PaymentStatus paymentStatus;
  final String? providerNotes;
  final DateTime completedAt;
  final DateTime? recordedAt;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.taskId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceType,
    this.specificService,
    this.selectedSubServices,
    this.serviceDetails,
    required this.basePrice,
    required this.distanceTraveled,
    required this.costPerKm,
    required this.distanceSurcharge,
    required this.finalCost,
    this.adminFee = 0.0,
    this.additionalCost = 0.0,
    this.status = TransactionStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.providerNotes,
    required this.completedAt,
    this.recordedAt,
    required this.createdAt,
  });

  /// Create a Transaction from a Firestore document
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceType: data['serviceType'] ?? '',
      specificService: data['specificService'],
      selectedSubServices: data['selectedSubServices'] is Map
          ? (data['selectedSubServices'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            )
          : null,
      serviceDetails: data['serviceDetails'] as Map<String, dynamic>?,
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      distanceTraveled: (data['distanceTraveled'] as num?)?.toDouble() ?? 0.0,
      costPerKm: (data['costPerKm'] as num?)?.toDouble() ?? 0.0,
      distanceSurcharge: (data['distanceSurcharge'] as num?)?.toDouble() ?? 0.0,
      finalCost: (data['finalCost'] as num?)?.toDouble() ?? 0.0,
      adminFee: (data['adminFee'] as num?)?.toDouble() ?? 0.0,
      additionalCost: (data['additionalCost'] as num?)?.toDouble() ?? 0.0,
      status:
          TransactionStatus.values.asNameMap()[data['status']] ??
          TransactionStatus.pending,
      paymentStatus:
          PaymentStatus.values.asNameMap()[data['paymentStatus']] ??
          PaymentStatus.pending,
      providerNotes: data['providerNotes'],
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert Transaction to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'serviceType': serviceType,
      'specificService': specificService,
      'selectedSubServices': selectedSubServices,
      'serviceDetails': serviceDetails,
      'basePrice': basePrice,
      'distanceTraveled': distanceTraveled,
      'costPerKm': costPerKm,
      'distanceSurcharge': distanceSurcharge,
      'finalCost': finalCost,
      'adminFee': adminFee,
      'additionalCost': additionalCost,
      'status': status.toString().split('.').last,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'providerNotes': providerNotes,
      'completedAt': Timestamp.fromDate(completedAt),
      'recordedAt': recordedAt != null ? Timestamp.fromDate(recordedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with modified fields
  Transaction copyWith({
    String? id,
    String? taskId,
    String? bookingId,
    String? customerId,
    String? providerId,
    String? serviceType,
    String? specificService,
    Map<String, int>? selectedSubServices,
    Map<String, dynamic>? serviceDetails,
    double? basePrice,
    double? distanceTraveled,
    double? costPerKm,
    double? distanceSurcharge,
    double? finalCost,
    double? adminFee,
    double? additionalCost,
    TransactionStatus? status,
    PaymentStatus? paymentStatus,
    String? providerNotes,
    DateTime? completedAt,
    DateTime? recordedAt,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceType: serviceType ?? this.serviceType,
      specificService: specificService ?? this.specificService,
      selectedSubServices: selectedSubServices ?? this.selectedSubServices,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      basePrice: basePrice ?? this.basePrice,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      costPerKm: costPerKm ?? this.costPerKm,
      distanceSurcharge: distanceSurcharge ?? this.distanceSurcharge,
      finalCost: finalCost ?? this.finalCost,
      adminFee: adminFee ?? this.adminFee,
      additionalCost: additionalCost ?? this.additionalCost,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      providerNotes: providerNotes ?? this.providerNotes,
      completedAt: completedAt ?? this.completedAt,
      recordedAt: recordedAt ?? this.recordedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, task: $taskId, provider: $providerId, amount: ₱$finalCost, status: ${status.toString().split('.').last})';
  }
}
