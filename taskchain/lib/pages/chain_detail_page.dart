import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../services/notification_badge_service.dart';
import '../services/toast_notification_service.dart';
import '../services/chain_service.dart';
import '../models/message.dart';

class ChainDetailPage extends StatefulWidget {
  final String chainId;
  final String chainTitle;
  final String members;
  final double progress;
  final String code;

  const ChainDetailPage({
    super.key,
    required this.chainId,
    required this.chainTitle,
    required this.members,
    required this.progress,
    required this.code,
  });

  @override
  State<ChainDetailPage> createState() => _ChainDetailPageState();
}

class _ChainDetailPageState extends State<ChainDetailPage> {
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final NotificationBadgeService _badgeService = NotificationBadgeService();
  final ChainService _chainService = ChainService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _markAsRead();
    ToastNotificationService().setCurrentChain(widget.chainId);
  }

  @override
  void dispose() {
    ToastNotificationService().setCurrentChain(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _badgeService.markChainAsRead(widget.chainId, user.uid);
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
        title: Text(widget.chainTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: _showMembersSheet,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _showShareSheet,
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildCompleteButton(),
          _buildChatHeader(),
          _buildMessageList(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildProgressSection()),
              const Icon(Icons.group, color: Colors.white, size: 32),
              const SizedBox(width: 8),
              Text(
                widget.members,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              )
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: widget.progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
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
      await _chainService.completeDailyActivity(
        userId: user.uid,
        userEmail: user.email ?? '',
        chainId: widget.chainId,
        chainTitle: widget.chainTitle,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's activity completed.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Widget _buildChatHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Team Chat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(msg.imageUrl!, fit: BoxFit.cover),
              ),
            if (msg.imageUrl != null && msg.text.isNotEmpty)
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: () => _pickImage(fromCamera: true),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: () => _pickImage(fromCamera: false),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMembersSheet() {
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
                'Chain Members',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final email = data['email'] ?? 'Unknown';
                        final role = data['role'] ?? 'member';
                        final isOwner = role == 'owner';

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