import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/level_utils.dart';
import '../../data/local/database_helper.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
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
    const RoadmapStep(index: 0, title: 'Semailles', description: 'Plante tes premières intentions.', icon: Icons.eco_rounded, level: 1, levelTitle: 'Graine', xpRequired: 0),
    const RoadmapStep(index: 1, title: 'Éclosion', description: 'La vie commence à percer.', icon: Icons.auto_awesome_rounded, level: 1, levelTitle: 'Graine', xpRequired: 250),
    const RoadmapStep(index: 2, title: 'Premières Feuilles', description: 'Le savoir commence à verdir.', icon: Icons.grass_rounded, level: 2, levelTitle: 'Jeune Pousse', xpRequired: 500),
    const RoadmapStep(index: 3, title: 'Vers le Ciel', description: 'Ta curiosité s\'élève.', icon: Icons.trending_up_rounded, level: 2, levelTitle: 'Jeune Pousse', xpRequired: 1000),
    const RoadmapStep(index: 4, title: 'Ancrage', description: 'Tes racines deviennent fortes.', icon: Icons.yard_rounded, level: 3, levelTitle: 'Baobab', xpRequired: 1500),
    const RoadmapStep(index: 5, title: 'Baobab Majestueux', description: 'Ton savoir est un pilier.', icon: Icons.park_rounded, level: 3, levelTitle: 'Baobab', xpRequired: 2500),
    const RoadmapStep(index: 6, title: 'L\'Étincelle', description: 'La passion s\'allume.', icon: Icons.lightbulb_rounded, level: 4, levelTitle: 'Feu de Brousse', xpRequired: 3500),
    const RoadmapStep(index: 7, title: 'Grand Brasier', description: 'Ta soif d\'apprendre brille.', icon: Icons.local_fire_department_rounded, level: 4, levelTitle: 'Feu de Brousse', xpRequired: 5200),
    const RoadmapStep(index: 8, title: 'Paroles d\'Or', description: 'Apprends tel un Griot.', icon: Icons.auto_stories_rounded, level: 5, levelTitle: 'Griot', xpRequired: 7000),
    const RoadmapStep(index: 9, title: 'Kora Sacrée', description: 'Trouve le rythme parfait.', icon: Icons.music_note_rounded, level: 5, levelTitle: 'Griot', xpRequired: 9500),
    const RoadmapStep(index: 10, title: 'Légendes', description: 'Plonge dans les récits.', icon: Icons.history_edu_rounded, level: 6, levelTitle: 'Masque', xpRequired: 12000),
    const RoadmapStep(index: 11, title: 'Initiation', description: 'Sous le masque du savoir.', icon: Icons.visibility_rounded, level: 6, levelTitle: 'Masque', xpRequired: 16000),
    const RoadmapStep(index: 12, title: 'Transmission', description: 'Partage tes connaissances.', icon: Icons.record_voice_over_rounded, level: 7, levelTitle: 'Gardien', xpRequired: 20000),
    const RoadmapStep(index: 13, title: 'Vigie', description: 'Surveille tes progrès.', icon: Icons.remove_red_eye_rounded, level: 7, levelTitle: 'Gardien', xpRequired: 27000),
    const RoadmapStep(index: 14, title: 'Sagesse Antique', description: 'Écoute les voix du passé.', icon: Icons.interpreter_mode_rounded, level: 8, levelTitle: 'Ancêtre', xpRequired: 35000),
    const RoadmapStep(index: 15, title: 'Immortalité', description: 'Ton savoir ne périra pas.', icon: Icons.all_inclusive_rounded, level: 8, levelTitle: 'Ancêtre', xpRequired: 47000),
    const RoadmapStep(index: 16, title: 'Mystères', description: 'Comprends la profondeur.', icon: Icons.psychology_rounded, level: 9, levelTitle: 'Sage', xpRequired: 60000),
    const RoadmapStep(index: 17, title: 'Harmonie', description: 'La fusion des savoirs.', icon: Icons.mediation_rounded, level: 9, levelTitle: 'Sage', xpRequired: 80000),
    const RoadmapStep(index: 18, title: 'Sommet', description: 'Tu es une Lumière éternelle.', icon: Icons.auto_awesome_rounded, level: 10, levelTitle: 'Lumière', xpRequired: 100000),
    const RoadmapStep(index: 19, title: 'Illumination', description: 'L\'infini du savoir.', icon: Icons.wb_sunny_rounded, level: 10, levelTitle: 'Lumière', xpRequired: 130000),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.fredokaTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2D6A2D)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Parcours d\'Apprentissage',
            style: GoogleFonts.fredoka(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
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

              int activeIndex = 0;
              for (int i = 0; i < roadmapSteps.length; i++) {
                if (points >= roadmapSteps[i].xpRequired) {
                  activeIndex = i;
                } else {
                  break;
                }
              }

              final levelInfo = LevelUtils.getLevelInfo(points);
              const double headerHeight = 180.0; // Hauteur estimée de la bannière
              const double nodeHeight = 200.0;   // Hauteur estimée d'une étape (bulle + texte)
              const double verticalGap = 150.0;  // L'espace égal souhaité entre chaque élément
              
              const double levelBlockHeight = headerHeight + (2 * nodeHeight) + (3 * verticalGap);
              final double mapHeight = LevelUtils.levels.length * levelBlockHeight + 200;

              return Column(
                children: [
                  _buildHeaderProgress(points, levelInfo),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Container(
                            color: const Color(0xFFF2EAD3),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: ParchmentPatternPainter(),
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: SerpentinePathPainter(
                                      steps: roadmapSteps,
                                      userPoints: points,
                                      screenWidth: screenWidth,
                                      headerHeight: headerHeight,
                                      nodeHeight: nodeHeight,
                                      verticalGap: verticalGap,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: mapHeight,
                                  width: screenWidth,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ...LevelUtils.levels.map((lvl) {
                                        final double yPos = (lvl.level - 1) * levelBlockHeight + 50;
                                        return Positioned(
                                          top: yPos,
                                          left: 0,
                                          right: 0,
                                          child: _buildWorldHeader(lvl, screenWidth),
                                        );
                                      }),
                                      ...List.generate(roadmapSteps.length, (index) {
                                        final step = roadmapSteps[index];
                                        bool isCompleted = points >= step.xpRequired && index < activeIndex;
                                        bool isActive = index == activeIndex;
                                        bool isLocked = points < step.xpRequired;

                                        if (points >= roadmapSteps.last.xpRequired && index == roadmapSteps.length - 1) {
                                          isCompleted = false;
                                          isActive = true;
                                          isLocked = false;
                                        }

                                        final bool isFirstStepInLevel = index % 2 == 0;
                                        final double yPos = ((step.level - 1) * levelBlockHeight) + 50 + headerHeight + verticalGap + (isFirstStepInLevel ? 0 : (nodeHeight + verticalGap));
                                        double x = screenWidth / 2 + 100 * math.sin(index * 1.8);

                                        return Positioned(
                                          left: x - 65, 
                                          top: yPos,
                                          child: PremiumRoadmapNode(
                                            step: step,
                                            isCompleted: isCompleted,
                                            isActive: isActive,
                                            isLocked: isLocked,
                                            onTap: () => _showStepDetails(context, step, points, isCompleted, isActive, isLocked, userId),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildWorldHeader(LevelInfo lvl, double width) {
    String worldName;
    String worldDescription;
    Color accentColor;
    
    switch (lvl.level) {
      case 1: 
        worldName = 'MONDE DU FLORISSANT'; 
        worldDescription = 'Les bases qui germent';
        accentColor = const Color(0xFF2D6A2D); 
        break;
      case 2: 
        worldName = 'MONDE DES RACINES'; 
        worldDescription = 'Tu prends racine';
        accentColor = const Color(0xFF43A047); 
        break;
      case 3: 
        worldName = 'MONDE DU BAOBAB'; 
        worldDescription = 'Tes racines de savoir';
        accentColor = const Color(0xFF854F0B); 
        break;
      case 4: 
        worldName = 'MONDE DU FEU'; 
        worldDescription = 'Allume la flamme';
        accentColor = const Color(0xFFC92A2A); 
        break;
      case 5: 
        worldName = 'MONDE DU GRIOT'; 
        worldDescription = 'Raconte ce que tu sais';
        accentColor = const Color(0xFFE07B39); 
        break;
      case 6: 
        worldName = 'MONDE DES MASQUES'; 
        worldDescription = 'Maîtrise les rituels';
        accentColor = const Color(0xFF673AB7); 
        break;
      case 7: 
        worldName = 'MONDE DES GARDIENS'; 
        worldDescription = 'Protège la sagesse';
        accentColor = const Color(0xFF3F51B5); 
        break;
      case 8: 
        worldName = 'MONDE DES ANCÊTRES'; 
        worldDescription = 'Deviens légende';
        accentColor = const Color(0xFF795548); 
        break;
      case 9: 
        worldName = 'MONDE DES SAGES'; 
        worldDescription = 'Lis dans les étoiles';
        accentColor = const Color(0xFF009688); 
        break;
      case 10: 
        worldName = 'MONDE DE LA LUMIÈRE'; 
        worldDescription = 'Deviens le soleil';
        accentColor = const Color(0xFFB8860B); 
        break;
      default: 
        worldName = 'NOUVEAU MONDE'; 
        worldDescription = 'Continue ton voyage';
        accentColor = Colors.grey;
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fond de la bannière
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [accentColor.withValues(alpha: 0.8), accentColor.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
              ),
              // Image d'ambiance
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/roadmap/${lvl.assetImage}',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withValues(alpha: 0.3),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
              // Mascotte
              Positioned(
                left: -10,
                bottom: -15,
                child: Image.asset(
                  'assets/roadmap/${lvl.mascotImage}',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              // Contenu textuel
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                left: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NIVEAU ${lvl.level}',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      worldName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worldDescription,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderProgress(int points, LevelInfo levelInfo) {
    final double progress = (points / levelInfo.nextLevelPoints).clamp(0.0, 1.0);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Hero(
                    tag: 'mascot_roadmap',
                    child: Image.asset('assets/images/Bonome.png', height: 38, errorBuilder: (_,__,___) => const Icon(Icons.school, color: Color(0xFF2D6A2D))),
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w800),
                    ),
                    Row(
                      children: [
                        Text(
                          levelInfo.title.toUpperCase(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Niveau ${levelInfo.level}',
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D6A2D)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8E4DA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
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
                'assets/roadmap/${LevelUtils.levels[step.level - 1].mascotImage}',
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
            if (isLocked)
              Text('XP REQUIS : ${step.xpRequired}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            if (isLocked)
              const SizedBox(height: 12),
            if (isLocked)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.grey, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('CONTINUE TES RÉVISIONS POUR DÉBLOQUER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              )
            else
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
                      final randomDeck = decks[math.Random().nextInt(decks.length)];
                      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(deckUuid: randomDeck['uuid'], deckTitle: randomDeck['title'] ?? 'Quiz Rapide')));
                    }
                  },
                  child: Text(isCompleted ? 'REFAIRE LE DÉFI' : 'RELEVER LE DÉFI ! (+10 XP)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) _buildStatusBadge(),
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(top: 8, child: Container(width: 130, height: 130, decoration: BoxDecoration(color: shadowColor, shape: BoxShape.circle))),
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isLocked ? Colors.grey.shade300 : baseColor, width: 5),
                  boxShadow: [if (isActive) BoxShadow(color: baseColor.withValues(alpha: 0.5), blurRadius: 25, spreadRadius: 4)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(65),
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/roadmap/${LevelUtils.levels[step.level - 1].assetImage}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_,__,___) => Container(color: baseColor.withValues(alpha: 0.1)),
                      ),
                      Container(color: isLocked ? Colors.black.withValues(alpha: 0.4) : baseColor.withValues(alpha: 0.2)),
                      Center(
                        child: isLocked 
                          ? const Icon(Icons.lock_rounded, color: Colors.white, size: 42)
                          : Icon(isCompleted ? Icons.check_rounded : step.icon, color: Colors.white, size: 50),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0, left: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: shadowColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: Text('${step.index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 150,
            child: Text(
              step.title, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w900, 
                color: isLocked ? Colors.grey : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
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

class ParchmentPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    
    // 1. Texture de fond (grain léger)
    final paintGrain = Paint()
      ..color = const Color(0xFF854F0B).withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 2000; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paintGrain);
    }

    // 2. Fibres du papier
    final paintFiber = Paint()
      ..color = const Color(0xFF854F0B).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    for (int i = 0; i < 800; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double length = random.nextDouble() * 30 + 10;
      double angle = random.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length * math.cos(angle), y + length * math.sin(angle)),
        paintFiber,
      );
    }

    // 3. Tâches d'usure/temps
    final paintSpot = Paint()
      ..color = const Color(0xFF854F0B).withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 40; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = random.nextDouble() * 80 + 20;
      canvas.drawCircle(Offset(x, y), radius, paintSpot);
    }

    // 4. Motifs géométriques ancestraux (Marges)
    final paintPattern = Paint()
      ..color = const Color(0xFF854F0B).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawAfricanPatterns(canvas, size, paintPattern);

    // 5. Effet de bords brûlés (Vignettage)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paintVignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF854F0B).withValues(alpha: 0.02),
          const Color(0xFF854F0B).withValues(alpha: 0.15),
        ],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, paintVignette);
  }

  void _drawAfricanPatterns(Canvas canvas, Size size, Paint paint) {
    const double patternSize = 40.0;
    const double spacing = 120.0;

    // Dessiner des motifs sur les côtés
    for (double y = 0; y < size.height; y += spacing) {
      // Gauche
      _drawSinglePattern(canvas, Offset(20, y), patternSize, paint);
      // Droite
      _drawSinglePattern(canvas, Offset(size.width - 60, y + 60), patternSize, paint);
    }
  }

  void _drawSinglePattern(Canvas canvas, Offset offset, double size, Paint paint) {
    // Un motif simple de type "losange avec croix" (inspiré Bogolan)
    final path = Path();
    path.moveTo(offset.dx + size / 2, offset.dy);
    path.lineTo(offset.dx + size, offset.dy + size / 2);
    path.lineTo(offset.dx + size / 2, offset.dy + size);
    path.lineTo(offset.dx, offset.dy + size / 2);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(offset.dx, offset.dy), Offset(offset.dx + size, offset.dy + size), paint);
    canvas.drawLine(Offset(offset.dx + size, offset.dy), Offset(offset.dx, offset.dy + size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SerpentinePathPainter extends CustomPainter {
  final List<RoadmapStep> steps;
  final int userPoints;
  final double screenWidth;
  final double headerHeight;
  final double nodeHeight;
  final double verticalGap;

  SerpentinePathPainter({
    required this.steps, 
    required this.userPoints, 
    required this.screenWidth, 
    required this.headerHeight, 
    required this.nodeHeight, 
    required this.verticalGap
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;
    final double levelBlockHeight = headerHeight + (2 * nodeHeight) + (3 * verticalGap);
    
    final paintCompleted = Paint()
      ..color = const Color(0xFF2D6A2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
      
    final paintLocked = Paint()
      ..color = const Color(0xFF2D6A2D).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < steps.length - 1; i++) {
      final stepPrev = steps[i];
      final stepCurr = steps[i + 1];
      
      final bool isFirstStepInLevelPrev = i % 2 == 0;
      double yPrev = ((stepPrev.level - 1) * levelBlockHeight) + 50 + headerHeight + verticalGap + (isFirstStepInLevelPrev ? 0 : (nodeHeight + verticalGap)) + 65;
      double xPrev = screenWidth / 2 + 100 * math.sin(i * 1.8);
      
      final bool isFirstStepInLevelCurr = (i + 1) % 2 == 0;
      double yCurr = ((stepCurr.level - 1) * levelBlockHeight) + 50 + headerHeight + verticalGap + (isFirstStepInLevelCurr ? 0 : (nodeHeight + verticalGap)) + 65;
      double xCurr = screenWidth / 2 + 100 * math.sin((i + 1) * 1.8);

      final path = Path();
      path.moveTo(xPrev, yPrev);
      
      double currentGap = (stepCurr.level > stepPrev.level) ? (verticalGap * 2 + headerHeight) : (verticalGap + nodeHeight);
      path.cubicTo(xPrev, yPrev + currentGap * 0.5, xCurr, yCurr - currentGap * 0.5, xCurr, yCurr);

      if (userPoints >= stepCurr.xpRequired) {
        // Segment entièrement complété
        canvas.drawPath(path, paintCompleted);
      } else if (userPoints <= stepPrev.xpRequired) {
        // Segment entièrement verrouillé
        _drawDashedPath(canvas, path, paintLocked);
      } else {
        // Segment en cours de progression (partiel)
        double progress = (userPoints - stepPrev.xpRequired) / (stepCurr.xpRequired - stepPrev.xpRequired);
        progress = progress.clamp(0.0, 1.0);
        
        final metrics = path.computeMetrics();
        for (final metric in metrics) {
          final double solidLength = metric.length * progress;
          
          // Dessiner la partie solide (XP acquis)
          final solidPath = metric.extractPath(0, solidLength);
          canvas.drawPath(solidPath, paintCompleted);
          
          // Dessiner la partie en pointillés (XP restant)
          final remainingPath = metric.extractPath(solidLength, metric.length);
          _drawDashedPath(canvas, remainingPath, paintLocked);
        }
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 12.0;
    const double dashSpace = 10.0;
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
  bool shouldRepaint(covariant SerpentinePathPainter oldDelegate) => userPoints != oldDelegate.userPoints;
}
