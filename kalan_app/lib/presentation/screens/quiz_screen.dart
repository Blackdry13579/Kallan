import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/flashcard.dart';
import '../blocs/flashcard/flashcard_bloc.dart';
import '../blocs/flashcard/flashcard_event.dart';
import '../blocs/flashcard/flashcard_state.dart';
import '../blocs/quiz/quiz_bloc.dart';
import '../blocs/quiz/quiz_event.dart';
import '../blocs/quiz/quiz_state.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../../../services/audio_service.dart';
import '../../../services/celebration_coordinator.dart';
import '../../../services/celebration_gate.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String? deckUuid;
  final String deckTitle;
  const QuizScreen({super.key, this.deckUuid, this.deckTitle = 'Quiz'});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _totalCorrect = 0;
  int _totalAnswered = 0;
  final DateTime _startTime = DateTime.now();
  List<Map<String, dynamic>> _quizQuestions = [];
  bool _isLoading = true;
  
  Timer? _timer;
  int _secondsRemaining = 15;
  int? _selectedIndex;
  bool _isAnswered = false;
  String? _xpFeedback;
  Color _xpFeedbackColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    CelebrationGate.enter();
    if (widget.deckUuid != null) {
      context.read<FlashcardBloc>().add(LoadFlashcards(widget.deckUuid!));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CelebrationGate.exit();
    CelebrationCoordinator.flushPending();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 15;
      _isAnswered = false;
      _selectedIndex = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _timer?.cancel();
    AudioService().play('wrong'); // Son pour erreur/timeout
    // On déplace la question à la fin
    setState(() {
      final currentQuestion = _quizQuestions.removeAt(_currentQuestionIndex);
      _quizQuestions.add(currentQuestion);
      // On ne change pas l'index car la question suivante prend la place de l'actuelle
      // Sauf si on était à la dernière, l'index reste le même mais pointe sur la nouvelle dernière
      if (_currentQuestionIndex >= _quizQuestions.length) {
        _currentQuestionIndex = 0;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Temps écoulé ! On y réfléchira plus tard.'),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _startTimer();
    });
  }

  void _generateQuiz(List<Flashcard> cards) {
    if (cards.isEmpty) return;
    
    final List<Map<String, dynamic>> questions = [];

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final List<String> options = [card.answer];
      
      final otherAnswers = cards.where((c) => c.uuid != card.uuid).map((c) => c.answer).toList();
      otherAnswers.shuffle();
      
      options.addAll(otherAnswers.take(3));

      while (options.length < 4) {
        options.add('Réponse ${options.length + 1}');
      }

      options.shuffle();
      
      questions.add({
        'q': card.question,
        'options': options,
        'a': options.indexOf(card.answer),
        'original_card_uuid': card.uuid,
      });
    }

    // Mélanger les questions pour un ordre aléatoire
    questions.shuffle();

    setState(() {
      _quizQuestions = questions;
      _isLoading = false;
    });
    
    if (questions.isNotEmpty) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlashcardBloc, FlashcardState>(
      listener: (context, state) {
        if (state is FlashcardLoaded &&
            widget.deckUuid != null &&
            state.deckUuid == widget.deckUuid) {
          _generateQuiz(state.cards);
        } else if (state is FlashcardError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: BlocListener<QuizBloc, QuizState>(
        listener: (context, state) {
          if (state is QuizSubmitted) {
            context.read<UserBloc>().add(LoadUserProfile());
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => QuizResultScreen(
                  score: _totalCorrect, 
                  total: _totalAnswered, // On utilise le total répondu (peut être différent si timeout)
                  deckUuid: widget.deckUuid,
                  deckTitle: widget.deckTitle,
                ),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F2EA),
          body: SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _quizQuestions.isEmpty
                ? _buildEmptyState()
                : Stack(
                    children: [
                      _buildQuizBody(),
                      if (_xpFeedback != null)
                        Center(
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _xpFeedback!,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: _xpFeedbackColor,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Pas assez de flashcards pour un quiz'),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        ],
      ),
    );
  }

  Widget _buildCustomTopBar(String subject) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8E4DA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close,
              color: Color(0xFF555555),
              size: 20,
            ),
          ),
        ),
        // Subject Title
        Expanded(
          child: Center(
            child: Text(
              subject,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
        ),
        // Timer
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: _secondsRemaining / 15,
                strokeWidth: 2,
                backgroundColor: const Color(0xFFE8E4DA),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _secondsRemaining < 5 ? Colors.red : const Color(0xFF2D6A2D),
                ),
              ),
            ),
            Text(
              '$_secondsRemaining',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _secondsRemaining < 5 ? Colors.red : const Color(0xFF2D6A2D),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizBody() {
    final question = _quizQuestions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _buildCustomTopBar(widget.deckTitle),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _totalAnswered / _quizQuestions.length,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8E4DA),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D6A2D)),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 32),
          Text(
            'Question ${_totalAnswered + 1} sur ${_quizQuestions.length}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question['q'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              fontFamily: 'Plus Jakarta Sans',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: question['options'].length,
              itemBuilder: (context, index) {
                String letter = ['A', 'B', 'C', 'D'][index];
                bool isCorrect = index == question['a'];
                bool isSelected = index == _selectedIndex;
                
                Color bgOption = Colors.white;
                BorderSide borderSide = const BorderSide(color: Color(0xFFE8E4DA), width: 1);
                Color letterBg = const Color(0xFFF4F2EB);
                Color letterTextCol = const Color(0xFF555555);
                Color optionTextCol = const Color(0xFF1A1A1A);
                Widget? rightIcon;

                if (_isAnswered) {
                  if (isCorrect) {
                    bgOption = const Color(0xFFEAF3DE);
                    borderSide = const BorderSide(color: Color(0xFFB7D98C), width: 1.5);
                    letterBg = const Color(0xFF2D6A2D);
                    letterTextCol = Colors.white;
                    optionTextCol = const Color(0xFF27500A);
                    rightIcon = const Icon(Icons.check, color: Color(0xFF2D6A2D), size: 16);
                  } else if (isSelected) {
                    bgOption = const Color(0xFFFCEBEB);
                    borderSide = const BorderSide(color: Color(0xFFF3A9A9), width: 1.5);
                    letterBg = const Color(0xFFC92A2A);
                    letterTextCol = Colors.white;
                    optionTextCol = const Color(0xFF7D1C1C);
                    rightIcon = const Icon(Icons.close, color: Color(0xFFC92A2A), size: 16);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _isAnswered ? null : () => _answerQuestion(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgOption,
                        border: Border.fromBorderSide(borderSide),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          if (!_isAnswered)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: letterBg,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: letterTextCol,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              question['options'][index],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: optionTextCol,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                          ),
                          if (rightIcon != null) ...[
                            const SizedBox(width: 8),
                            rightIcon,
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _answerQuestion(int index) {
    if (_isAnswered) return;
    
    _timer?.cancel();
    setState(() {
      _isAnswered = true;
      _selectedIndex = index;
      _totalAnswered++;
    });

    final isCorrect = index == _quizQuestions[_currentQuestionIndex]['a'];
    
    setState(() {
      if (isCorrect) {
        _xpFeedback = '+10 XP';
        _xpFeedbackColor = Colors.green;
        AudioService().play('correct');
        _totalCorrect++;
        context.read<UserBloc>().add(const AddPoints(10));
      } else {
        _xpFeedback = '-5 XP';
        _xpFeedbackColor = Colors.red;
        AudioService().play('wrong');
        context.read<UserBloc>().add(const AddPoints(-5));
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _xpFeedback = null);
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      if (_totalAnswered < _quizQuestions.length) {
        setState(() {
          _currentQuestionIndex++;
          _isAnswered = false;
          _selectedIndex = null;
          // Si on a enlevé des éléments et réindexé, on s'assure de ne pas déborder
          if (_currentQuestionIndex >= _quizQuestions.length) {
            _currentQuestionIndex = 0;
          }
        });
        _startTimer();
      } else {
        final duration = DateTime.now().difference(_startTime).inSeconds;
        final xpGained = (_totalCorrect * 10) - ((_totalAnswered - _totalCorrect) * 5);
        context.read<QuizBloc>().add(SubmitQuiz(
          deckId: widget.deckUuid,
          score: _totalCorrect,
          total: _quizQuestions.length,
          duration: duration,
          xpGained: xpGained,
        ));
      }
    });
  }
}
