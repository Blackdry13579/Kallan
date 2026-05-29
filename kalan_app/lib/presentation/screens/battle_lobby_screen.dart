import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../services/battle_service.dart';
import '../../services/local_ai_service.dart';
import '../../core/utils/level_utils.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_state.dart';
import '../widgets/challenge_invitation_bottom_sheet.dart';
import 'notification_screen.dart';
import 'waiting_room_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kFire   = Color(0xFFEA580C);
const _kFireLt = Color(0xFFFFF7ED);
const _kBg     = Color(0xFFF5F2EA);
const _kCard   = Colors.white;
const _kText   = Color(0xFF1C1C1C);
const _kSub    = Color(0xFF9CA3AF);
const _kGold   = Color(0xFFF59E0B);
const _kGreen  = Color(0xFF16A34A);
const _kBlue   = Color(0xFF1E4D8C);
const _kBrown  = Color(0xFF7C5C32);
const _kRed    = Color(0xFFDC2626);

const _kThemeColors = {
  'Mathématiques'  : Color(0xFF1E4D8C),
  'SVT'            : Color(0xFF16A34A),
  'Physique-Chimie': Color(0xFF7C3AED),
  'Français'       : Color(0xFFB91C1C),
  'Histoire-Géo'   : Color(0xFF7C5C32),
  'Anglais'        : Color(0xFFEA580C),
};

