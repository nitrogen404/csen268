import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  /// Stream of a user's friends.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFriends(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .orderBy('displayName')
        .snapshots();
  }

  /// Stream of incoming friend requests for the given user.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFriendRequests(
      String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream of incoming chain invites for the given user.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamChainInvites(
      String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chainInvites')
        // Only show pending invites in the inbox. Accepted / declined
        // ones are still stored but filtered out here.
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Send a friend request by target email.
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String fromEmail,
    required String fromDisplayName,
    required String targetEmail,
  }) async {
    final trimmed = targetEmail.trim();
    if (trimmed.isEmpty) {
      throw 'Please enter an email.';
    }

    // Look up target user by email.
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw 'No user found with this email.';
    }

    final targetDoc = query.docs.first;
    final targetUserId = targetDoc.id;
    if (targetUserId == fromUserId) {
      throw 'You cannot add yourself as a friend.';
    }

    final targetRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('friendRequests')
        .doc();

    await targetRef.set({
      'fromUserId': fromUserId,
      'fromEmail': fromEmail,
      'fromDisplayName': fromDisplayName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a friend request. Creates a mutual friendship between users.
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String currentUserEmail,
    required String currentUserDisplayName,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final fromUserId = requestData['fromUserId'] as String? ?? '';
    final fromEmail = requestData['fromEmail'] as String? ?? '';
    final fromName = requestData['fromDisplayName'] as String? ?? 'Friend';

    if (fromUserId.isEmpty) return;

    final currentUserRef =
        _firestore.collection('users').doc(currentUserId);
    final fromUserRef = _firestore.collection('users').doc(fromUserId);

    final batch = _firestore.batch();

    // Friend entry for the current user (the one accepting the request).
    final currentFriendRef =
        currentUserRef.collection('friends').doc(fromUserId);
    batch.set(currentFriendRef, {
      'userId': fromUserId,
      'email': fromEmail,
      'displayName': fromName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Reciprocal friend entry for the sender so they also see this user.
    final reverseFriendRef =
        fromUserRef.collection('friends').doc(currentUserId);
    batch.set(reverseFriendRef, {
      'userId': currentUserId,
      'email': currentUserEmail,
      'displayName': currentUserDisplayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Mark request as accepted for the inbox owner.
    final reqRef = currentUserRef.collection('friendRequests').doc(requestId);
    batch.set(reqRef, {'status': 'accepted'}, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> declineFriendRequest({
    required String currentUserId,
    required String requestId,
  }) async {
    final reqRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friendRequests')
        .doc(requestId);
    await reqRef.set({'status': 'declined'}, SetOptions(merge: true));
  }

  /// Send a chain invite to a friend (by friend userId).
  Future<void> sendChainInvite({
    required String toUserId,
    required String chainId,
    required String chainTitle,
    required String chainCode,
    required String inviterId,
    required String inviterEmail,
    required String inviterName,
  }) async {
    final inviteRef = _firestore
        .collection('users')
        .doc(toUserId)
        .collection('chainInvites')
        .doc();

    await inviteRef.set({
      'chainId': chainId,
      'chainTitle': chainTitle,
      'chainCode': chainCode,
      'inviterId': inviterId,
      'inviterEmail': inviterEmail,
      'inviterName': inviterName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChainInviteStatus({
    required String currentUserId,
    required String inviteId,
    required String status,
  }) async {
    final inviteRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('chainInvites')
        .doc(inviteId);

    // Mark status; the inbox stream only shows `pending` items so
    // accepted/declined invites automatically disappear without
    // needing delete() (which may be blocked by security rules).
    await inviteRef.set({'status': status}, SetOptions(merge: true));
  }

  /// Remove a friend relationship from both users' friends lists.
  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    final currentUserRef =
        _firestore.collection('users').doc(currentUserId);
    final friendRef = _firestore.collection('users').doc(friendUserId);

    final batch = _firestore.batch();

    batch.delete(
      currentUserRef.collection('friends').doc(friendUserId),
    );
    batch.delete(
      friendRef.collection('friends').doc(currentUserId),
    );

    await batch.commit();
  }
}


