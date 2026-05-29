import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/battle_service.dart';

class ChallengeResultScreen extends StatefulWidget {
  final String opponentName;
  final String? opponentAvatar;
  final int stake;
  final int scoreYou;
  final int scoreThem;
  final String battleId;
  final bool isLocalBattle;

  const ChallengeResultScreen({
    super.key,
    required this.opponentName,
    this.opponentAvatar,
    required this.stake,
    required this.scoreYou,
    required this.scoreThem,
    required this.battleId,
    this.isLocalBattle = false,
  });

  @override
  State<ChallengeResultScreen> createState() => _ChallengeResultScreenState();
}

class _ChallengeResultScreenState extends State<ChallengeResultScreen> {
  final BattleService _battleService = BattleService();

  @override
  void initState() {
    super.initState();
    if (!widget.isLocalBattle) {
      _battleService.finishBattle(widget.battleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool win = widget.scoreYou > widget.scoreThem;
    final bool tie = widget.scoreYou == widget.scoreThem;

    const Color emerald = Color(0xFF10B981);
    const Color rose = Color(0xFFF43F5E);
    const Color clay = Color(0xFF8B4513);
    const Color gold = Color(0xFFF59E0B);
    const Color background = Color(0xFFF8FAFC);

    final Color resultColor = win ? emerald : (tie ? clay : rose);
    final String resultTitle = win ? "Victoire !" : (tie ? "Égalité" : "Défaite");
    final IconData resultIcon = win ? Icons.emoji_events_rounded : (tie ? Icons.flare_rounded : Icons.priority_high_rounded);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildResultIcon(resultIcon, resultColor, gold),
              const SizedBox(height: 32),
              _buildResultTitle(resultTitle),
              const SizedBox(height: 12),
              _buildScoreText(widget.opponentName, widget.scoreYou, widget.scoreThem),
              const SizedBox(height: 40),
              _buildXpReward(win, tie, widget.stake, gold),
              const SizedBox(height: 60),
              _buildActionButtons(context, resultColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultIcon(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: bgColor.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Center(
        child: Icon(icon, size: 60, color: Colors.white),
      ),
    );
  }

  Widget _buildResultTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w900),
    );
  }

  Widget _buildScoreText(String name, int you, int them) {
    return Text(
      'Score final : $you – $them contre ${widget.opponentName}',
      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
    );
  }

  Widget _buildXpReward(bool win, bool tie, int stake, Color gold) {
    String rewardText = win ? '+${stake * 2} XP' : (tie ? '+0 XP (mise rendue)' : '-$stake XP');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: gold, size: 24),
          const SizedBox(width: 8),
          Text(
            rewardText,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: gold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: Text(
              'TERMINER',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black12, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text(
              'RETOUR À L\'ARÈNE',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
