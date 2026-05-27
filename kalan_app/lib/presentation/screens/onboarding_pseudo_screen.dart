import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import 'package:kalan_app/data/models/user_model.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/kalan_button.dart';
import 'home_screen.dart';

String _hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

class OnboardingPseudoScreen extends StatefulWidget {
  final Map<String, dynamic>? registrationData;

  const OnboardingPseudoScreen({
    super.key,
    this.registrationData,
  });

  @override
  State<OnboardingPseudoScreen> createState() => _OnboardingPseudoScreenState();
}

class _OnboardingPseudoScreenState extends State<OnboardingPseudoScreen> {
  final TextEditingController _pseudoController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _pinConfirmControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _pinConfirmFocusNodes =
      List.generate(6, (_) => FocusNode());

  int _step = 1; // 1 = Pseudo, 2 = Avatar, 3 = PIN
  int _selectedAvatar = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _pseudoController.dispose();
    for (final c in _pinControllers) { c.dispose(); }
    for (final c in _pinConfirmControllers) { c.dispose(); }
    for (final f in _pinFocusNodes) { f.dispose(); }
    for (final f in _pinConfirmFocusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _pin => _pinControllers.map((c) => c.text).join();
  String get _pinConfirm => _pinConfirmControllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (_step == 1) _buildLogo(),
              if (_step == 2) _buildAvatarPreview(),
              if (_step == 3) _buildPinIcon(),
              const SizedBox(height: 35),
              Text(
                _step == 1
                    ? 'Choisis ton pseudo'
                    : _step == 2
                        ? 'Choisis ton avatar'
                        : 'Crée ton code secret',
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
                        : "Ce code PIN à 6 chiffres te permettra de récupérer ton compte si tu changes de téléphone. Note-le bien !",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A7A58),
                ),
              ),
              const SizedBox(height: 24),
              if (_step == 1) _buildInputBox('Ton pseudo'),
              if (_step == 2) _buildAvatarGrid(),
              if (_step == 3) _buildPinStep(),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                KalanButton(
                  text: _step == 1
                      ? 'Suivant'
                      : _step == 2
                          ? 'Suivant'
                          : 'Commencer mon aventure',
                  onPressed: _step == 1
                      ? _goToStep2
                      : _step == 2
                          ? () => setState(() => _step = 3)
                          : _handleStartAventure,
                ),
              if (_step > 1)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Retour',
                      style: TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold)),
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

  Widget _buildPinIcon() {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_rounded, size: 50, color: AppColors.primary),
    );
  }

  Widget _buildInputBox(String hint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: TextField(
        controller: _pseudoController,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
          border: InputBorder.none,
        ),
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
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
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey),
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

  Widget _buildPinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ton code PIN',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF555555))),
        const SizedBox(height: 10),
        _buildPinRow(_pinControllers, _pinFocusNodes, isConfirm: false),
        const SizedBox(height: 24),
        const Text('Confirme ton code PIN',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF555555))),
        const SizedBox(height: 10),
        _buildPinRow(_pinConfirmControllers, _pinConfirmFocusNodes, isConfirm: true),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Note ce PIN précieusement ! Sans lui, tu ne pourras pas récupérer ton compte sur un nouveau téléphone.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinRow(List<TextEditingController> controllers,
      List<FocusNode> focusNodes, {required bool isConfirm}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 46, height: 54,
          child: TextField(
            controller: controllers[i],
            focusNode: focusNodes[i],
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
                borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                focusNodes[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                focusNodes[i - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
    );
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

  Future<void> _handleStartAventure() async {
    final pseudo = _pseudoController.text.trim();

    // Validation PIN
    if (_pin.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre les 6 chiffres de ton PIN')),
      );
      return;
    }
    if (_pin != _pinConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Les deux codes ne correspondent pas !'),
            backgroundColor: Colors.red),
      );
      // Effacer les champs de confirmation
      for (final c in _pinConfirmControllers) { c.clear(); }
      _pinConfirmFocusNodes[0].requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Vérification d'unicité locale
      final existingLocal = await DatabaseHelper.instance.getUserByPseudo(pseudo);
      if (existingLocal != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ce pseudo est déjà pris localement !'),
                backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // 2. Vérification d'unicité distante
      try {
        final existingRemote = await SupabaseService.client
            .from('users')
            .select('uuid')
            .eq('pseudo', pseudo)
            .maybeSingle();
        if (existingRemote != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Ce pseudo est déjà pris, choisis-en un autre !'),
                  backgroundColor: Colors.red),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      } catch (e) {
        debugPrint('Vérification pseudo en ligne échouée (hors-ligne probable): $e');
      }

      // 3. Créer le compte
      final uuid = const Uuid().v4();
      final pinHash = _hashPin(_pin);

      final userModel = UserModel(
        uuid: uuid,
        pseudo: pseudo,
        avatarId: _selectedAvatar,
        isGuest: false,
        createdAt: DateTime.now(),
        pinHash: pinHash,
      );

      // 4. Sauvegarde SQLite locale
      final db = await DatabaseHelper.instance.database;
      await db.insert('users', userModel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_uuid', uuid);

      // 5. Sauvegarde Supabase
      try {
        await SupabaseService.client.from('users').upsert(userModel.toSupabaseJson());
      } catch (e) {
        debugPrint('Erreur upsert Supabase: $e');
      }

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
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
