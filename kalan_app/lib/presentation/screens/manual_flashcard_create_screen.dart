import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../services/local_ai_service.dart';
import 'package:uuid/uuid.dart';

class ManualFlashcardCreateScreen extends StatefulWidget {
  final String extractedText;

  const ManualFlashcardCreateScreen({super.key, required this.extractedText});

  @override
  State<ManualFlashcardCreateScreen> createState() => _ManualFlashcardCreateScreenState();
}

class _ManualFlashcardCreateScreenState extends State<ManualFlashcardCreateScreen> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _isSaving = false;
  bool _isGenerating = false;
  final Uuid _uuid = const Uuid();
  final LocalAIService _ai = LocalAIService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Créer tes fiches')),
      body: Row(
        children: [
          // Panneau de gauche : Texte extrait (lecture seule)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  const Text('Texte extrait (OCR) :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(widget.extractedText),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Panneau de droite : Éditeur
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Titre du Deck')),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionController,
                          decoration: const InputDecoration(labelText: 'Question ou phrase'),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Générer la réponse via l\'IA',
                        child: Material(
                          color: const Color(0xFF2D6A2D),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _isGenerating ? null : _generateWithAI,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _isGenerating
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _answerController, decoration: const InputDecoration(labelText: 'Réponse'), maxLines: 3),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveFlashcard,
                    child: _isSaving ? const CircularProgressIndicator() : const Text('Enregistrer la fiche'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateWithAI() async {
    final input = _questionController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tape une question ou une phrase d\'abord.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final notes = widget.extractedText.trim().isNotEmpty ? widget.extractedText : null;
      final result = await _ai.generateSingleFlashcard(input: input, notes: notes)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final answer = result['answer'];
      final warning = result['warning'];

      if (warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $warning — vérifie la réponse manuellement.')),
        );
      }

      if (answer != null) {
        _questionController.text = result['question'] ?? input;
        _answerController.text = answer.toString();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'IA n\'a pas pu trouver de réponse. Essaie avec plus de notes.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau — vérifie ta connexion.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveFlashcard() async {
    setState(() => _isSaving = true);
    
    try {
      final String deckUuid = _uuid.v4();
      final deckData = {
        'uuid': deckUuid,
        'user_id': 'local_user', // À ajuster selon gestion utilisateur
        'title': _titleController.text,
        'subject': 'Autre',
        'is_synced': 0, // Flag pour synchro ultérieure
      };
      
      final cardData = {
        'uuid': _uuid.v4(),
        'deck_id': deckUuid,
        'question': _questionController.text,
        'answer': _answerController.text,
        'is_synced': 0,
      };
      
      await DatabaseHelper.instance.insertDeck(deckData);
      await DatabaseHelper.instance.insertFlashcard(cardData);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche enregistrée localement !')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
