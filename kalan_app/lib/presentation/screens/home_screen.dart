import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../ai/model_downloader.dart';
import '../../core/constants/app_colors.dart';
import '../../services/ocr_service.dart';
import '../../services/pdf_service.dart';
import '../../services/presence_service.dart';
import '../../services/battle_invite_service.dart';
import '../blocs/deck/deck_bloc.dart';
import '../blocs/deck/deck_event.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_event.dart';
import '../blocs/badge/badge_bloc.dart';
import '../blocs/badge/badge_event.dart';
import 'home_dashboard.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'create_deck_screen.dart';
import 'camera_ocr_screen.dart';
import 'generating_screen.dart';
import 'offline_context_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();

  static HomeScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeScreenState>();
  }
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ── Téléchargement IA offline ──────────────────────────────────────
  double? _aiDownloadProgress; // null = pas de DL, 0..1 = en cours, -1 = erreur
  StreamSubscription<double>? _aiDownloadSub;

  void changeTab(int index) => setState(() => _currentIndex = index);

  final OCRService _ocrService = OCRService();

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserProfile());
    context.read<BadgeBloc>().add(CheckNewBadges());
    if (kIsWeb) {
      context.read<DeckBloc>().add(const LoadDecks());
    }
    PresenceService.startHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOfflineAI());
  }

  @override
  void dispose() {
    _aiDownloadSub?.cancel();
    _ocrService.dispose();
    super.dispose();
  }

  // ── Vérification au démarrage ──────────────────────────────────────
  Future<void> _checkOfflineAI() async {
    if (kIsWeb) return;
    final isInstalled = await ModelDownloader.isModelDownloaded();
    if (isInstalled || !mounted) return;
    _showOfflineAIDialog();
  }

  void _showOfflineAIDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF5F2EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'IA hors-ligne non installée',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pour générer des flashcards sans connexion internet, installe le modèle IA Qwen2.5 (~986 Mo) sur ton téléphone.\n\nLe téléchargement se fera en arrière-plan — tu pourras continuer à utiliser KALAN normalement.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.black54, height: 1.55),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startBackgroundDownload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text(
                  'J\'accepte — Télécharger',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Plus tard',
                  style: TextStyle(
                      color: Colors.black45, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Téléchargement en arrière-plan ─────────────────────────────────
  void _startBackgroundDownload() {
    setState(() => _aiDownloadProgress = 0.0);
    _aiDownloadSub?.cancel();
    _aiDownloadSub = ModelDownloader.downloadModel().listen(
      (progress) {
        if (!mounted) return;
        if (progress < 0) {
          // Erreur
          setState(() => _aiDownloadProgress = -1.0);
          _aiDownloadSub?.cancel();
          return;
        }
        setState(() => _aiDownloadProgress = progress);
        if (progress >= 1.0) {
          // Succès
          _aiDownloadSub?.cancel();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _aiDownloadProgress = null);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ IA hors-ligne installée avec succès !'),
              backgroundColor: Color(0xFF2D6A2D),
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      onError: (_) {
        if (mounted) setState(() => _aiDownloadProgress = -1.0);
      },
    );
  }

  // ── Bannière de progression ────────────────────────────────────────
  Widget _buildDownloadBanner() {
    final progress = _aiDownloadProgress;
    if (progress == null) return const SizedBox.shrink();

    final bool isError = progress < 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: isError
          ? Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Échec du téléchargement',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.red),
                  ),
                ),
                GestureDetector(
                  onTap: _startBackgroundDownload,
                  child: const Text('Réessayer',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D6A2D))),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _aiDownloadProgress = null),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.red),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Téléchargement IA hors-ligne...',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D6A2D)),
                      ),
                    ),
                    Text(
                      progress >= 1.0 ? '✅' : '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D6A2D)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFD0E8C4),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF2D6A2D)),
                  ),
                ),
              ],
            ),
    );
  }

  final List<Widget> _screens = [
    const HomeDashboard(),
    const LibraryScreen(),
    const CreateDeckScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserLoaded) {
          final userId = state.profile['uuid'] as String? ?? 'guest';
          context.read<NotificationBloc>().add(LoadNotifications(userId));
          if (userId != 'guest') {
            BattleInviteService.instance.start(userId);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            _buildDownloadBanner(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BlocBuilder<UserBloc, UserState>(
                builder: (context, state) {
                  return Row(
                    children: [
                      _buildNavTab(
                          0, 'assets/icons/bottom/home.png', 'Accueil'),
                      _buildNavTab(
                          1, 'assets/icons/bottom/librairie.png', 'Librairie'),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showCreateOptions(context),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/icons/bottom/+.png',
                                height: 22,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildNavTab(
                          3, 'assets/icons/bottom/classement.png', 'Niveau'),
                      _buildProfileNavTab(4, state),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Créer une nouvelle fiche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),
            _createOptionItem(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF2D6A2D),
              title: 'Scanner un cours',
              subtitle: 'Prendre une photo de tes notes',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CameraOCRScreen()));
              },
            ),
            const SizedBox(height: 12),
            _createOptionItem(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFE24B4A),
              title: 'Importer un PDF',
              subtitle: 'Max 5 pages · Génère des fiches auto',
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndProcessPDF();
              },
            ),
            const SizedBox(height: 12),
            _createOptionItem(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF185FA5),
              title: 'Importer une image',
              subtitle: 'Depuis ta galerie photos',
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndProcessImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessPDF() async {
    bool dialogShown = false;
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;
      if (!mounted) return;

      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await File(result.files.single.path!).readAsBytes();
      final analysis = await PdfService().analyze(bytes: bytes);

      if (!mounted) return;
      Navigator.pop(context);
      dialogShown = false;

      if (analysis.text.trim().isEmpty) {
        final detail = analysis.likelyScanned
            ? 'Ce PDF semble être scanné ou composé d\'images. On ajoutera l\'OCR PDF dans l\'étape suivante.'
            : 'Aucun texte exploitable trouvé dans ce PDF.';
        ScaffoldMessenger.of(context).showSnackBar(
<<<<<<< HEAD
          const SnackBar(
              content: Text(
                  'Aucun texte trouvé dans ce PDF (PDF scanné non supporté)')),
=======
          SnackBar(content: Text(detail), duration: const Duration(seconds: 5)),
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
        );
        return;
      }

<<<<<<< HEAD
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => GeneratingScreen(ocrText: text)));
=======
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfflineContextScreen(
            ocrText: analysis.text,
            detectedSubject: _detectSubjectFromPdfAnalysis(analysis),
            documentContext: analysis.aiContext,
            showOfflineBadge: false,
          ),
        ),
      );
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    } catch (e) {
      if (mounted) {
        if (dialogShown) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import PDF : $e')),
        );
      }
    }
  }

  String _detectSubjectFromPdfAnalysis(PdfAnalysis analysis) {
    final lower = analysis.text.toLowerCase();
    if (lower.contains('plante') ||
        lower.contains('oxygène') ||
        lower.contains('oxygen') ||
        lower.contains('photosynthèse') ||
        lower.contains('cellule') ||
        lower.contains('molécule') ||
        lower.contains('équation') ||
        lower.contains('force') ||
        lower.contains('vitesse')) {
      return 'Sciences';
    }
    if (lower.contains('poème') ||
        lower.contains('roman') ||
        lower.contains('grammaire') ||
        lower.contains('auteur')) {
      return 'Français';
    }
    if (lower.contains('histoire') ||
        lower.contains('géographie') ||
        lower.contains('empire') ||
        lower.contains('climat')) {
      return 'Histoire-Géo';
    }
    if (analysis.detectedLanguage == 'anglais' ||
        lower.contains('english') ||
        lower.contains('vocabulary')) {
      return 'Langues';
    }
    return 'Autre';
  }

  Future<void> _pickAndProcessImage() async {
    bool dialogShown = false;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      if (!mounted) return;

      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final text = await _ocrService.extractText(image.path);

      if (!mounted) return;
      Navigator.pop(context);
      dialogShown = false;

      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun texte détecté dans cette image')),
        );
        return;
      }

      Navigator.push(context,
          MaterialPageRoute(builder: (_) => GeneratingScreen(ocrText: text)));
    } catch (e) {
      if (mounted) {
        if (dialogShown) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import image : $e')),
        );
      }
    }
  }

  Widget _createOptionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavTab(int index, UserState state) {
    final isSelected = _currentIndex == index;
    final avatarId = state is UserLoaded ? state.profile['avatar_id'] : null;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 30 : 26,
              height: isSelected ? 30 : 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  avatarId != null
                      ? 'assets/avatars/avatar$avatarId.png'
                      : 'assets/avatars/avatar1.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                      color:
                          isSelected ? AppColors.primary : Colors.grey.shade500,
                      size: 16),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
