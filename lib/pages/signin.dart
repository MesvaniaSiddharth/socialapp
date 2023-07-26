import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:socialapp/pages/otp.dart';
import '../Servives/auth.dart';

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  TextEditingController _countrycode = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  Text? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _countrycode.text = '+91';
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required.';
    }
    if (value.length != 10) {
      return 'Phone number must be 10 digits.';
    }
    if (!value.startsWith('9') &&
        !value.startsWith('8') &&
        !value.startsWith('1') &&
        !value.startsWith('7')) {
      return 'Phone number must start with 9, 8, 1, or 7.';
    }
    return null;
  }

  void _signIn(BuildContext context) async {
    String countryCode = _countrycode.text;
    String phoneNumber = _phoneController.text;

    if (countryCode.isNotEmpty && phoneNumber.isNotEmpty) {
      String fullPhoneNumber = countryCode + phoneNumber;

      setState(() {
        _loading = true;
      });

      AuthMethods().storePhoneNumber(fullPhoneNumber);
      AuthMethods().verifyPhoneNumber(
        fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Handle verification completed
        },
        verificationFailed: (FirebaseAuthException exception) {
          // Handle verification failed
          setState(() {
            _errorMessage = Text('Invalid phone number. Please try again.');
            _loading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) async {
          // Save the phone number in Firestore
          await _savePhoneNumberToFirestore(fullPhoneNumber);

          // Show snackbar message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('OTP has been sent successfully to $fullPhoneNumber'),
            ),
          );

          // Navigate to the OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPPage(
                verificationId: verificationId,
                countryCode: countryCode,
                phoneNumber: phoneNumber,
                documentID: _documentID,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle code auto-retrieval timeout
        },
      );
    } else {
      setState(() {
        _errorMessage = Text('Please enter a valid phone number.');
      });
    }
  }

  String? _documentID;

  Future<void> _savePhoneNumberToFirestore(String phoneNumber) async {
    CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await usersCollection
        .where('phonenumber', isEqualTo: phoneNumber)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Document already exists with the given phone number
      return;
    }

    Map<String, dynamic> userData = {
      'name': null,
      'email': null,
      'phonenumber': phoneNumber,
      'DOB': null,
      'photourl': null,
    };

    DocumentReference userRef = await usersCollection.add(userData);
    String autogeneratedId = userRef.id; // Replace with the autogenerated ID
    await userRef.update({'phonenumber': phoneNumber});
    _documentID = userRef.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        margin: const EdgeInsets.only(right: 25, left: 25),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/img1.png',
                height: 150,
                width: 150,
              ),
              const SizedBox(
                height: 25,
              ),
              const Text(
                "Sign Up",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                "We need to register your phone number before getting started.",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w100,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 30,
              ),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 10,
                    ),
                    SizedBox(
                      width: 40,
                      child: TextField(
                        controller: _countrycode,
                        decoration:
                            const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    const Text(
                      "|",
                      style: TextStyle(fontSize: 33, color: Colors.grey),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.phone,
                        controller: _phoneController,
                        validator: validatePhone,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter your phone number!",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 45,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : () {
                          if (_countrycode.text.isNotEmpty &&
                              _phoneController.text.isNotEmpty) {
                            _signIn(context);
                          }
                        },
                  child: _loading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Send the code',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              if (_errorMessage != null) _errorMessage!,
            ],
          ),
        ),
      ),
    );
  }
}