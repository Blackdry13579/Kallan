import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'duel_game_screen.dart';

class ChallengeRulesScreen extends StatelessWidget {
  final String opponentName;
  final String? opponentAvatar;
  final int stake;
  final String battleId;
  final Map<String, dynamic>? battleContent;
  final bool isLocalBattle;

  const ChallengeRulesScreen({
    super.key,
    required this.opponentName,
    this.opponentAvatar,
    required this.stake,
    required this.battleId,
    this.battleContent,
    this.isLocalBattle = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFF59E0B);
    const Color rose = Color(0xFFF43F5E);
    const Color emerald = Color(0xFF10B981);
    const Color background = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildIconHeader(gold),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 40),
              _buildStepCard(
                number: 1,
                title: 'Le Quiz',
                description:
                    '5 questions à choix multiples. Réponds vite et juste pour gagner la mise de $stake XP !',
                color: rose,
              ),
              const Spacer(),
              _buildStartButton(context, emerald),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconHeader(Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.description_outlined, color: color, size: 40),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Règles du Duel',
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Affronte $opponentName en répondant le plus vite possible.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required int number,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DuelGameScreen(
              opponentName: opponentName,
              opponentAvatar: opponentAvatar,
              stake: stake,
              battleId: battleId,
              battleContent: battleContent,
              isLocalBattle: isLocalBattle,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'C\'EST PARTI !',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.play_arrow_rounded, size: 24),
          ],
        ),
      ),
    );
  }
}
