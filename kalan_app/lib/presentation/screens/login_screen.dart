<<<<<<< HEAD
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
=======
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import 'package:kalan_app/data/models/user_model.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:kalan_app/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/kalan_button.dart';
import 'home_screen.dart';
import 'onboarding_pseudo_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 40),
              const Text(
                'Bon retour !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connecte-toi avec ton email pour continuer ton aventure.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A7A58),
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField('Adresse email', _emailController,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildPasswordField(),
              const SizedBox(height: 28),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                KalanButton(text: 'Se connecter', onPressed: _handleLogin),
              const SizedBox(height: 40),
              _buildRegisterLink(),
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
      width: 180, height: 180, fit: BoxFit.contain,
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8CFBA), width: 2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFC0B080), fontWeight: FontWeight.w600),
          border: InputBorder.none,
        ),
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3A2810)),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8CFBA), width: 2),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: 'Mot de passe',
          hintStyle: const TextStyle(color: Color(0xFFC0B080), fontWeight: FontWeight.w600),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3A2810)),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPseudoScreen()),
      ),
      child: const Text(
        "Pas encore de compte ? Inscris-toi ici",
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton adresse email')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton mot de passe')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
<<<<<<< HEAD
      // Sur le web : connexion via Supabase (SQLite web est optionnel)
      if (kIsWeb) {
        await _loginViaSupabase(pseudo);
        return;
      }

      // 1. Chercher localement — login simple sans PIN
      final userMap = await DatabaseHelper.instance.getUserByPseudo(pseudo);
      if (userMap != null) {
        await _loginWithMap(userMap);
        return;
      }
=======
      // 1. Connexion Supabase Auth
      final response = await SupabaseService.signInWithPassword(
        email: email,
        password: password,
      );
      final supabaseUser = response.user;
      if (supabaseUser == null) throw Exception('Connexion échouée');
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612

      final uuid = supabaseUser.id;

      // 2. Vérifier si l'utilisateur existe localement
      final db = await DatabaseHelper.instance.database;
      final localRows = await db.query('users', where: 'uuid = ?', whereArgs: [uuid]);

      if (localRows.isEmpty) {
        // Récupérer le profil depuis Supabase
        try {
          final remoteData = await SupabaseService.client
              .from('users')
              .select()
              .eq('uuid', uuid)
              .maybeSingle();
          if (remoteData != null) {
            final userModel = UserModel.fromMap({
              ...remoteData,
              'is_guest': 0,
              'created_at': remoteData['created_at'] ?? DateTime.now().toIso8601String(),
            });
            await db.insert('users', userModel.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } catch (e) {
          debugPrint('Erreur récupération profil Supabase: $e');
        }
      }

      // 3. Sauvegarder l'UUID en local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_uuid', uuid);

      // 4. Synchroniser depuis le cloud
      try {
        await SyncService.instance.syncAllFromCloud(uuid);
      } catch (e) {
        debugPrint('Sync échouée (hors-ligne probable): $e');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (msg.contains('Invalid login credentials')) {
          msg = 'Email ou mot de passe incorrect.';
        } else if (msg.contains('Email not confirmed')) {
          msg = 'Vérifie ta boîte mail pour confirmer ton compte.';
        }
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
<<<<<<< HEAD

  /// Connexion navigateur (Chrome) — pseudo trouvé sur Supabase.
  Future<void> _loginViaSupabase(String pseudo) async {
    try {
      final remoteData = await SupabaseService.client
          .from('users')
          .select()
          .eq('pseudo', pseudo)
          .maybeSingle();

      if (remoteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pseudo inconnu. Crée un compte ou vérifie l\'orthographe.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final userModel = UserModel.fromMap({
        ...remoteData,
        'created_at': remoteData['created_at'] ?? DateTime.now().toIso8601String(),
        'is_guest': 0,
      });

      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('users', userModel.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Cache local web ignoré: $e');
      }

      await _loginWithMap(userModel.toMap());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur connexion: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithMap(Map<String, dynamic> userMap) async {
    final uuid = userMap['uuid'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_uuid', uuid);

    try {
      await SyncService.instance.syncAllFromCloud(uuid);
    } catch (e) {
      debugPrint('Sync échouée (hors-ligne probable): $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _clearPin() {
    for (final c in _pinControllers) {
      c.clear();
    }
    _pinFocusNodes[0].requestFocus();
  }
=======
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
}
