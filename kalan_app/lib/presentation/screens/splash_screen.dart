import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_carousel_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoOffset;
  late Animation<double> _sloganOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );

    _logoOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.2)).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 1.0, curve: Curves.easeInOut)),
    );

    _sloganOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward().then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_uuid');
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => currentUserId != null
                ? const HomeScreen()
                : const WelcomeCarouselScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SlideTransition(
                  position: _logoOffset,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: Image.asset('assets/images/LOGO-removebg-preview.png', width: 220),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _sloganOpacity,
                  child: Image.asset('assets/images/SLOGAN-removebg-preview.png', width: 200),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
