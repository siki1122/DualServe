import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_towing_app/services/booking_service.dart';
import 'package:household_towing_app/models/booking_model.dart';
import 'package:mockito/mockito.dart';

// Very basic mocks for simple testing of the BookingService methods

class FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> mockBookings = {
    'booking_1': {
      'customerId': 'cust1',
      'serviceType': 'Towing',
      'status': 'pending',
    },
  };

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(collectionPath, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollectionReference implements CollectionReference<Map<String, dynamic>> {
  final String path;
  final FakeFirestore firestore;

  FakeCollectionReference(this.path, this.firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(this.path, path ?? 'new_id', firestore);
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) async {
    final id = 'new_booking_${DateTime.now().millisecondsSinceEpoch}';
    firestore.mockBookings[id] = data;
    return FakeDocumentReference(path, id, firestore);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final String collectionPath;
  final String docId;
  final FakeFirestore firestore;

  FakeDocumentReference(this.collectionPath, this.docId, this.firestore);

  @override
  String get id => docId;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final data = firestore.mockBookings[docId];
    return FakeDocumentSnapshot(docId, data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (firestore.mockBookings.containsKey(docId)) {
      final stringData = data.map((key, value) => MapEntry(key.toString(), value));
      firestore.mockBookings[docId]!.addAll(stringData);
    }
  }

  @override
  Future<void> delete() async {
    firestore.mockBookings.remove(docId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final String _id;

  FakeDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BookingService Tests', () {
    late BookingService bookingService;
    late FakeFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirestore();
      bookingService = BookingService(firestore: fakeFirestore);
    });

    test('getBooking returns data if exists', () async {
      final booking = await bookingService.getBooking('booking_1');
      expect(booking, isNotNull);
      expect(booking!.customerId, 'cust1');
      expect(booking.serviceType, 'Towing');
    });

    test('getBooking returns null if not exists', () async {
      final booking = await bookingService.getBooking('unknown');
      expect(booking, isNull);
    });

    test('createBooking adds new booking to collection', () async {
      final newBooking = Booking(
        id: '',
        customerId: 'cust2',
        serviceType: 'Cleaning',
        address: '123 Main',
        scheduledDate: DateTime.now(),
        scheduledTime: '12:00',
        createdAt: DateTime.now(),
      );

      final id = await bookingService.createBooking(newBooking);
      expect(id, startsWith('new_booking_'));
      expect(fakeFirestore.mockBookings[id], isNotNull);
      expect(fakeFirestore.mockBookings[id]!['customerId'], 'cust2');
    });

    test('rescheduleBooking updates date and time', () async {
      final newDate = DateTime(2026, 12, 25);
      await bookingService.rescheduleBooking('booking_1', newDate, '10:00');
      
      final updatedData = fakeFirestore.mockBookings['booking_1'];
      expect((updatedData!['scheduledDate'] as Timestamp).toDate(), newDate);
      expect(updatedData['scheduledTime'], '10:00');
    });

    test('deleteBooking removes booking if pending', () async {
      expect(fakeFirestore.mockBookings.containsKey('booking_1'), true);
      await bookingService.deleteBooking('booking_1');
      expect(fakeFirestore.mockBookings.containsKey('booking_1'), false);
    });
  });
}
