import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final CollectionReference _images = FirebaseFirestore.instance.collection('images');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadMessage;

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _pickImage(ImageSource.camera);
            },
            child: Text('Camera'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _pickImage(ImageSource.gallery);
            },
            child: Text('Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadMessage = null;
    });

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      File file = File(pickedFile.path);
      UploadTask uploadTask = FirebaseStorage.instance.ref('uploads/$fileName').putFile(file);
      await uploadTask.whenComplete(() => null);
      String downloadUrl = await FirebaseStorage.instance.ref('uploads/$fileName').getDownloadURL();
      await _images.add({'url': downloadUrl});
      setState(() {
        _uploadMessage = 'Successfully uploaded!';
      });
    } catch (e) {
      setState(() {
        _uploadMessage = 'Failed to upload image: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showImagePreview(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ImagePreviewScreen(imageUrl: imageUrl),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Gallery'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder(
            stream: _images.snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  String imageUrl = snapshot.data!.docs[index]['url'];
                  return GestureDetector(
                    onTap: () => _showImagePreview(imageUrl),
                    child: Container(
                      margin: EdgeInsets.all(8.0),
                      padding: EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isUploading) Center(child: CircularProgressIndicator()),
          if (_uploadMessage != null) Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _uploadMessage!,
                style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImageSourceDialog,
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  ImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Preview'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => Share.share(imageUrl),
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        itemCount: 1,
        builder: (context, index) => PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
        scrollPhysics: BouncingScrollPhysics(),
        backgroundDecoration: BoxDecoration(color: Colors.black),
        pageController: PageController(),
      ),
    );
  }
}
