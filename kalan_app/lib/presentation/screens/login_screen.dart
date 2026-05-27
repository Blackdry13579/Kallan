import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import 'package:kalan_app/data/models/user_model.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:kalan_app/services/sync_service.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/kalan_button.dart';
import 'home_screen.dart';
import 'onboarding_pseudo_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

String _hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pseudoController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _recoveryMode = false;

  String get _pin => _pinControllers.map((c) => c.text).join();

  @override
  void dispose() {
    _pseudoController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
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
              Text(
                _recoveryMode
                    ? 'Entre ton pseudo et ton code PIN pour récupérer ton compte.'
                    : 'Connecte-toi avec ton pseudo pour continuer ton aventure.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A7A58),
                ),
              ),
              const SizedBox(height: 32),
              _buildInputBox('Ton pseudo'),
              if (_recoveryMode) ...[
                const SizedBox(height: 20),
                _buildPinSection(),
              ],
              const SizedBox(height: 28),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                KalanButton(
                  text: 'Se connecter',
                  onPressed: _handleLogin,
                ),
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
      width: 180,
      height: 180,
      fit: BoxFit.contain,
    );
  }

  Widget _buildInputBox(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8CFBA), width: 2),
      ),
      child: TextField(
        controller: _pseudoController,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFC0B080), fontWeight: FontWeight.w600),
          border: InputBorder.none,
        ),
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3A2810)),
      ),
    );
  }

  Widget _buildPinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Code PIN (6 chiffres)',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF555555)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 54,
              child: TextField(
                controller: _pinControllers[i],
                focusNode: _pinFocusNodes[i],
                textAlign: TextAlign.center,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey[300]!, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                ),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900),
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) {
                    _pinFocusNodes[i + 1].requestFocus();
                  } else if (val.isEmpty && i > 0) {
                    _pinFocusNodes[i - 1].requestFocus();
                  }
                  setState(() {});
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OnboardingPseudoScreen(),
          ),
        );
      },
      child: const Text(
        'Pas encore de compte ? Inscris-toi ici',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final pseudo = _pseudoController.text.trim();
    if (pseudo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton pseudo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Chercher localement — login simple sans PIN
      final userMap = await DatabaseHelper.instance.getUserByPseudo(pseudo);
      if (userMap != null) {
        await _loginWithMap(userMap);
        return;
      }

      // 2. Pas trouvé localement → mode récupération
      if (!_recoveryMode) {
        // Afficher les champs PIN pour la récupération
        if (mounted) {
          setState(() {
            _recoveryMode = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte non trouvé sur ce téléphone. Entre ton PIN pour récupérer ton compte.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // 3. Mode récupération actif → vérifier PIN + Supabase
      if (_pin.length < 6) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entre les 6 chiffres de ton PIN')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

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
                  content: Text('Pseudo inconnu, crée un compte'),
                  backgroundColor: Colors.red),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        final remoteHash = remoteData['pin_hash'] as String?;
        if (remoteHash == null || _hashPin(_pin) != remoteHash) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Code PIN incorrect'),
                  backgroundColor: Colors.red),
            );
            _clearPin();
            setState(() => _isLoading = false);
          }
          return;
        }

        // PIN validé → sauvegarder localement et connecter
        final userModel = UserModel.fromMap({
          ...remoteData,
          'created_at': remoteData['created_at'] ?? DateTime.now().toIso8601String(),
          'is_guest': 0,
        });
        final db = await DatabaseHelper.instance.database;
        await db.insert('users', userModel.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        await _loginWithMap(userModel.toMap());
      } catch (e) {
        debugPrint('Erreur récupération Supabase: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Impossible de récupérer le compte. Vérifie ta connexion.')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
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
}