class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key});
  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  int _tab = 0;

  // user
  String? _userId;
  int    _userXp     = 0;
  String _userPseudo = '';

  // tab Créer
  int    _stake          = 100;
  String _mode           = 'theme';
  String? _selectedTheme;
  bool  _themesExpanded  = false;
  Map<String, dynamic>? _selectedOpponent;
  List<dynamic> _searchResults = [];
  bool  _isLoading = false;
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  static const _themes = [
    'Mathématiques', 'SVT', 'Physique-Chimie',
    'Français', 'Histoire-Géo', 'Anglais'
  ];
  static const _stakes = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userId = prefs.getString('current_user_uuid'));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool _isOnline(String? lastActive) {
    if (lastActive == null) return false;
    try {
      return DateTime.now().difference(DateTime.parse(lastActive)).inMinutes < 10;
    } catch (_) { return false; }
  }

  Stream<List<Map<String, dynamic>>> _myBattlesStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);
    return SupabaseService.client
        .from('battles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list
            .where((r) => r['inviter_id'] == uid || r['invited_id'] == uid)
            .toList());
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (state is UserLoaded) {
          _userXp     = state.profile['points'] as int?    ?? 0;
          _userPseudo = state.profile['pseudo'] as String? ?? '';
          _userId   ??= state.profile['uuid']  as String?;
        }
        return Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                _AppBar(onBack: () => Navigator.pop(context)),
                const SizedBox(height: 10),
                _TabPills(selected: _tab, onTap: (i) => setState(() => _tab = i)),
                const SizedBox(height: 10),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [_buildArena(), _buildCreate(), _buildHistory()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0 — ARÈNE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildArena() {
    if (_userId == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myBattlesStream(),
      builder: (context, battleSnap) {
        final all      = battleSnap.data ?? [];
        final pending  = all.where((r) => r['invited_id'] == _userId && r['status'] == 'invitation_sent').toList();
        final finished = all.where((r) => r['status'] == 'finished').toList();
        final lastFights = finished.take(3).toList();

        final wins   = finished.where((r) => r['winner_id'] == _userId).length;
        final losses = finished.length - wins;
        final xpNet  = finished.fold<int>(0, (acc, r) {
          final bet = r['xp_bet'] as int? ?? 0;
          return acc + (r['winner_id'] == _userId ? bet : -bet);
        });

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client.from('users').stream(primaryKey: ['uuid']),
          builder: (context, usersSnap) {
            final allUsers     = usersSnap.data ?? [];
            final onlineFriends = allUsers
                .where((u) => u['uuid'] != _userId && _isOnline(u['last_active'] as String?))
                .take(5)
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArenaHero(onTap: () => setState(() => _tab = 1)),
                  const SizedBox(height: 14),
                  _QuickStatsRow(total: finished.length, wins: wins, losses: losses, xpNet: xpNet),
                  const SizedBox(height: 6),

                  // Défis en attente
                  if (pending.isNotEmpty) ...[
                    const _SectionHeader(icon: '⏳', label: 'DÉFIS EN ATTENTE', iconBg: Color(0xFFFEF3C7)),
                    ...pending.map((r) {
                      final sender = allUsers.firstWhere((u) => u['uuid'] == r['inviter_id'], orElse: () => <String, dynamic>{});
                      return _PendingCard(
                        challenge: r,
                        senderName: sender['pseudo'] as String? ?? 'Joueur',
                        onAccept: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChallengeInvitationBottomSheet(
                            challenge: {...r, 'opponent_name': sender['pseudo'] ?? 'Joueur'},
                          ),
                        ),
                        onDecline: () => BattleService().refuseBattle(r['id'] as String),
                      );
                    }),
                  ],

                  // Amis en ligne
                  const _SectionHeader(icon: '🟢', label: 'EN LIGNE MAINTENANT', iconBg: Color(0xFFDCFCE7)),
                  if (onlineFriends.isEmpty)
                    const _EmptyHint(text: 'Aucun joueur en ligne pour l\'instant'),
                  ...onlineFriends.map((u) => _FriendRow(
                    user: u,
                    onChallenge: () => setState(() {
                      _tab = 1;
                      _selectedOpponent = u;
                      _searchCtrl.text = u['pseudo'] as String? ?? '';
                    }),
                  )),

                  // Derniers combats
                  const _SectionHeader(icon: '📋', label: 'DERNIERS COMBATS', iconBg: Color(0xFFF5F0E8)),
                  if (lastFights.isEmpty)
                    const _EmptyHint(text: 'Lance ton premier défi pour voir tes combats ici'),
                  ...lastFights.map((r) {
                    final isInviter = r['inviter_id'] == _userId;
                    final oppId     = isInviter ? r['invited_id'] : r['inviter_id'];
                    final opp       = allUsers.firstWhere((u) => u['uuid'] == oppId, orElse: () => <String, dynamic>{});
                    final won       = r['winner_id'] == _userId;
                    final myScore   = (isInviter ? r['inviter_score'] : r['invited_score']) as int? ?? 0;
                    final theirScore= (isInviter ? r['invited_score'] : r['inviter_score']) as int? ?? 0;
                    final xpDelta   = won ? (r['xp_bet'] as int? ?? 0) : -(r['xp_bet'] as int? ?? 0);
                    return _BattleRow(
                      opponentName: opp['pseudo'] as String? ?? 'Joueur',
                      theme:        r['theme']    as String? ?? '?',
                      createdAt:    r['created_at'] as String?,
                      myScore: myScore, theirScore: theirScore,
                      won: won, xpDelta: xpDelta,
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — CRÉER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCreate() {
    final themeOk = _mode == 'ai' || _selectedTheme != null;
    final canSend = _selectedOpponent != null
        && themeOk
        && _userXp >= _stake
        && !_isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mise XP
          const _SectionHeader(icon: '⚡', label: 'MISE EN XP', iconBg: Color(0xFFFEF3C7)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: _stakes.map((v) {
                    final sel       = _stake == v;
                    final canAfford = _userXp >= v;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _stake = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: sel ? (canAfford ? _kGold : Colors.red.shade400) : _kCard,
                            borderRadius: BorderRadius.circular(14),
                            border: sel ? null : Border.all(color: Colors.black.withValues(alpha: 0.06)),
                            boxShadow: [BoxShadow(
                              color: sel ? _kGold.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
                              blurRadius: sel ? 10 : 6, offset: const Offset(0, 3),
                            )],
                          ),
                          child: Column(children: [
                            Text('$v', textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16,
                                color: sel ? Colors.white : _kText)),
                            Text('XP', textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 9,
                                color: sel ? Colors.white.withValues(alpha: 0.75) : _kSub)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                RichText(text: TextSpan(children: [
                  const TextSpan(text: 'Ton solde : ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kSub)),
                  TextSpan(text: '$_userXp XP',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _kFire)),
                ])),
              ],
            ),
          ),

          // Mode
          const SizedBox(height: 20),
          const _SectionHeader(icon: '🎮', label: 'MODE DE DÉFI', iconBg: Color(0xFFEEF2FF)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _ModeButton(
                icon: '🗂️', label: 'PAR THÈME', sub: 'Choisis une matière',
                selected: _mode == 'theme', selColor: _kBlue,
                onTap: () => setState(() {
                  _mode = 'theme';
                  _selectedTheme = null;
                  _themesExpanded = true;
                  _selectedOpponent = null;
                  _searchCtrl.clear();
                  _searchResults = [];
                }),
              ),
              const SizedBox(width: 12),
              _ModeButton(
                icon: '🤖', label: 'MAÎTRE KALAN', sub: 'IA choisit le thème',
                selected: _mode == 'ai', selColor: const Color(0xFF7C3AED),
                onTap: () => setState(() {
                  _mode = 'ai';
                  _selectedTheme = null;
                  _themesExpanded = false;
                  _selectedOpponent = null;
                  _searchCtrl.clear();
                  _searchResults = [];
                }),
              ),
            ]),
          ),

          // Catégories — révélées quand on clique sur PAR THÈME
          if (_mode == 'theme') ...[
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState: _themesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _themes.map((t) {
                    final sel = _selectedTheme == t;
                    final themeColor = _kThemeColors[t] ?? _kFire;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedTheme = t;
                        _themesExpanded = false;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? themeColor : _kCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? themeColor : themeColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                        ),
                        child: Text(t,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : themeColor)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Recherche adversaire (tous les modes)
          if (_selectedOpponent == null) ...[
            const SizedBox(height: 20),
            const _SectionHeader(icon: '🔍', label: 'CHERCHER UN ADVERSAIRE', iconBg: Color(0xFFF5F0E8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                ),
                child: Row(children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search, color: _kSub, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Taper le pseudo de ton ami...',
                        hintStyle: TextStyle(color: _kSub, fontWeight: FontWeight.w600),
                        border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Container(
                    width: 40, height: 40, margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _kFire, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ]),
              ),
            ),
            if (_searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    children: _searchResults
                        .where((u) => u['uuid'] != _userId)
                        .map<Widget>((u) {
                      final online = _isOnline(u['last_active'] as String?);
                      return ListTile(
                        leading: Stack(children: [
                          CircleAvatar(
                            backgroundColor: _kFire.withValues(alpha: 0.1),
                            child: Text(
                              ((u['pseudo'] as String?) ?? '?').isNotEmpty
                                  ? (u['pseudo'] as String)[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: _kFire)),
                          ),
                          Positioned(right: 0, bottom: 0,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: online ? const Color(0xFF22C55E) : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            )),
                        ]),
                        title: Text(u['pseudo'] as String? ?? 'Inconnu',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text(
                          online
                            ? '🟢 En ligne · Niveau ${LevelUtils.getLevelInfo(u['points'] ?? 0).level}'
                            : '⚫ Hors ligne · Niveau ${LevelUtils.getLevelInfo(u['points'] ?? 0).level}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub),
                        ),
                        trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5)),
                        onTap: () => setState(() {
                          _selectedOpponent = u as Map<String, dynamic>;
                          _searchCtrl.text  = (u as Map<String, dynamic>)['pseudo'] as String? ?? '';
                          _searchResults    = [];
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],

          // Récap
          if (_selectedOpponent != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RecapCard(
                myPseudo:    _userPseudo,
                opponent:    _selectedOpponent!,
                theme:       _selectedTheme ?? '—',
                stake:       _stake,
                canSend:     canSend,
                isLoading:   _isLoading,
                hasEnoughXp: _userXp >= _stake,
                onClear: () => setState(() {
                  _selectedOpponent = null;
                  _mode = 'theme';
                  _searchCtrl.clear();
                  _selectedTheme = null;
                }),
                onSend: _sendChallenge,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().length < 2) {
        if (mounted) setState(() => _searchResults = []);
        return;
      }
      try {
        final repo = context.read<UserRepositoryImpl>();
        final results = await repo.searchUsers(q.trim());
        if (mounted) setState(() => _searchResults = results);
      } catch (_) {}
    });
  }

  Future<void> _sendChallenge() async {
    if (_selectedOpponent == null) return;
    final isAI = _mode == 'ai';
    if (isAI && (_selectedTheme == null || _selectedTheme!.isEmpty)) {
      final randomThemes = ['Mathématiques', 'SVT', 'Physique-Chimie', 'Français', 'Histoire-Géo', 'Anglais'];
      randomThemes.shuffle();
      setState(() => _selectedTheme = randomThemes.first);
    }
    if (_selectedTheme == null) return;

    if (!isAI && !_isOnline(_selectedOpponent!['last_active'] as String?)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Ami hors ligne', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text('${_selectedOpponent!['pseudo']} n\'est pas connecté. Le défi sera envoyé dès qu\'il se reconnecte.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kFire, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs    = await SharedPreferences.getInstance();
      final inviterId = _userId ?? prefs.getString('current_user_uuid') ?? '';
      if (inviterId.isEmpty) return;

      final service = BattleService();
      final battle  = await service.createBattle(
        inviterId: inviterId,
        invitedId: _selectedOpponent!['uuid'] as String,
        theme:     _selectedTheme,
        xpBet:     _stake,
      );

      if (isAI) {
        await service.acceptBattle(battle.id);
        try {
          await service.startGeneration(battle.id);
          final content = await LocalAIService().generateBattleContent(theme: _selectedTheme ?? 'Mélange');
          await service.updateBattleContent(battle.id, content);
        } catch (e) { debugPrint('AI gen: $e'); }
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            opponentName: _selectedOpponent!['pseudo'] as String? ?? 'Adversaire',
            stake:    _stake,
            battleId: battle.id,
          ),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'envoyer le défi. Vérifie ta connexion.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — HISTORIQUE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistory() {
    if (_userId == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myBattlesStream(),
      builder: (context, battleSnap) {
        final finished = (battleSnap.data ?? []).where((r) => r['status'] == 'finished').toList();
        final wins   = finished.where((r) => r['winner_id'] == _userId).length;
        final losses = finished.length - wins;
        final xpNet  = finished.fold<int>(0, (acc, r) {
          final bet = r['xp_bet'] as int? ?? 0;
          return acc + (r['winner_id'] == _userId ? bet : -bet);
        });
        final pct = finished.isEmpty ? 0 : (wins * 100 ~/ finished.length);

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client.from('users').stream(primaryKey: ['uuid']),
          builder: (context, usersSnap) {
            final allUsers = usersSnap.data ?? [];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Column(
                children: [
                  if (finished.isEmpty)
                    const _EmptyHint(text: 'Aucun combat terminé. Lance ton premier défi !'),
                  ...finished.map((r) {
                    final isInviter  = r['inviter_id'] == _userId;
                    final oppId      = isInviter ? r['invited_id'] : r['inviter_id'];
                    final opp        = allUsers.firstWhere((u) => u['uuid'] == oppId, orElse: () => <String, dynamic>{});
                    final won        = r['winner_id'] == _userId;
                    final myScore    = (isInviter ? r['inviter_score'] : r['invited_score']) as int? ?? 0;
                    final theirScore = (isInviter ? r['invited_score'] : r['inviter_score']) as int? ?? 0;
                    final xpDelta    = won ? (r['xp_bet'] as int? ?? 0) : -(r['xp_bet'] as int? ?? 0);
                    return _BattleRow(
                      opponentName: opp['pseudo'] as String? ?? 'Joueur',
                      theme:        r['theme']    as String? ?? '?',
                      createdAt:    r['created_at'] as String?,
                      myScore: myScore, theirScore: theirScore,
                      won: won, xpDelta: xpDelta,
                    );
                  }),
                  const SizedBox(height: 14),
                  if (finished.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF5F0E8), Colors.white]),
                        border: Border.all(color: const Color(0xFFE8E2D8)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(children: [
                        const Text('📊', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bilan global',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: _kText)),
                              const SizedBox(height: 4),
                              Text('${finished.length} duels · ${wins}V ${losses}D · $pct%',
                                style: const TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                xpNet >= 0 ? '+$xpNet XP net' : '$xpNet XP net',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                                  color: xpNet >= 0 ? _kGreen : _kRed),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVÉS
// ═══════════════════════════════════════════════════════════════════════════════

class _AppBar extends StatelessWidget {
  final VoidCallback onBack;
  const _AppBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kCard, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
        const Spacer(),
        Text('⚔️  ARÈNE',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: _kText)),
        const Spacer(),
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (ctx, _) => GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const NotificationScreen())),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCard, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TabPills extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _TabPills({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const labels = ['Arène', 'Créer', 'Historique'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (i) {
          final sel = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _kFire : _kCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: sel ? _kFire.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
                    blurRadius: sel ? 10 : 6, offset: const Offset(0, 3),
                  )],
                ),
                child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800, fontSize: 13,
                    color: sel ? Colors.white : _kSub)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ArenaHero extends StatelessWidget {
  final VoidCallback onTap;
  const _ArenaHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A5C3A), _kBrown],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: const Color(0xFF0F3460).withValues(alpha: 0.35),
            blurRadius: 20, offset: const Offset(0, 8),
          )],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/bottom/eper.png',
              height: 86,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(width: 86),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arène de Duels',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                  const SizedBox(height: 5),
                  Text('Défie tes amis et gagne des XP !',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.68))),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF15803D)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('⚔️  NOUVEAU DÉFI',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12,
                        color: Colors.white, letterSpacing: 0.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final int total, wins, losses, xpNet;
  const _QuickStatsRow({required this.total, required this.wins, required this.losses, required this.xpNet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _StatBox(value: '$total',                              label: 'DUELS',    color: _kText),
        const SizedBox(width: 10),
        _StatBox(value: '$wins',                              label: 'VICTOIRES', color: _kGreen),
        const SizedBox(width: 10),
        _StatBox(value: '$losses',                            label: 'DÉFAITES',  color: _kRed),
        const SizedBox(width: 10),
        _StatBox(value: xpNet >= 0 ? '+$xpNet' : '$xpNet',  label: 'XP NET',    color: _kGold),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _kSub, letterSpacing: 0.8)),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon, label;
  final Color iconBg;
  const _SectionHeader({required this.icon, required this.label, required this.iconBg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 14))),
        ),
        const SizedBox(width: 8),
        Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kSub, letterSpacing: 0.8)),
      ]),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final String senderName;
  final VoidCallback onAccept, onDecline;
  const _PendingCard({required this.challenge, required this.senderName, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(18),
        border: const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        const Text('🦁', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$senderName te défie !',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 2),
            Text('${challenge['theme'] ?? '?'}  ·  ${challenge['xp_bet'] ?? 50} XP',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
          ]),
        ),
        Row(children: [
          GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
              child: const Text('✓', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: const Text('✕', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFB91C1C))),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onChallenge;
  const _FriendRow({required this.user, required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    final pseudo = user['pseudo'] as String? ?? 'Joueur';
    final lvl    = LevelUtils.getLevelInfo(user['points'] ?? 0).level;
    final xp     = user['points'] ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFA5D6A7), Color(0xFF4CAF50)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
          ),
          Positioned(bottom: 1, right: 1,
            child: Container(
              width: 11, height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E), shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            )),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pseudo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 2),
            Text('Niv. $lvl  ·  $xp XP',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
          ]),
        ),
        GestureDetector(
          onTap: onChallenge,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _kFireLt, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kFire.withValues(alpha: 0.2))),
            child: const Text('⚔️ Défier',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kFire)),
          ),
        ),
      ]),
    );
  }
}

