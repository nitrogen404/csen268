import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import '../services/chain_service.dart';
import '../services/user_service.dart';

class AiriaService {
  // Load from .env file
  String get _apiKey => dotenv.env['AIRIA_API_KEY'] ?? '';
  String get _pipelineId => dotenv.env['AIRIA_PIPELINE_ID'] ?? '';
  String get _reminderPipelineId => dotenv.env['AIRIA_REMINDER_PIPELINE_ID'] ?? '';
  static const String _baseUrl = 'https://api.airia.ai/v2/PipelineExecution';

  final AuthService _authService = AuthService();
  final ChainService _chainService = ChainService();
  final UserService _userService = UserService();

  /// Get user's chain data for context
  Future<Map<String, dynamic>> _getUserChainContext() async {
    final user = _authService.currentUser;
    if (user == null) return {};

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get user profile
      final profile = await _userService.getUserProfile(user.uid);
      final profileData = profile.data() as Map<String, dynamic>? ?? {};

      // Get joined chains with all fields from Firestore
      final memberDocs = await firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: user.uid)
          .get();

      final chains = <Map<String, dynamic>>[];
      
      for (final memberDoc in memberDocs.docs) {
        final chainRef = memberDoc.reference.parent.parent;
        if (chainRef == null) continue;

        final chainSnap = await chainRef.get();
        if (!chainSnap.exists) continue;

        final chainData = chainSnap.data() as Map<String, dynamic>? ?? {};
        final startDate = chainData['startDate'] as Timestamp?;
        
        // Check if today's check-in is completed
        final today = DateTime.now().toUtc();
        final todayKey = _dateKeyUtc(today);
        final lastCheckInDate = chainData['lastGroupCheckInDate'] as String?;
        final todayCompleted = lastCheckInDate == todayKey;

        chains.add({
          'title': chainData['title'] ?? '',
          'frequency': chainData['frequency'] ?? 'daily',
          'startDate': startDate != null 
              ? startDate.toDate().toIso8601String() 
              : null,
          'durationDays': chainData['durationDays'] ?? 0,
          'memberCount': chainData['memberCount'] ?? 0,
          'currentStreak': chainData['currentStreak'] ?? 0,
          'totalDaysCompleted': chainData['totalDaysCompleted'] ?? 0,
          'todayCompleted': todayCompleted,
          'code': chainData['code'] ?? '',
        });
      }

