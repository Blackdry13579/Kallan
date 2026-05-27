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
      'title': 'Bienvenue sur KALAN',
      'description': 'Ton compagnon d\'apprentissage intelligent qui t\'accompagne partout, même sans connexion.',
      'image': 'assets/images/welcome/enfant.png',
      'isBackground': false,
    },
    {
      'title': 'Apprentissage intelligent',
      'description': 'Réviser de manière simple et efficace avec des flashcards et des quiz avec notre IA hors ligne',
      'image': 'assets/images/welcome/enfant.png',
      'isBackground': true,
      'buttonColor': Colors.blue,
    },
    {
      'title': 'Bataille de Quiz',
      'description': 'Un endroit pour défier vos amis en apprenant ensemble !',
      'image': 'assets/images/welcome/quizbattle.png',
      'isBackground': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final isBackground = page['isBackground'] == true;

                  return Stack(
                    children: [
                      if (isBackground)
                        Positioned.fill(
                          child: Image.asset(page['image']!, fit: BoxFit.cover),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: isBackground ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            if (!isBackground) ...[
                              Image.asset(page['image']!, height: 350, fit: BoxFit.contain),
                              const SizedBox(height: 40),
                            ] else 
                              const SizedBox(height: 100),
                            Text(
                              page['title']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: isBackground ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page['description']!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: isBackground ? Colors.white70 : const Color(0xFF8A7A58),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
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
                  const SizedBox(height: 40),
                  KalanButton(
                    backgroundColor: _pages[_currentPage]['buttonColor'] ?? AppColors.primary,
                    text: _currentPage == _pages.length - 1 ? 'Commencer mon aventure' : 'Suivant',
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