<<<<<<< HEAD
              decoration: const BoxDecoration(
=======
              decoration: BoxDecoration(
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, String imagePath, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.40,
              duration: const Duration(milliseconds: 200),
              child: Image.asset(
                imagePath,
                height: isSelected ? 26 : 22,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PEINTRE DU NOTCH GLISSANT
// ═══════════════════════════════════════════
class _SlidingNotchPainter extends CustomPainter {
  final double notchCenterX;
  final Color backgroundColor;

  _SlidingNotchPainter({
    required this.notchCenterX,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();
    const double topRadius = 20;
    const double notchHalfWidth = 38.0;
    const double notchDepth = 22.0;

    // Coin supérieur gauche arrondi
    path.moveTo(0, topRadius);
    path.quadraticBezierTo(0, 0, topRadius, 0);

    // Ligne jusqu'au début du notch
    final double notchStart = notchCenterX - notchHalfWidth;
    final double notchEnd = notchCenterX + notchHalfWidth;

    path.lineTo(notchStart, 0);

    // Courbe d'entrée du notch (descend doucement)
    path.cubicTo(
      notchCenterX - notchHalfWidth * 0.55,
      0,
      notchCenterX - notchHalfWidth * 0.45,
      notchDepth,
      notchCenterX,
      notchDepth,
    );

    // Courbe de sortie du notch (remonte doucement)
    path.cubicTo(
      notchCenterX + notchHalfWidth * 0.45,
      notchDepth,
      notchCenterX + notchHalfWidth * 0.55,
      0,
      notchEnd,
      0,
    );

    // Coin supérieur droit arrondi
    path.lineTo(size.width - topRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);

    // Bas de la barre
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Ombre douce
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 8, true);
    // Barre blanche
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SlidingNotchPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX;
  }
}
