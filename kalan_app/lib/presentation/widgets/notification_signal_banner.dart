import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalan_app/core/constants/app_colors.dart';
import 'package:kalan_app/services/audio_service.dart';
import 'package:kalan_app/services/notification_signal_service.dart';

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
  NotificationSignal? _signal;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationSignalService.instance.stream.listen(_show);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _show(NotificationSignal signal) {
    if (!mounted) return;

    setState(() {
      _signal = signal;
      _visible = true;
    });

    AudioService().play('notification');

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    final signal = _signal;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedPositioned(
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
                      onClose: _hide,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final NotificationSignal signal;
  final VoidCallback onClose;

  const _BannerCard({
    required this.signal,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(signal.type);
    final icon = _iconForType(signal.type);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
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
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF777777),
                tooltip: 'Fermer',
              ),
            ],
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
