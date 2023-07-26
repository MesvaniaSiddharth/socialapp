import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatPage extends StatefulWidget {
  final String personName;
  final String userId;
  final String? name;
  final String email;

  const ChatPage({
    Key? key,
    required this.personName,
    required this.userId,
    this.name,
    required this.email,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late User _currentUser;
  late String _currentUserId;
  late TextEditingController _messageController;
  List<String>? recentlyCommunicatedUsers;
  String _generateConversationId(String userId1, String userId2) {
    List<String> userIds = [userId1, userId2]..sort();
    return '${userIds[0]}_${userIds[1]}';
  }

  final _picker = ImagePicker();
  bool _isEmojiPickerVisible = false;
  late FocusNode _messageFocusNode;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _messageController = TextEditingController();
    _messageFocusNode = FocusNode();

    // Load recently communicated users
    _loadRecentlyCommunicatedUsers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUser = user;
      _currentUserId = user.uid;
    }
  }

  Future<void> _loadRecentlyCommunicatedUsers() async {
    // Load recently communicated users from Firestore or wherever you store them.
    // For simplicity, I'm using a dummy list here.
    // In a real-world scenario, you would fetch this list from Firestore or any other database.
    recentlyCommunicatedUsers = ['123', '456', '789'];
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isNotEmpty) {
      _messageController.clear();

      final senderId = _currentUserId;
      final receiverId = widget.userId;

      final conversationId = _generateConversationId(senderId, receiverId);

      final messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': messageText,
        'timeSent': Timestamp.now(),
      };

      await _firestore
          .collection('conversation')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);
    }
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageFile = await pickedFile.readAsBytes();
      final imageStorageRef = FirebaseStorage.instance
          .ref()
          .child('message')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = imageStorageRef.putData(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final imageUrl = await snapshot.ref.getDownloadURL();
      String conversationId =
          _generateConversationId(_currentUserId, widget.userId);

      final senderId = _currentUserId;
      final receiverId = widget.userId;

      final messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': imageUrl, // Save the image URL in the Firestore
        'timeSent': Timestamp.now(),
      };

      await _firestore
          .collection('conversation')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);
    }
  }

  Future<void> _sendFile() async {
    final pickedFile = await FilePicker.platform.pickFiles();
    if (pickedFile != null) {
      final filePath = pickedFile.files.single.path!;
      final fileBytes = await File(filePath).readAsBytes();

      // Here, you can upload the file to Firebase Storage or any other storage service
      // and then send the file URL as a message to the recipient.
      // For simplicity, let's just print the file path for now:
      print('File Path: $filePath');
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
      if (_isEmojiPickerVisible) {
        // Hide the keyboard when emoji picker is visible
        _messageFocusNode.unfocus();
      } else {
        // Show the keyboard when emoji picker is hidden
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _messageController.text += emoji.emoji;
  }

  Widget _buildMessageList() {
    String conversationId =
        _generateConversationId(_currentUserId, widget.userId);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversation')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timeSent', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error occurred.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return const Center(child: Text('No messages.'));
        }

        return ListView.builder(
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final senderId = message['senderId'] as String;
            final messageText = message['message'] as String;
            final timeSent = message['timeSent'] as Timestamp;
            final isCurrentUser = _currentUserId == senderId;

            return Align(
              alignment:
                  isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messageText,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      DateFormat.jm().format(timeSent.toDate()),
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.personName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green, // Set the app bar color to green
      ),
      body: Container(
        color: Colors.white, // Set the background color of the body
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            if (_isEmojiPickerVisible)
              EmojiPicker(onEmojiSelected: _onEmojiSelected),
            Container(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _messageFocusNode,
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendImage,
                    icon: Icon(Icons.image, color: Colors.green, size: 24),
                  ),
                  IconButton(
                    onPressed: _sendFile,
                    icon:
                        Icon(Icons.attach_file, color: Colors.green, size: 24),
                  ),
                  IconButton(
                    onPressed: _toggleEmojiPicker,
                    icon: Icon(Icons.emoji_emotions,
                        color: Colors.green, size: 24),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send, color: Colors.green, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
