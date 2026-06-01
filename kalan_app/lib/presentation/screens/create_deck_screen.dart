import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/deck/deck_bloc.dart';
import '../blocs/deck/deck_event.dart';
import '../../services/local_ai_service.dart';

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedSubject = 'Sciences';
  final String _selectedLevel = 'Général';
  bool _isGenerating = false;
  List<Map<String, String>> _generatedCards = [];

  final LocalAIService _aiService = LocalAIService();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generateAI() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le texte du cours')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await _aiService.generateFlashcards(
        text: _contentController.text.trim(),
      );
      setState(() {
        _selectedSubject = result['subject'];
        _generatedCards = (result['flashcards'] as List).cast<Map<String, String>>();
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur IA : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.fredokaTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Nouvelle fiche',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Titre de la fiche'),
                const SizedBox(height: 8),
                _buildTextField('Ex: Les fractions, Guerre mondiale...', _titleController),
                const SizedBox(height: 24),

                const Divider(height: 40),
                _buildLabel('Contenu du cours (pour l\'IA)'),
                const SizedBox(height: 8),
                _buildTextField(
                  'Colle ici le texte de ta leçon pour générer des flashcards automatiquement...',
                  _contentController,
                  maxLines: 6,
                ),
                const SizedBox(height: 16),
                _buildAIButton(),
                if (_generatedCards.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildLabel('Flashcards générées (${_generatedCards.length})'),
                  const SizedBox(height: 12),
                  _buildGeneratedCardsList(),
                ],
                const SizedBox(height: 40),
                _buildSubmitButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D6A2D), width: 1.5)),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Champ obligatoire' : null,
    );
  }

  Widget _buildAIButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateAI,
        icon: _isGenerating 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(_isGenerating ? 'Analyse en cours...' : 'Générer avec l\'IA KALAN'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D6A2D),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildGeneratedCardsList() {
    return Column(
      children: _generatedCards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0D8CC)),
          ),
          child: ListTile(
            title: Text(card['question'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(card['answer'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => setState(() => _generatedCards.removeAt(index)),
            ),
            onTap: () => _editCardDialog(index),
          ),
        );
      }).toList(),
    );
  }

  void _editCardDialog(int index) {
    final qController = TextEditingController(text: _generatedCards[index]['question']);
    final aController = TextEditingController(text: _generatedCards[index]['answer']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la carte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qController, decoration: const InputDecoration(labelText: 'Question')),
            TextField(controller: aController, decoration: const InputDecoration(labelText: 'Réponse')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              setState(() {
                _generatedCards[index] = {
                  'question': qController.text,
                  'answer': aController.text,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Color(0xFF2D6A2D))),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            context.read<DeckBloc>().add(CreateDeck(
              _titleController.text.trim(),
              _selectedSubject,
              _selectedLevel,
              cards: _generatedCards,
            ));
            // Ici on devrait aussi sauvegarder les cartes générées, 
            // mais DeckBloc CreateDeck ne prend que le deck pour l'instant.
            // On supposera qu'une étape de création de cartes suit.
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fiche créée avec succès !'), backgroundColor: Color(0xFF2D6A2D)),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text('Enregistrer la fiche', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() {
    _aiService.unloadModel();
    super.dispose();
  }
}
