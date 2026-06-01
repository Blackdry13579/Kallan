import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'create_challenge_screen.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_state.dart';
import '../../data/remote/supabase_service.dart';

class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key});

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInitialUsers();
  }

  Future<void> _fetchInitialUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.client
          .from('users')
          .select('uuid, pseudo')
          .limit(10);

      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur de chargement: $e";
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      _fetchInitialUsers();
      return;
    }
    
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final data = await SupabaseService.client
          .from('users')
          .select('uuid, pseudo')
          .ilike('pseudo', '%$query%')
          .limit(10);

      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (state is UserLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        if (state is UserLoaded) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Mode Versus', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2D6A2D))),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
            ),
            body: _buildContent(state.profile['uuid']),
          );
        }

        return const Scaffold(
          body: Center(
            child: Text("Erreur: Profil non chargé. Veuillez vous reconnecter."),
          ),
        );
      },
    );
  }

  Widget _buildContent(String currentUserId) {
    final filteredUsers = _users.where((u) => u['uuid'] != currentUserId).toList();

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }

    return Column(
      children: [
        // Bannière
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF2D6A2D), borderRadius: BorderRadius.circular(24)),
          child: const Text(
            'Prêt pour le défi ? Invite tes amis et teste tes connaissances !',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Recherche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Rechercher un pseudo...',
              prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        // Liste
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A2D)))
              : filteredUsers.isEmpty 
                ? const Center(child: Text("Aucun joueur trouvé."))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final pseudo = user['pseudo']?.toString() ?? 'Joueur';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2D6A2D).withValues(alpha: 0.1),
                          child: Text(pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF2D6A2D))),
                        ),
                        title: Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => CreateChallengeScreen(
                                  initialOpponentId: user['uuid'],
                                  initialOpponentPseudo: pseudo,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A2D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Défier'),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
