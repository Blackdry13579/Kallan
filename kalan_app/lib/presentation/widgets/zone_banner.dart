import 'package:flutter/material.dart';

class ZoneBanner extends StatelessWidget {
  final String title;
  final String levelSubtitle;
  final Color color;
  final Color bgColor;

  const ZoneBanner({
    super.key,
    required this.title,
    required this.levelSubtitle,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$levelSubtitle : $title',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
