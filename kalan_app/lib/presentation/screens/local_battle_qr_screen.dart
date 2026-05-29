import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/duel_theme.dart';
import '../../services/local_battle_service.dart';
import 'challenge_rules_screen.dart';

/// L'hôte affiche le QR après avoir créé un défi local.
class LocalBattleQrScreen extends StatelessWidget {
  final LocalBattlePayload battle;
  final bool isHost;

  const LocalBattleQrScreen({
    super.key,
    required this.battle,
    this.isHost = true,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = LocalBattleService.encodeForQr(battle);
    final opponentName =
        isHost ? battle.guestPseudo : battle.hostPseudo;

    return Scaffold(
      backgroundColor: DuelTheme.bg,
      appBar: AppBar(
        backgroundColor: DuelTheme.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DuelTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Défi local', style: DuelTheme.title()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            DuelTheme.modeBadge(isOnline: false),
            const SizedBox(height: 20),
            Text(
              isHost
                  ? 'Montre ce QR à ${battle.guestPseudo}'
                  : 'Défi reçu de ${battle.hostPseudo}',
              textAlign: TextAlign.center,
              style: DuelTheme.title(size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Thème : ${battle.theme} · ${battle.xpBet} XP',
              style: DuelTheme.body(),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: DuelTheme.cardDecoration(borderColor: DuelTheme.primary.withValues(alpha: 0.3)),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: DuelTheme.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: DuelTheme.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ton ami scanne ce code dans Arène → Rejoindre',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DuelTheme.sub,
              ),
            ),
            const SizedBox(height: 32),
            if (isHost) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChallengeRulesScreen(
                          opponentName: opponentName,
                          stake: battle.xpBet,
                          battleId: battle.id,
                          battleContent: battle.content,
                          isLocalBattle: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuelTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Text(
                    'COMMENCER LE DÉFI',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu peux commencer dès que ton ami a scanné',
                style: DuelTheme.body(size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
