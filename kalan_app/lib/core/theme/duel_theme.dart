import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette partagée pour les écrans de duel (arène, QR, scan, règles).
class DuelTheme {
  DuelTheme._();

  static const Color bg = Color(0xFFF5F2EA);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF1C1C1C);
  static const Color sub = Color(0xFF9CA3AF);
  static const Color primary = Color(0xFF2D6A2D);
  static const Color fire = Color(0xFFEA580C);
  static const Color fireLight = Color(0xFFFFF7ED);
  static const Color gold = Color(0xFFF59E0B);
  static const Color green = Color(0xFF16A34A);
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF6B7280);

  static TextStyle title({double size = 18}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: FontWeight.w900, color: text);

  static TextStyle body({double size = 14, Color? color}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: FontWeight.w600, color: color ?? sub);

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
      );

  static Widget modeBadge({required bool isOnline}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? online.withValues(alpha: 0.12) : offline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOnline ? online : offline, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 14, color: isOnline ? online : offline),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Mode en ligne' : 'Mode local (QR)',
            style: body(size: 11, color: isOnline ? online : offline),
          ),
        ],
      ),
    );
  }
}
