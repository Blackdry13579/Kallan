import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import 'package:kalan_app/data/models/user_model.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../services/presence_service.dart';
import '../widgets/kalan_button.dart';
import 'home_screen.dart';

class OnboardingPseudoScreen extends StatefulWidget {
  final Map<String, dynamic>? registrationData;
  const OnboardingPseudoScreen({super.key, this.registrationData});

  @override
  State<OnboardingPseudoScreen> createState() => _OnboardingPseudoScreenState();
}

class _OnboardingPseudoScreenState extends State<OnboardingPseudoScreen> {
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _step = 1; // 1=Pseudo, 2=Avatar, 3=Auth
  int _selectedAvatar = 1;
  bool _isLoading = false;
  bool _hasInternet = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    final pseudo = _pseudoController.text.trim();
    if (pseudo.length < 3 || pseudo.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le pseudo doit faire entre 3 et 20 caractères')),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _goToStep3() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = result.first != ConnectivityResult.none;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (_step == 1) _buildLogo(),
              if (_step == 2) _buildAvatarPreview(),
              if (_step == 3) _buildAuthIcon(),
              const SizedBox(height: 35),
              Text(
                _step == 1
                    ? 'Choisis ton pseudo'
                    : _step == 2
                        ? 'Choisis ton avatar'
                        : _hasInternet
                            ? 'Crée ton compte'
                            : 'Prêt(e) à commencer !',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _step == 1
                    ? "C'est avec ce pseudo que tu seras reconnu(e) par les autres élèves."
                    : _step == 2
                        ? "C'est l'image qui te représentera dans KALAN."
                        : _hasInternet
                            ? "Crée un compte pour sauvegarder ta progression et jouer contre tes amis."
                            : "Tu peux commencer à apprendre maintenant. Tu pourras créer un compte plus tard depuis ton profil.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A7A58),
                ),
              ),
              const SizedBox(height: 24),
              if (_step == 1) _buildTextField('Ton pseudo', _pseudoController),
              if (_step == 2) _buildAvatarGrid(),
              if (_step == 3) _buildAuthStep(),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_step == 1)
                KalanButton(text: 'Suivant', onPressed: _goToStep2)
              else if (_step == 2)
                KalanButton(text: 'Suivant', onPressed: _goToStep3),
              if (_step > 1 && !_isLoading)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text(
                    'Retour',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/LOGO-removebg-preview.png',
      width: 220, height: 220, fit: BoxFit.contain,
    );
  }

  Widget _buildAvatarPreview() {
    return CircleAvatar(
      radius: 60,
      backgroundImage: AssetImage('assets/avatars/avatar$_selectedAvatar.png'),
    );
  }

  Widget _buildAuthIcon() {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _hasInternet ? Icons.email_rounded : Icons.offline_bolt_rounded,
        size: 50,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: 'Mot de passe (6 caractères min)',
          hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }

  Widget _buildAvatarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final avatarNum = index + 1;
        final isSelected = _selectedAvatar == avatarNum;
        return GestureDetector(
          onTap: () => setState(() => _selectedAvatar = avatarNum),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 3 : 2.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 6, spreadRadius: 2)]
                      : [],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/avatars/avatar$avatarNum.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 1, right: 1,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthStep() {
    if (!_hasInternet) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: KalanButton(
          text: "Commencer l'aventure",
          onPressed: _isLoading ? null : _handleGuestMode,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          'Adresse email',
          _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildPasswordField(),
        const SizedBox(height: 8),
        KalanButton(
          text: "S'inscrire",
          onPressed: _isLoading ? null : _handleSignUp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _handleGuestMode,
          child: const Text(
            'Continuer sans compte (limité)',
            style: TextStyle(
              color: Color(0xFF8A7A58),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignUp() async {
    final pseudo = _pseudoController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre une adresse email valide')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit faire au moins 6 caractères')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Vérifier unicité du pseudo
      try {
        final existing = await SupabaseService.client
            .from('users')
            .select('uuid')
            .eq('pseudo', pseudo)
            .maybeSingle();
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ce pseudo est déjà pris, choisis-en un autre !'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      } catch (_) {}

      // Créer le compte Supabase Auth avec metadata (récupéré par le trigger)
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {
          'pseudo': pseudo,
          'avatar_id': _selectedAvatar ?? 1,
        },
      );
      final supabaseUser = response.user;
      if (supabaseUser == null) throw Exception('Création du compte échouée');

      final uuid = supabaseUser.id;

      final userModel = UserModel(
        uuid: uuid,
        pseudo: pseudo,
        email: email,
        avatarId: _selectedAvatar,
        isGuest: false,
        createdAt: DateTime.now(),
      );

      // Sauvegarder en local
      final db = await DatabaseHelper.instance.database;
      await db.insert('users', userModel.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_uuid', uuid);

      // Sauvegarder profil dans Supabase avec last_active immédiat
      try {
        final payload = {
          ...userModel.toSupabaseJson(),
          'last_active': DateTime.now().toIso8601String(),
        };
        await SupabaseService.client.from('users').upsert(payload);
      } catch (e) {
        debugPrint('Erreur upsert users: $e');
      }

      // Démarrer la présence immédiatement (pas attendre HomeScreen)
      PresenceService.startHeartbeat();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (msg.contains('already registered')) msg = 'Cet email est déjà utilisé.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestMode() async {
    setState(() => _isLoading = true);
    try {
      final uuid = const Uuid().v4();
      final pseudo = _pseudoController.text.trim();

      final userModel = UserModel(
        uuid: uuid,
        pseudo: pseudo,
        avatarId: _selectedAvatar,
        isGuest: true,
        createdAt: DateTime.now(),
      );

      final db = await DatabaseHelper.instance.database;
      await db.insert('users', userModel.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_uuid', uuid);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

