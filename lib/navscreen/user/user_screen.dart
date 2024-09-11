import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isUploading = false;
  String _photoURL = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _photoURL = user?.photoURL ?? '';
  }

  Future<void> _updateDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.updateProfile(displayName: _nameController.text);
        await user.reload();
        setState(() {
          _isEditing = false; // Hide the input
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Display name updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update display name: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });

      File file = File(pickedFile.path);
      try {
        final storageRef = FirebaseStorage.instance.ref().child('avatars/${FirebaseAuth.instance.currentUser?.uid}.jpg');
        final uploadTask = storageRef.putFile(file);

        uploadTask.snapshotEvents.listen((taskSnapshot) {
          if (taskSnapshot.state == TaskState.success) {
            print('Upload successful');
          } else if (taskSnapshot.state == TaskState.running) {
            print('Upload in progress');
          }
        });

        await uploadTask;
        String downloadURL = await storageRef.getDownloadURL();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePhotoURL(downloadURL);
          await user.reload();
          setState(() {
            _photoURL = downloadURL;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile picture updated successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _isUploading = false; // Hide loading
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('User Screen'),
        leading: Container(),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _photoURL.isNotEmpty
                        ? NetworkImage(_photoURL)
                        : AssetImage('assets/placeholder.png') as ImageProvider,
                  ),
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                Positioned(
                  left: -10,
                  top: -10,
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.displayName ?? 'Unknown User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                if (!_isEditing)
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
              ],
            ),
            SizedBox(height: 8),
            Divider(
              color: Colors.grey,
              thickness: 1,
            ),
            if (_isEditing)
              Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Update Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _updateDisplayName,
                    child: Text('Submit'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
