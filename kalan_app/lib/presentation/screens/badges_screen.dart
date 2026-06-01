import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/level_utils.dart';
import '../widgets/tree_evolution.dart';
import '../blocs/badge/badge_bloc.dart';
import '../blocs/badge/badge_event.dart';
import '../blocs/badge/badge_state.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); 
    });
    context.read<BadgeBloc>().add(LoadBadges());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fond beige crème conforme au HTML
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mes badges',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocBuilder<BadgeBloc, BadgeState>(
        builder: (context, state) {
          if (state is BadgeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BadgeLoaded) {
            final unlockedKeys = state.unlockedBadges.map((b) => b.badgeKey).toSet();

            // Sort: earned first, then locked
            final allSorted = List<Map<String, dynamic>>.from(state.allBadges)
              ..sort((a, b) {
                bool aUnlocked = unlockedKeys.contains(a['id']);
                bool bUnlocked = unlockedKeys.contains(b['id']);
                if (aUnlocked && !bUnlocked) return -1;
                if (!aUnlocked && bUnlocked) return 1;
                return 0;
              });

            // Filter based on active tab: 0=Tous, 1=Obtenus, 2=À débloquer
            final filteredBadges = switch (_tabController.index) {
              1 => allSorted.where((b) => unlockedKeys.contains(b['id'])).toList(),
              2 => allSorted.where((b) => !unlockedKeys.contains(b['id'])).toList(),
              _ => allSorted,
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsHeader(context, unlockedKeys.length, state.allBadges.length),
                _buildTabs(),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredBadges.isEmpty
                      ? _buildEmptyState()
                      : _buildBadgesGrid(filteredBadges, unlockedKeys),
                ),
              ],
            );
          }
          
          if (state is BadgeError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, int obtained, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Badges obtenus
            Expanded(
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    '$obtained',
                    style: const TextStyle(
                      color: Color(0xFF2D6A2D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Badges obtenus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // À débloquer
            Expanded(
              child: Column(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    '${total - obtained}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'À débloquer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Points XP
            Expanded(
              child: BlocBuilder<UserBloc, UserState>(
                builder: (context, userState) {
                  int points = 0;
                  int stage = 1;
                  if (userState is UserLoaded) {
                    points = userState.profile['points'] as int? ?? 0;
                    stage = LevelUtils.getLevelInfo(points).level;
                  }
                  return Column(
                    children: [
                      TreeEvolution(stage: stage, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Points XP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: List.generate(3, (index) {
            final labels = ['Tous', 'Obtenus', 'À débloquer'];
            final isActive = _tabController.index == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _tabController.index = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: isActive ? const Color(0xFF2D6A2D) : Colors.grey.shade500,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBadgesGrid(List<Map<String, dynamic>> badges, Set<String> unlockedKeys) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isUnlocked = unlockedKeys.contains(badge['id']);
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUnlocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/badges/${badge['image_path']}',
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                      child: Center(
                        child: Text(badge['emoji'] ?? '🏅', style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 22)),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                badge['label'] ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Aucun badge disponible',
        style: TextStyle(
          color: Color(0xFF666666),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


