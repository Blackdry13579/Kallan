import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:kalan_app/presentation/blocs/deck/deck_bloc.dart';
import 'package:kalan_app/presentation/blocs/deck/deck_event.dart';
import 'package:kalan_app/presentation/screens/flashcard_study_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../services/local_ai_service.dart';
import '../../services/connectivity_service.dart';
import '../../ai/model_downloader.dart';
import '../../data/repositories/deck_repository_impl.dart';
import 'model_download_screen.dart';
import 'offline_context_screen.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';

class GeneratingScreen extends StatefulWidget {
  final String ocrText;
  final String? userSubject;
  final String? userContext;
  const GeneratingScreen({super.key, required this.ocrText, this.userSubject, this.userContext});

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> with TickerProviderStateMixin {
  final LocalAIService _aiService = LocalAIService();
  List<Map<String, String>> _flashcards = [];
  String _selectedSubject = 'Littérature';
  final String _selectedLevel = 'Général';

  late AnimationController _rotationController;
  late AnimationController _pulseController;
  int _currentStep = 0;
  Timer? _stepTimer;
  bool _aiFinished = false;
  final Uuid _uuid = const Uuid();
  bool _isRedirecting = false;
  bool _isOffline = false;
  String? _aiModeLabel;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _runAutoGeneration();
  }

