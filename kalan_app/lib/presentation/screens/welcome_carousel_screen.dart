import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/kalan_button.dart';
import 'login_screen.dart';

class WelcomeCarouselScreen extends StatefulWidget {
  const WelcomeCarouselScreen({super.key});

  @override
  State<WelcomeCarouselScreen> createState() => _WelcomeCarouselScreenState();
}

class _WelcomeCarouselScreenState extends State<WelcomeCarouselScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Apprentissage intelligent',
      'description':
          'Révise facilement avec des flashcards et des quiz générés par notre IA — même sans internet.',
      'image': 'assets/images/welcome/enfant.png',
      'imageAsBackground': true,
    },
    {
      'title': 'Joue avec tes amis',
      'description':
          'Défie tes camarades en ligne ou hors ligne via QR code.\nApprends ensemble, où que tu sois !',
      'image': 'assets/images/welcome/quizbattle.png',
      'imageAsBackground': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  if (page['imageAsBackground'] == true) {
                    return _buildBackgroundPage(page);
                  }
                  return _buildNormalPage(page);
                },
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  // Page 1 & 3 : image en haut, texte en bas
  Widget _buildNormalPage(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            page['image']!,
            height: 300,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 36),
          Text(
            page['title']!,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page['description']!,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8A7A58),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Page 2 : image en fond, texte dans une carte en BAS (pas sur le visage)
  Widget _buildBackgroundPage(Map<String, dynamic> page) {
    return Stack(
      children: [
        // Image de fond plein écran
        Positioned.fill(
          child: Image.asset(
            page['image']!,
            fit: BoxFit.cover,
          ),
        ),
        // Gradient du bas vers le haut pour lisibilité du texte
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 0.65, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        // Texte collé en bas, au-dessus du gradient
        Positioned(
          left: 28,
          right: 28,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                page['title']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page['description']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          // Indicateurs de page
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Bouton vert léger style hover leaderboard
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF2D6A2D),
                elevation: 0,
                shadowColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFF2D6A2D), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? 'Commencer mon aventure' : 'Suivant',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D6A2D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

