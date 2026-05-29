import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/remote/supabase_service.dart';
import 'notification_signal_service.dart';

/// Écoute les défis reçus (realtime + polling) et affiche une alerte in-app.
class BattleInviteService {
  BattleInviteService._();
  static final BattleInviteService instance = BattleInviteService._();

  final Set<String> _seenBattleIds = {};
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  String? _userUuid;

  void start(String userId) {
    if (userId.isEmpty || userId == _userUuid) return;
    stop();
    _bootstrap(userId);
  }

  Future<void> _bootstrap(String userIdentifier) async {
    final resolved = await _resolveUserUuid(userIdentifier);
    if (resolved == null) return;
    _userUuid = resolved;
    _pollPending();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollPending());
    _subscribeRealtime(resolved);
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _channel?.unsubscribe();
    _channel = null;
    _userUuid = null;
  }

  void _subscribeRealtime(String userUuid) {
    try {
      _channel = SupabaseService.client
          .channel('battle_invites_$userUuid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'battles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'invited_id',
              value: userUuid,
            ),
            callback: (payload) {
              final row = payload.newRecord;
              if (row.isNotEmpty) _onBattleRow(Map<String, dynamic>.from(row));
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'battles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'invited_id',
              value: userUuid,
            ),
            callback: (payload) {
              final row = payload.newRecord;
              if (row.isNotEmpty) _onBattleRow(Map<String, dynamic>.from(row));
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[BattleInvite] Realtime: $e');
    }
  }

  Future<void> _pollPending() async {
    final uid = _userUuid;
    if (uid == null) return;
    try {
      final rows = await SupabaseService.client
          .from('battles')
          .select('id, inviter_id, invited_id, status, theme, xp_bet, created_at')
          .eq('invited_id', uid)
          .eq('status', 'invitation_sent')
          .order('created_at', ascending: false);
      for (final row in rows as List) {
        _onBattleRow(Map<String, dynamic>.from(row as Map));
      }
    } catch (e) {
      debugPrint('[BattleInvite] Poll: $e');
    }
  }

  Future<void> _onBattleRow(Map<String, dynamic> battle) async {
    if (battle['status'] != 'invitation_sent') return;
    final battleId = battle['id']?.toString();
    if (battleId == null || _seenBattleIds.contains(battleId)) return;
    _seenBattleIds.add(battleId);

    String inviterName = 'Un joueur';
    try {
      final inviterUuid = battle['inviter_id']?.toString();
      if (inviterUuid != null) {
        final user = await SupabaseService.client
            .from('users')
            .select('pseudo')
            .eq('uuid', inviterUuid)
            .maybeSingle();
        inviterName = user?['pseudo'] as String? ?? inviterName;
      }
    } catch (_) {}

    final theme = battle['theme'] as String? ?? 'Général';
    final stake = battle['xp_bet'] as int? ?? 50;

    NotificationSignalService.instance.show(
      title: 'Nouveau défi !',
      message: '$inviterName te défie sur $theme ($stake XP)',
      type: 'battle',
      payload: {
        'battle_id': battleId,
        'inviter_name': inviterName,
        'theme': theme,
        'xp_bet': stake,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> fetchUserBattles(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final resolved = await _resolveUserUuid(userId);
      if (resolved == null) return [];
      final rows = await SupabaseService.client
          .from('battles')
          .select()
          .or('inviter_id.eq.$resolved,invited_id.eq.$resolved')
          .order('created_at', ascending: false);
      return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[BattleInvite] fetchUserBattles: $e');
      return [];
    }
  }

  static Future<String?> _resolveUserUuid(String userIdentifier) async {
    if (userIdentifier.isEmpty) return null;
    try {
      final byUuid = await SupabaseService.client
          .from('users')
          .select('uuid')
          .eq('uuid', userIdentifier)
          .maybeSingle();
      if (byUuid?['uuid'] != null) return byUuid!['uuid'] as String;

      final byId = await SupabaseService.client
          .from('users')
          .select('uuid')
          .eq('id', userIdentifier)
          .maybeSingle();
      return byId?['uuid'] as String?;
    } catch (_) {
      return null;
    }
  }
}
