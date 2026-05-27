import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalan_app/domain/entities/flashcard.dart';
import 'package:kalan_app/presentation/blocs/flashcard/flashcard_bloc.dart';
import 'package:kalan_app/presentation/blocs/flashcard/flashcard_event.dart';
import 'package:kalan_app/presentation/blocs/flashcard/flashcard_state.dart';
import 'package:kalan_app/services/audio_service.dart';
import 'quiz_screen.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final String deckTitle;
  final String deckUuid;
  const FlashcardStudyScreen(
      {super.key, required this.deckTitle, required this.deckUuid});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  Timer? _timer;
  int _secondsRemaining = 5;
  List<Flashcard> _sessionCards = [];

  @override
  void initState() {
    super.initState();
    context.read<FlashcardBloc>().add(LoadFlashcards(widget.deckUuid));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 5;
      _showAnswer = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
        if (mounted) {
          AudioService().play('swipe');
          setState(() {
            _showAnswer = true;
          });
        }
      }
    });
  }

  void _nextCard(int total, {bool playSwipe = true}) {
    if (playSwipe) {
      AudioService().play('swipe');
    }
    if (_currentIndex < total - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      _startTimer();
    } else {
      _showTransitionDialog();
    }
  }

  void _showTransitionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Flashcards terminées !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu as bien mémorisé ces cartes. Maintenant, place au Quiz pour tester tes connaissances !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF555555),
                  height: 1.5,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          deckUuid: widget.deckUuid,
                          deckTitle: widget.deckTitle,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A2D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Commencer le Quiz',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EA),
      body: SafeArea(
        child: BlocConsumer<FlashcardBloc, FlashcardState>(
          listener: (context, state) {
            if (state is FlashcardLoaded && state.cards.isNotEmpty) {
              if (_sessionCards.isEmpty) {
                setState(() {
                  final List<Flashcard> allCards = List.from(state.cards);
                  allCards.shuffle();
                  _sessionCards = allCards.take(5).toList();
                });
              }
              if (_timer == null) {
                _startTimer();
              }
            }
          },
          builder: (context, state) {
            if (state is FlashcardLoading && _sessionCards.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is FlashcardError) {
              return Center(child: Text(state.message));
            }

            if (_sessionCards.isNotEmpty) {
              final cards = _sessionCards;

              return Column(
                children: [
                  _buildCustomTopBar(widget.deckTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${_currentIndex + 1} sur ${cards.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 13,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return RotationYTransition(
                              animation: animation, child: child);
                        },
                        child: _showAnswer
                            ? _buildCardSide(cards[_currentIndex].answer, true)
                            : _buildCardSide(
                                cards[_currentIndex].question, false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_showAnswer)
                    _buildFeedbackButtons(
                        cards.length, cards[_currentIndex].uuid)
                  else
                    _buildFlipInstruction(),
                  const SizedBox(height: 32),
                ],
              );
            }
            return const Center(child: Text('Aucune carte dans ce deck.'));
          },
        ),
      ),
    );
  }

  Widget _buildCustomTopBar(String subject) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
                Icons.chevron_left,
                color: Color(0xFF555555),
                size: 24,
              ),
            ),
          ),
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
          _showAnswer
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF3DE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF2D6A2D),
                    size: 16,
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: _secondsRemaining / 5,
                        strokeWidth: 2,
                        backgroundColor: const Color(0xFFE8E4DA),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2D6A2D),
                        ),
                      ),
                    ),
                    Text(
                      '$_secondsRemaining',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A2D),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCardSide(String text, bool isAnswer) {
    return Container(
      key: ValueKey(isAnswer),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isAnswer ? const Color(0xFFEAF3DE) : const Color(0xFFF4F2EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAnswer ? 'SOLUTION' : 'QUESTION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    isAnswer ? const Color(0xFF2D6A2D) : Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1C),
              fontFamily: 'Plus Jakarta Sans',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipInstruction() {
    return Column(
      children: [
        const Text(
          "La réponse s'affiche dans...",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_secondsRemaining secondes',
          style: const TextStyle(
            color: Color(0xFF2D6A2D),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackButtons(int total, String cardUuid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Tu connaissais cette réponse ?",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionButton(
                label: "Je ne sais pas",
                icon: Icons.close,
                color: const Color(0xFFE24B4A),
                onTap: () {
                  context.read<FlashcardBloc>().add(UpdateReview(cardUuid, 1));
                  _nextCard(total, playSwipe: false);
                },
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                label: "Je sais",
                icon: Icons.check,
                color: const Color(0xFF2D6A2D),
                isPrimary: true,
                onTap: () {
                  context.read<FlashcardBloc>().add(UpdateReview(cardUuid, 3));
                  _nextCard(total, playSwipe: false);
                },
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                label: "Plus tard",
                icon: Icons.access_time,
                color: Colors.grey,
                onTap: () => _nextCard(total),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final size = isPrimary ? 72.0 : 56.0;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isPrimary ? color : Colors.white,
              shape: BoxShape.circle,
              border: isPrimary
                  ? null
                  : Border.all(
                      color: Colors.black.withValues(alpha: 0.1), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : color,
              size: isPrimary ? 28 : 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: isPrimary ? 12 : 11,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
            color: isPrimary ? color : Colors.grey,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
      ],
    );
  }
}

class RotationYTransition extends AnimatedWidget {
  final Widget child;
  const RotationYTransition(
      {super.key, required Animation<double> animation, required this.child})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final rotation = animation.value * 3.14159;
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(rotation),
      alignment: Alignment.center,
      child: rotation > 1.5708
          ? Transform(
              transform: Matrix4.identity()..rotateY(3.14159),
              alignment: Alignment.center,
              child: child)
          : child,
    );
  }
}
