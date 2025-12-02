import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../services/notification_badge_service.dart';
import '../services/toast_notification_service.dart';
import '../services/chain_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../services/group_reminder_service.dart';
import '../models/message.dart';
import 'chain_media_widgets.dart';
import 'full_screen_image_page.dart';

class ChainDetailPage extends StatefulWidget {
  final String chainId;
  final String chainTitle;
  final String members;
  final double progress;
  final String code;
  final String theme;

  const ChainDetailPage({
    super.key,
    required this.chainId,
    required this.chainTitle,
    required this.members,
    required this.progress,
    required this.code,
    this.theme = 'Ocean',
  });

  @override
  State<ChainDetailPage> createState() => _ChainDetailPageState();
}

class _ChainDetailPageState extends State<ChainDetailPage> {
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final NotificationBadgeService _badgeService = NotificationBadgeService();
  final ChainService _chainService = ChainService();
  final FriendService _friendService = FriendService();
  final UserService _userService = UserService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _nameCache = {};
  final AudioRecorder _audioRecorder = AudioRecorder();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chainSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  bool _isRecording = false;
  bool _isDeleting = false;
  bool _isOwner = false;
  Set<String> _friendEmails = {};

  @override
  void initState() {
    super.initState();
    _markAsRead();
    ToastNotificationService().setCurrentChain(widget.chainId);
    _loadOwnership();
    _loadFriends();

    // Listen to chain membership for the current user; if their member
    // document goes away (e.g., chain deleted or they are removed),
    // immediately send them back home.
    final user = _authService.currentUser;
    if (user != null) {
      _memberSub = FirebaseFirestore.instance
          .collection('chains')
          .doc(widget.chainId)
          .collection('members')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
        if (!snap.exists && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are no longer a member of this chain.'),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          navIndex.value = 0;
        }
      }, onError: (error) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        navIndex.value = 0;
      });
    }

    // Listen for chain document changes so if the chain is deleted while this
    // screen is open (e.g., by the owner), all members are gracefully navigated
    // back to the home screen.
    _chainSub = FirebaseFirestore.instance
        .collection('chains')
        .doc(widget.chainId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists && mounted) {
        // Ensure we don't show multiple snackbars if this fires more than once.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This chain has been deleted.')),
        );
        // Navigate back to the root (home tab) for all users.
        Navigator.of(context).popUntil((route) => route.isFirst);
        navIndex.value = 0;
      }
    }, onError: (error) {
      // If we lose permission to read this chain (e.g., it was deleted and
      // security rules no longer allow access), treat it the same as a
      // deletion and send the user back home.
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      navIndex.value = 0;
    });
  }

  @override
  void dispose() {
    ToastNotificationService().setCurrentChain(null);
    _chainSub?.cancel();
    _memberSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _badgeService.markChainAsRead(widget.chainId, user.uid);
    }
  }

  Future<void> _loadOwnership() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('chains')
          .doc(widget.chainId)
          .get();
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;
      final ownerId = data['ownerId'] as String? ?? '';
      if (mounted) {
        setState(() {
          _isOwner = ownerId == user.uid;
        });
      }
    } catch (_) {
      // Ignore errors; simply hide owner-only actions.
    }
  }

  Future<void> _loadFriends() async {
    final user = _authService.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .get();
      final emails = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final email = (data['email'] as String?) ?? '';
        if (email.isNotEmpty) {
          emails.add(email.toLowerCase());
        }
      }
      if (mounted) {
        setState(() {
          _friendEmails = emails;
        });
      }
    } catch (_) {
      // Non-critical; we just won't hide the add friend button.
    }
  }

  Future<String> _getSenderName(String uid) async {
    if (_nameCache.containsKey(uid)) {
      return _nameCache[uid]!;
    }

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = snap.data()?['displayName'] ?? 'Unknown';

    _nameCache[uid] = name;
    return name;
  }

  Future<String> _getMyDisplayName() async {
    final uid = _authService.currentUser!.uid;
    return _getSenderName(uid);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = _authService.currentUser;
    if (user == null) return;

    final senderName = await _getMyDisplayName();

    await _messageService.sendMessage(
      chainId: widget.chainId,
      senderId: user.uid,
      senderName: senderName,
      text: _messageController.text.trim(),
      imageUrl: null,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  // ================================================================
  // UPDATED IMAGE UPLOAD (MATCHES STORAGE RULES)
  // ================================================================
  Future<void> _pickImage({required bool fromCamera}) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );

      if (picked == null) return;

      final File file = File(picked.path);

      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg";

      final String storagePath = "chat_images/${widget.chainId}/$fileName";

      final Reference ref = FirebaseStorage.instance.ref(storagePath);

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: "image/jpeg",
          customMetadata: {
            "uploadedBy": user.uid,
            "chainId": widget.chainId,
          },
        ),
      );

      await uploadTask;

      final downloadUrl = await ref.getDownloadURL();
      final senderName = await _getMyDisplayName();

      await _messageService.sendMessage(
        chainId: widget.chainId,
        senderId: user.uid,
        senderName: senderName,
        text: "",
        imageUrl: downloadUrl,
      );

      _scrollToBottom();
    } catch (e, stack) {
      debugPrint("❌ IMAGE UPLOAD ERROR: $e");
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image upload failed: $e")),
        );
      }
    }
  }
  // ================================================================

  // ================================================================
  // AUDIO RECORDING
  // ================================================================
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        // Use WAV to rule out emulator AAC encoding issues
        final String filePath = '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ RECORDING START ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        // Debug: check file size
        final f = File(path);
        final bytes = await f.length();
        debugPrint('🎙️ Recorded file: $path (${bytes} bytes)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recorded ${bytes ~/ 1024} KB')),
          );
        }
        await _uploadAudio(File(path));
      }
    } catch (e) {
      debugPrint("❌ RECORDING STOP ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  Future<void> _uploadAudio(File audioFile) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${user.uid}.m4a";
      final String storagePath = "chat_audio/${widget.chainId}/$fileName";
      final Reference ref = FirebaseStorage.instance.ref(storagePath);

      final uploadTask = ref.putFile(
        audioFile,
        SettableMetadata(
          contentType: "audio/m4a",
          customMetadata: {
            "uploadedBy": user.uid,
            "chainId": widget.chainId,
          },
        ),
      );

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      final senderName = await _getMyDisplayName();

      await _messageService.sendMessage(
        chainId: widget.chainId,
        senderId: user.uid,
        senderName: senderName,
        text: "🎤 Voice message",
        imageUrl: null,
        audioUrl: downloadUrl,
      );

      _scrollToBottom();
      
      // Delete local file after upload
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e, stack) {
      debugPrint("❌ AUDIO UPLOAD ERROR: $e");
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Audio upload failed: $e")),
        );
      }
    }
  }
  // ================================================================

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_authService.currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.chainTitle),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text("Please sign in to view messages"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(''), // Remove title from AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: _showMembersSheet,
            color: Colors.white, // Make icons white to match header
          ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDeleteChain,
            ),
        ],
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white, // Make back button white
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_getThemeAsset(widget.theme)),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Removed SizedBox, padding handled inside _buildHeader
            _buildHeader(),
            _buildCompleteButton(),
            _buildChatHeader(),
            _buildMessageList(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  String _getThemeAsset(String theme) {
    switch (theme) {
      case 'Forest':
        return 'assets/images/forest_bg.png';
      case 'Sunset':
        return 'assets/images/sunset_bg.png';
      case 'Energy':
        return 'assets/images/energy_bg.png';
      case 'Ocean':
      default:
        return 'assets/images/ocean_bg.png';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 10, // Add top padding for status bar + app bar
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chain Title
          Text(
            widget.chainTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildProgressSection()),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 700),
              tween: Tween<double>(begin: 0, end: widget.progress),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 10,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Progress',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          '${(widget.progress * 100).toInt()}%',
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        )
      ],
    );
  }

  Widget _buildCompleteButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _onCompleteToday,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Complete today's activity"),
        ),
      ),
    );
  }

  Future<void> _onCompleteToday() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Check if all OTHER members (excluding current user) have already checked in
      final allOthersCheckedIn = await _checkIfAllOtherMembersCheckedIn(user.uid);
      
      // Complete the check-in first (without reminders)
      await _chainService.completeDailyActivity(
        userId: user.uid,
        userEmail: user.email ?? '',
        chainId: widget.chainId,
        chainTitle: widget.chainTitle,
        sendReminders: false, // Don't send reminders automatically
      );
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's activity completed.")),
        );
        
        // Only show remind dialog if not everyone else has checked in
        if (!allOthersCheckedIn) {
          // Show dialog asking if they want to remind others
          final shouldRemind = await _showRemindOthersDialog();
          
          if (shouldRemind == true && mounted) {
            // Send reminders to other members
            try {
              final groupReminderService = GroupReminderService();
              final userProfile = await _userService.getUserProfile(user.uid);
              final userData = userProfile.data() as Map<String, dynamic>? ?? {};
              final userName = userData['displayName'] as String? ?? 
                              user.email?.split('@').first ?? 'You';
              
              await groupReminderService.remindGroupMembers(
                chainId: widget.chainId,
                chainTitle: widget.chainTitle,
                completedByUserId: user.uid,
                completedByUserName: userName,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reminders sent to other members!")),
                );
              }
            } catch (e) {
              print('Error sending reminders: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Check-in completed, but couldn't send reminders: ${e.toString()}")),
                );
              }
            }
          }
        } else {
          // All other members have already checked in
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Great! Everyone has already checked in today! 🎉")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Check if all OTHER members (excluding current user) have checked in today
  Future<bool> _checkIfAllOtherMembersCheckedIn(String currentUserId) async {
    try {
      final today = _dateKeyUtc(DateTime.now().toUtc());
      final chainRef = FirebaseFirestore.instance
          .collection('chains')
          .doc(widget.chainId);
      
      final membersSnap = await chainRef.collection('members').get();
      
      if (membersSnap.docs.isEmpty) {
        return true; // No members, consider all checked in
      }
      
      // Check if all OTHER members (excluding current user) have checked in today
      for (final memberDoc in membersSnap.docs) {
        final memberData = memberDoc.data();
        final memberUserId = memberData['userId'] as String? ?? memberDoc.id;
        
        // Skip the current user
        if (memberUserId == currentUserId) continue;
        
        final lastCheckIn = memberData['lastCheckInDate'] as String?;
        
        if (lastCheckIn != today) {
          return false; // At least one other member hasn't checked in
        }
      }
      
      return true; // All other members have checked in
    } catch (e) {
      print('Error checking if all other members checked in: $e');
      return false; // On error, assume not all checked in (safer to show dialog)
    }
  }

  /// Helper to format date as yyyy-MM-dd
  String _dateKeyUtc(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<bool?> _showRemindOthersDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFF7B61FF)),
              SizedBox(width: 8),
              Text('Remind Others?'),
            ],
          ),
          content: const Text(
            'Would you like to remind other members to complete their check-in? This will help keep the streak going!',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
              ),
              child: const Text('Yes, Remind Them'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteChain() async {
    if (_isDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete chain?'),
          content: const Text(
              'This will remove the chain for all members. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final user = _authService.currentUser;
    if (user == null) return;

    // Capture ids before navigating away.
    final chainId = widget.chainId;
    final requesterId = user.uid;

    // First navigate the owner back home for an immediate UX response.
    Navigator.of(context).popUntil((route) => route.isFirst);
    navIndex.value = 0;

    // Then perform the delete in the background so all members are
    // kicked back to home via their listeners.
    unawaited(_chainService.deleteChain(
      chainId: chainId,
      requesterId: requesterId,
    ));
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _HeaderChip(
            icon: Icons.photo_library_outlined,
            label: 'Media',
            onTap: _showMediaSheet,
          ),
          const SizedBox(width: 8),
          _HeaderChip(
            icon: Icons.check_circle_outline,
            label: 'Check-ins',
            onTap: _showCheckInsSheet,
          ),
          if (_isDeleting) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isDeleting) {
      // While deleting, avoid attaching listeners to messages to prevent
      // noisy permission errors and just show an empty area.
      return const Expanded(
        child: Center(
          child: SizedBox.shrink(),
        ),
      );
    }
    return Expanded(
      child: StreamBuilder<List<Message>>(
        stream: _messageService.getChainMessages(widget.chainId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];
          if (messages.isEmpty) return _buildEmptyChat();

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              final isMe = m.senderId == _authService.currentUser!.uid;

              return FutureBuilder<String>(
                future: _getSenderName(m.senderId),
                builder: (context, nameSnap) {
                  final senderName = nameSnap.data ?? m.senderName;
                  return _buildMessageBubble(m, senderName, isMe);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Start the conversation.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, String senderName, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF7B61FF) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(senderName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.deepPurple)),
            if (!isMe) const SizedBox(height: 4),
            if (msg.imageUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenImagePage(
                        imageUrl: msg.imageUrl!,
                        heroTag: 'chat_image_${msg.id}',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'chat_image_${msg.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      msg.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (msg.imageUrl != null && msg.text.isNotEmpty)
              const SizedBox(height: 8),
            if (msg.audioUrl != null)
              _buildAudioPlayer(msg.audioUrl!, isMe),
            if (msg.audioUrl != null && msg.text.isNotEmpty)
              const SizedBox(height: 8),
            if (msg.text.isNotEmpty)
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.black45, fontSize: 11),
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAudioPlayer(String audioUrl, bool isMe) {
    return _AudioPlayerWidget(
      audioUrl: audioUrl,
      isMe: isMe,
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Padding(
        // No padding above; just a small gap from the screen edge.
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          height: 52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      // Glassy circular "+" button to open actions drawer.
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7B61FF).withOpacity(0.6),
                            width: 1.6,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: Color(0xFF7B61FF),
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          onPressed: _showInputActionsSheet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Message text field
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Gradient circular send button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          padding: EdgeInsets.zero,
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInputActionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to message',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionChip(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      color: cs.primary,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _pickImage(fromCamera: true);
                      },
                    ),
                    _ActionChip(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      color: cs.secondary,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _pickImage(fromCamera: false);
                      },
                    ),
                    _ActionChip(
                      icon: _isRecording ? Icons.stop : Icons.mic,
                      label: _isRecording ? 'Stop' : 'Voice',
                      color: Colors.redAccent,
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        if (_isRecording) {
                          await _stopRecording();
                        } else {
                          await _startRecording();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    labelColor: cs.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: cs.primary,
                    tabs: const [
                      Tab(text: 'Images'),
                      Tab(text: 'Recordings'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ChainImagesGrid(chainId: widget.chainId),
                        ChainRecordingsList(chainId: widget.chainId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCheckInsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final today = DateTime.now().toUtc();
        final todayKey =
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  "Today's check-ins",
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('chains')
                        .doc(widget.chainId)
                        .collection('members')
                        .orderBy('joinedAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('No members in this chain.'));
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final email =
                              (data['email'] as String?) ?? 'Unknown user';
                          final lastCheckIn =
                              data['lastCheckInDate'] as String?;
                          final hasCheckedIn = lastCheckIn == todayKey;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primary.withOpacity(0.1),
                              child: Text(
                                email[0].toUpperCase(),
                                style: TextStyle(color: cs.primary),
                              ),
                            ),
                            title:
                                Text(email, overflow: TextOverflow.ellipsis),
                            trailing: Icon(
                              hasCheckedIn
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: hasCheckedIn
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMembersSheet() {
    if (_isDeleting) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chain Members',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showShareSheet();
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chains')
                      .doc(widget.chainId)
                      .collection('members')
                      .orderBy('joinedAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('No members yet.'));
                    }

                    final currentEmail =
                        _authService.currentUser?.email ?? '';

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final email = (data['email'] ?? 'Unknown') as String;
                        final role = data['role'] ?? 'member';
                        final isOwner = role == 'owner';

                        final isMe = email == currentEmail;
                        final isFriend =
                            _friendEmails.contains(email.toLowerCase());

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withOpacity(0.1),
                            child: Text(
                              email[0].toUpperCase(),
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                          title: Text(email, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            isOwner ? 'Owner' : 'Member',
                            style: TextStyle(
                              color: isOwner
                                  ? cs.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                          trailing: (isMe || isFriend)
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.person_add_alt_1),
                                  tooltip: 'Add friend',
                                  onPressed: () async {
                                    final currentUser =
                                        _authService.currentUser;
                                    if (currentUser == null) return;

                                    try {
                                      final displayName =
                                          await _getMyDisplayName();
                                      await _friendService.sendFriendRequest(
                                        fromUserId: currentUser.uid,
                                        fromEmail:
                                            currentUser.email ?? '',
                                        fromDisplayName: displayName,
                                        targetEmail: email,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Friend request sent to $email'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Could not send friend request: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Share Chain',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: widget.code,
                version: QrVersions.auto,
                size: 180,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: cs.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_open, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy code',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.code),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chain code copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Stateful Audio Player Widget
class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const _AudioPlayerWidget({
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player.play(UrlSource(widget.audioUrl));
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('❌ AUDIO PLAY ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.black87,
            ),
            onPressed: _togglePlayPause,
          ),
          Icon(
            Icons.graphic_eq,
            size: 16,
            color: widget.isMe ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(
            _duration.inSeconds > 0
                ? '${_format(_position)} / ${_format(_duration)}'
                : 'Voice message',
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.deepPurple),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
