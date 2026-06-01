import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/remote/supabase_service.dart';
import '../../services/battle_service.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../../data/repositories/user_repository_impl.dart';
import 'waiting_room_screen.dart';
import '../../core/utils/level_utils.dart';

class CreateChallengeScreen extends StatefulWidget {
  final String? initialOpponentId;
  final String? initialOpponentPseudo;

  const CreateChallengeScreen({
    super.key, 
    this.initialOpponentId,
    this.initialOpponentPseudo,
  });

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  int _xpBet = 50;
  String? _selectedTheme;
  bool _showThemes = false;
  bool _isLoading = false;
  
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  
  final TextEditingController _opponentController = TextEditingController();
  Timer? _debounce;
  
  final List<String> _themes = ['Mathématiques', 'SVT', 'Physique-Chimie', 'Français', 'Histoire-Géo', 'Anglais'];
  final List<int> _stakes = [50, 100, 200, 500];

  final Color _primaryColor = const Color(0xFF2D6A2D);
  final Color _gold = const Color(0xFFF59E0B);
  final Color _bgColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    if (widget.initialOpponentId != null) {
      _selectedUser = {
        'uuid': widget.initialOpponentId,
        'pseudo': widget.initialOpponentPseudo ?? 'Ami',
        'level': 1, // Par défaut si inconnu
      };
      _opponentController.text = widget.initialOpponentPseudo ?? 'Ami';
    }
  }

  @override
  void dispose() {
    _opponentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    try {
      // Utilisation du repository comme dans la page Profil
      final userRepo = context.read<UserRepositoryImpl>();
      final results = await userRepo.searchUsers(query);
      
      if (mounted) {
        setState(() {
          // Filtrer soi-même si nécessaire (getUserProfile() donne notre ID)
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint("Erreur recherche standardisée: $e");
    }
  }

  bool _isUserOnline(String? lastActiveStr) {
    if (lastActiveStr == null) return false;
    try {
      final lastActive = DateTime.parse(lastActiveStr);
      return DateTime.now().difference(lastActive).inMinutes < 10;
    } catch (e) { return false; }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        int userXp = 0;
        String? currentUserId;
        if (state is UserLoaded) {
          userXp = state.profile['points'] as int? ?? 0;
          currentUserId = state.profile['uuid'];
        }

        final bool hasEnoughXp = _xpBet <= userXp;
        final filteredResults = _searchResults.where((u) => u['uuid'] != currentUserId).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('NOUVEAU DÉFI', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(Icons.bolt_rounded, 'MISE EN XP', _gold),
                const SizedBox(height: 12),
                _buildStakeSelector(userXp),
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text('Ton solde: $userXp XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
                
                const SizedBox(height: 32),

                _buildHeader(Icons.auto_stories_rounded, 'MODE DE DÉFI', _primaryColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeBlock(
                        _selectedTheme ?? 'THÈME',
                        Icons.grid_view_rounded,
                        _primaryColor,
                        () => setState(() => _showThemes = !_showThemes),
                        selected: _selectedTheme != null && _selectedTheme != 'Mélange IA',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeBlock(
                        'MAÎTRE KALAN',
                        Icons.psychology_rounded,
                        _gold,
                        _challengeAI,
                        selected: _selectedTheme == 'Mélange IA',
                      ),
                    ),
                  ],
                ),

                if (_showThemes) _buildThemeDropdown(),

                const SizedBox(height: 32),

                if (_selectedUser == null) ...[
                  _buildHeader(Icons.person_search_rounded, 'CHERCHER UN ADVERSAIRE', _primaryColor),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _opponentController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Taper le pseudo de ton ami...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredResults.isNotEmpty) _buildSearchResults(filteredResults),
                  const SizedBox(height: 24),
                ],

                if (_selectedUser != null)
                  _buildRecapBlock(hasEnoughXp),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(List<dynamic> results) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: results.map((user) {
          final bool isOnline = _isUserOnline(user['last_active']);
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withValues(alpha: 0.1),
                  backgroundImage: (user['avatar_url'] != null && user['avatar_url'].toString().startsWith('http')) 
                      ? NetworkImage(user['avatar_url']) 
                      : null,
                  child: (user['avatar_url'] == null) ? Text(user['pseudo']?[0].toUpperCase() ?? '?', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(user['pseudo'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isOnline 
                ? 'En ligne • Niveau ${LevelUtils.getLevelInfo(user['points'] ?? 0).level}' 
                : 'Hors ligne • Niveau ${LevelUtils.getLevelInfo(user['points'] ?? 0).level}', 
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)
            ),
            trailing: const Icon(Icons.add_circle_outline_rounded, color: Colors.blue),
            onTap: () {
              setState(() {
                _selectedUser = user;
                _opponentController.text = user['pseudo'];
                _searchResults = [];
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeBlock(String title, IconData icon, Color color, VoidCallback onTap, {bool selected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4CAF50).withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.35), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2D6A2D), size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: const Color(0xFF2D6A2D),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
      ),
      child: Column(
        children: _themes.map((theme) => ListTile(
          title: Text(theme, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          trailing: _selectedTheme == theme ? Icon(Icons.check_circle_rounded, color: _primaryColor) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () {
            setState(() {
              _selectedTheme = theme;
              _showThemes = false;
            });
          },
        )).toList(),
      ),
    );
  }

  void _challengeAI() {
    // Maître Kalan = l'IA choisit le thème à surprise, on joue quand même entre humains
    setState(() {
      _selectedTheme = 'Mélange IA';
      _showThemes = false;
    });
  }

  Widget _buildHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2, color: Colors.black54)),
      ],
    );
  }

  Widget _buildStakeSelector(int currentXp) {
    return Row(
      children: _stakes.map((val) {
        bool isSelected = _xpBet == val;
        bool canAfford = currentXp >= val;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _xpBet = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? (canAfford ? _gold : Colors.red.shade400) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: canAfford ? Colors.black.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.2)),
              ),
              child: Text(
                '$val', 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  color: isSelected ? Colors.white : (canAfford ? Colors.black : Colors.red.shade300)
                )
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecapBlock(bool hasEnoughXp) {
    bool canSend = _selectedUser != null && _selectedTheme != null && hasEnoughXp && !_isLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                backgroundImage: (_selectedUser?['avatar_url'] != null && _selectedUser!['avatar_url'].toString().startsWith('http')) 
                    ? NetworkImage(_selectedUser!['avatar_url']) 
                    : null,
                child: (_selectedUser?['avatar_url'] == null) ? Text(_selectedUser?['pseudo']?[0].toUpperCase() ?? '?', style: TextStyle(fontWeight: FontWeight.w900, color: _primaryColor, fontSize: 24)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedUser?['pseudo'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    if (_selectedUser != null) Text('Niveau ${_selectedUser!['level'] ?? 1}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() { _selectedUser = null; _opponentController.clear(); }),
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (canSend) 
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: _sendChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('ENVOYER LE DÉFI ⚔️', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            )
          else
            Text(
              !hasEnoughXp ? 'SOLDE XP INSUFFISANT !' : 'Sélectionne un thème et un adversaire.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
        ],
      ),
    );
  }

  Future<void> _sendChallenge() async {
    if (_selectedUser == null) return;

    final isOnline = _isUserOnline(_selectedUser!['last_active'] as String?);
    if (!isOnline) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Ami hors ligne', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text('${_selectedUser!['pseudo']} n\'est pas connecté en ce moment. Le défi sera envoyé mais il devra accepter dès qu\'il se reconnecte.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4500), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final inviterId = prefs.getString('current_user_uuid') ?? '';
      if (inviterId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'identifier ton compte. Reconnecte-toi.')));
        return;
      }
      final battleService = BattleService();
      String? inviterPseudo;
      final userState = context.read<UserBloc>().state;
      if (userState is UserLoaded) {
        inviterPseudo = userState.profile['pseudo'] as String?;
      }

      final battle = await battleService.createBattle(
        inviterId: inviterId,
        invitedId: _selectedUser!['uuid'] as String,
        theme: _selectedTheme,
        xpBet: _xpBet,
        inviterPseudo: inviterPseudo,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(
              opponentName: _selectedUser!['pseudo'],
              stake: _xpBet,
              battleId: battle.id,
            ),
          ),
        );
      }
    } catch (e) {
<<<<<<< HEAD
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'envoyer le défi. Vérifie ta connexion et réessaie.')),
=======
      debugPrint('Erreur envoi défi: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), duration: const Duration(seconds: 6)),
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
      );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

