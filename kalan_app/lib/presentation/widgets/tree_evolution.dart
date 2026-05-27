import 'package:flutter/material.dart';

class TreeEvolution extends StatelessWidget {
  final int stage;
  final double size;

  const TreeEvolution({
    super.key,
    required this.stage,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final safeStage = stage.clamp(1, 6);

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          'assets/roadmap/level-$safeStage-${_assetSlug(safeStage)}.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/icons/badges_niveau/level$safeStage.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => CustomPaint(
              painter: _TreePainter(stage: safeStage),
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
}

class _TreePainter extends CustomPainter {
  final int stage;

  _TreePainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()..color = const Color(0xFFEAF3DE);
    canvas.drawCircle(center, radius, bgPaint);

    final trunkPaint = Paint()..color = const Color(0xFF854F0B);
    final leafPaint = Paint()..color = const Color(0xFF2D6A2D);
    final darkLeafPaint = Paint()..color = const Color(0xFF1E4D1E);
    final firePaint = Paint()..color = const Color(0xFFFF5722);
    final goldPaint = Paint()..color = const Color(0xFFFFD700);
    final whitePaint = Paint()..color = Colors.white;
    final orangePaint = Paint()..color = Colors.orange;

    switch (stage) {
      case 1: // Graine
        canvas.drawCircle(Offset(center.dx, center.dy + 5), 3, trunkPaint);
        break;
      case 2: // Baobab
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(center.dx - 10, center.dy + 2, 20, 20),
                const Radius.circular(4)),
            trunkPaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 15, center.dy - 18, 30, 24), leafPaint);
        break;
      case 3: // Feu de Brousse
        canvas.drawRect(
            Rect.fromLTWH(center.dx - 3, center.dy + 5, 6, 12), trunkPaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 15, center.dy - 15, 30, 26), firePaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 10, center.dy - 10, 20, 18), orangePaint);
        break;
      case 4: // Griot
        canvas.drawRect(
            Rect.fromLTWH(center.dx - 3, center.dy + 5, 6, 12), trunkPaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 18, center.dy - 18, 36, 30), leafPaint);
        canvas.drawCircle(Offset(center.dx - 10, center.dy - 5), 2, goldPaint);
        canvas.drawCircle(Offset(center.dx + 10, center.dy - 10), 2, goldPaint);
        break;
      case 5: // Masque
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(center.dx - 4, center.dy + 5, 8, 15),
                const Radius.circular(2)),
            trunkPaint);
        canvas.drawOval(Rect.fromLTWH(center.dx - 22, center.dy - 22, 44, 38),
            darkLeafPaint);
        canvas.drawCircle(
            Offset(center.dx - 2, center.dy + 10), 1.5, whitePaint);
        canvas.drawCircle(
            Offset(center.dx + 2, center.dy + 10), 1.5, whitePaint);
        break;
      case 6: // Ancêtre
      default:
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(center, radius - 5, glowPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(center.dx - 5, center.dy + 5, 10, 15),
                const Radius.circular(3)),
            trunkPaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 25, center.dy - 25, 50, 42), goldPaint);
        canvas.drawOval(
            Rect.fromLTWH(center.dx - 15, center.dy - 15, 30, 25), whitePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
