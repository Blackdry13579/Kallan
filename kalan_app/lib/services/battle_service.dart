import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/battle_model.dart';

class BattleService {
  static const _uuid = Uuid();
  SupabaseClient get _client => Supabase.instance.client;

  Future<Battle> createBattle({
    required String inviterId,
    required String invitedId,
    String? theme,
    int xpBet = 50,
    String? inviterPseudo,
  }) async {
    if (inviterId.isEmpty || invitedId.isEmpty) {
      throw Exception('Joueur ou adversaire invalide.');
    }

    final inviterUuid = await _resolveUserUuid(inviterId);
    final invitedUuid = await _resolveUserUuid(invitedId);
    if (inviterUuid == null || invitedUuid == null) {
      throw Exception('Compte introuvable sur le serveur. Reconnecte-toi.');
    }
    if (inviterUuid == invitedUuid) {
      throw Exception('Tu ne peux pas te défier toi-même.');
    }

    try {
      final row = Map<String, dynamic>.from(await _client.from('battles').insert({
        'inviter_id': inviterUuid,
        'invited_id': invitedUuid,
        'theme': theme,
        'xp_bet': xpBet,
        'status': 'invitation_sent',
        'turn_user_id': inviterUuid,
      }).select().single());

      final pseudo = inviterPseudo ?? await _fetchPseudo(inviterUuid);
      await _notifyInvitee(
        invitedUuid: invitedUuid,
        inviterPseudo: pseudo,
        theme: theme ?? 'Général',
        xpBet: xpBet,
        battleId: row['id'].toString(),
      );

      return Battle.fromJson(row);
    } catch (e) {
      debugPrint('[Battle] Insert: $e');
      final msg = e.toString();
      if (msg.contains('row-level security') || msg.contains('42501')) {
        throw Exception(
          'Supabase bloque la création du défi (RLS). '
          'Exécute le script supabase/migrations/20260529_battles_rls_fix.sql '
          'dans le SQL Editor de ton projet Supabase.',
        );
      }
      if (msg.contains('foreign key') || msg.contains('23503')) {
        throw Exception(
          'Joueur introuvable côté serveur. Vérifie que les deux comptes existent bien dans Supabase.',
        );
      }
      throw Exception('Impossible de créer le défi : $msg');
    }
  }

  /// battles.inviter_id / invited_id référencent users.uuid (pas users.id).
  Future<String?> _resolveUserUuid(String userIdentifier) async {
    if (userIdentifier.isEmpty) return null;
    try {
      final byUuid = await _client
          .from('users')
          .select('uuid')
          .eq('uuid', userIdentifier)
          .maybeSingle();
      if (byUuid?['uuid'] != null) return byUuid!['uuid'] as String;

      final byId = await _client
          .from('users')
          .select('uuid')
          .eq('id', userIdentifier)
          .maybeSingle();
      return byId?['uuid'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> _fetchPseudo(String userUuid) async {
    try {
      final u = await _client
          .from('users')
          .select('pseudo')
          .eq('uuid', userUuid)
          .maybeSingle();
      return u?['pseudo'] as String? ?? 'Un joueur';
    } catch (_) {
      return 'Un joueur';
    }
  }

  Future<void> _notifyInvitee({
    required String invitedUuid,
    required String inviterPseudo,
    required String theme,
    required int xpBet,
    required String battleId,
  }) async {
    final notifId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final title = 'Nouveau défi !';
    final message = '$inviterPseudo te défie sur $theme ($xpBet XP)';

    final payload = {
      'id': notifId,
      'user_id': invitedUuid,
      'type': 'battle',
      'title': title,
      'message': message,
      'is_read': false,
      'created_at': now,
    };

    try {
      await _client.from('notifications').insert({
        ...payload,
        'data': {'battle_id': battleId},
      });
    } catch (e) {
      debugPrint('[Battle] Notification (data jsonb): $e');
      try {
        await _client.from('notifications').insert({
          ...payload,
          'message': '$message · battle:$battleId',
        });
      } catch (e2) {
        debugPrint('[Battle] Notification: $e2');
      }
    }
  }

  Stream<Battle> streamBattle(String battleId) {
    return _client
        .from('battles')
        .stream(primaryKey: ['id'])
        .eq('id', battleId)
        .map((list) => Battle.fromJson(list.first));
  }

  Future<void> acceptBattle(String battleId) async {
    await _client.from('battles').update({'status': 'accepted'}).eq('id', battleId);
  }

  Future<void> startGeneration(String battleId) async {
    await _client.from('battles').update({'status': 'generating'}).eq('id', battleId);
  }

  Future<void> updateBattleContent(String battleId, Map<String, dynamic> content) async {
    try {
      await _client.from('battles').update({
        'content': content,
        'status': 'in_progress',
      }).eq('id', battleId);
    } catch (e) {
      debugPrint('[Battle] updateBattleContent: $e');
      if (e.toString().contains('content') && e.toString().contains('PGRST204')) {
        throw Exception(
          'Colonne battles.content manquante. '
          'Exécute supabase/migrations/20260530_battles_missing_columns.sql',
        );
      }
      rethrow;
    }
  }

  Future<void> refuseBattle(String battleId) async {
    await _client.from('battles').update({'status': 'refused'}).eq('id', battleId);
  }

  Future<void> submitAnswer(String battleId, String userId, int questionIndex, String answer) async {
    final userUuid = await _resolveUserUuid(userId) ?? userId;
    await _client.rpc('submit_answer', params: {
      'p_battle_id': battleId,
      'p_user_id': userUuid,
      'p_question_index': questionIndex,
      'p_answer': answer,
    });
  }

  Future<void> abandonBattle(String battleId, String loserId) async {
    final loserUuid = await _resolveUserUuid(loserId) ?? loserId;
    await _client.rpc('abandon_battle', params: {
      'p_battle_id': battleId,
      'p_loser_id': loserUuid,
    });
  }

  Future<void> finishBattle(String battleId) async {
    await _client.rpc('finish_battle', params: {
      'p_battle_id': battleId,
    });
  }
}
