import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_event.dart';
import '../blocs/notification/notification_state.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../navigation/battle_invite_navigation.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Charger les notifications dès le démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = context.read<UserBloc>().state;
      String userId = 'guest';
      if (userState is UserLoaded) {
        userId = userState.profile['uuid'] ?? 'guest';
      }
      context.read<NotificationBloc>().add(LoadNotifications(userId));
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _mapNotification(Map<String, dynamic> sqNotification) {
    final type = sqNotification['type'] ?? 'review';
    IconData icon;
    Color color;

    switch (type) {
      case 'review':
        icon = Icons.menu_book_rounded;
        color = const Color(0xFF2D6A2D);
        break;
      case 'badge':
        icon = Icons.emoji_events_rounded;
        color = const Color(0xFF854F0B);
        break;
      case 'leaderboard':
        icon = Icons.trending_up_rounded;
        color = const Color(0xFF185FA5);
        break;
      case 'social':
        icon = Icons.share_rounded;
        color = const Color(0xFFBE123C);
        break;
      case 'battle':
      case 'challenge':
        icon = Icons.sports_kabaddi_rounded;
        color = const Color(0xFF4F46E5);
        break;
      default:
        icon = Icons.notifications_rounded;
        color = const Color(0xFF2D6A2D);
    }

    String timeStr = 'Récemment';
    try {
      final createdAt = DateTime.parse(sqNotification['created_at']);
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) {
        timeStr = 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        timeStr = 'Il y a ${diff.inHours} heures';
      } else {
        timeStr = 'Hier';
      }
    } catch (_) {}

    return {
      'id': sqNotification['id'],
      'type': type,
      'title': sqNotification['title'] ?? '',
      'message': sqNotification['message'] ?? '',
      'time': timeStr,
      'isRead': sqNotification['is_read'] == 1,
      'icon': icon,
      'color': color,
      'battleId': parseBattleIdFromNotification(sqNotification),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocListener<UserBloc, UserState>(
        listener: (context, userState) {
          if (userState is UserLoaded) {
            final userId = userState.profile['uuid'] ?? 'guest';
            context.read<NotificationBloc>().add(LoadNotifications(userId));
          }
        },
        child: Stack(
          children: [
            // Arrière-plan avec filigranes animés
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AfricanWatermarkPainter(progress: _animationController.value),
                  );
                },
              ),
            ),
  
            // Contenu principal
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<NotificationBloc, NotificationState>(
                    builder: (context, state) {
                      final notifications = state is NotificationLoaded ? state.notifications : [];
                      final hasUnread = notifications.any((n) => n['is_read'] == 0);
                      return _buildHeader(context, hasUnread);
                    },
                  ),
                  Expanded(
                    child: BlocBuilder<NotificationBloc, NotificationState>(
                      builder: (context, state) {
                        if (state is NotificationLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (state is NotificationError) {
                          return Center(child: Text(state.message));
                        }
                        if (state is NotificationLoaded) {
                          final list = state.notifications;
                          if (list.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildNotificationList(list);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
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

  Widget _buildHeader(BuildContext context, bool hasUnread) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A4D2E)),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Notifications',
                style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A4D2E),
                ),
              ),
            ],
          ),
          if (hasUnread)
            TextButton(
              onPressed: () {
                final userState = context.read<UserBloc>().state;
                if (userState is UserLoaded) {
                  final userId = userState.profile['uuid'] ?? 'guest';
                  context.read<NotificationBloc>().add(MarkAllNotificationsAsRead(userId));
                }
              },
              child: Text(
                'Tout lire',
                style: GoogleFonts.fredoka(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> rawNotifications) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: rawNotifications.length,
      itemBuilder: (context, index) {
        final mapped = _mapNotification(rawNotifications[index]);
        return _buildNotificationItem(mapped);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'];

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          final userState = context.read<UserBloc>().state;
          if (userState is UserLoaded) {
            final userId = userState.profile['uuid'] ?? 'guest';
            context.read<NotificationBloc>().add(MarkSingleNotificationAsRead(
              notificationId: notification['id'],
              userId: userId,
            ));
          }
        }
        final battleId = notification['battleId'] as String?;
        if (battleId != null) {
          await openBattleInviteSheet(battleId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white.withValues(alpha: 0.7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? const Color(0xFFF0EBE0) : AppColors.primary.withValues(alpha: 0.1),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (!isRead)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE24B4A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(notification['icon'], color: notification['color'], size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'],
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'],
                          style: GoogleFonts.fredoka(
                            fontSize: 13,
                            color: const Color(0xFF666666),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notification['time'],
                          style: GoogleFonts.fredoka(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFAAAAAA),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F7F0),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'Tout est calme ici',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A4D2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reviens plus tard pour tes rappels.',
            style: GoogleFonts.fredoka(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class AfricanWatermarkPainter extends CustomPainter {
  final double progress;
  AfricanWatermarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double w = size.width;
    final double h = size.height;

    double offset = math.sin(progress * 2 * math.pi) * 15;

    _drawAdinkraGyeNyame(canvas, paint, w * 0.15, h * 0.15 + offset, 40);
    _drawAdinkraGyeNyame(canvas, paint, w * 0.85, h * 0.8 + offset, 60);
    _drawPattern(canvas, paint, w * 0.1, h * 0.5 - offset, 30);
    _drawPattern(canvas, paint, w * 0.8, h * 0.3 - offset, 25);
  }

  void _drawAdinkraGyeNyame(Canvas canvas, Paint paint, double x, double y, double size) {
    final path = Path();
    path.moveTo(x, y - size);
    path.quadraticBezierTo(x + size, y, x, y + size);
    path.quadraticBezierTo(x - size, y, x, y - size);
    path.moveTo(x - size * 0.5, y);
    path.lineTo(x + size * 0.5, y);
    canvas.drawPath(path, paint);
  }

  void _drawPattern(Canvas canvas, Paint paint, double x, double y, double size) {
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x + i * 10, y + i * 10), width: size, height: size),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
