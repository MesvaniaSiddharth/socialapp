import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialapp/pages/register.dart';

class OTPPage extends StatefulWidget {
  final String verificationId;
  final String countryCode;
  final String phoneNumber;
  final String? documentID;

  const OTPPage({
    Key? key,
    required this.verificationId,
    required this.countryCode,
    required this.phoneNumber,
    this.documentID,
  }) : super(key: key);

  @override
  _OTPPageState createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/img1.png',
                  height: 150,
                  width: 150,
                ),
                const SizedBox(height: 25),
                const Text(
                  "Phone Verification",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We need to verify your phone number before getting started.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w100,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the OTP';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _isLoading ? null : _verifyOTP,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Verify',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Edit Phone Number',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : _resendOTP,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setLoggedIn(bool isLoggedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<void> _logout() async {
    await _setLoggedIn(false);
  }

  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      String otp = _otpController.text;
      String phoneNumber = widget.countryCode + widget.phoneNumber;

      setState(() {
        _isLoading = true;
      });

      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otp,
        );

        // Sign in with the provided credential
        UserCredential userCredential =
            await auth.signInWithCredential(credential);

        // Check if the authentication was successful
        if (userCredential.user != null) {
          // OTP verification successful
          // You can now perform actions based on whether the user exists or not

          // Verify if the user exists in the database
          CollectionReference usersCollection =
              FirebaseFirestore.instance.collection('users');
          QuerySnapshot<Object?> userSnapshot = await usersCollection
              .where('phonenumber', isEqualTo: phoneNumber)
              .get();

          if (userSnapshot.docs.isNotEmpty) {
            // User with matching phone number found
            DocumentSnapshot<Map<String, dynamic>> userDoc = userSnapshot
                .docs.first as DocumentSnapshot<Map<String, dynamic>>;

            // Print the available fields in the DocumentSnapshot
            print('Available fields in the DocumentSnapshot:');
            userDoc.data()?.forEach((key, value) {
              print('$key: $value');
            });

            bool isPhoneNumberNotNull = userDoc.data()?['phonenumber'] != null;
            bool isNameNotNull = userDoc.data()?['name'] != null;
            bool isEmailFieldExists =
                userDoc.data()?.containsKey('email') ?? false;
            bool isDOBFieldExists = userDoc.data()?.containsKey('DOB') ?? false;
            bool isPhotoUrlFieldExists =
                userDoc.data()?.containsKey('photourl') ?? false;

            if (isPhoneNumberNotNull &&
                isNameNotNull &&
                isEmailFieldExists &&
                isDOBFieldExists &&
                isPhotoUrlFieldExists) {
              await _setLoggedIn(true);
              // User exists and has all required information, navigate to the People List
              print('User exists and has all required information');
              Navigator.pushReplacementNamed(context, 'people');
            } else {
              // User does not exist or does not have all required information, navigate to the Registration Page
              print(
                  'User does not exist or does not have all required information');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRegistrationPage(
                    phoneNumber: phoneNumber,
                    documentID: widget.documentID,
                  ),
                ),
              );
            }
          } else {
            // User does not exist, navigate to the Registration Page
            print('User does not exist');
            Navigator.pushReplacementNamed(context, 'reg',
                arguments: phoneNumber);
            return;
          }
        } else {
          // Handle case when the user is null after OTP verification
          print('User is null after OTP verification');
          _showSnackBar('The OTP entered is incorrect.');
        }
      } catch (e) {
        // Handle verification failure or any other errors
        print('Error occurred during OTP verification: $e');
        _showSnackBar('An error occurred while verifying the OTP.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    String phoneNumber = widget.countryCode + widget.phoneNumber;
    String newVerificationId = ''; // Variable to store the new verification ID

    setState(() {
      _isLoading = true;
    });

    // Define the function for verification completed
    void verificationCompleted(PhoneAuthCredential credential) {
      // Handle verification completed
    }

    // Define the function for verification failed
    void verificationFailed(FirebaseAuthException exception) {
      // Handle verification failed
    }

    // Define the function for code sent
    void codeSent(String verificationId, int? resendToken) async {
      // Update the new verification ID
      newVerificationId = verificationId;

      // Show a Snackbar to inform the user that the OTP has been resent
      _showSnackBar('OTP has been resent to your phone number.');
    }

    // Define the function for code auto-retrieval timeout
    void codeAutoRetrievalTimeout(String verificationId) {
      // Handle code auto-retrieval timeout
    }

    // Resend the OTP
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
