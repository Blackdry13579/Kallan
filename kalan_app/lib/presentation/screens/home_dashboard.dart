import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/utils/level_utils.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import 'home_screen.dart';
import 'flashcard_study_screen.dart';
import 'badges_screen.dart';
import 'notification_screen.dart';
import 'roadmap_screen.dart';
import 'create_deck_screen.dart';
import 'battle_lobby_screen.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_state.dart';

class HomeDashboard extends StatelessWidget {
  final VoidCallback? onCreateTap;
  const HomeDashboard({super.key, this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            if (state is UserLoading) return const Center(child: CircularProgressIndicator());
            if (state is UserError) return Center(child: Text(state.message));
            if (state is UserLoaded) {
              final profile = state.profile;
              final stats = state.stats;
              final points = profile['points'] as int? ?? 0;
              final levelInfo = LevelUtils.getLevelInfo(points);
              final recentDecks = (stats['recentDecks'] as List<dynamic>?) ?? [];

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, profile, points),
                      const SizedBox(height: 18),
                      _buildLevelBanner(context, levelInfo, points),
                      const SizedBox(height: 20),
                      _buildActionGrid(context),
                      const SizedBox(height: 20),
                      _buildBattleBanner(context),
                      const SizedBox(height: 20),
                      _buildRecentActivitySection(context, recentDecks),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, Map<String, dynamic> profile, int points) {
    final avatarId = profile['avatar_id'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Avatar circulaire avec étoile niveau
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4CAF50), width: 2.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: ClipOval(
                  child: Image.asset(
                    avatarId != null ? 'assets/avatars/avatar$avatarId.png' : 'assets/avatars/avatar1.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Color(0xFF4CAF50), size: 30),
                  ),
                ),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(color: Color(0xFFE8C87A), shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Compteur XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/bottom/etoile3d.png', height: 16,
                  errorBuilder: (_, __, ___) => const Text('⭐', style: TextStyle(fontSize: 14))),
                const SizedBox(width: 4),
                Text(
                  NumberFormat('#,###').format(points).replaceAll(',', ' '),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFD4A017)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cloche notifications
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, notifState) {
              final unreadCount = notifState is NotificationLoaded
                  ? notifState.notifications.where((n) => n['is_read'] == 0).length
                  : 0;
              return GestureDetector(
                onTap: () => _push(context, const NotificationScreen()),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.notifications_none_rounded, size: 22, color: Color(0xFF1A1A1A)),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -3, right: -3,
                        child: Container(
                          width: 19, height: 19,
                          decoration: const BoxDecoration(color: Color(0xFFE24B4A), shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── BANNIÈRE NIVEAU (même hauteur que profil = 110px) ───────────────────────
  Widget _buildLevelBanner(BuildContext context, LevelInfo levelInfo, int points) {
    final (levelColors, mascotImg) = _getLevelAssets(levelInfo.level);
    final progress = (levelInfo.nextLevelPoints > 0)
        ? (points / levelInfo.nextLevelPoints).clamp(0.0, 1.0)
        : 1.0;

    return GestureDetector(
      onTap: () => _push(context, const RoadmapScreen()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fond de bannière en bois
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SizedBox(
                  height: 112,
                  child: Stack(
                    children: [
                      // Image de fond en bois
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icons/baniere_dashboard.png',
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4A96A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Contenu texte par-dessus l'image
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 110, 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STATUT ACTUEL',
                              style: TextStyle(color: Color(0xFF5A7A3A), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              levelInfo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF3B2E1A), fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF5A7A3A), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🌱', style: TextStyle(fontSize: 9)),
                                      const SizedBox(width: 3),
                                      Text('Niveau ${levelInfo.level}', style: const TextStyle(color: Color(0xFF3B5E20), fontSize: 9, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Color(0xFF6B4E2A), fontSize: 9, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFBFA07A),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5A7A3A)),
                                minHeight: 5,
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Mascot flottant au-dessus de la bannière
              Positioned(
                right: 6,
                bottom: 0,
                child: Image.asset(
                  'assets/roadmap/$mascotImg',
                  height: 126,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (List<Color>, String) _getLevelAssets(int level) {
    return switch (level) {
      2 => (const [Color(0xFF1B5E20), Color(0xFF2E7D32)], 'mascot-2.png'),
      3 => (const [Color(0xFFBF360C), Color(0xFFD84315)], 'mascot-3.png'),
      4 => (const [Color(0xFF4A148C), Color(0xFF7B1FA2)], 'mascot-4.png'),
      5 => (const [Color(0xFF004D40), Color(0xFF00796B)], 'mascot-5.png'),
      6 => (const [Color(0xFF7B4700), Color(0xFFBF8000)], 'mascot-6.png'),
      _ => (const [Color(0xFF2E7D32), Color(0xFF43A047)], 'mascot-1.png'),
    };
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  // ── GRILLE D'ACTIONS ────────────────────────────────────────────────────────
  Widget _buildActionGrid(BuildContext context) {
    final blocks = [
      ('assets/icons/flashcard_block.png', onCreateTap ?? () => _push(context, const CreateDeckScreen())),
      ('assets/icons/parcour_block.png',   () => _push(context, const RoadmapScreen())),
      ('assets/icons/badges_block.png',    () => _push(context, const BadgesScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: blocks[i].$2,
                child: Image.asset(
                  blocks[i].$1,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── BANNIÈRE DÉFI (trophée + texte, sans barre XP) ──────────────────────────
  Widget _buildBattleBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _push(context, const BattleLobbyScreen()),
        child: Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/bottom/eper.png',
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 72),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Défie tes amis ! 🔥',
                      maxLines: 1,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lance un duel,\ngagne des XP ⚡',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Jouer',
                  style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACTIVITÉS RÉCENTES ───────────────────────────────────────────────────────
  Widget _buildRecentActivitySection(BuildContext context, List<dynamic> recentDecks) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activités récentes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => HomeScreen.of(context)?.changeTab(1),
                child: const Text('Voir tout', style: TextStyle(fontSize: 11, color: Color(0xFF2D5C14), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentDecks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucune activité récente', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 0.5),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentDecks.length.clamp(0, 4),
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withValues(alpha: 0.04)),
                itemBuilder: (context, index) {
                  final deck = recentDecks[index];
                  final subject = deck['subject'] as String? ?? 'Général';
                  final xpGained = deck['xp_gained'] as int?;
                  final dateStr = deck['created_at'] as String? ?? DateTime.now().toIso8601String();
                  final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                  final color = _subjectColor(subject);

                  return ListTile(
                    onTap: () => _push(context, FlashcardStudyScreen(deckTitle: deck['title'], deckUuid: deck['uuid'])),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.book_rounded, size: 20, color: color),
                    ),
                    title: Text(
                      deck['title'] as String? ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                    subtitle: Text(_formatDate(date), style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                    trailing: (xpGained != null && xpGained > 0)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+$xpGained XP',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2D6A2D)),
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCCCCCC)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _subjectColor(String subject) {
    return switch (subject.toLowerCase()) {
      'mathématiques' || 'maths' => const Color(0xFF185FA5),
      'svt' => const Color(0xFF2D6A2D),
      'physique-chimie' => const Color(0xFF6A2D9F),
      'anglais' => const Color(0xFFE07B39),
      'français' => const Color(0xFFB00020),
      'histoire-géo' => const Color(0xFF854F0B),
      _ => const Color(0xFF2196F3),
    };
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    return '${diff.inDays} jours';
  }
}


