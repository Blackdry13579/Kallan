import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kalan_app/core/navigation/app_navigator_key.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:kalan_app/presentation/widgets/challenge_invitation_bottom_sheet.dart';

/// Ouvre la feuille d'acceptation d'un défi (bannière, liste notifs, arène).
Future<bool> openBattleInviteSheet(String battleId) async {
  final nav = appNavigatorKey.currentState;
  if (nav == null || battleId.isEmpty) return false;

  Map<String, dynamic>? battle;
  try {
    final row = await SupabaseService.client
        .from('battles')
        .select()
        .eq('id', battleId)
        .maybeSingle();
    if (row != null) {
      battle = Map<String, dynamic>.from(row);
    }
  } catch (_) {}

  if (battle == null) {
    final ctx = nav.context;
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Défi introuvable ou expiré.'),
        ),
      );
    }
    return false;
  }

  final Map<String, dynamic> battleRow = battle;
  final status = battleRow['status'] as String? ?? '';
  if (status != 'invitation_sent') {
    final ctx = nav.context;
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            status == 'refused'
                ? 'Ce défi a été refusé.'
                : 'Ce défi a déjà été traité.',
          ),
        ),
      );
    }
    return false;
  }

  String opponentName = 'Un joueur';
  try {
    final inviterUuid = battleRow['inviter_id']?.toString();
    if (inviterUuid != null) {
      final user = await SupabaseService.client
          .from('users')
          .select('pseudo')
          .eq('uuid', inviterUuid)
          .maybeSingle();
      opponentName = user?['pseudo'] as String? ?? opponentName;
    }
  } catch (_) {}

  final ctx = nav.context;
  if (!ctx.mounted) return false;

  final challenge = Map<String, dynamic>.from(battleRow);
  challenge['opponent_name'] = opponentName;

  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChallengeInvitationBottomSheet(challenge: challenge),
  );
  return true;
}

/// Extrait un battle_id depuis le champ data Supabase ou le message de secours.
String? parseBattleIdFromNotification(Map<String, dynamic> raw) {
  final data = raw['data'];
  if (data is Map && data['battle_id'] != null) {
    return data['battle_id'].toString();
  }
  if (data is String && data.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      if (decoded['battle_id'] != null) {
        return decoded['battle_id'].toString();
      }
    } catch (_) {}
  }

  final message = raw['message']?.toString() ?? '';
  final match = RegExp(r'battle:([0-9a-fA-F-]{36})').firstMatch(message);
  return match?.group(1);
}
