import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Défi local partagé via QR (hors connexion Supabase).
class LocalBattlePayload {
  final String id;
  final String hostId;
  final String hostPseudo;
  final String guestPseudo;
  final String theme;
  final int xpBet;
  final Map<String, dynamic> content;

  const LocalBattlePayload({
    required this.id,
    required this.hostId,
    required this.hostPseudo,
    required this.guestPseudo,
    required this.theme,
    required this.xpBet,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'v': 1,
        'id': id,
        'hostId': hostId,
        'hostPseudo': hostPseudo,
        'guestPseudo': guestPseudo,
        'theme': theme,
        'xpBet': xpBet,
        'content': content,
      };

  factory LocalBattlePayload.fromJson(Map<String, dynamic> json) {
    return LocalBattlePayload(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      hostPseudo: json['hostPseudo'] as String? ?? 'Hôte',
      guestPseudo: json['guestPseudo'] as String? ?? 'Invité',
      theme: json['theme'] as String? ?? 'Mélange',
      xpBet: json['xpBet'] as int? ?? 50,
      content: Map<String, dynamic>.from(json['content'] as Map),
    );
  }
}

class LocalBattleService {
  static const String qrPrefix = 'kalan://duel/';

  static LocalBattlePayload create({
    required String hostId,
    required String hostPseudo,
    required String guestPseudo,
    required String theme,
    required int xpBet,
    required Map<String, dynamic> content,
  }) {
    return LocalBattlePayload(
      id: const Uuid().v4(),
      hostId: hostId,
      hostPseudo: hostPseudo,
      guestPseudo: guestPseudo,
      theme: theme,
      xpBet: xpBet,
      content: content,
    );
  }

  /// Encode le défi pour affichage QR (base64url du JSON compact).
  static String encodeForQr(LocalBattlePayload battle) {
    final json = jsonEncode(battle.toJson());
    final bytes = utf8.encode(json);
    return '$qrPrefix${base64Url.encode(bytes)}';
  }

  /// Décode une chaîne scannée (QR ou collage manuel).
  static LocalBattlePayload? decodeFromQr(String raw) {
    try {
      var data = raw.trim();
      if (data.startsWith(qrPrefix)) {
        data = data.substring(qrPrefix.length);
      }
      final bytes = base64Url.decode(data);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if ((json['v'] as int? ?? 0) < 1) return null;
      return LocalBattlePayload.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
