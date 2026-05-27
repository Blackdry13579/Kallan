import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/audio_service.dart';
import '../../services/celebration_coordinator.dart';
import 'confetti_widget.dart';

class BadgeUnlockPopup {
  static void show(
    BuildContext context, {
    required String label,
    required String emoji,
    String? imagePath,
    required int color,
    String? reason,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'badge_popup',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) {
        AudioService().play('badge_unlock');
        return _BadgePopupContent(
          label: label,
          emoji: emoji,
          imagePath: imagePath,
          color: Color(color),
          reason: reason,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.35),
                ),
                child: const ConfettiWidget(),
              ),
            ),
            ScaleTransition(
              scale: Tween<double>(begin: 0.4, end: 1.0).animate(curved),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.4),
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgePopupContent extends StatefulWidget {
  final String label;
  final String emoji;
  final String? imagePath;
  final Color color;
  final String? reason;

  const _BadgePopupContent({
    required this.label,
    required this.emoji,
    required this.color,
    this.imagePath,
    this.reason,
  });

  @override
  State<_BadgePopupContent> createState() => _BadgePopupContentState();
}

class _BadgePopupContentState extends State<_BadgePopupContent>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _sparkleController;
  late final AnimationController _entryController;

  // Entry animations (staggered)
  late final Animation<double> _badgeScale;
  late final Animation<double> _labelFade;
  late final Animation<Offset> _labelSlide;
  late final Animation<double> _reasonFade;
  late final Animation<Offset> _reasonSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _badgeScale = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );
    _labelFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
    );
    _labelSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
    ));
    _reasonFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
    );
    _reasonSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
    ));
    _buttonFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sparkleController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Color get _accentColor => widget.color;
  Color get _accentLight => Color.lerp(widget.color, Colors.white, 0.85)!;
  Color get _accentMid => Color.lerp(widget.color, Colors.white, 0.5)!;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 340, maxHeight: maxHeight),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.26),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBadge(),
                            const SizedBox(height: 14),
                            _buildLabel(),
                            const SizedBox(height: 12),
                            if (widget.reason != null &&
                                widget.reason!.isNotEmpty)
                              _buildReasonCard(),
                            if (widget.reason == null || widget.reason!.isEmpty)
                              _buildDefaultDescription(),
                            const SizedBox(height: 18),
                            _buildButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor,
            Color.lerp(_accentColor, const Color(0xFF1B5E20), 0.6)!,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            'Badge débloqué !',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Text('✨', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return ScaleTransition(
      scale: _badgeScale,
      child: SizedBox(
        width: 124,
        height: 124,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _sparkleController]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing rings
                CustomPaint(
                  size: const Size(124, 124),
                  painter: _PulsingRingPainter(
                    animation: _pulseController.value,
                    color: _accentColor,
                  ),
                ),
                // Sparkles orbiting
                CustomPaint(
                  size: const Size(124, 124),
                  painter: _SparklesPainter(
                    animation: _sparkleController.value,
                    color: const Color(0xFFFAC775),
                  ),
                ),
                // Badge circle
                child!,
              ],
            );
          },
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_accentLight, _accentMid],
              ),
              border: Border.all(color: _accentColor, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: widget.imagePath != null
                  ? Image.asset(
                      'assets/badges/${widget.imagePath}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 42),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return SlideTransition(
      position: _labelSlide,
      child: FadeTransition(
        opacity: _labelFade,
        child: Column(
          children: [
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFAC775).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFAC775).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '🏆  Nouveau trophée',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B6508),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonCard() {
    return SlideTransition(
      position: _reasonSlide,
      child: FadeTransition(
        opacity: _reasonFade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: _accentColor, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Pourquoi ce badge ?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _accentColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444444),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultDescription() {
    return SlideTransition(
      position: _reasonSlide,
      child: FadeTransition(
        opacity: _reasonFade,
        child: Text(
          'Félicitations pour ta progression ! Continue comme ça.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF777777),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return SlideTransition(
      position: _buttonSlide,
      child: FadeTransition(
        opacity: _buttonFade,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor,
                  Color.lerp(_accentColor, const Color(0xFF1B5E20), 0.55)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                CelebrationCoordinator.dismiss();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Super ! 🎉',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Painters
// ──────────────────────────────────────────────────────

class _PulsingRingPainter extends CustomPainter {
  final double animation;
  final Color color;

  _PulsingRingPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 45.0;

    for (int i = 0; i < 3; i++) {
      final delay = i / 3.0;
      final t = ((animation - delay) % 1.0 + 1.0) % 1.0;
      final ringRadius = baseRadius + t * 18.0;
      final opacity = (1.0 - t) * 0.45;

      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PulsingRingPainter old) => old.animation != animation;
}

class _SparklesPainter extends CustomPainter {
  final double animation;
  final Color color;

  _SparklesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const orbitRadius = 52.0;
    const count = 6;

    for (int i = 0; i < count; i++) {
      final baseAngle = (i / count) * 2 * math.pi;
      final angle = baseAngle + animation * 2 * math.pi * 0.18;
      final wave = math.sin(animation * 2 * math.pi + i * math.pi / 3);
      final opacity = ((wave + 1) / 2 * 0.75 + 0.25).clamp(0.0, 1.0);
      final starSize = 4.0 + (wave + 1) / 2 * 3.5;

      final pos = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle),
      );

      _drawStar(canvas, pos, starSize, color.withValues(alpha: opacity));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    const points = 4;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? size : size * 0.38;
      final angle = i * math.pi / points - math.pi / 4;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklesPainter old) => old.animation != animation;
}
