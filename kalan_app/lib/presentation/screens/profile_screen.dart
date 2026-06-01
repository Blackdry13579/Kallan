import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/level_utils.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';
import 'badges_screen.dart';
import 'login_screen.dart';
import 'about_screen.dart';
import 'roadmap_screen.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/supabase_service.dart';
import '../../services/notification_scheduler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  String _reminderTime = '19:00';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<UserBloc>().add(LoadUserProfile());
    context.read<UserBloc>().add(LoadFriends());
    _loadReminderTime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderTime = prefs.getString('reminder_time') ?? '19:00';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true, // Crucial pour le clavier
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

              return SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, state.isOnline),
                    _buildIdentity(context, profile),
                    const SizedBox(height: 20),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildProfileTab(context, profile, stats, state.badges, levelInfo, points),
                          _buildProgressionTab(profile, stats),
                          _buildFriendsTab(state),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/images/LOGO-removebg-preview.png', height: 50, fit: BoxFit.contain),
              const SizedBox(width: 6),
              Image.asset('assets/images/KALAN-removebg-preview.png', height: 14),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFFEAF3DE) : const Color(0xFFF5F2EA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isOnline ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    color: isOnline ? const Color(0xFF2D6A2D) : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentity(BuildContext context, Map<String, dynamic> profile) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: ClipOval(child: _buildAvatarImage(profile)),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: GestureDetector(
                onTap: () => _showAvatarPicker(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              profile['pseudo'] ?? 'Élève KALAN',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showEditProfileBottomSheet(context, profile),
              child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4CAF50)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
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
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        labelColor: const Color(0xFF2D6A2D),
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: const [
          Tab(text: 'PROFIL'),
          Tab(text: 'PROGRESSION'),
          Tab(text: 'AMIS'),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, Map<String, dynamic> profile, Map<String, dynamic> stats, List<Map<String, dynamic>> badges, LevelInfo levelInfo, int points) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(child: _buildStatBlock('NIVEAU', levelInfo.level.toString(), const Color(0xFF4CAF50), 'assets/icons/badges_niveau/level${levelInfo.level}.png')),
            const SizedBox(width: 15),
            Expanded(child: _buildStatBlock('XP TOTAL', points.toString(), const Color(0xFFE8C87A), 'assets/icons/xp_icon.png')),
          ],
        ),
        const SizedBox(height: 20),
        _buildRoadmapBanner(context, levelInfo),
        const SizedBox(height: 20),
        _buildBadgesSection(context, badges),
        _buildSettingsSection(context),
        _buildLogoutButton(context),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatBlock(String label, String value, Color color, String assetPath) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Image.asset(
                assetPath,
                height: 80,
                width: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, color: color, size: 50),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapBanner(BuildContext context, LevelInfo levelInfo) {
    String worldImg;
    switch (levelInfo.level) {
      case 1: worldImg = 'level-1-graine.jpg'; break;
      case 2: worldImg = 'level-2-baobab.jpg'; break;
      case 3: worldImg = 'level-3-feu.jpg'; break;
      case 4: worldImg = 'level-4-griot.jpg'; break;
      case 5: worldImg = 'level-5-masque.jpg'; break;
      case 6: worldImg = 'level-6-ancetre.jpg'; break;
      default: worldImg = 'level-1-graine.jpg';
    }
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          image: DecorationImage(
            image: AssetImage('assets/roadmap/$worldImg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MON PARCOURS', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('Actuel : ${levelInfo.title}', style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressionTab(Map<String, dynamic> profile, Map<String, dynamic> stats) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildStreakCard(profile['streak'] ?? 0),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildProgressionSmallCard('Quiz faits', (stats['quizCount'] ?? 0).toString(), Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: _buildProgressionSmallCard('Cartes créées', (stats['deckCount'] ?? 0).toString(), Colors.purple)),
          ],
        ),
        const SizedBox(height: 15),
        _buildProgressionCard(
          'Taux de réussite', 
          '${stats['avgScore'] ?? 0}%', 
          const Color(0xFF4CAF50), 
          Icons.auto_graph_rounded,
          'Précision moyenne sur tes quiz'
        ),
      ],
    );
  }

  Widget _buildStreakCard(int streakDays) {
    final List<String> weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final int today = DateTime.now().weekday - 1; // 0-6

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SÉRIE DE RÉVISION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('$streakDays', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
                      const SizedBox(width: 8),
                      const Text('JOURS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.whatshot_rounded, color: Color(0xFFE24B4A), size: 48),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              bool isCompleted = index <= today && streakDays > (today - index);
              bool isToday = index == today;
              
              return Column(
                children: [
                  Text(weekDays[index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isToday ? const Color(0xFFE24B4A) : Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFE24B4A) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: const Color(0xFFE24B4A), width: 2) : null,
                    ),
                    child: isCompleted 
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : (isToday ? const Icon(Icons.timer_outlined, color: Color(0xFFE24B4A), size: 18) : null),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue comme ça ! 🔥', style: TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionCard(String title, String value, Color color, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionSmallCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(UserLoaded state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Barre de recherche
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (val) {
                    setState(() {}); // Force le rebuild pour cacher "Résultats" si vide
                    context.read<UserBloc>().add(SearchFriends(val.trim()));
                  },
                  decoration: const InputDecoration(                    hintText: 'Rechercher un pseudo...',
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: () {
                    final val = _searchController.text.trim();
                    if (val.isNotEmpty) {
                      context.read<UserBloc>().add(SearchFriends(val));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A2D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Résultats de recherche - On ne les affiche que si la barre n'est pas vide ET qu'il y a des résultats
        if (_searchController.text.trim().isNotEmpty && state.searchResults.isNotEmpty) ...[
          const Text('RÉSULTATS DE RECHERCHE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...state.searchResults.map((user) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  backgroundImage: user['avatar_id'] != null 
                    ? AssetImage('assets/avatars/avatar${user['avatar_id']}.png')
                    : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['pseudo'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A1A))),
                      const Text('Disponible pour réviser', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<UserBloc>().add(AddFriend(user));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user['pseudo']} ajouté !'), backgroundColor: const Color(0xFF2D6A2D)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF3DE),
                    foregroundColor: const Color(0xFF2D6A2D),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFE0D8CC), thickness: 1),
          ),
        ],

        const Text('TES AMIS ACTUELS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 16),
        
        if (state.friends.isEmpty)
          _buildEmptyState('Invite tes amis pour comparer vos scores !', Icons.people_outline_rounded)
        else
          ...state.friends.map((friend) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: friend['friend_avatar_id'] != null 
                    ? AssetImage('assets/avatars/avatar${friend['friend_avatar_id']}.png')
                    : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(friend['friend_pseudo'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1A1A1A))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEAF3DE), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Niveau 1', style: TextStyle(color: Color(0xFF2D6A2D), fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          )),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAvatarImage(Map<String, dynamic> profile) {
    final avatarId = profile['avatar_id'];
    if (avatarId != null) return Image.asset('assets/avatars/avatar$avatarId.png', fit: BoxFit.cover);
    return Image.asset('assets/avatars/avatar1.png', fit: BoxFit.cover);
  }

  Widget _buildBadgesSection(BuildContext context, List<Map<String, dynamic>> userBadges) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('BADGES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
              child: const Text('VOIR TOUT', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (userBadges.isEmpty)
          _buildEmptyState('Aucun badge pour le moment', Icons.emoji_events_outlined)
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getAllBadges(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 80);
              final allBadges = snapshot.data!;
              final unlockedKeys = userBadges.map((b) => b['badge_key']).toSet();
              final earnedBadges = allBadges.where((b) => unlockedKeys.contains(b['id'])).toList();

              return SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: earnedBadges.length.clamp(0, 6),
                  separatorBuilder: (_, __) => const SizedBox(width: 15),
                  itemBuilder: (context, index) {
                    final b = earnedBadges[index];
                    final color = Color(b['color']);
                    return Column(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: ClipOval(
                            child: b['image_path'] != null
                                ? Image.asset(
                                    'assets/badges/${b['image_path']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(b['emoji'] ?? '🏆', style: const TextStyle(fontSize: 24)),
                                  )
                                : Text(b['emoji'] ?? '🏆', style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b['label'],
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF555555)),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('PARAMÈTRES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
                  const _SettingItem(
                icon: Icons.volume_up_rounded,
                iconColor: Color(0xFF00C853),
                title: 'Son',
                subtitle: 'Effets sonores de l\'application',
                prefKey: 'sound_enabled',
                defaultValue: true,
              ),
              _SettingItem(
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFF7C4DFF),
                title: 'Rappel Notification',
                subtitle: 'Rappels de révisions quotidiens',
                prefKey: 'notifications_enabled',
                defaultValue: true,
                onChanged: (enabled) async {
                  if (enabled) {
                    final prefs = await SharedPreferences.getInstance();
                    final timeStr = prefs.getString('reminder_time') ?? '19:00';
                    final parts = timeStr.split(':');
                    await NotificationScheduler.scheduleDaily(
                        int.parse(parts[0]), int.parse(parts[1]));
                  } else {
                    await NotificationScheduler.cancel();
                  }
                },
              ),
              _SettingItem(
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFFFF6F00),
                title: 'Heure de révision',
                subtitle: 'Rappel programmé à $_reminderTime',
                prefKey: 'reminder_time_action',
                defaultValue: true,
                isAction: true,
                onTap: () => _selectReminderTime(context),
              ),
              _SettingItem(
                icon: Icons.info_rounded,
                iconColor: const Color(0xFF0288D1),
                title: 'À propos',
                subtitle: 'En savoir plus sur KALAN',
                prefKey: 'about',
                defaultValue: true,
                isAction: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final timeParts = _reminderTime.split(':');
    final initialTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    
    if (!mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D6A2D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final formattedTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      await prefs.setString('reminder_time', formattedTime);
      setState(() => _reminderTime = formattedTime);

      if (prefs.getBool('notifications_enabled') ?? true) {
        await NotificationScheduler.scheduleDaily(selectedTime.hour, selectedTime.minute);
      }
    }
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
      child: Column(children: [Icon(icon, color: Colors.grey.shade400, size: 40), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF555555), fontSize: 13, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(18)),
          child: const Center(child: Text('DÉCONNEXION', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1))),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Veux-tu vraiment quitter KALAN ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NON', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900))),
          TextButton(onPressed: () async {
            await SupabaseService.client.auth.signOut();
            if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
          }, child: const Text('OUI, QUITTER', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir un avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 15, mainAxisSpacing: 15),
              itemCount: 8,
              itemBuilder: (context, index) {
                final id = index + 1;
                return GestureDetector(
                  onTap: () { context.read<UserBloc>().add(UpdateUserProfile(avatarId: id)); Navigator.pop(context); },
                  child: ClipOval(child: Image.asset('assets/avatars/avatar$id.png', fit: BoxFit.cover)),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditProfileBottomSheet(BuildContext context, Map<String, dynamic> profile) {
    final pseudoController = TextEditingController(text: profile['pseudo']);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Modifier le pseudo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            TextField(
              controller: pseudoController,
              decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF5F2EA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  context.read<UserBloc>().add(UpdateUserProfile(pseudo: pseudoController.text.trim()));
                  Navigator.pop(context);
                },
                child: const Text('ENREGISTRER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SettingItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String prefKey;
  final bool defaultValue;
  final bool isAction;
  final VoidCallback? onTap;
  final Future<void> Function(bool value)? onChanged;

  const _SettingItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.prefKey = '',
    this.defaultValue = true,
    this.isAction = false,
    this.onTap,
    this.onChanged,
  });

  @override
  State<_SettingItem> createState() => _SettingItemState();
}

class _SettingItemState extends State<_SettingItem> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAction) _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _value = prefs.getBool(widget.prefKey) ?? widget.defaultValue);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.isAction
          ? widget.onTap
          : () async {
              final newValue = !_value;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(widget.prefKey, newValue);
              setState(() => _value = newValue);
              await widget.onChanged?.call(newValue);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(Colors.white, widget.iconColor, 0.6)!,
                    widget.iconColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.iconColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.7),
                    blurRadius: 4,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))), const SizedBox(height: 1), Text(widget.subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600))])),
            if (widget.isAction) const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey)
            else AnimatedContainer(
              duration: const Duration(milliseconds: 200), width: 44, height: 24,
              decoration: BoxDecoration(color: _value ? const Color(0xFF2D6A2D) : const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(14)),
              child: Stack(children: [AnimatedPositioned(duration: const Duration(milliseconds: 200), curve: Curves.easeIn, left: _value ? 22 : 2, top: 2, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))])))]),
            ),
          ],
        ),
      ),
    );
  }
}
