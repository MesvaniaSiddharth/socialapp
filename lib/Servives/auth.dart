import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialapp/Servives/databse.dart';
import 'package:socialapp/helperfunct/sharedpref_helper.dart';

import '../pages/people.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  Future<void> signIn(BuildContext context, String phoneNumber) async {
    try {
      UserCredential result = await _auth.signInAnonymously();

      User? userDetails = result.user;

      await SharedPreferenceHelper().saveUserPhone(phoneNumber);
      await SharedPreferenceHelper().saveUserId(userDetails!.uid);

      Map<String, dynamic> userInfoMap = {
        "phone": phoneNumber,
        "username": userDetails.displayName,
        "name": userDetails.displayName,
        "imgUrl": userDetails.photoURL
      };

      await DatabaseMethods(_auth).addUserInfoToDB(userDetails.uid, userInfoMap);

      Navigator.pushReplacement(
        context,
        'people' as Route<Object?>
      );
    } catch (e) {
      // Handle sign-in error
      print(e.toString());
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Sign-in Error'),
            content: const Text('An error occurred during sign-in.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> signOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _auth.signOut();
  }

  Future<void> updateUserProfile(
      String name, String email, String dob, File? profilePhoto) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        String profilePhotoUrl = user.photoURL ?? '';

        if (profilePhoto != null) {
          // Upload profile photo to Firebase Storage
          Reference storageReference = FirebaseStorage.instance
              .ref()
              .child('profile_photos/${user.uid}');
          UploadTask uploadTask = storageReference.putFile(profilePhoto);
          TaskSnapshot storageSnapshot = await uploadTask;
          profilePhotoUrl = await storageSnapshot.ref.getDownloadURL();
        }

        // Update user profile data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'name': name,
          'email': email,
          'dob': dob,
          'profilePhotoUrl': profilePhotoUrl,
        });
      }
    } catch (e) {
      // Handle error
      print('Error updating user profile: $e');
    }
  }

  Future<void> storePhoneNumber(String phoneNumber) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phoneNumber', phoneNumber);
  }

  Future<String?> getStoredPhoneNumber() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('phoneNumber');
  }

  Future<void> sendOtp(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {},
      codeSent: (String verificationId, int? resendToken) {
        // Handle OTP code sent
        // You can implement your logic here, such as navigating to the OTP page
        // and passing the verification ID and phone number
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> verifyPhoneNumber(String phoneNumber,
      {required PhoneVerificationCompleted verificationCompleted,
      required PhoneVerificationFailed verificationFailed,
      required PhoneCodeSent codeSent,
      required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout}) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> signInWithCredential(
      BuildContext context, PhoneAuthCredential credential) async {
    try {
      UserCredential result = await _auth.signInWithCredential(credential);

      User? userDetails = result.user;

      await SharedPreferenceHelper().saveUserId(userDetails!.uid);

      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,'people' as Route<Object?>
      );
    } catch (e) {
      // Handle sign-in error
      print(e.toString());
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Sign-in Error'),
            content: const Text('An error occurred during sign-in.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> resendOTP(String countrycode, String phone) async {
    FirebaseAuth auth = FirebaseAuth.instance;
    String phoneNumber = countrycode + phone;
    PhoneVerificationCompleted verificationCompleted =
        (PhoneAuthCredential credential) {
      // Handle verification completed if needed
    };
    PhoneVerificationFailed verificationFailed =
        (FirebaseAuthException authException) {
      // Handle verification failed if needed
    };
    PhoneCodeSent codeSent = (String verificationId, int? resendToken) async {
      // Handle code sent, you can store the verificationId to use it for OTP verification
      // Optionally, you can show a success message or enable a button for manual verification
      verificationId = verificationId; // Update the verificationId
    };
    PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
        (String verificationId) {
      // Handle code auto retrieval timeout if needed
    };

    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 120), // Set an appropriate timeout value
      // You can also provide an optional `forceResendingToken` if you want to forcefully resend the OTP
    );
  }
}
