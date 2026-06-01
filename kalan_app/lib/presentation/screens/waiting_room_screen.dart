import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/battle_service.dart';
import 'challenge_rules_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String opponentName;
  final String? opponentAvatar;
  final int stake;
  final String battleId;

  const WaitingRoomScreen({
    super.key,
    required this.opponentName,
    this.opponentAvatar,
    required this.stake,
    required this.battleId,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  int _secondsRemaining = 60;
  Timer? _timer;

  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _accentColor = const Color(0xFFF43F5E);

  StreamSubscription? _battleSubscription;
  String _statusMessage = 'En attente...';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startTimer();
    _listenToBattle();
  }

  void _listenToBattle() {
    final battleService = BattleService();
    _battleSubscription = battleService.streamBattle(widget.battleId).listen((battle) {
      if (!mounted) return;

      if (battle.status == 'generating') {
        setState(() => _statusMessage = 'Génération du défi par l\'IA...');
      } else if (battle.status == 'in_progress') {
        _timer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeRulesScreen(
              opponentName: widget.opponentName,
              opponentAvatar: widget.opponentAvatar,
              stake: widget.stake,
              battleId: widget.battleId,
            ),
          ),
        );
      } else if (battle.status == 'refused' || battle.status == 'abandoned') {
        _timer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le défi a été annulé.')));
        Navigator.pop(context);
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _battleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            const Spacer(),
            _buildMascotSection(),
            const SizedBox(height: 40),
            _buildWaitingText(),
            const SizedBox(height: 30),
            _buildTimer(),
            const Spacer(),
            _buildCancelButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFEAB308), size: 18),
                const SizedBox(width: 6),
                Text('${widget.stake} XP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 200 * (1 + _pulseController.value * 0.2),
              height: 200 * (1 + _pulseController.value * 0.2),
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha((25 * (1 - _pulseController.value)).toInt()),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _primaryColor.withAlpha(50), blurRadius: 20)],
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: ClipOval(
            child: (widget.opponentAvatar != null && widget.opponentAvatar!.isNotEmpty)
                ? Image.asset(widget.opponentAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitial())
                : _buildInitial(),
          ),
        ),
      ],
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        widget.opponentName.isNotEmpty ? widget.opponentName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(fontSize: 60, fontWeight: FontWeight.w900, color: _primaryColor),
      ),
    );
  }

  Widget _buildWaitingText() {
    return Column(
      children: [
        Text(
          _statusMessage,
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'L\'adversaire a 1 minute pour rejoindre le duel. Ne quitte pas cet écran !',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    String minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    String seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _accentColor.withAlpha(25),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: _accentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'ANNULER L\'ATTENTE',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}



