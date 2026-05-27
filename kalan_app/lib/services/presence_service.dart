import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  static Timer? _heartbeatTimer;

  static void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _updatePresence();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updatePresence();
    });
  }

  static void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> _updatePresence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_uuid');
      if (userId == null || userId == 'guest') return;

      await Supabase.instance.client
          .from('users')
          .update({'last_active': DateTime.now().toIso8601String()})
          .eq('uuid', userId);
    } catch (_) {}
  }
}
