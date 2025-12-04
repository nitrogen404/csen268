import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/airia_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'shop_page.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final AiriaService _airiaService = AiriaService();
  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isPremium = false;
  int _messagesToday = 0;
  static const int FREE_MESSAGE_LIMIT = 5;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hi! I'm your TaskChain AI assistant. I can help you with your chains, streaks, and provide personalized advice. What would you like to know?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _loadPremiumStatus();
    _loadMessageCount();
  }

  Future<void> _loadPremiumStatus() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final isPremium = await _shopService.isPremiumActive(user.uid);
      setState(() {
        _isPremium = isPremium;
      });
    } catch (e) {
      print('Error loading premium status: $e');
    }
  }

  Future<void> _loadMessageCount() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _userService.getUserProfile(user.uid);
      final data = userDoc.data() ?? {};
      final today = _dateKeyUtc(DateTime.now());
      final messageDate = data['aiMessagesDate'] as String?;
      final messagesToday = data['aiMessagesToday'] as int? ?? 0;

      // Reset count if it's a new day
      if (messageDate != today) {
        setState(() {
          _messagesToday = 0;
        });
      } else {
        setState(() {
          _messagesToday = messagesToday;
        });
      }
    } catch (e) {
      print('Error loading message count: $e');
    }
  }

  String _dateKeyUtc(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _incrementMessageCount() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final today = _dateKeyUtc(DateTime.now());
    final userDoc = await _userService.getUserProfile(user.uid);
    final data = userDoc.data() ?? {};
    final messageDate = data['aiMessagesDate'] as String?;
    final currentCount = data['aiMessagesToday'] as int? ?? 0;

    // Reset if new day
    final newCount = messageDate == today ? currentCount + 1 : 1;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'aiMessagesToday': newCount,
      'aiMessagesDate': today,
    });

    setState(() {
      _messagesToday = newCount;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Check message limit for free users
    if (!_isPremium) {
      if (_messagesToday >= FREE_MESSAGE_LIMIT) {
        _showUpgradeDialog();
        return;
      }
    }

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _airiaService.sendMessage(text);
      
      // Increment message count for free users
      if (!_isPremium) {
        await _incrementMessageCount();
      }

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.stars, color: Color(0xFF7B61FF)),
            SizedBox(width: 8),
            Text('Message Limit Reached'),
          ],
        ),
        content: Text(
          'You\'ve used all $FREE_MESSAGE_LIMIT free messages today. Upgrade to Premium for unlimited AI access!',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopPage()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Color(0xFF7B61FF)),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Message limit indicator for free users
          if (!_isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Messages today: $_messagesToday/$FREE_MESSAGE_LIMIT',
                    style: text.bodySmall?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          
          // Messages list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Loading indicator
                  return _buildLoadingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          // Input area
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask me anything about your chains...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: text.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parse markdown and build TextSpans for RichText
  /// Supports **text** and *text* for bold formatting
  List<TextSpan> _parseMarkdown(String text, Color textColor) {
    final spans = <TextSpan>[];
    
    // Pattern to match **text** (double asterisks) or *text* (single asterisk)
    // Priority: **text** first, then *text*
    final regex = RegExp(r'\*\*([^*]+)\*\*|\*([^*\n]+)\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      // Add bold text (group(1) for **text**, group(2) for *text*)
      final boldText = match.group(1) ?? match.group(2) ?? '';
      if (boldText.isNotEmpty) {
        spans.add(TextSpan(
          text: boldText,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ));
      }

      lastIndex = match.end;
    }

    // Add remaining text after last match
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: textColor),
      ));
    }

    // If no markdown found, return single span with original text
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: TextStyle(color: textColor),
      ));
    }

    return spans;
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final textColor = isUser
        ? Colors.white
        : (message.isError ? Colors.red : cs.onSurface);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 18,
                color: Color(0xFF7B61FF),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF7B61FF)
                    : (message.isError
                        ? Colors.red.withOpacity(0.1)
                        : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  children: _parseMarkdown(message.text, textColor),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: cs.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              size: 18,
              color: Color(0xFF7B61FF),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

