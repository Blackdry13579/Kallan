import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/leaderboard/leaderboard_bloc.dart';
import '../blocs/leaderboard/leaderboard_event.dart';
import '../blocs/leaderboard/leaderboard_state.dart';
import '../../core/utils/level_utils.dart';
import '../../data/remote/supabase_service.dart';
import '../../services/connectivity_service.dart';
import 'roadmap_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _currentScope = 'national';
  bool _isOnline = true;
  bool _checkingConnection = false;

  ImageProvider _getAvatarImage(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return const AssetImage('assets/avatars/avatar1.png');
    }
    final intValue = int.tryParse(avatar);
    if (intValue != null) {
      return AssetImage('assets/avatars/avatar$intValue.png');
    }
    if (avatar.startsWith('assets/')) {
      return AssetImage(avatar);
    }
    return NetworkImage(avatar);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnectionAndRefresh());
  }

  // La connexion est gérée par le Bloc et le Repository, 
  // on garde une version simplifiée pour l'affichage du mode offline initial.
  Future<void> _checkConnectionAndRefresh() async {
    setState(() => _checkingConnection = true);
    final online = await ConnectivityService().isOnline();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
      _checkingConnection = false;
    });
    if (online) {
      context.read<LeaderboardBloc>().add(LoadLeaderboard(scope: _currentScope));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        title: const Text('Classement', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2D5C14))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
            icon: const Icon(Icons.map_rounded, color: Color(0xFF2D5C14)),
            tooltip: 'Mon Parcours',
          ),
        ],
      ),
      body: _checkingConnection
          ? const Center(child: CircularProgressIndicator())
          : !_isOnline
              ? _buildOfflineWidget()
              : BlocBuilder<LeaderboardBloc, LeaderboardState>(
                  builder: (context, state) {
                    if (state is LeaderboardLoading || state is LeaderboardInitial) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is LeaderboardError) {
                      return _buildErrorWidget(state.message);
                    }
                    if (state is LeaderboardLoaded) {
                      if (state.entries.isEmpty) {
                        return _buildEmptyWidget();
                      }

                      final topThree = state.entries.take(3).toList();
                      final remaining = state.entries.skip(3).take(7).toList();

                      return RefreshIndicator(
                        onRefresh: _checkConnectionAndRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              _buildTabs(),
                              _buildTopThree(topThree),
                              const SizedBox(height: 14),
                              _buildCompactList(remaining),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 56, color: Color(0xFF2D5C14)),
            const SizedBox(height: 16),
            const Text(
              'Le classement se remplit…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2A1A08)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Joue des quiz et gagne des XP pour apparaître ici avec les autres élèves.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkConnectionAndRefresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Actualiser', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5C14),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkConnectionAndRefresh,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5C14).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFF2D5C14),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connexion internet requise',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2A1A08),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pour afficher ton rang et le classement des 10 meilleurs élèves en temps réel sur Supabase, tu dois être connecté à Internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _checkConnectionAndRefresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5C14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  shadowColor: const Color(0xFF2D5C14).withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _tabItem('Semaine', 'weekly'),
          _tabItem('National', 'national'),
          _tabItem('Amis', 'friends'),
        ],
      ),
    );
  }

  Widget _tabItem(String label, String scope) {
    final active = _currentScope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentScope = scope);
          context.read<LeaderboardBloc>().add(LoadLeaderboard(scope: scope));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: active ? const Color(0xFFD97706) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopThree(List<dynamic> topThree) {
    // estrade.png : 1649 × 954 px → ratio W/H ≈ 1.73
    const double kRatio = 1.73;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final imgH = w / kRatio;      // hauteur rendue de l'image
          final totalH = imgH + 120.0;  // espace pour les avatars au-dessus

          return SizedBox(
            height: totalH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Image de l'estrade en bas
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Image.asset(
                    'assets/icons/bottom/estrade.png',
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => SizedBox(height: imgH),
                  ),
                ),
                // 2e place — marche gauche
                if (topThree.length >= 2)
                  Positioned(
                    bottom: imgH * 0.70,
                    left: 0,
                    width: w * 0.33,
                    child: Center(child: _podiumUser(topThree[1], 2, 52)),
                  ),
                // 1re place — marche centrale (la plus haute)
                if (topThree.isNotEmpty)
                  Positioned(
                    bottom: imgH * 0.80,
                    left: w * 0.33,
                    width: w * 0.34,
                    child: Center(child: _podiumUser(topThree[0], 1, 66, isFirst: true)),
                  ),
                // 3e place — marche droite
                if (topThree.length >= 3)
                  Positioned(
                    bottom: imgH * 0.58,
                    left: w * 0.67,
                    width: w * 0.33,
                    child: Center(child: _podiumUser(topThree[2], 3, 52)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _podiumUser(dynamic entry, int rank, double size, {bool isFirst = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst) const Text('👑', style: TextStyle(fontSize: 20)),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: rank == 1 ? const Color(0xFFF5C842) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
              width: 3,
            ),
          ),
          child: ClipOval(child: Image(image: _getAvatarImage(entry.avatar), fit: BoxFit.cover)),
        ),
        const SizedBox(height: 4),
        Text(
          entry.pseudo,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
        Text('${entry.points} XP',
          style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700, fontSize: 10)),
      ],
    );
  }

  Widget _buildCompactList(List<dynamic> remaining) {
    final currentUserId = SupabaseService.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10, right: 10, bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 30, child: Text('RANG', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800))),
                Expanded(child: Text('UTILISATEUR', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800))),
                Text('POINTS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final entry = remaining[index];
                final rank = index + 4;
                final isMe = entry.userId == currentUserId;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  color: isMe ? const Color(0xFFFEF3C7) : Colors.transparent,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? const Color(0xFFD97706) : Colors.grey, fontSize: 13)),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMe ? const Color(0xFFD97706) : Colors.transparent, width: 1.5)),
                        child: ClipOval(child: Image(image: _getAvatarImage(entry.avatar), fit: BoxFit.cover)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.pseudo + (isMe ? ' (Toi)' : ''),
                              style: TextStyle(fontWeight: FontWeight.w700, color: isMe ? const Color(0xFFD97706) : const Color(0xFF2A1A08), fontSize: 13),
                            ),
                            Text(
                              'Niv. ${LevelUtils.getLevelInfo(entry.points).level}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Text('${entry.points} XP', style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? const Color(0xFFD97706) : const Color(0xFFB45309), fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class MarqueeTicker extends StatefulWidget {
  final String text;
  const MarqueeTicker({super.key, required this.text});

  @override
  State<MarqueeTicker> createState() => _MarqueeTickerState();
}

class _MarqueeTickerState extends State<MarqueeTicker> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final duration = Duration(milliseconds: (maxScrollExtent * 30).toInt());

    _scrollController.animateTo(
      maxScrollExtent,
      duration: duration,
      curve: Curves.linear,
    ).then((_) {
      if (mounted) {
        _scrollController.jumpTo(0);
        _startScrolling();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF2D5C14),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF2D5C14).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SizedBox(width: 375), // Initial delay space
          Center(
            child: Text(
              widget.text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 375), // End delay space
        ],
      ),
    );
  }
}
