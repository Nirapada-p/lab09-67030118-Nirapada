import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadListingImage(File imageFile, String sellerId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sellerId}_$timestamp.jpg';

    final storageRef = _storage.ref().child('listing_images').child(fileName);

    // อัปโหลดไฟล์และรอจนเสร็จสมบูรณ์
    await storageRef.putFile(imageFile);

    // ขอ Download URL หลังอัปโหลดสำเร็จแล้วเท่านั้น
    final downloadUrl = await storageRef.getDownloadURL();

    return downloadUrl;
  }
}
