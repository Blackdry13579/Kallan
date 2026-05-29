import 'package:flutter/material.dart';

// Constantes de style locales et constantes de compilation pour éviter les erreurs Dart
const Color _primaryColor = Color(0xFF2D6A2D);
const Color _textPrimary = Color(0xFF1F2937);
const Color _textSecondary = Color(0xFF4B5563);
const Color _background = Color(0xFFFDFCF8);

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'À propos de KALAN',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo et Version
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/LOGO-removebg-preview.png',
                width: 80,
                height: 80,
                errorBuilder: (context, _, __) => const Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'KALAN',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _primaryColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Cartes d'information
            _buildInfoCard(
              icon: Icons.lightbulb_outline_rounded,
              title: "Qu'est-ce que KALAN ?",
              content:
                  "KALAN (qui signifie 'apprendre' en Dioula) est le premier cahier numérique intelligent pensé spécifiquement pour l'élève africain.",
              iconColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              icon: Icons.public_rounded,
              title: "Pourquoi a-t-il été créé ?",
              content:
                  "Pour démocratiser l'accès à l'Intelligence Artificielle. KALAN a été conçu pour fonctionner 100% hors ligne afin que les élèves, notamment au Burkina Faso, puissent réviser partout sans se soucier des connexions Internet capricieuses ou coûteuses.",
              iconColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 16),

            _buildStepsCard(),
            const SizedBox(height: 16),

            _buildInfoCard(
              icon: Icons.trending_up_rounded,
              title: "Comment il peut t'aider ?",
              content:
                  "Gagne un temps précieux dans tes révisions, retiens tes leçons sur le long terme et améliore tes résultats scolaires grâce à une méthode d'apprentissage espacée prouvée scientifiquement.",
              iconColor: const Color(0xFF10B981),
            ),

            const SizedBox(height: 40),
            const Text(
              'Développé avec ❤️ pour l\'éducation en Afrique.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: _primaryColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: _primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Comment l'utiliser ?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStepRow('1', 'Prends tes cours en photo ou importe un PDF.'),
          const SizedBox(height: 12),
          _buildStepRow('2', 'L\'IA extrait le texte et crée tes Flashcards.'),
          const SizedBox(height: 12),
          _buildStepRow('3', 'Révise régulièrement pour ne plus rien oublier.'),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: _primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
