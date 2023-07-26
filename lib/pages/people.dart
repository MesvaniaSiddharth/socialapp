import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialapp/Servives/databse.dart';
import 'package:socialapp/helperfunct/sharedpref_helper.dart';
import 'package:socialapp/pages/chatpage.dart';

class PeopleListPage extends StatefulWidget {
  final Future<void> Function() logoutCallback;

  const PeopleListPage({Key? key, required this.logoutCallback}) : super(key: key);

  @override
  _PeopleListPageState createState() => _PeopleListPageState();
}

class _PeopleListPageState extends State<PeopleListPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late DatabaseMethods _databaseService;
  late List<String> recentlyCommunicatedUsers = [];
  Stream<QuerySnapshot>? _usersStream;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateRecentlyCommunicatedUsers();
    WidgetsBinding.instance?.addObserver(this);
    _databaseService = DatabaseMethods(FirebaseAuth.instance);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateRecentlyCommunicatedUsers();
    }
  }

  Future<void> _getRecentlyCommunicatedUsers() async {
    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      recentlyCommunicatedUsers = await _databaseService.getRecentlyCommunicatedUsers(currentUserId);
    } catch (e) {
      print('Error getting recently communicated users: $e');
    }
  }

  Future<void> _updateRecentlyCommunicatedUsers() async {
    await _getRecentlyCommunicatedUsers();

    setState(() {
      _usersStream = _databaseService.getUsersStream(recentlyCommunicatedUsers);
    });
  }

  Future<void> _searchUser(String query) async {
    try {
      if (query.isNotEmpty) {
        String lowerCaseQuery = query.toLowerCase();

        Query querySnapshot = FirebaseFirestore.instance
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: lowerCaseQuery)
            .where('name', isLessThanOrEqualTo: lowerCaseQuery + '\uf8ff')
            .orderBy('name');

        setState(() {
          _usersStream = querySnapshot.snapshots();
        });
      } else {
        _updateRecentlyCommunicatedUsers();
      }
    } catch (e) {
      print('Error searching user: $e');
    }
  }

  Widget _buildUserTile(String? name, String? email, String userId, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(name ?? 'No Name'),
      onTap: onTap,
    );
  }

Widget _buildInboxTab(User? currentUser) {
  if (currentUser == null) {
    // User is not signed in, handle this case as needed
    return const Center(child: Text('Not signed in.'));
  }

  return FutureBuilder<List<String>>(
    future: _databaseService.getUsersWithReceivedMessages(currentUser.email!),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return const Center(child: Text('Error occurred.'));
      } else {
        List<String> usersWithReceivedMessages = snapshot.data ?? [];

        // Combine the list of users with received messages and users from conversations
        List<String> allInboxUsers = [];

        // Add users from conversations
        allInboxUsers.addAll(recentlyCommunicatedUsers);

        // Add users with received messages
        allInboxUsers.addAll(usersWithReceivedMessages);

        // Include the current user's email as well, in case they sent messages to others
        allInboxUsers.add(currentUser.email!);

        // Filter out null and duplicate emails
        allInboxUsers = allInboxUsers.where((email) => email != null).toSet().toList();

        if (allInboxUsers.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('email', whereIn: allInboxUsers) // Query by email instead of document ID
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error occurred.'));
            } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No users found.'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data!.docs[index];
                  final userId = user.id;
                  final name = user.get('name') as String?;
                  final email = user.get('email') as String?;

                  // Filter out the current user from the list
                  if (email != currentUser.email) {
                    return _buildUserTile(name!, email!, userId,
                        onTap: () => _navigateToChatPage(userId, name, email));
                  } else {
                    return Container(); // Skip the current user from the list
                  }
                },
              );
            }
          },
        );
      }
    },
  );
}



  Widget _buildAllUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error occurred.'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final user = snapshot.data!.docs[index];
              final userId = user.id;
              final name = user.get('name') as String?;
              final email = user.get('email') as String?;

              return _buildUserTile(name!, email!, userId,
                  onTap: () => _navigateToChatPage(userId, name, email));
            },
          );
        }
      },
    );
  }

  void _navigateToChatPage(String userId, String name, String email) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          personName: name,
          userId: userId,
          name: name,
          email: email,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('People List'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);

                await widget.logoutCallback();

                Navigator.pushNamedAndRemoveUntil(context, 'phone', (route) => false);
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _searchUser(value),
              ),
            ),
            Expanded(
              child: _currentIndex == 0
                  ? _buildInboxTab(FirebaseAuth.instance.currentUser)
                  : _buildAllUsersTab(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.mail),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'All Users',
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Exit'),
            content: Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }
}
