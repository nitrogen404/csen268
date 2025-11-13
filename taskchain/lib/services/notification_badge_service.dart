import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationBadgeService {
  static const String _lastReadKey = 'last_read_messages';

  // Get last read timestamp for a chain
  Future<DateTime?> getLastReadTime(String chainId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastReadKey);
    
    if (data == null) return null;
    
    try {
      final Map<String, dynamic> lastReadMap = json.decode(data);
      final key = '${userId}_$chainId';
      
      if (lastReadMap.containsKey(key)) {
        return DateTime.parse(lastReadMap[key]);
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  // Mark chain as read (store current timestamp)
  Future<void> markChainAsRead(String chainId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastReadKey);
    
    Map<String, dynamic> lastReadMap = {};
    
    if (data != null) {
      try {
        lastReadMap = json.decode(data);
      } catch (e) {
        lastReadMap = {};
      }
    }
    
    final key = '${userId}_$chainId';
    lastReadMap[key] = DateTime.now().toIso8601String();
    
    await prefs.setString(_lastReadKey, json.encode(lastReadMap));
  }

  // Clear all read markers (for testing)
  Future<void> clearAllReadMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReadKey);
  }
}

