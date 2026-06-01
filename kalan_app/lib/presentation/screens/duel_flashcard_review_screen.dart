import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/battle_model.dart' show Battle;
import 'duel_game_screen.dart';

class DuelFlashcardReviewScreen extends StatefulWidget {
  final String opponentName;
  final String? opponentAvatar;
  final int stake;
  final String battleId;
  final Map<String, dynamic>? battleContent;
  final bool isLocalBattle;

  const DuelFlashcardReviewScreen({
    super.key,
    required this.opponentName,
    this.opponentAvatar,
    required this.stake,
    required this.battleId,
    this.battleContent,
    this.isLocalBattle = false,
  });

  @override
  State<DuelFlashcardReviewScreen> createState() => _DuelFlashcardReviewScreenState();
}

class _DuelFlashcardReviewScreenState extends State<DuelFlashcardReviewScreen> {
  List<dynamic> _flashcards = [];
  int _currentIndex = 0;
  Timer? _timer;
  int _secondsLeft = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    try {
      if (widget.battleContent != null && widget.battleContent!['flashcards'] != null) {
        setState(() {
          _flashcards = widget.battleContent!['flashcards'] as List<dynamic>;
          _isLoading = false;
        });
        _startTimer();
        return;
      }

      final response = await Supabase.instance.client
          .from('battles')
          .select('content')
          .eq('id', widget.battleId)
          .single();

      final content = Battle.parseContent(response['content']);
      if (content != null && content['flashcards'] != null) {
        setState(() {
          _flashcards = content['flashcards'];
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Erreur loading flashcards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 10;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    if (_currentIndex < _flashcards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      _goToQuiz();
    }
  }

  void _goToQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DuelGameScreen(
          opponentName: widget.opponentName,
          opponentAvatar: widget.opponentAvatar,
          stake: widget.stake,
          battleId: widget.battleId,
          battleContent: widget.battleContent,
          isLocalBattle: widget.isLocalBattle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (_flashcards.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Aucune flashcard disponible')),
      );
    }

    final currentCard = _flashcards[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Révision (${_currentIndex + 1}/${_flashcards.length})',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFFF43F5E), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '00:${_secondsLeft.toString().padLeft(2, '0')}',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFF43F5E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Flashcard
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    Text(
                      currentCard['question'] ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),
                    Text(
                      currentCard['answer'] ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _flashcards.length,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