      // Sort chains by title
      chains.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));

      return {
        'userProfile': {
          'displayName': profileData['displayName'] ?? 'User',
          'bio': profileData['bio'] ?? '',
          'location': profileData['location'] ?? '',
          'isPremium': profileData['isPremium'] ?? false,
        },
        'globalStats': {
          'currentStreak': profileData['currentStreak'] ?? 0,
          'longestStreak': profileData['longestStreak'] ?? 0,
          'checkIns': profileData['checkIns'] ?? 0,
          'successRate': profileData['successRate'] ?? 0.0,
        },
        'chains': chains,
      };
    } catch (e) {
      return {'error': 'Failed to load user context: $e'};
    }
  }

  /// Helper to format date as yyyy-MM-dd
  String _dateKeyUtc(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Build a prompt with user's chain data
  Future<String> _buildPrompt(String userInput) async {
    final context = await _getUserChainContext();
    
    // Build the system prompt
    final systemPrompt = '''You are TaskChain AI — an accountability coach for habits and chain-based check-ins.

You will receive:

A `memory` object containing long-term summaries of the user's habits, preferences, struggles, motivations, and group dynamics. Use this memory to personalize responses. If memory contradicts the JSON context, trust the JSON and update memory next session.

A user profile (displayName, bio, location, isPremium).

A list of the user's chains with fields such as:

title, frequency, startDate, durationDays, memberCount, currentStreak, totalDaysCompleted, todayCompleted, code.

The user's global stats: currentStreak, longestStreak, checkIns, successRate.

(Optional) A focusedChain object containing recentMessages (senderName, text, timestamp).

(Optional) Social or friend context.

A JSON snapshot of this context will be appended after this message.

Only use information found inside this JSON. Do NOT invent any additional data.

Your Goals

Incorporate memory to provide deeper coaching, but never hallucinate or invent details. Memory is a supplement, not a source of truth.

Answer the user's question directly, clearly, and in a warm, encouraging tone.

Give specific, actionable suggestions when possible

(ex: "Complete today's check-in for Read 20 Pages" or "Invite a friend to stay accountable").

Use the data in the JSON to personalize your response.

Mention streaks, progress, achievements, missed check-ins, member activity, etc.

If focusedChain data is provided:

Reference the recent messages only if they are relevant.

Identify group momentum, engagement trends, or accountability opportunities.

If something is NOT in the context, say you don't know. Never guess.

Format your answers in:

Short paragraphs

Occasional bullets

Friendly, simple tone

Never output the raw JSON. Convert it into natural, conversational insights.

Behavior Rules

Stay supportive, never shaming.

Emphasize motivation, consistency, and achievable steps.

If the user asks for comparisons:

Focus on positive accountability, not competition.

If the JSON context is empty or missing fields, give generalized habit-coaching advice.

Forbidden Content

Do not give:

Medical, legal, or financial advice

Mental health diagnoses

Instructions that are dangerous or harmful

If the user expresses self-harm or crisis, encourage them to seek immediate professional help or emergency services.

Final Instruction

After reading the JSON context that follows, respond as TaskChain AI with the best possible personalized guidance.''';

    // Build JSON context
    final jsonContext = jsonEncode(context);
    
    // Combine everything
    final prompt = '''$systemPrompt

---

JSON Context:

$jsonContext

---

User Question: $userInput''';

    return prompt;
  }

  /// Send a message to Airia API and get response
  Future<String> sendMessage(String userInput) async {
    if (_apiKey.isEmpty) {
      throw Exception('Airia API key not configured. Please set AIRIA_API_KEY in .env file');
    }

    try {
      final prompt = await _buildPrompt(userInput);

      final response = await http.post(
        Uri.parse('$_baseUrl/$_pipelineId'),
        headers: {
          'X-API-KEY': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userInput': prompt,
          'asyncOutput': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Debug: Print the response structure to understand the format
        print('Airia API Response: ${response.body}');
        
        // Try multiple possible response structures
        // Based on Airia API documentation and execution output
        String? result;
        
        if (data is Map<String, dynamic>) {
          // Check various possible fields - 'result' is the primary field for Airia API
          result = data['result'] as String?;
          result ??= data['output'] as String?;
          result ??= data['response'] as String?;
          result ??= data['message'] as String?;
          result ??= data['processedData'] as String?;
          result ??= data['processed_data'] as String?;
          
          // Check nested structures
          if (result == null && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            result = dataMap['result'] as String?;
            result ??= dataMap['output'] as String?;
            result ??= dataMap['response'] as String?;
            result ??= dataMap['processedData'] as String?;
          }
          
          // Check if output is in an execution result
          if (result == null && data['execution'] is Map) {
            final execution = data['execution'] as Map<String, dynamic>;
            result = execution['result'] as String?;
            result ??= execution['output'] as String?;
            result ??= execution['processedData'] as String?;
          }
        } else if (data is String) {
          result = data;
        }
        
        if (result != null && result.isNotEmpty) {
          return result;
        } else {
          // If we can't find the response, return the full response body for debugging
          throw Exception('Could not parse response. Response body: ${response.body}');
        }
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Re-throw with more context
      if (e.toString().contains('Could not parse response')) {
        rethrow;
      }
      throw Exception('Failed to send message to Airia: $e');
    }
  }

  /// Send a reminder message using the reminder pipeline
  /// This uses a separate pipeline optimized for generating short reminder messages
  Future<String> sendReminderMessage(String userInput) async {
    if (_apiKey.isEmpty) {
      throw Exception('Airia API key not configured. Please set AIRIA_API_KEY in .env file');
    }

    try {
      final prompt = await _buildPrompt(userInput);

      final response = await http.post(
        Uri.parse('$_baseUrl/$_reminderPipelineId'),
        headers: {
          'X-API-KEY': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userInput': prompt,
          'asyncOutput': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Try multiple possible response structures
        String? result;
        
        if (data is Map<String, dynamic>) {
          result = data['result'] as String?;
          result ??= data['output'] as String?;
          result ??= data['response'] as String?;
          result ??= data['message'] as String?;
        } else if (data is String) {
          result = data;
        }
        
        if (result != null && result.isNotEmpty) {
          return result;
        } else {
          throw Exception('Could not parse reminder response. Response body: ${response.body}');
        }
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send reminder message to Airia: $e');
    }
  }
}

