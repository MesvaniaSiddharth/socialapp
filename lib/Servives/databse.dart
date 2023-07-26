import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../helperfunct/sharedpref_helper.dart';

class DatabaseMethods {
  FirebaseAuth _auth;
  DatabaseMethods(this._auth);
  Future<void> addUserInfoToDB(
      String userId, Map<String, dynamic> userInfoMap) async {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .set(userInfoMap);
    } catch (e) {
      print('Error adding user info to database: $e');
    }
  }

  bool isCurrentUser(String userId) {
    final currentUser = _auth.currentUser;
    return currentUser != null && currentUser.uid == userId;
  }

  Future<List<String>> getUsersWithReceivedMessages(String currentUserId) async {
    List<String> usersWithReceivedMessages = [];

    try {
      // Query the Firestore collection that stores conversations
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('conversation')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Loop through the conversations and extract other participants' IDs
      for (var doc in snapshot.docs) {
        List<String> participants = List.from(doc['participants']);
        participants.remove(currentUserId); // Remove the current user's ID
        usersWithReceivedMessages.addAll(participants);
      }

      // Remove duplicates from the list of users
      usersWithReceivedMessages = usersWithReceivedMessages.toSet().toList();
    } catch (e) {
      print('Error fetching users with received messages: $e');
    }

    return usersWithReceivedMessages;
  }

  Future<Stream<QuerySnapshot>> getUserByUserName(String username) async {
    try {
      return FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .snapshots();
    } catch (e) {
      print('Error getting user by username: $e');
      throw e;
    }
  }

Future<List<String>> getRecentlyCommunicatedUsers(String currentUserId) async {
  try {
    // Fetch conversations where the current user is a sender or receiver
    final snapshot = await FirebaseFirestore.instance
        .collection('conversation')
        .where('senderId', isEqualTo: currentUserId)
        .get();

    final List<String> recentlyCommunicatedUsers = [];

    // Extract unique receiver IDs from conversations
    for (final doc in snapshot.docs) {
      final receiverId = doc['receiverId'] as String;
      if (!recentlyCommunicatedUsers.contains(receiverId)) {
        recentlyCommunicatedUsers.add(receiverId);
      }
    }

    // Fetch conversations where the current user is a receiver
    final snapshotReceiver = await FirebaseFirestore.instance
        .collection('conversation')
        .where('receiverId', isEqualTo: currentUserId)
        .get();

    // Extract unique sender IDs from conversations
    for (final doc in snapshotReceiver.docs) {
      final senderId = doc['senderId'] as String;
      if (!recentlyCommunicatedUsers.contains(senderId)) {
        recentlyCommunicatedUsers.add(senderId);
      }
    }

    // You can sort the users list based on the latest conversation timestamp if needed
    // For example, you can fetch the timestamp of the last message in each conversation
    // and sort the users accordingly.

    return recentlyCommunicatedUsers;
  } catch (e) {
    print('Error getting recently communicated users: $e');
    throw e;
  }
}


  Stream<QuerySnapshot> getUsersStream(List<String> userNames) {
    // Implement the logic to get the user stream based on the list of user names
    // Example:
    return FirebaseFirestore.instance
        .collection('users')
        .where('name', whereIn: userNames)
        .snapshots();
  }
}

Future<void> addMessage(String chatRoomId, String messageId,
    Map<String, dynamic> messageInfoMap) async {
  try {
    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .doc(messageId)
        .set(messageInfoMap);
  } catch (e) {
    print('Error adding message to chatroom: $e');
  }
}

Future<void> updateLastMessageSend(
    String chatRoomId, Map<String, dynamic> lastMessageInfoMap) async {
  try {
    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .update(lastMessageInfoMap);
  } catch (e) {
    print('Error updating last message sent: $e');
  }
}

Future<void> createChatRoom(
    String chatRoomId, Map<String, dynamic> chatRoomInfoMap) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .get();

    if (snapshot.exists) {
      print('Chatroom already exists');
    } else {
      await FirebaseFirestore.instance
          .collection("chatrooms")
          .doc(chatRoomId)
          .set(chatRoomInfoMap);
    }
  } catch (e) {
    print('Error creating chatroom: $e');
  }
}

Future<Stream<QuerySnapshot>> getChatRoomMessages(String chatRoomId) async {
  try {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("ts", descending: true)
        .snapshots();
  } catch (e) {
    print('Error getting chatroom messages: $e');
    throw e;
  }
}

Future<Stream<QuerySnapshot>> getChatRooms() async {
  try {
    String? myUsername = await SharedPreferenceHelper().getUserName();
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .orderBy("lastMessageSendTs", descending: true)
        .where("users", arrayContains: myUsername)
        .snapshots();
  } catch (e) {
    print('Error getting chatrooms: $e');
    throw e;
  }
}

Future<QuerySnapshot> getUserInfo(String username) async {
  try {
    return await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .get();
  } catch (e) {
    print('Error getting user info: $e');
    throw e;
  }
}
