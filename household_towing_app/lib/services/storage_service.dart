import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

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

  /// Upload task evidence image
  Future<String?> uploadTaskEvidenceImage(String taskId, XFile image, int index) async {
    try {
      final String fileName = 'evidence_${taskId}_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('tasks').child(taskId).child('evidence').child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = ref.putFile(File(image.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Evidence upload failed: $e');
      return null;
    }
  }

  /// Upload a signature directly from Uint8List to avoid XFile path issues on mobile
  Future<String?> uploadSignature(String taskId, Uint8List signatureData) async {
    try {
      final String fileName = 'signature_${taskId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final Reference ref = _storage.ref().child('tasks').child(taskId).child('signatures').child(fileName);

      final UploadTask uploadTask = ref.putData(
        signatureData,
        SettableMetadata(contentType: 'image/png'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Upload a verification document for a provider (Base64 Bypass)
  Future<String?> uploadVerificationDocument(
    String providerId,
    XFile image,
    String docType,
  ) async {
    try {
      // Bypass Firebase Storage completely to avoid billing/CORS issues
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';
      
      print('Document encoded to Base64 successfully');
      return dataUri;
    } catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }

  /// Upload an image sent in a chat message
  Future<String?> uploadChatImage(String bookingId, XFile image) async {
    try {
      final String fileName =
          'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage
          .ref()
          .child('chats')
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
      print('Chat image upload failed: $e');
      return null;
    }
  }
}
