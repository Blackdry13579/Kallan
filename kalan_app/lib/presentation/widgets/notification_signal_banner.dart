import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalan_app/core/constants/app_colors.dart';
import 'package:kalan_app/core/navigation/app_navigator_key.dart';
import 'package:kalan_app/services/audio_service.dart';
import 'package:kalan_app/presentation/navigation/battle_invite_navigation.dart';
import 'package:kalan_app/services/notification_signal_service.dart';

/// Écoute les signaux et les affiche via l'[Overlay] du [Navigator]
/// (évite l'erreur « No Overlay widget found » du builder MaterialApp).
class NotificationSignalBanner extends StatefulWidget {
  final Widget child;

  const NotificationSignalBanner({
    super.key,
    required this.child,
  });

  @override
  State<NotificationSignalBanner> createState() =>
      _NotificationSignalBannerState();
}

class _NotificationSignalBannerState extends State<NotificationSignalBanner> {
  StreamSubscription<NotificationSignal>? _subscription;
  Timer? _hideTimer;
  OverlayEntry? _overlayEntry;
  NotificationSignal? _signal;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationSignalService.instance.stream.listen(_show);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOverlayEntry());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _ensureOverlayEntry() {
    if (_overlayEntry != null) return;
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(builder: _buildOverlayBanner);
    overlay.insert(_overlayEntry!);
  }

  void _show(NotificationSignal signal) {
    _ensureOverlayEntry();
    if (_overlayEntry == null) return;

    setState(() {
      _signal = signal;
      _visible = true;
    });
    _overlayEntry!.markNeedsBuild();

    AudioService().play('notification');

    _hideTimer?.cancel();
    final isBattle = signal.type == 'battle' && signal.battleId != null;
    _hideTimer = Timer(
      Duration(seconds: isBattle ? 12 : 4),
      _hide,
    );
  }

  Future<void> _onBannerTap(NotificationSignal signal) async {
    if (signal.type == 'battle' && signal.battleId != null) {
      _hideTimer?.cancel();
      _hide();
      await openBattleInviteSheet(signal.battleId!);
      return;
    }
    _hide();
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _visible = false);
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildOverlayBanner(BuildContext context) {
    final signal = _signal;
    final topPadding = MediaQuery.paddingOf(context).top;

    return IgnorePointer(
      ignoring: !_visible,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            top: _visible ? topPadding + 10 : -120,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _visible ? 1 : 0,
              child: signal == null
                  ? const SizedBox.shrink()
                  : _BannerCard(
                      signal: signal,
                      onTap: () => _onBannerTap(signal),
                      onClose: _hide,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerCard extends StatelessWidget {
  final NotificationSignal signal;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _BannerCard({
    required this.signal,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(signal.type);
    final icon = _iconForType(signal.type);

    final tappable = signal.type == 'battle' && signal.battleId != null;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: tappable ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF151515),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (signal.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        signal.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5A5A5A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (tappable) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Appuie pour accepter ou refuser',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF777777),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'badge':
        return const Color(0xFFE8A317);
      case 'challenge':
      case 'battle':
        return const Color(0xFF4F46E5);
      case 'level':
        return const Color(0xFFBE560E);
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'badge':
        return Icons.emoji_events_rounded;
      case 'challenge':
      case 'battle':
        return Icons.sports_kabaddi_rounded;
      case 'level':
        return Icons.trending_up_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
