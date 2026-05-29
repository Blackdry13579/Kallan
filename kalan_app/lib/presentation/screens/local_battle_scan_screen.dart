import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/duel_theme.dart';
import '../../services/local_battle_service.dart';
import 'challenge_rules_screen.dart';

/// Scanner un QR de défi local pour rejoindre.
class LocalBattleScanScreen extends StatefulWidget {
  const LocalBattleScanScreen({super.key});

  @override
  State<LocalBattleScanScreen> createState() => _LocalBattleScanScreenState();
}

class _LocalBattleScanScreenState extends State<LocalBattleScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final battle = LocalBattleService.decodeFromQr(raw);
    if (battle == null) return;

    _handled = true;
    _controller.stop();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeRulesScreen(
          opponentName: battle.hostPseudo,
          stake: battle.xpBet,
          battleId: battle.id,
          battleContent: battle.content,
          isLocalBattle: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuelTheme.text,
      appBar: AppBar(
        backgroundColor: DuelTheme.text,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scanner le défi',
          style: DuelTheme.title(size: 16).copyWith(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Place le QR code du défi dans le cadre',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DuelTheme.fireLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DuelTheme.fire.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: DuelTheme.fire, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les deux téléphones doivent être hors connexion ou en mode local.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DuelTheme.text,
                      ),
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
}
