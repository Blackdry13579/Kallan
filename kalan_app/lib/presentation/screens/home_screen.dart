import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../services/ocr_service.dart';
import '../../services/presence_service.dart';
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

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  final OCRService _ocrService = OCRService();

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserProfile());
    context.read<BadgeBloc>().add(CheckNewBadges());
    PresenceService.startHeartbeat();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
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
          final userId = state.profile['uuid'] ?? 'guest';
          context.read<NotificationBloc>().add(LoadNotifications(userId));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = MediaQuery.of(context).size.width;
                      final itemWidth = width / 5;
                      double notchCenterX;
                      if (_currentIndex < 2) {
                        notchCenterX = itemWidth * _currentIndex + itemWidth / 2;
                      } else if (_currentIndex > 2) {
                        notchCenterX = itemWidth * _currentIndex + itemWidth / 2;
                      } else {
                        notchCenterX = width / 2;
                      }
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: notchCenterX),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        builder: (context, animatedX, child) {
                          return CustomPaint(
                            size: Size(width, 70),
                            painter: _SlidingNotchPainter(
                              notchCenterX: animatedX,
                              backgroundColor: Colors.white,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: BlocBuilder<UserBloc, UserState>(
                    builder: (context, state) {
                      return Row(
                        children: [
                          _buildNavTab(0, Icons.home_rounded, 'Accueil'),
                          _buildNavTab(1, Icons.menu_book_rounded, 'Librairie'),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showCreateOptions(context),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.3),
                                          AppColors.primary,
                                        ],
                                        radius: 0.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildNavTab(3, Icons.emoji_events_rounded, 'Niveau'),
                          _buildProfileNavTab(4, state),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Créer une nouvelle fiche',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                _createOptionItem(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF2D6A2D),
                  title: 'Scanner un cours',
                  subtitle: 'Prendre une photo de tes notes',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraOCRScreen()));
                  },
                ),
                const SizedBox(height: 16),
                _createOptionItem(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFE24B4A),
                  title: 'Importer un PDF',
                  subtitle: 'Générer depuis un document',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndProcessPDF();
                  },
                ),
                const SizedBox(height: 16),
                _createOptionItem(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF185FA5),
                  title: 'Importer une image',
                  subtitle: 'Depuis ta galerie photos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraOCRScreen()));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curvedAnim),
          child: child,
        );
      },
    );
  }

  Future<void> _pickAndProcessPDF() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final text = await _ocrService.extractTextFromPDF(result.files.single.path!);
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        if (text.trim().isEmpty || text.contains('Erreur')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'extraire le texte du PDF')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GeneratingScreen(ocrText: text),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'import : $e')),
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                transform: Matrix4.translationValues(0, isSelected ? -14 : 0, 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSelected ? 44 : 32,
                  height: isSelected ? 44 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 2)
                        : Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarId != null
                          ? 'assets/avatars/avatar$avatarId.png'
                          : 'assets/avatars/avatar1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        color: isSelected ? AppColors.primary : Colors.grey.shade500,
                        size: isSelected ? 24 : 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedOpacity(
                opacity: isSelected ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'Profil',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône qui monte quand sélectionnée
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                transform: Matrix4.translationValues(
                  0,
                  isSelected ? -14 : 0,
                  0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSelected ? 44 : 32,
                  height: isSelected ? 44 : 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isSelected ? AppColors.primary : Colors.grey.shade500,
                      size: isSelected ? 24 : 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Label qui disparaît quand actif
              AnimatedOpacity(
                opacity: isSelected ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
      notchCenterX - notchHalfWidth * 0.55, 0,
      notchCenterX - notchHalfWidth * 0.45, notchDepth,
      notchCenterX, notchDepth,
    );

    // Courbe de sortie du notch (remonte doucement)
    path.cubicTo(
      notchCenterX + notchHalfWidth * 0.45, notchDepth,
      notchCenterX + notchHalfWidth * 0.55, 0,
      notchEnd, 0,
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
