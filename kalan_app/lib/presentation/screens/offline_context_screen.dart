import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'generating_screen.dart';

class OfflineContextScreen extends StatefulWidget {
  final String ocrText;
  final String detectedSubject;

  const OfflineContextScreen({
    super.key,
    required this.ocrText,
    required this.detectedSubject,
  });

  @override
  State<OfflineContextScreen> createState() => _OfflineContextScreenState();
}

class _OfflineContextScreenState extends State<OfflineContextScreen> {
  late String _selectedSubject;
  final TextEditingController _contextController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> _subjects = [
    'Mathématiques', 'SVT', 'Physique-Chimie', 'Informatique',
    'Français', 'Histoire-Géo', 'Anglais', 'Autre',
  ];

  static const Map<String, String> _subjectEmojis = {
    'Mathématiques': '📐',
    'SVT': '🌿',
    'Physique-Chimie': '⚗️',
    'Informatique': '💻',
    'Français': '📝',
    'Histoire-Géo': '🌍',
    'Anglais': '🗣️',
    'Autre': '📚',
  };

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjects.contains(widget.detectedSubject)
        ? widget.detectedSubject
        : 'Autre';
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contextController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _generate() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GeneratingScreen(
          ocrText: widget.ocrText,
          userSubject: _selectedSubject,
          userContext: _contextController.text.trim().isEmpty
              ? null
              : _contextController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF9F4),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildInfoBanner(),
                      const SizedBox(height: 28),
                      _buildSubjectSection(),
                      const SizedBox(height: 24),
                      _buildContextSection(),
                      const SizedBox(height: 32),
                      _buildGenerateButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEAE3), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aide l\'IA à mieux comprendre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xFFE65100)),
                SizedBox(width: 5),
                Text(
                  'Hors ligne',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFE65100), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sans internet, le contexte améliore tout',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Indique la matière et décris brièvement ton sujet — l\'IA locale Gemma génèrera des fiches bien plus pertinentes.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Matière',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 3),
        const Text(
          'Quelle est la matière de ce cours ?',
          style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjects.map((subject) {
            final isSelected = _selectedSubject == subject;
            final emoji = _subjectEmojis[subject] ?? '📚';
            return GestureDetector(
              onTap: () => setState(() => _selectedSubject = subject),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1565C0) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFE5E1DA),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.20), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Contexte',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Facultatif',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'En quelques lignes, de quoi parle ce texte ?',
          style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focusNode.hasFocus ? const Color(0xFF1565C0) : const Color(0xFFE5E1DA),
              width: _focusNode.hasFocus ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
          ),
          child: TextField(
            controller: _contextController,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A), height: 1.5),
            decoration: const InputDecoration(
              hintText: 'Ex : Cours de SVT sur la photosynthèse, niveau lycée. Le texte explique le rôle des chloroplastes dans la production d\'énergie...',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), height: 1.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Preview du texte scanné
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.document_scanner_rounded, size: 14, color: Color(0xFFAAAAAA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.ocrText.length > 120
                      ? '${widget.ocrText.substring(0, 120).trim()}...'
                      : widget.ocrText,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888), height: 1.4, fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D6A2D),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20),
            SizedBox(width: 10),
            Text(
              'Générer mes flashcards',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
