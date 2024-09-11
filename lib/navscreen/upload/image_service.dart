import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      File file = File(image.path);
      String fileName = basename(file.path);
      Reference ref = _storage.ref().child('uploads/$fileName');
      await ref.putFile(file);
      String imageUrl = await ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}
