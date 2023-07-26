import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialapp/pages/chatpage.dart';

import 'package:socialapp/pages/otp.dart';
import 'package:socialapp/pages/people.dart';
import 'package:socialapp/pages/register.dart';
import 'package:socialapp/pages/signin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Check if the user is already logged in
  bool isLoggedIn = await _checkLoggedInState();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}
Future<bool> _checkLoggedInState() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}


class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? 'people' : 'phone',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      routes: {
        'phone': (context) => const SignIn(),
        'otp': (context) => OTPPage(
              verificationId: '',
              countryCode: '',
              phoneNumber: '',
            ),
        'reg': (context) => const UserRegistrationPage(
              phoneNumber: '',
            ),
        'chat': (context) => ChatPage(
              email: '',
              personName: '',
              userId: '',
            ),
        'people': (context) => PeopleListPage(
              logoutCallback: _logout,
            ),
      },
    );
  }

  Future<bool> _checkLoggedInState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

Future<void> _logout() async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    print('Error logging out: $e');
  }
}


  Future<void> _setLoggedIn(bool isLoggedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }
}
