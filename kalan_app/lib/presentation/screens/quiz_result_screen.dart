import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/level_utils.dart';
import '../../services/audio_service.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../widgets/tree_evolution.dart';
import 'quiz_screen.dart';
import 'home_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final int score;
  final int total;
  final String? deckUuid;
  final String? deckTitle;

  const QuizResultScreen({
    super.key,
    required this.score,
    required this.total,
    this.deckUuid,
    this.deckTitle,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _arcController;

  // Staggered entry animations
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _circleFade;
  late final Animation<double> _statsFade;
  late final Animation<Offset> _statsSlide;
  late final Animation<double> _xpScale;
  late final Animation<double> _levelFade;
  late final Animation<Offset> _levelSlide;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  // Score arc animation
  late final Animation<double> _arcProgress;
  late final Animation<double> _counterAnim;

  late final double _percent;
  late final int _earnedPoints;
  late final Color _scoreColor;

  @override
  void initState() {
    super.initState();

    _percent = widget.total > 0 ? widget.score / widget.total : 0.0;
    _earnedPoints = widget.score * 10;

    _scoreColor = _percent >= 0.8
        ? const Color(0xFF2D6A2D)
        : _percent >= 0.5
            ? const Color(0xFFE07B39)
            : const Color(0xFFE24B4A);

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _headerFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    ));

    _circleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
    );

    _statsFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    );
    _statsSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    ));

    _xpScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.5, 0.72, curve: Curves.elasticOut),
    );

    _levelFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.6, 0.82, curve: Curves.easeOut),
    );
    _levelSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.6, 0.82, curve: Curves.easeOut),
    ));

    _buttonsFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
    ));

    _arcProgress = Tween<double>(begin: 0.0, end: _percent).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeInOut),
    );
    _counterAnim = Tween<double>(begin: 0.0, end: _percent * 100).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeInOut),
    );

    // Start animations with slight delay for the arc
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _arcController.forward();
    });

    // Son de fin de quiz : victoire si ≥80%, encouragement sinon
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        AudioService().play(_percent >= 0.8 ? 'quiz_victory' : 'quiz_complete');
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  String get _motivationalMessage {
    if (_percent >= 0.8) return 'Tu maîtrises ce chapitre ! 💪';
    if (_percent >= 0.5) return 'Bon début, continue comme ça ! 👍';
    return 'Continue de t\'entraîner ! 🌱';
  }

  String get _gradeLabel {
    if (_percent >= 0.8) return 'Excellent';
    if (_percent >= 0.5) return 'Bien';
    return 'À revoir';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EA),
      body: Stack(
        children: [
          // Subtle background decorations
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: BlocBuilder<UserBloc, UserState>(
                  builder: (context, state) {
                    int totalPoints = _earnedPoints;
                    bool isLoaded = false;

                    if (state is UserLoaded) {
                      totalPoints = state.profile['points'] as int? ?? 0;
                      isLoaded = true;
                    }

                    final previousPoints = math.max(0, totalPoints - _earnedPoints);
                    final prevLevelInfo = LevelUtils.getLevelInfo(previousPoints);
                    final currentLevelInfo = LevelUtils.getLevelInfo(totalPoints);
                    final leveledUp = prevLevelInfo.level < currentLevelInfo.level;

                    return Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildScoreCircle(),
                        const SizedBox(height: 28),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildXpPill(),
                        const SizedBox(height: 20),
                        if (isLoaded) ...[
                          _buildLevelCard(currentLevelInfo, totalPoints),
                          const SizedBox(height: 16),
                        ],
                        if (leveledUp) ...[
                          _buildLevelUpCard(currentLevelInfo),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 8),
                        _buildButtons(),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Column(
          children: [
            Text(
              widget.deckTitle != null
                  ? 'Quiz — ${widget.deckTitle}'
                  : 'Résultats du Quiz',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bravo !',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111111),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCircle() {
    return FadeTransition(
      opacity: _circleFade,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: Listenable.merge([_arcProgress, _counterAnim]),
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _ScoreArcPainter(
                      progress: _arcProgress.value,
                      color: _scoreColor,
                      strokeWidth: 13,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_counterAnim.value.toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _scoreColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.score} / ${widget.total}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _gradeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return SlideTransition(
      position: _statsSlide,
      child: FadeTransition(
        opacity: _statsFade,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Bonnes réponses',
                    value: '${widget.score}',
                    icon: Icons.check_circle_rounded,
                    bg: const Color(0xFFEAF3DE),
                    textColor: const Color(0xFF2D6A2D),
                    iconColor: const Color(0xFF2D6A2D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Mauvaises réponses',
                    value: '${widget.total - widget.score}',
                    icon: Icons.cancel_rounded,
                    bg: const Color(0xFFFCEBEB),
                    textColor: const Color(0xFFE24B4A),
                    iconColor: const Color(0xFFE24B4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEE8DC)),
              ),
              child: Text(
                _motivationalMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF444444),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpPill() {
    return ScaleTransition(
      scale: _xpScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8DC), Color(0xFFFFF0A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              '+$_earnedPoints XP gagnés',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF8B7500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(LevelInfo info, int totalPoints) {
    final progress =
        ((totalPoints - info.minPoints) / (info.maxPoints - info.minPoints))
            .clamp(0.0, 1.0);

    return SlideTransition(
      position: _levelSlide,
      child: FadeTransition(
        opacity: _levelFade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEE8DC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TreeEvolution(stage: info.level, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${info.icon} ${info.title}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Niv. ${info.level}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFF0EBE0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$totalPoints / ${info.maxPoints} XP',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF888888),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelUpCard(LevelInfo info) {
    return SlideTransition(
      position: _levelSlide,
      child: FadeTransition(
        opacity: _levelFade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7C2), Color(0xFFFFEFA6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(
                'MONTÉE DE NIVEAU !',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8B6508),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu es maintenant ${info.icon} ${info.title} !',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5E491A),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return SlideTransition(
      position: _buttonsSlide,
      child: FadeTransition(
        opacity: _buttonsFade,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'RETOUR À L\'ACCUEIL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    deckUuid: widget.deckUuid,
                    deckTitle: widget.deckTitle ?? 'Quiz',
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Rejouer le Quiz',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Stat card widget
// ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color textColor;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Score arc painter
// ──────────────────────────────────────────────────────

class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _ScoreArcPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Glowing dot at arc tip
    final endAngle = -math.pi / 2 + 2 * math.pi * progress;
    final dotX = center.dx + radius * math.cos(endAngle);
    final dotY = center.dy + radius * math.sin(endAngle);
    final dotCenter = Offset(dotX, dotY);
    final dotRadius = strokeWidth / 2 + 1;

    canvas.drawCircle(
      dotCenter,
      dotRadius + 3,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(dotCenter, dotRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      dotCenter,
      dotRadius - 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter old) =>
      old.progress != progress;
}