class _BattleRow extends StatelessWidget {
  final String opponentName, theme;
  final String? createdAt;
  final int myScore, theirScore, xpDelta;
  final bool won;
  const _BattleRow({
    required this.opponentName, required this.theme, required this.createdAt,
    required this.myScore, required this.theirScore, required this.won, required this.xpDelta,
  });

  String _dateLabel() {
    if (createdAt == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(createdAt!)).inDays;
      if (diff == 0) return 'Aujourd\'hui';
      if (diff == 1) return 'Hier';
      return 'Il y a ${diff}j';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: won ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(won ? '🏆' : '💔', style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('vs $opponentName',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 2),
            Text('$theme  ·  ${_dateLabel()}  ·  $myScore/$theirScore',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
          ]),
        ),
        Text(
          xpDelta >= 0 ? '+$xpDelta XP' : '$xpDelta XP',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
            color: xpDelta >= 0 ? _kGreen : _kRed),
        ),
      ]),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String icon, label, sub;
  final bool selected;
  final Color selColor;
  final VoidCallback onTap;
  const _ModeButton({required this.icon, required this.label, required this.sub,
    required this.selected, required this.selColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: _kCard, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? selColor : Colors.transparent, width: 2.5),
            boxShadow: [BoxShadow(
              color: selected ? selColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 20 : 8,
            )],
          ),
          child: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: selColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
              color: selColor, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
          ]),
        ),
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  final String myPseudo, theme;
  final Map<String, dynamic> opponent;
  final int stake;
  final bool canSend, isLoading, hasEnoughXp;
  final VoidCallback onClear, onSend;
  const _RecapCard({
    required this.myPseudo, required this.opponent, required this.theme,
    required this.stake, required this.canSend, required this.isLoading,
    required this.hasEnoughXp,
    required this.onClear, required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final oppName = opponent['pseudo'] as String? ?? 'Adversaire';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(children: [
        // VS row
        Row(children: [
          _PlayerBadge(pseudo: myPseudo, label: 'Toi'),
          const Spacer(),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFEA580C)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.4), blurRadius: 10)],
            ),
            child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 16))),
          ),
          const Spacer(),
          _PlayerBadge(
            pseudo: oppName, label: 'Adversaire',
            onClear: opponent['uuid'] != '00000000-0000-0000-0000-000000000000' ? onClear : null,
          ),
        ]),
        const SizedBox(height: 18),
        // Details
        Row(children: [
          _DetailBox(value: theme, label: 'THÈME'),
          const SizedBox(width: 8),
          _DetailBox(value: '$stake XP', label: 'MISE', valueColor: _kGold),
          const SizedBox(width: 8),
          const _DetailBox(value: '10 Q.', label: 'FORMAT'),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: canSend ? onSend : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kFire, foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade200, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: isLoading
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(
                    canSend
                      ? 'ENVOYER LE DÉFI ⚔️'
                      : (!hasEnoughXp
                          ? 'SOLDE INSUFFISANT'
                          : (opponent['uuid'] == null ? 'Sélectionne un adversaire' : 'Sélectionne un thème')),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                  ),
          ),
        ),
      ]),
    );
  }

}

class _PlayerBadge extends StatelessWidget {
  final String pseudo, label;
  final VoidCallback? onClear;
  const _PlayerBadge({required this.pseudo, required this.label, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE8DE), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF0EBE0), width: 2),
          ),
          child: Center(child: Text(
            pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        ),
        if (onClear != null)
          Positioned(top: -2, right: -2,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            )),
      ]),
      const SizedBox(height: 6),
      Text(pseudo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _kText)),
      Text(label, style: const TextStyle(fontSize: 10, color: _kSub, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _DetailBox extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  const _DetailBox({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: valueColor ?? _kText)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _kSub, letterSpacing: 0.4)),
        ]),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Text(text, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _kSub, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
