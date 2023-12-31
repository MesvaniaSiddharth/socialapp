import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socialapp/pages/people.dart';
import 'package:email_validator/email_validator.dart';

import 'otp.dart';

class UserRegistrationPage extends StatefulWidget {
  final String phoneNumber;
  final String? documentID;

  const UserRegistrationPage(
      {Key? key, required this.phoneNumber, this.documentID})
      : super(key: key);

  @override
  _UserRegistrationPageState createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  bool _isLoading = false;
  bool _showRequiredError = false;
  bool _isFormSubmitted = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;
  File? _image;

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_image != null) {
      String imageName =
          DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
      String imagePath = 'users/${widget.documentID}/photourl/$imageName';
      firebase_storage.Reference ref = _storage.ref().child(imagePath);
      firebase_storage.UploadTask uploadTask = ref.putFile(_image!);

      try {
        await uploadTask;
        firebase_storage.TaskSnapshot storageSnapshot =
            await uploadTask.whenComplete(() {});
        String imageUrl = await storageSnapshot.ref.getDownloadURL();
        return imageUrl;
      } catch (e) {
        print('Error uploading photo: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> _registerUser() async {
    setState(() {
      _isFormSubmitted = true;
    });
    // Perform validation
    if (nameController.text.isEmpty ||
        dobController.text.isEmpty ||
        _image == null || 
        (_isFormSubmitted && !EmailValidator.validate(emailController.text))) {
      setState(() {
        _showRequiredError = true;
      });
      return;
    }

    // Perform any desired actions with the collected user data
    String name = nameController.text;
    String email = emailController.text;
    String dob = dobController.text;
    String phoneNumber = widget.phoneNumber;

    // Check if the email is empty or not valid
    bool isEmailInvalid = email.isNotEmpty && !EmailValidator.validate(email);
    setState(() {
      _showRequiredError = true;
    });
      return;
    

    // Upload profile picture and get the download URL
    String? photoUrl = await _uploadPhoto();

    try {
      setState(() {
        _isLoading = true;
      });

      CollectionReference usersCollection =
          FirebaseFirestore.instance.collection('users');
      DocumentReference userRef = usersCollection.doc(widget.documentID);
      // Save user information to Firestore and get the autogenerated ID
      await userRef.update({
        'name': name,
        'email': email,
        'DOB': dob,
        'photourl': photoUrl ?? null, // Use empty string if photoUrl is null
      });

      // Navigate to the People List page
      Navigator.pushReplacementNamed(context, 'people');
    } catch (e) {
      print('Error saving user information: $e');
      // Show an error message or handle the error as needed
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Registration'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _uploadImage();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          _image != null ? FileImage(_image!) : null,
                      backgroundColor: Colors.grey,
                    ),
                    if (_image == null)
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Add Image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  errorText: _showRequiredError && nameController.text.isEmpty
                      ? 'Required'
                      : null,
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  errorText: _showRequiredError && emailController.text.isEmpty
                      ? 'Required'
                      : !EmailValidator.validate(emailController.text)
                          ? 'Invalid email'
                          : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _showRequiredError = false;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  errorText: _showRequiredError && dobController.text.isEmpty
                      ? 'Required'
                      : null,
                ),
                readOnly: true,
                onTap: () {
                  showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  ).then((selectedDate) {
                    if (selectedDate != null) {
                      dobController.text =
                          selectedDate.toString().split(' ')[0];
                    }
                  });
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _showRequiredError = false;
                          });
                          _registerUser();
                        },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 50),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
