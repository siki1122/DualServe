import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024, // Compress to save data/space
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// Upload image to Firebase Storage and return the download URL
  Future<String?> uploadServiceImage(String bookingId, XFile image) async {
    try {
      final String fileName =
          'service_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage
          .ref()
          .child('bookings')
          .child(bookingId)
          .child(fileName);

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web requires bytes
        final bytes = await image.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Mobile can use File
        uploadTask = ref.putFile(File(image.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }
}
