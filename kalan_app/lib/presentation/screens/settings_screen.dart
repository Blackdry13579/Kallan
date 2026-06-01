import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kalan_app/presentation/blocs/sync/sync_bloc.dart';
import 'package:kalan_app/presentation/blocs/sync/sync_event.dart';
import 'package:kalan_app/presentation/blocs/user/user_bloc.dart';
import 'package:kalan_app/presentation/blocs/user/user_event.dart';
import 'package:kalan_app/presentation/screens/login_screen.dart';
import 'package:kalan_app/presentation/screens/about_screen.dart';
import 'package:kalan_app/presentation/screens/model_download_screen.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _dataSaver = false;
  String _language = 'Français';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection('Compte & Profil'),
          _buildSettingsCard([
            _buildSettingTile(Icons.person_outline_rounded, 'Modifier mon profil', 'Pseudo, Avatar', _showEditProfileDialog),
            _buildDivider(),
            _buildSettingTile(Icons.lock_outline_rounded, 'Sécurité', 'Mot de passe, PIN', () {}),
          ]),
          const SizedBox(height: 24),
          _buildSection('Préférences'),
          _buildSettingsCard([
            _buildSwitchTile(Icons.notifications_none_rounded, 'Notifications', 'Alertes de révision', _notifications, (val) => setState(() => _notifications = val)),
            _buildDivider(),
            _buildSettingTile(Icons.language_rounded, 'Langue de l\'application', _language, _showLanguagePicker),
            _buildDivider(),
            _buildSwitchTile(Icons.data_usage_rounded, 'Économie de données', 'Chargement optimisé', _dataSaver, (val) => setState(() => _dataSaver = val)),
          ]),
          const SizedBox(height: 24),
          _buildSection('IA hors ligne'),
          _buildSettingsCard([
            _buildSettingTile(
              Icons.psychology_outlined,
              'IA locale Gemma',
              'Créer des fiches sans internet (~350 Mo)',
              () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
                );
                if (mounted) setState(() {});
              },
              iconColor: AppColors.primary,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Support & Synchronisation'),
          _buildSettingsCard([
            _buildSettingTile(Icons.sync_rounded, 'Forcer la synchronisation', 'Mettre à jour avec le Cloud', () {
              context.read<SyncBloc>().add(ProcessSyncQueue());
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronisation en cours...')));
            }, iconColor: AppColors.primary),
            _buildDivider(),
            _buildSettingTile(Icons.info_outline_rounded, 'À propos de Kalan', 'Version 1.0.0', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            }),
          ]),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.error,
              elevation: 0,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('DÉCONNEXION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.1)),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D8CC), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (iconColor ?? const Color(0xFF854F0B)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor ?? const Color(0xFF854F0B), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF854F0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF854F0B), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 60, color: const Color(0xFFE0D8CC).withValues(alpha: 0.5));
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Français', 'Mooré', 'Dioula', 'Fulfuldé'].map((lang) => ListTile(
            title: Text(lang, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: _language == lang ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _language = lang);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showEditProfileDialog() async {
    final db = await DatabaseHelper.instance.database;
    final users = await db.query('users', limit: 1);
    
    String currentPseudo = 'Eleve KALAN';
    int currentAvatar = 1;
    
    if (users.isNotEmpty) {
      currentPseudo = (users.first['pseudo'] as String?) ?? 'Eleve KALAN';
      currentAvatar = (users.first['avatar_id'] as int?) ?? 1;
    }

    final pseudoController = TextEditingController(text: currentPseudo);
    int selectedAvatar = currentAvatar;

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier mon profil', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pseudoController,
                  decoration: InputDecoration(
                    labelText: 'Pseudo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choisis ton avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final avatarNum = index + 1;
                      final isSelected = selectedAvatar == avatarNum;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedAvatar = avatarNum),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/avatars/avatar$avatarNum.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final newPseudo = pseudoController.text.trim();
                if (newPseudo.isEmpty) return;
                
                context.read<UserBloc>().add(UpdateUserProfile(
                  pseudo: newPseudo,
                  avatarId: selectedAvatar,
                ));

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil mis à jour ✓'), backgroundColor: Color(0xFF2D6A2D)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Es-tu sûre de vouloir te déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, me déconnecter')),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
      }
    }
  }
}