  Future<void> _runAutoGeneration() async {
    await _loadSubjects();
    _isOffline = !await ConnectivityService().isOnline();

    // Si hors ligne et qu'on n'a pas encore collecté le contexte → page contexte
    if (_isOffline && widget.userContext == null) {
      if (!mounted) return;
      final detected = _detectSubject(widget.ocrText);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OfflineContextScreen(
            ocrText: widget.ocrText,
            detectedSubject: detected,
          ),
        ),
      );
      return;
    }

    // Hors ligne + contexte fourni : vérifier si Gemma est installé
    if (_isOffline && !await ModelDownloader.isModelDownloaded() && mounted) {
      final proceed = await _showOfflineModelDialog();
      if (!mounted) return;
      if (proceed == _OfflineChoice.cancel) {
        Navigator.pop(context);
        return;
      }
      if (proceed == _OfflineChoice.download) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
        );
      }
    }

    if (!mounted) return;
    _startGeneration();
  }

  Future<_OfflineChoice> _showOfflineModelDialog() async {
    final choice = await showDialog<_OfflineChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Mode hors ligne')),
          ],
        ),
        content: const Text(
          "Tu n'as pas internet. Pour de meilleures fiches, télécharge l'IA locale Gemma (~350 Mo, Wi‑Fi conseillé).\n\n"
          'Sinon, KALAN créera des fiches simplifiées à partir de ton texte.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _OfflineChoice.cancel),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _OfflineChoice.heuristic),
            child: const Text('Continuer sans IA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _OfflineChoice.download),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Télécharger l\'IA'),
          ),
        ],
      ),
    );
    return choice ?? _OfflineChoice.cancel;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  String _detectSubject(String text) {
    final lowerText = text.toLowerCase();
    
    // 1. Détection Sciences (Maths, SVT, Physique, Informatique)
    if (lowerText.contains('fraction') ||
        lowerText.contains('équation') ||
        lowerText.contains('calculer') ||
        lowerText.contains('géométrie') ||
        lowerText.contains('triangle') ||
        lowerText.contains('théorème') ||
        lowerText.contains('nombre') ||
        lowerText.contains('fonction') ||
        lowerText.contains('cellule') ||
        lowerText.contains('plante') ||
        lowerText.contains('corps humain') ||
        lowerText.contains('organe') ||
        lowerText.contains('adn') ||
        lowerText.contains('génétique') ||
        lowerText.contains('reproduction') ||
        lowerText.contains('chimie') ||
        lowerText.contains('physique') ||
        lowerText.contains('atome') ||
        lowerText.contains('molécule') ||
        lowerText.contains('force') ||
        lowerText.contains('vitesse') ||
        lowerText.contains('pesanteur') ||
        lowerText.contains('informatique') ||
        lowerText.contains('ordinateur') ||
        lowerText.contains('code') ||
        lowerText.contains('programmation') ||
        lowerText.contains('algorithme')) {
      return 'Sciences';
    }
    
    // 2. Détection Littérature (Français, poésie)
    if (lowerText.contains('poème') ||
        lowerText.contains('conjugaison') ||
        lowerText.contains('verbe') ||
        lowerText.contains('grammaire') ||
        lowerText.contains('orthographe') ||
        lowerText.contains('littérature') ||
        lowerText.contains('adjectif')) {
      return 'Littérature';
    }
    
    // 3. Détection Humanités (Histoire, Géographie)
    if (lowerText.contains('histoire') ||
        lowerText.contains('guerre') ||
        lowerText.contains('siècle') ||
        lowerText.contains('géographie') ||
        lowerText.contains('climat') ||
        lowerText.contains('carte') ||
        lowerText.contains('afrique')) {
      return 'Humanités';
    }
    
    // 4. Détection Langues (Anglais, etc.)
    if (lowerText.contains('english') ||
        lowerText.contains('vocabulary') ||
        lowerText.contains('translate') ||
        lowerText.contains('pronoun')) {
      return 'Langues';
    }
    
    return 'Autre';
  }

  Future<void> _loadSubjects() async {
    // Priorité au sujet sélectionné par l'utilisateur sur la page contexte
    if (widget.userSubject != null) {
      setState(() => _selectedSubject = widget.userSubject!);
      return;
    }
    final subjects = await DatabaseHelper.instance.getAllSubjects();
    if (mounted) {
      setState(() {
        final detected = _detectSubject(widget.ocrText);
        if (subjects.any((s) => s['label'] == detected)) {
          _selectedSubject = detected;
        } else if (subjects.isNotEmpty) {
          _selectedSubject = subjects.first['label'] as String;
        }
      });
    }
  }

  void _startGeneration() {
    // Progression visuelle des étapes
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentStep < 3) {
          _currentStep++;
        } else {
          _stepTimer?.cancel();
          if (_aiFinished && !_isRedirecting) {
            _autoSaveAndRedirect();
          }
        }
      });
    });

    _generate();
  }

  Future<void> _generate() async {
    try {
      // Nettoyage et limitation TRÈS stricte du texte (Crash SIGSEGV si > 1024 tokens)
      String cleanText = widget.ocrText.trim();
      if (cleanText.length > 2000) {
        // 2000 caractères ~ 600-700 tokens, ce qui laisse une marge de sécurité pour la réponse de l'IA
        cleanText = "${cleanText.substring(0, 1000)}\n\n[...]\n\n${cleanText.substring(cleanText.length - 1000)}";
      }

      final result = await _aiService.generateFlashcards(
        text: cleanText,
        userSubject: widget.userSubject,
        userContext: widget.userContext,
      );
      if (mounted) {
        setState(() {
          _selectedSubject = result['subject'];
          _flashcards = (result['flashcards'] as List).cast<Map<String, String>>();
          _aiModeLabel = _labelForMode(result['mode'] as String?);
          _aiFinished = true;

          // Si les étapes visuelles sont déjà finies, on redirige
          if (_currentStep >= 3 && !_isRedirecting) {
            _autoSaveAndRedirect();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('IMAGE_FLOUE')
            ? 'Image trop floue ou illisible. Reprends la photo.'
            : 'Erreur lors de la génération : $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: e.toString().contains('IMAGE_FLOUE') ? Colors.orange : null),
        );
        Navigator.pop(context);
      }
    }
  }
  Future<void> _autoSaveAndRedirect() async {
    if (_isRedirecting) return;
    setState(() => _isRedirecting = true);

    if (_flashcards.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
        final offlineHint = _isOffline
            ? "Aucune fiche générée. Essaie avec l'IA locale installée (Paramètres → télécharger Gemma) ou un texte plus long."
            : "Désolé, l'IA n'a pas pu générer de fiches pour ce contenu.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineHint), duration: const Duration(seconds: 5)),
        );
      }
      return;
    }

    // Titre automatique basé sur le début du texte
    String title = 'Nouveau Deck';
    if (widget.ocrText.isNotEmpty) {
      title = widget.ocrText.split('\n').first.trim();
      if (title.length > 35) title = '${title.substring(0, 35)}...';
    }

    final String deckUuid = _uuid.v4();

    try {
      // On utilise le Repository directement pour attendre la fin de l'insertion
      // Cela garantit que FlashcardStudyScreen trouvera les cartes
      final repository = context.read<DeckRepositoryImpl>();
      await repository.createDeck(
        title,
        _selectedSubject,
        _selectedLevel,
        cards: _flashcards,
        uuid: deckUuid,
      );

      if (!mounted) return;

      // On notifie le Bloc pour rafraîchir la liste en arrière-plan
      context.read<DeckBloc>().add(const LoadDecks());
      // On recharge aussi le profil et les activités récentes
      context.read<UserBloc>().add(LoadUserProfile());

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardStudyScreen(
              deckTitle: title,
              deckUuid: deckUuid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRedirecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sauvegarde : $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildLoadingUI();
  }

  Widget _buildLoadingUI() {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      body: SafeArea(
        child: Stack(
          children: [
            // Icônes de fond
            const Positioned(top: 50, left: 40, child: Opacity(opacity: 0.1, child: Text('🌿', style: TextStyle(fontSize: 48)))),
            const Positioned(top: 120, right: 50, child: Opacity(opacity: 0.1, child: Text('🌍', style: TextStyle(fontSize: 40)))),
            const Positioned(bottom: 150, left: 60, child: Opacity(opacity: 0.1, child: Text('📐', style: TextStyle(fontSize: 44)))),
            const Positioned(bottom: 80, right: 70, child: Opacity(opacity: 0.1, child: Text('🧪', style: TextStyle(fontSize: 48)))),
            
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const Text(
                    'Génération en cours...',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Plus Jakarta Sans'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _aiModeLabel ??
                        (_isOffline
                            ? "Mode hors ligne — l'IA locale transforme ton cours"
                            : "L'IA KALAN transforme ton cours en succès"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _isOffline ? Colors.orange.shade800 : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isOffline) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Text(
                            'Sans connexion internet',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Loader
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _rotationController,
                            child: SizedBox(
                              width: 170,
                              height: 170,
                              child: CustomPaint(painter: DashedCirclePainter(color: AppColors.primary.withValues(alpha: 0.4))),
                            ),
                          ),
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                            child: Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 8, offset: const Offset(0, 4))],
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1),
                              ),
                              child: Center(
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/kalan_logo.png', width: 70, height: 70, fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.forest, color: AppColors.primary, size: 54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Étapes
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepItem(0, "Analyse du texte (OCR)"),
                        const SizedBox(height: 12),
                        _buildStepItem(1, "Extraction des idées clés"),
                        const SizedBox(height: 12),
                        _buildStepItem(2, "Création des flashcards"),
                        const SizedBox(height: 12),
                        _buildStepItem(3, "Lancement de l'étude"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  if (_isRedirecting)
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))
                  else
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Text('ANNULER LA GÉNÉRATION', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int stepIndex, String title) {
    bool isCompleted = _currentStep > stepIndex;
    bool isActive = _currentStep == stepIndex;
    Color textColor = isCompleted ? Colors.grey.shade700 : isActive ? AppColors.primary : Colors.grey.shade400;
    FontWeight textWeight = isActive || isCompleted ? FontWeight.bold : FontWeight.normal;
    double opacity = isActive || isCompleted ? 1.0 : 0.3;

    return Opacity(
      opacity: opacity,
      child: Row(
        children: [
          if (isCompleted)
            Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle), child: const Center(child: Icon(Icons.check, color: Colors.white, size: 13)))
          else if (isActive)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: const Color(0xFFEAF3DE), shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
              child: Center(child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))),
            )
          else
            Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 1))),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, color: textColor, fontWeight: textWeight, fontFamily: 'Plus Jakarta Sans'))),
        ],
      ),
    );
  }
}

enum _OfflineChoice { cancel, download, heuristic }

String? _labelForMode(String? mode) {
  switch (mode) {
    case 'online':
      return 'IA en ligne (Qwen) — fiches de haute qualité';
    case 'gemma':
      return 'IA locale Gemma — génération hors ligne';
    case 'heuristic':
      return 'Mode simplifié — fiches extraites de ton texte';
    default:
      return null;
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  DashedCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double radius = width / 2;
    final Paint paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final double circumference = 2 * 3.14159 * radius;
    const double dashWidth = 8, dashSpace = 8;
    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();
    for (int i = 0; i < dashCount; i++) {
      final double startAngle = (i * (dashWidth + dashSpace) / circumference) * 2 * 3.14159;
      final double sweepAngle = (dashWidth / circumference) * 2 * 3.14159;
      canvas.drawArc(Rect.fromCircle(center: Offset(width / 2, size.height / 2), radius: radius), startAngle, sweepAngle, false, paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
