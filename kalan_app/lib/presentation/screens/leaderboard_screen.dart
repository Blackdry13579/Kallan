import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/leaderboard/leaderboard_bloc.dart';
import '../blocs/leaderboard/leaderboard_event.dart';
import '../blocs/leaderboard/leaderboard_state.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../../core/utils/level_utils.dart';
import '../../data/remote/supabase_service.dart';
import '../../services/connectivity_service.dart';
import '../../domain/entities/leaderboard_entry.dart';
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _currentScope = 'national';
  bool _isOnline = true;
  bool _checkingConnection = false;
  int _nationalRank = -1;
  int _myPoints = 0;
  int _myLevel = 0; // 0 = pas encore chargé depuis Supabase
  String? _myAvatar;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionAndRefresh();
      _fetchNationalRank();
    });
  }

  Future<void> _fetchNationalRank() async {
    try {
      // Attendre que la session soit restaurée (nouveau téléphone / cold start)
      String? uid = SupabaseService.currentUser?.id;
      if (uid == null) {
        await Future.delayed(const Duration(seconds: 2));
        uid = SupabaseService.currentUser?.id;
      }
      if (uid == null) return;

      final userRes = await SupabaseService.client
          .from('users')
          .select('points, avatar_id, level')
          .eq('uuid', uid)
          .maybeSingle();

      final myPoints = (userRes?['points'] as num?)?.toInt() ?? 0;
      final myLevel  = (userRes?['level']  as num?)?.toInt() ?? 1;
      final myAvatar = userRes?['avatar_id']?.toString();
      // Nombre d'utilisateurs avec PLUS de points = rang - 1
      final above = await SupabaseService.client
          .from('users')
          .select('uuid')
          .gt('points', myPoints);

      final rank = (above as List).length + 1;
      if (mounted) {
        setState(() {
          _nationalRank = rank;
          _myPoints = myPoints;
          _myLevel  = myLevel;
          _myAvatar = myAvatar;
        });
      }
    } catch (e) {
      debugPrint('[LeaderboardScreen] _fetchNationalRank error: $e');
    }
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Classement', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2D5C14))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
                              _buildMyRankBanner(state),
                              const SizedBox(height: 8),
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
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF2D6A2D) : Colors.grey.shade500,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
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
          style: const TextStyle(color: Color(0xFF7C5C32), fontWeight: FontWeight.w700, fontSize: 10)),
      ],
    );
  }

  String _formatPoints(int points) {
    if (points >= 1000) {
      final k = points / 1000;
      return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)} k';
    }
    return '$points';
  }

  Widget _buildMyRankBanner(LeaderboardLoaded state) {
    // UserBloc comme source principale pour l'uuid (toujours disponible)
    final userBlocState = context.read<UserBloc>().state;
    int blocPoints = 0;
    String? blocAvatar;
    String? blocUuid;
    if (userBlocState is UserLoaded) {
      blocPoints = userBlocState.profile['points'] as int? ?? 0;
      blocAvatar = userBlocState.profile['avatar_id']?.toString();
      blocUuid   = userBlocState.profile['uuid']?.toString();
    }

    // uid : Supabase Auth en priorité, fallback sur UserBloc
    final currentUserId = SupabaseService.currentUser?.id ?? blocUuid;

    int localRank = -1;
    LeaderboardEntry? myEntry;
    for (int i = 0; i < state.entries.length; i++) {
      if (state.entries[i].userId == currentUserId) {
        localRank = i + 1;
        myEntry = state.entries[i];
        break;
      }
    }

    // Rang réel : _nationalRank (requête directe count) en priorité, puis localRank
    final displayRank = _nationalRank > 0
        ? _nationalRank
        : (localRank > 0 ? localRank : (state.entries.isNotEmpty ? state.entries.length + 1 : 1));

    // Points / avatar / niveau : Supabase direct → UserBloc → entry du classement
    final userPoints = _myPoints > 0 ? _myPoints : (blocPoints > 0 ? blocPoints : (myEntry?.points ?? 0));
    final userAvatar = _myAvatar ?? blocAvatar ?? myEntry?.avatar;
    final userLevel  = _myLevel > 0 ? _myLevel : LevelUtils.getLevelInfo(userPoints).level;
    final rankText   = '#$displayRank';

    // Hauteur fixe compacte
    const double H = 116.0;
    const double avatarSize = 44.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final W = constraints.maxWidth;

          return SizedBox(
            width: W,
            height: H,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Image de fond ────────────────────────────────────
                Positioned.fill(
                  child: Image.asset(
                    'assets/icons/baniere_rang.png',
                    fit: BoxFit.fill,
                  ),
                ),

                // ── Avatar ───────────────────────────────────────────
                Positioned(
                  left: W * 0.095,
                  top: (H - avatarSize) / 2,
                  child: ClipOval(
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: Image(
                        image: _getAvatarImage(userAvatar),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // ── Niveau (sans étoile, petit) ──────────────────────
                Positioned(
                  left: W * 0.225,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'NIVEAU $userLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),

                // ── Rang national : en dessous de la coupe ────────────
                Positioned(
                  left: 3,
                  right: 0,
                  top: H * 0.51,
                  child: Center(
                    child: Text(
                      rankText,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: W * 0.055,
                        letterSpacing: -0.5,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 8),
                          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Points alignés horizontalement avec l'avatar ─────
                Positioned(
                  right: W * 0.052 + 57,
                  top: 5,
                  bottom: 0,
                  child: Center(
                    child: Text(
                    _formatPoints(userPoints),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactList(List<dynamic> remaining) {
    final userBlocState = context.read<UserBloc>().state;
    String? blocUuid;
    if (userBlocState is UserLoaded) blocUuid = userBlocState.profile['uuid']?.toString();
    final currentUserId = SupabaseService.currentUser?.id ?? blocUuid;

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
            child: Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remaining.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final entry = remaining[index];
                    final rank = index + 4;
                    final isMe = entry.userId == currentUserId;
                    return _buildListRow(entry.pseudo, entry.avatar, rank, entry.points, isMe);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(String pseudo, dynamic avatar, dynamic rank, int points, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      color: isMe ? const Color(0xFFFEF3C7) : Colors.transparent,
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? const Color(0xFF7C5C32) : Colors.grey, fontSize: 13))),
          Container(
            width: 30, height: 30,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMe ? const Color(0xFF7C5C32) : Colors.transparent, width: 1.5)),
            child: ClipOval(child: Image(image: _getAvatarImage(avatar), fit: BoxFit.cover)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pseudo + (isMe ? ' (Toi)' : ''), style: TextStyle(fontWeight: FontWeight.w700, color: isMe ? const Color(0xFF7C5C32) : const Color(0xFF2A1A08), fontSize: 13)),
                Text('Niv. ${LevelUtils.getLevelInfo(points).level}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('$points XP', style: TextStyle(fontWeight: FontWeight.w800, color: isMe ? const Color(0xFF7C5C32) : const Color(0xFFB45309), fontSize: 12)),
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
