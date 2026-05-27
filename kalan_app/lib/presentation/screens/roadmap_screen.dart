import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/level_utils.dart';
import '../../data/local/database_helper.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../widgets/zone_banner.dart';
import 'quiz_screen.dart';

class RoadmapStep {
  final int index;
  final String title;
  final String description;
  final IconData icon;
  final int level;
  final String levelTitle;
  final int xpRequired;

  const RoadmapStep({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
    required this.level,
    required this.levelTitle,
    required this.xpRequired,
  });
}

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final List<RoadmapStep> roadmapSteps = [
    const RoadmapStep(index: 0, title: 'Semailles', description: 'Sème tes premières graines.', icon: Icons.eco_rounded, level: 1, levelTitle: 'Graine', xpRequired: 0),
    const RoadmapStep(index: 1, title: 'Première Pousse', description: 'Les premières feuilles apparaissent.', icon: Icons.grass_rounded, level: 1, levelTitle: 'Graine', xpRequired: 50),
    const RoadmapStep(index: 2, title: 'Racines Fortes', description: 'Ancre tes connaissances profondément.', icon: Icons.yard_rounded, level: 2, levelTitle: 'Baobab', xpRequired: 100),
    const RoadmapStep(index: 3, title: 'Tronc Solide', description: 'Ton savoir devient robuste.', icon: Icons.forest_rounded, level: 2, levelTitle: 'Baobab', xpRequired: 170),
    const RoadmapStep(index: 4, title: 'Ombrage', description: 'Offre ta sagesse protectrice.', icon: Icons.park_rounded, level: 2, levelTitle: 'Baobab', xpRequired: 240),
    const RoadmapStep(index: 5, title: 'L\'Étincelle', description: 'Le grand feu commence.', icon: Icons.lightbulb_rounded, level: 3, levelTitle: 'Feu de Brousse', xpRequired: 300),
    const RoadmapStep(index: 6, title: 'Propagation', description: 'Rien ne peut t\'arrêter.', icon: Icons.whatshot_rounded, level: 3, levelTitle: 'Feu de Brousse', xpRequired: 400),
    const RoadmapStep(index: 7, title: 'Grand Brasier', description: 'Ta soif d\'apprendre brille.', icon: Icons.local_fire_department_rounded, level: 3, levelTitle: 'Feu de Brousse', xpRequired: 500),
    const RoadmapStep(index: 8, title: 'Paroles d\'Or', description: 'Apprends tel un Griot.', icon: Icons.auto_stories_rounded, level: 4, levelTitle: 'Griot', xpRequired: 600),
    const RoadmapStep(index: 9, title: 'Kora Sacrée', description: 'Trouve le rythme parfait.', icon: Icons.music_note_rounded, level: 4, levelTitle: 'Griot', xpRequired: 700),
    const RoadmapStep(index: 10, title: 'Légendes', description: 'Plonge dans les récits.', icon: Icons.history_edu_rounded, level: 4, levelTitle: 'Griot', xpRequired: 1000),
    const RoadmapStep(index: 11, title: 'Transmission', description: 'Partage tes connaissances.', icon: Icons.record_voice_over_rounded, level: 4, levelTitle: 'Griot', xpRequired: 1100),
    const RoadmapStep(index: 12, title: 'Initiation', description: 'Sous le masque du savoir.', icon: Icons.visibility_rounded, level: 5, levelTitle: 'Masque', xpRequired: 1200),
    const RoadmapStep(index: 13, title: 'Danse Sacrée', description: 'Jongle entre les matières.', icon: Icons.theater_comedy_rounded, level: 5, levelTitle: 'Masque', xpRequired: 1400),
    const RoadmapStep(index: 14, title: 'Mystères', description: 'Comprends la profondeur.', icon: Icons.psychology_rounded, level: 5, levelTitle: 'Masque', xpRequired: 1600),
    const RoadmapStep(index: 15, title: 'Gardien', description: 'L\'assiduité est ton pouvoir.', icon: Icons.security_rounded, level: 5, levelTitle: 'Masque', xpRequired: 1800),
    const RoadmapStep(index: 16, title: 'Sommet', description: 'Tu es un Ancêtre vénéré.', icon: Icons.auto_awesome_rounded, level: 6, levelTitle: 'Ancêtre', xpRequired: 2000),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Parcours d\'Apprentissage',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            if (state is UserLoading) return const Center(child: CircularProgressIndicator());
            if (state is UserError) return Center(child: Text(state.message));
            if (state is UserLoaded) {
              final points = state.profile['points'] as int? ?? 0;
              final userId = state.profile['uuid'] as String? ?? '';
              final levelInfo = LevelUtils.getLevelInfo(points);

              int activeIndex = 0;
              for (int i = 0; i < roadmapSteps.length; i++) {
                if (points >= roadmapSteps[i].xpRequired) activeIndex = i;
                else break;
              }

              return Column(
                children: [
                  _buildHeaderProgress(points, levelInfo, levelInfo.level),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        final mapHeight = 300.0 + (roadmapSteps.length * 200.0);

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Stack(
                            children: [
                              _buildWorldBackgrounds(mapHeight, screenWidth),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SerpentinePathPainter(
                                    steps: roadmapSteps,
                                    userPoints: points,
                                    screenWidth: screenWidth,
                                  ),
                                ),
                              ),
                              Positioned(top: 40, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DES GRAINES', levelSubtitle: 'Niveau 1', color: Colors.white, bgColor: const Color(0xFF4CAF50).withValues(alpha: 0.8)))),
                              Positioned(top: 440, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DU BAOBAB', levelSubtitle: 'Niveau 2', color: Colors.white, bgColor: const Color(0xFF795548).withValues(alpha: 0.8)))),
                              Positioned(top: 1040, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DU FEU', levelSubtitle: 'Niveau 3', color: Colors.white, bgColor: const Color(0xFFC92A2A).withValues(alpha: 0.8)))),
                              Positioned(top: 1640, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DU GRIOT', levelSubtitle: 'Niveau 4', color: Colors.white, bgColor: const Color(0xFFE07B39).withValues(alpha: 0.8)))),
                              Positioned(top: 2440, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DES MASQUES', levelSubtitle: 'Niveau 5', color: Colors.white, bgColor: const Color(0xFF673AB7).withValues(alpha: 0.8)))),
                              Positioned(top: 3240, left: 20, right: 20, child: Center(child: ZoneBanner(title: 'MONDE DES ANCÊTRES', levelSubtitle: 'Niveau 6', color: Colors.white, bgColor: const Color(0xFF009688).withValues(alpha: 0.8)))),
                              SizedBox(
                                height: mapHeight,
                                width: screenWidth,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: List.generate(roadmapSteps.length, (index) {
                                    final step = roadmapSteps[index];
                                    bool isCompleted = points >= step.xpRequired && index < activeIndex;
                                    bool isActive = index == activeIndex;
                                    bool isLocked = points < step.xpRequired;

                                    if (points >= roadmapSteps.last.xpRequired && index == roadmapSteps.length - 1) {
                                      isCompleted = false;
                                      isActive = true;
                                      isLocked = false;
                                    }

                                    double x = screenWidth / 2 + 85 * sin(index * 1.0);
                                    double y = 160 + index * 200.0;

                                    return Positioned(
                                      left: x - 90, 
                                      top: y - 70,
                                      child: PremiumRoadmapNode(
                                        step: step,
                                        isCompleted: isCompleted,
                                        isActive: isActive,
                                        isLocked: isLocked,
                                        onTap: () => _showStepDetails(context, step, points, isCompleted, isActive, isLocked, userId),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildWorldBackgrounds(double mapHeight, double screenWidth) {
    return Column(
      children: [
        _buildWorldSection('level-1-graine.jpg', 400, screenWidth),
        _buildWorldSection('level-2-baobab.jpg', 600, screenWidth),
        _buildWorldSection('level-3-feu.jpg', 600, screenWidth),
        _buildWorldSection('level-4-griot.jpg', 800, screenWidth),
        _buildWorldSection('level-5-masque.jpg', 800, screenWidth),
        _buildWorldSection('level-6-ancetre.jpg', 500, screenWidth),
      ],
    );
  }

  Widget _buildWorldSection(String img, double height, double width) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/roadmap/$img'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.1), BlendMode.darken),
        ),
      ),
    );
  }

  String _levelBgImage(int level) => switch (level) {
    2 => 'level-2-baobab.jpg',
    3 => 'level-3-feu.jpg',
    4 => 'level-4-griot.jpg',
    5 => 'level-5-masque.jpg',
    6 => 'level-6-ancetre.jpg',
    _ => 'level-1-graine.jpg',
  };

  Widget _buildHeaderProgress(int points, LevelInfo levelInfo, int level) {
    final double progress = (points / levelInfo.nextLevelPoints).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/roadmap/${_levelBgImage(level)}'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.50), BlendMode.darken),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Hero(
                    tag: 'mascot_roadmap',
                    child: Image.asset('assets/images/Bonome.png', height: 38, errorBuilder: (_,__,___) => const Icon(Icons.school, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progression Actuelle',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            levelInfo.title.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                          ),
                          child: Text(
                            'Niveau $level',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '$points XP',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF76D572)),
            ),
          ),
        ],
      ),
    );
  }

  void _showStepDetails(BuildContext context, RoadmapStep step, int userPoints, bool isCompleted, bool isActive, bool isLocked, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.shade100 : (isCompleted ? const Color(0xFFEAF3DE) : const Color(0xFFFFF3E0)),
                shape: BoxShape.circle,
                border: Border.all(color: isLocked ? Colors.grey.shade300 : (isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFE8C87A)), width: 3),
              ),
              child: Image.asset(
                'assets/roadmap/mascot-${step.level}.png',
                height: 60,
                errorBuilder: (_,__,___) => Icon(isLocked ? Icons.lock_rounded : step.icon, color: isLocked ? Colors.grey : (isCompleted ? const Color(0xFF2D6A2D) : const Color(0xFF854F0B)), size: 42),
              ),
            ),
            const SizedBox(height: 20),
            Text(step.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text('CHAPITRE : ${step.levelTitle.toUpperCase()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isLocked ? Colors.grey : const Color(0xFF4CAF50))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFFBFBF9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
              child: Text(step.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF555555))),
            ),
            const SizedBox(height: 32),
            if (isLocked) ...[
              Text('XP REQUIS : ${step.xpRequired}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.grey, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('CONTINUE TES RÉVISIONS POUR DÉBLOQUER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), elevation: 4, shadowColor: const Color(0xFF2D6A2D).withValues(alpha: 0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final dbHelper = DatabaseHelper.instance;
                    final decks = await dbHelper.getDecks(userId);
                    
                    if (!context.mounted) return;
                    if (decks.isEmpty) { 
                      _showNoDecksWarning(context); 
                    } else {
                      final randomDeck = decks[Random().nextInt(decks.length)];
                      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(deckUuid: randomDeck['uuid'], deckTitle: randomDeck['title'] ?? 'Quiz Rapide')));
                    }
                  },
                  child: Text(isCompleted ? 'REFAIRE LE DÉFI' : 'RELEVER LE DÉFI ! (+10 XP)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNoDecksWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Aucune fiche', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Crée ta première fiche pour pouvoir lancer des quiz et progresser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(dialogContext); },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class PremiumRoadmapNode extends StatelessWidget {
  final RoadmapStep step;
  final bool isCompleted;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;

  const PremiumRoadmapNode({super.key, required this.step, required this.isCompleted, required this.isActive, required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color baseColor = isCompleted ? const Color(0xFF4CAF50) : (isActive ? const Color(0xFFE8C87A) : const Color(0xFFE5E5E5));
    Color shadowColor = isCompleted ? const Color(0xFF2E7D32) : (isActive ? const Color(0xFFCBB06B) : const Color(0xFFAFAFAF));

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step.index % 2 == 0) _buildMascot(isLocked),
          Column(
            children: [
              if (isActive) _buildStatusBadge(),
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(top: 8, child: Container(width: 90, height: 90, decoration: BoxDecoration(color: shadowColor, borderRadius: BorderRadius.circular(28)))),
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: isLocked ? Colors.grey.shade300 : baseColor, width: 4),
                      boxShadow: [if (isActive) BoxShadow(color: baseColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/roadmap/level-${step.level}.jpg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_,__,___) => Container(color: baseColor.withValues(alpha: 0.1)),
                          ),
                          Container(color: isLocked ? Colors.black.withValues(alpha: 0.3) : baseColor.withValues(alpha: 0.2)),
                          Center(
                            child: isLocked 
                              ? const Icon(Icons.lock_rounded, color: Colors.white, size: 32)
                              : Icon(isCompleted ? Icons.check_rounded : step.icon, color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8, left: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: shadowColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: Text('${step.index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(step.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isLocked ? Colors.white70 : Colors.white)),
            ],
          ),
          if (step.index % 2 != 0) _buildMascot(isLocked),
        ],
      ),
    );
  }

  Widget _buildMascot(bool isLocked) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Image.asset(
          'assets/roadmap/mascot-${step.level}.png',
          errorBuilder: (_,__,___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8C87A), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: const Text('À TOI !', style: TextStyle(color: Color(0xFF854F0B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }
}

class SerpentinePathPainter extends CustomPainter {
  final List<RoadmapStep> steps;
  final int userPoints;
  final double screenWidth;

  SerpentinePathPainter({required this.steps, required this.userPoints, required this.screenWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    final paintCompleted = Paint()..color = Colors.white.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    final paintLocked = Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;

    for (int i = 0; i < steps.length - 1; i++) {
      double xPrev = screenWidth / 2 + 85 * sin(i * 1.0);
      double yPrev = 160 + i * 200.0;
      double xCurr = screenWidth / 2 + 85 * sin((i + 1) * 1.0);
      double yCurr = 160 + (i + 1) * 200.0;

      final path = Path();
      path.moveTo(xPrev, yPrev);
      path.cubicTo(xPrev, yPrev + 100, xCurr, yCurr - 100, xCurr, yCurr);

      bool isCompleted = userPoints >= steps[i+1].xpRequired;
      if (isCompleted) {
        canvas.drawPath(path, paintCompleted);
      } else {
        _drawDashedPath(canvas, path, paintLocked);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 8.0;
    const double dashSpace = 8.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SerpentinePathPainter oldDelegate) => true;
}
