import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/audio_service.dart';
import '../../services/celebration_coordinator.dart';
import 'tree_evolution.dart';
import 'confetti_widget.dart';

class LevelUpPopup {
  static void show(
    BuildContext context, {
    required int level,
    required String title,
    required String icon,
    required int pointsReward,
    required int flashcardsCount,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Forcer l'interaction
      barrierLabel: 'level_up_popup',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) {
        AudioService().play('level_up');
        return _LevelUpContent(
          level: level,
          title: title,
          icon: icon,
          pointsReward: pointsReward,
          flashcardsCount: flashcardsCount,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.elasticOut);
        return Stack(
          children: [
            // Confetti background
            const Positioned.fill(child: ConfettiWidget()),

            ScaleTransition(
              scale: curved,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LevelUpContent extends StatelessWidget {
  final int level;
  final String title;
  final String icon;
  final int pointsReward;
  final int flashcardsCount;

  const _LevelUpContent({
    required this.level,
    required this.title,
    required this.icon,
    required this.pointsReward,
    required this.flashcardsCount,
  });

  @override
  Widget build(BuildContext context) {
    final safeLevel = level.clamp(1, 6);

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D6A2D).withValues(alpha: 0.24),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/roadmap/level-$safeLevel-${_assetSlug(safeLevel)}.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFEAF3DE),
                            child: Center(
                                child:
                                    TreeEvolution(stage: safeLevel, size: 96)),
                          ),
                        ),
                      ),
                      Container(
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFFAC775), width: 2),
                              ),
                              child: Center(
                                  child: TreeEvolution(
                                      stage: safeLevel, size: 42)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Nouveau niveau',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFFFE9B7),
                                    ),
                                  ),
                                  Text(
                                    'Niveau $level',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bravo, tu progresses encore. Continue comme ça avec tes $flashcardsCount fiches de révision.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF5F5A52),
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _rewardItem(Icons.bolt_rounded, '+$pointsReward XP',
                                const Color(0xFFE8A317)),
                            const SizedBox(width: 10),
                            _rewardItem(
                                Icons.style_rounded,
                                '$flashcardsCount fiches',
                                const Color(0xFF2D6A2D)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              CelebrationCoordinator.dismiss();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D6A2D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Continuer',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _assetSlug(int stage) {
    switch (stage) {
      case 1:
        return 'graine';
      case 2:
        return 'baobab';
      case 3:
        return 'feu';
      case 4:
        return 'griot';
      case 5:
        return 'masque';
      case 6:
      default:
        return 'ancetre';
    }
  }

  Widget _rewardItem(IconData icon, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
