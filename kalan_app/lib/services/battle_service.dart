import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/battle_model.dart';

class BattleService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Battle> createBattle({
    required String inviterId,
    required String invitedId,
    String? theme,
    int xpBet = 50,
  }) async {
    // If the user created an RPC 'create_battle', we could use it here.
    // For now, fallback to insert if the RPC doesn't exist.
    try {
      final responseId = await _client.rpc('create_battle', params: {
        'p_inviter_id': inviterId,
        'p_invited_id': invitedId,
        'p_theme': theme,
        'p_xp_bet': xpBet,
      });
      final data = await _client.from('battles').select().eq('id', responseId).single();
      return Battle.fromJson(data);
    } catch (e) {
      // Fallback to direct insert
      final response = await _client.from('battles').insert({
        'inviter_id': inviterId,
        'invited_id': invitedId,
        'theme': theme,
        'xp_bet': xpBet,
        'status': 'invitation_sent',
        'turn_user_id': inviterId,
      }).select().single();
      return Battle.fromJson(response);
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
    await _client.from('battles').update({
      'content': content,
      'status': 'in_progress',
    }).eq('id', battleId);
  }

  Future<void> refuseBattle(String battleId) async {
    await _client.from('battles').update({'status': 'refused'}).eq('id', battleId);
  }

  Future<void> submitAnswer(String battleId, String userId, int questionIndex, String answer) async {
    await _client.rpc('submit_answer', params: {
      'p_battle_id': battleId,
      'p_user_id': userId,
      'p_question_index': questionIndex,
      'p_answer': answer,
    });
  }

  Future<void> abandonBattle(String battleId, String loserId) async {
    await _client.rpc('abandon_battle', params: {
      'p_battle_id': battleId,
      'p_loser_id': loserId,
    });
  }

  Future<void> finishBattle(String battleId) async {
    await _client.rpc('finish_battle', params: {
      'p_battle_id': battleId,
    });
  }
}
