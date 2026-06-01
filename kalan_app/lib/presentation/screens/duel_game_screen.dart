import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'challenge_result_screen.dart';
import '../../services/battle_service.dart';
import '../../services/local_ai_service.dart';
import '../../../data/remote/supabase_service.dart';
import '../../domain/models/battle_model.dart' show Battle;

class DuelGameScreen extends StatefulWidget {
  final String opponentName;
  final String? opponentAvatar;
  final String? yourAvatar;
  final int stake;
  final String battleId;
  final Map<String, dynamic>? battleContent;
  final bool isLocalBattle;

  const DuelGameScreen({
    super.key,
    required this.opponentName,
    this.opponentAvatar,
    this.yourAvatar,
    required this.stake,
    required this.battleId,
    this.battleContent,
    this.isLocalBattle = false,
  });

  @override
  State<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends State<DuelGameScreen> {
  List<dynamic> _deck = [];
  int _currentIndex = 0;
  int _scoreYou = 0;
  int _scoreThem = 0;
  
  String? _pickedAnswer;
  bool _isAnswered = false;
  
  StreamSubscription<Battle>? _battleSubscription;
  final BattleService _battleService = BattleService();
  String? _currentUserId;
  
  Timer? _timer;
  int _secondsRemaining = 15;
  bool _isLoading = true;

  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _correctColor = const Color(0xFF10B981);
  final Color _wrongColor = const Color(0xFFF43F5E);

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.currentUser?.id;
    _loadQuizzes();
    if (!widget.isLocalBattle) {
      _listenToBattle();
    }
  }

  Future<void> _loadQuizzes() async {
    try {
      Map<String, dynamic>? content = widget.battleContent;

      if (content == null) {
        final response = await Supabase.instance.client
            .from('battles')
            .select('content, theme')
            .eq('id', widget.battleId)
            .single();
        content = Battle.parseContent(response['content']);
        content?['theme'] = response['theme'];
      }

      if (content != null && content['quizzes'] != null) {
        final repaired = LocalAIService().repairBattleContent(
          content,
          theme: content['theme']?.toString(),
        );
        if (mounted) {
          setState(() {
            _deck = repaired['quizzes'] as List<dynamic>;
            _isLoading = false;
          });
          _startQuestionTimer();
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement quiz: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 15;
      _pickedAnswer = null;
      _isAnswered = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _deck.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startQuestionTimer();
    } else {
      _timer?.cancel();
      _finishGame();
    }
  }

  void _finishGame() {
    if (widget.isLocalBattle) {
      _navigateToResult();
      return;
    }
    _battleService.finishBattle(widget.battleId);
  }

  void _listenToBattle() {
    _battleSubscription = _battleService.streamBattle(widget.battleId).listen((battle) {
      if (!mounted) return;
      
      setState(() {
        bool isInviter = _currentUserId == battle.inviterId;
        _scoreYou = isInviter ? battle.inviterScore : battle.invitedScore;
        _scoreThem = isInviter ? battle.invitedScore : battle.inviterScore;
        
        if (battle.status == 'finished') {
          _navigateToResult();
        } else if (battle.status == 'abandoned') {
          _handleAbandon(battle.winnerId);
        }
      });
    });
  }

  void _handleAbandon(String? winnerId) {
    _battleSubscription?.cancel();
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("L'adversaire a abandonné.")));
    _navigateToResult();
  }

  void _navigateToResult() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeResultScreen(
          opponentName: widget.opponentName,
          opponentAvatar: widget.opponentAvatar,
          stake: widget.stake,
          scoreYou: _scoreYou,
          scoreThem: _scoreThem,
          battleId: widget.battleId,
          isLocalBattle: widget.isLocalBattle,
        ),
      ),
    );
  }

  void _handlePick(String choice) {
    if (_isAnswered) return;

    final correct = _deck[_currentIndex]['correctAnswer']?.toString() ?? '';
    final isCorrect = choice == correct;

    setState(() {
      _pickedAnswer = choice;
      _isAnswered = true;
      if (widget.isLocalBattle && isCorrect) {
        _scoreYou++;
      }
    });

    if (widget.isLocalBattle) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _nextQuestion();
      });
      return;
    }

    _battleService.submitAnswer(widget.battleId, _currentUserId!, _currentIndex, choice);
  }

  @override
  void dispose() {
    _battleSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (_deck.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: Text('Aucun quiz disponible')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTimerIndicator(),
            const SizedBox(height: 8),
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            _buildQuestionCard(),
            const Spacer(),
            _buildChoicesList(),
            const Spacer(),
            _buildScoreBoard(),
            const SizedBox(height: 8),
            _buildQuitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _secondsRemaining <= 5 ? _wrongColor.withValues(alpha: 0.1) : _primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "00:${_secondsRemaining.toString().padLeft(2, '0')}",
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          color: _secondsRemaining <= 5 ? _wrongColor : _primaryColor,
          letterSpacing: 1.2,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerScore('Toi', _scoreYou, _correctColor, widget.yourAvatar),
          _buildCenterInfo(),
          _buildPlayerScore(widget.opponentName, _scoreThem, _wrongColor, widget.opponentAvatar),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String label, int score, Color color, String? avatarPath) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: ClipOval(
              child: (avatarPath != null && avatarPath.isNotEmpty && avatarPath.startsWith('assets'))
                  ? Image.asset(avatarPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitial(label[0], color))
                  : _buildInitial(label[0], color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(score.toString(), style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildInitial(String char, Color color) {
    return Center(child: Text(char.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color)));
  }

  Widget _buildCenterInfo() {
    return Column(
      children: [
        Text('${_currentIndex + 1}/${_deck.length}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFEAB308), size: 14),
            const SizedBox(width: 4),
            Text('${widget.stake} XP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(
        children: [
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            width: (MediaQuery.of(context).size.width - 80) * ((_currentIndex + 1) / _deck.length),
            decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(
            'QUESTION ${_currentIndex + 1}',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryColor, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Text(
            _deck[_currentIndex]['question'] ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicesList() {
    List<dynamic> options = _deck[_currentIndex]['options'] ?? [];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: options.map((choice) {
          bool isSelected = _pickedAnswer == choice;
          bool isCorrect = choice == _deck[_currentIndex]['correctAnswer'];
          
          Color btnColor = Colors.white;
          Color textColor = Colors.black87;
          Color borderColor = Colors.grey[200]!;

          if (_isAnswered) {
            if (isCorrect) {
              btnColor = _correctColor.withValues(alpha: 0.1);
              textColor = _correctColor;
              borderColor = _correctColor;
            } else if (isSelected) {
              btnColor = _wrongColor.withValues(alpha: 0.1);
              textColor = _wrongColor;
              borderColor = _wrongColor;
            } else {
              textColor = Colors.grey[400]!;
            }
          }

          return GestureDetector(
            onTap: () => _handlePick(choice.toString()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      choice.toString(),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  if (_isAnswered && isCorrect) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  if (_isAnswered && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: Color(0xFFF43F5E), size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuitButton() {
    return TextButton(
      onPressed: () {
        if (!widget.isLocalBattle && _currentUserId != null) {
          _battleService.abandonBattle(widget.battleId, _currentUserId!);
        }
        Navigator.pop(context);
      },
      child: Text(
        'ABANDONNER LE DÉFI',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1),
      ),
    );
  }
}




