import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai/gemma_service.dart';
import '../ai/llamadart_engine.dart';
import '../ai/local_model_config.dart';
import '../ai/model_downloader.dart';
import 'connectivity_service.dart';
import 'qwen_flashcard_service.dart';

class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  // LAZY : services créés uniquement quand nécessaires.
  GemmaService? _gemmaService;
  QwenFlashcardService? _qwenService;

  static String get _hfToken => dotenv.env['HF_TOKEN'] ?? '';
  static const String _hfBaseUrl =
      'https://router.huggingface.co/v1/chat/completions';
  static const List<String> _models = [
    'Qwen/Qwen2.5-72B-Instruct',
    'Qwen/Qwen2.5-7B-Instruct',
  ];

  Future<bool> canUseOnlineAI() async {
    if (_hfToken.trim().isEmpty) return false;
    try {
      final isOnline = await ConnectivityService().isOnline();
      return isOnline;
    } catch (e) {
      // En mode test ou si le plugin échoue, on vérifie au moins le token
      debugPrint('[KALAN AI] canUseOnlineAI fallback: $e');
      return _hfToken.trim().isNotEmpty;
    }
  }

  Future<bool> isOfflineGemmaReady() => ModelDownloader.isModelDownloaded();

  // ═══════════════════════════════════════════════════════════════════════════
  // GÉNÉRATION FLASHCARDS (cours complet)
  // En ligne  → Qwen (priorité absolue, meilleure qualité)
  // Hors ligne → Gemma si installé, sinon heuristique intelligente
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateFlashcards({
    required String text,
    String? userSubject,
    String? userContext,
  }) async {
    // Priorité : sujet fourni par l'utilisateur, sinon heuristique
    final subject = userSubject ?? _detectSubjectHeuristic(text);

    if (await canUseOnlineAI()) {
      debugPrint('[KALAN AI] En ligne → Qwen...');
      try {
        final cards =
            await _generateOnlineFlashcards(text, subject, context: userContext)
                .timeout(const Duration(seconds: 45));
        if (cards.isNotEmpty) {
          debugPrint('[KALAN AI] ✅ ${cards.length} fiches via Qwen');
          return {'subject': subject, 'flashcards': cards, 'mode': 'online'};
        }
      } catch (e) {
        // Image floue : remonter directement à l'UI, pas de fallback offline
        if (e.toString().contains('IMAGE_FLOUE')) {
          throw Exception('IMAGE_FLOUE');
        }
        debugPrint('[KALAN AI] Qwen échoué, bascule offline : $e');
      }
    } else {
      debugPrint('[KALAN AI] Hors ligne ou HF_TOKEN absent → offline');
    }

    final offline =
        await _generateOfflineFlashcards(text, subject, context: userContext);
    return {
      'subject': subject,
      'flashcards': offline.cards,
      'mode': offline.mode,
      if (offline.modelMissing) 'offlineModelMissing': true,
    };
  }

  // ─── Online : Qwen avec prompt structuré et système de rôle ───────────────

  Future<List<Map<String, String>>> _generateOnlineFlashcards(
    String text,
    String subject, {
    String? context,
  }) async {
    final truncatedText =
        text.length > 6000 ? '${text.substring(0, 6000)}...' : text;
    final lang = _detectLanguage(truncatedText);
    final contextPart = context != null && context.trim().isNotEmpty
        ? '''

Contexte et analyse du document fournis à l'IA :
"""
${context.trim()}
"""
'''
        : '';

    final langInstruction = _buildOnlineLangInstruction(lang);
    final isEnglish = lang == 'anglais';

    final userPrompt = '''$langInstruction

${isEnglish ? 'Course text (subject: $subject)' : 'Texte de cours (matière : $subject)'} :
"""
$truncatedText
"""
$contextPart

${isEnglish ? '### STEP 1 — QUALITY CHECK' : '### ÉTAPE 1 — DIAGNOSTIC QUALITÉ'}
${isEnglish ? 'If the text is unreadable, too short (< 15 words) or incoherent (random characters),' : 'Si le texte est illisible, trop court (< 15 mots) ou incohérent (caractères aléatoires),'}
${isEnglish ? 'return ONLY: {"error": "image_floue"}' : 'retourne UNIQUEMENT : {"error": "image_floue"}'}

${isEnglish ? '### STEP 2 — GENERATION (if text is readable)' : '### ÉTAPE 2 — GÉNÉRATION (si texte lisible)'}
${isEnglish ? 'Generate exactly 5 varied revision flashcards.' : 'Génère exactement 5 flashcards de révision variées.'}
${isEnglish ? 'Rules:' : 'Règles :'}
${isEnglish ? '- Language: all questions AND answers in English. Never in French.' : '- Langue : toutes les questions et réponses en $lang'}
${isEnglish ? '- Questions MUST start with an interrogative word: What, How, Why, When, Who, Where, Which' : '- Questions commençant par un mot interrogatif : Quelle, Comment, Pourquoi, Quand, Qui, Où, Qu\'est-ce que'}
${isEnglish ? '- FORBIDDEN: fill-in-the-blank questions with "..." or blanks' : '- INTERDIT : questions à trous avec "..." ou blancs à remplir'}
${isEnglish ? '- Mix: 3 open questions + 2 True/False with explanation ("True, because..." or "False, because...")' : '- Mélange : 3 questions ouvertes + 2 questions Vrai/Faux avec explication ("Vrai, car..." ou "Faux, car...")'}
${isEnglish ? '- Question: maximum 30 words, complete and clear' : '- Question : maximum 30 mots, bien formulée'}
${isEnglish ? '- Answer: maximum 30 words, complete sentence' : '- Réponse : maximum 30 mots, phrase complète'}
${isEnglish ? '- Use the document context to understand the topic and level' : '- Utilise le contexte du document pour comprendre le sujet et le niveau'}
${isEnglish ? '- JSON only, no markdown, no surrounding text' : '- JSON uniquement, sans markdown ni texte autour'}

[
  {"question": "...", "answer": "..."}
]''';

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] Flashcards online via $model');
        final response = await http
            .post(
              Uri.parse(_hfBaseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_hfToken',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'Tu es un assistant pédagogique expert. Tu génères uniquement du JSON valide, sans markdown, sans explication.',
                  },
                  {'role': 'user', 'content': userPrompt},
                ],
                'temperature': 0.4,
                'max_tokens': 1200,
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 503 || response.statusCode == 429) {
          debugPrint(
              '[KALAN AI] $model indisponible (${response.statusCode}), suivant...');
          continue;
        }
        if (response.statusCode != 200) {
          debugPrint('[KALAN AI] $model erreur ${response.statusCode}');
          continue;
        }

        final raw = jsonDecode(response.body)['choices']?[0]?['message']
                    ?['content']
                ?.toString() ??
            '';
        if (raw.isNotEmpty) {
          // Vérifier si l'IA a détecté un texte illisible
          final diag = _extractJson(raw);
          if (diag != null && diag['error'] == 'image_floue') {
            throw Exception('IMAGE_FLOUE');
          }
          final cards = _parseFlashcardsJson(raw);
          if (cards.isNotEmpty) return cards;
        }
      } catch (e) {
        // Propager l'erreur image floue sans essayer le modèle suivant
        if (e.toString().contains('IMAGE_FLOUE')) rethrow;
        debugPrint('[KALAN AI] $model exception : $e');
      }
    }
    throw Exception('Tous les modèles Qwen ont échoué pour les flashcards.');
  }

  // ─── Offline : Qwen GGUF → Gemma (fallback) → heuristique ───────────────

  Future<({List<Map<String, String>> cards, String mode, bool modelMissing})>
      _generateOfflineFlashcards(String text, String subject,
          {String? context}) async {
    if (text.trim().length < 10) {
      return (cards: _smartHeuristic(text), mode: 'heuristic', modelMissing: false);
    }

    // Limite stricte pour les appareils bas de gamme (1500 chars ≈ 400 tokens)
    final truncated = text.length > 1500 ? '${text.substring(0, 1500)}...' : text;
    final lang = _detectLanguage(truncated);

    // 1. Qwen GGUF local (llamadart)
    final qwenPath = await ModelDownloader.getModelPath(qwen25LocalModel);
    if (qwenPath != null) {
      try {
        debugPrint('[KALAN AI] Qwen offline GGUF...');
        _qwenService ??= QwenFlashcardService(LlamadartEngine());
        await _qwenService!.ensureLoaded(qwenPath);
        final result = await _qwenService!
            .generateFlashcards(
              text: truncated,
              subject: subject,
              context: context,
              language: lang,
            )
            .timeout(const Duration(seconds: 600));
        if (result.hasEnoughCards) {
          debugPrint('[KALAN AI] ✅ ${result.flashcards.length} fiches via Qwen local');
          return (cards: result.flashcards, mode: 'qwen_local', modelMissing: false);
        }
      } catch (e) {
        debugPrint('[KALAN AI] Qwen local erreur : $e → fallback Gemma');
      }
    }

    // 2. Gemma (fallback si installé)
    final gemmaInstalled = await ModelDownloader.isGemmaInstalled();
    if (!gemmaInstalled) {
      return (
        cards: _smartHeuristic(text),
        mode: 'heuristic',
        modelMissing: qwenPath == null
      );
    }

    try {
      debugPrint('[KALAN AI] Gemma offline (fallback)...');
      _gemmaService ??= GemmaService();
      final prompt = _buildGemmaPrompt(truncated, subject, context: context, lang: lang);
      debugPrint('[KALAN AI] Langue détectée : $lang');
      final raw = await _gemmaService!
          .generateText(prompt, maxTokens: 768)
          .timeout(const Duration(seconds: 90));
      final cards = _parseFlashcardsQR(raw);
      if (cards.isNotEmpty) {
        debugPrint('[KALAN AI] ✅ ${cards.length} fiches via Gemma');
        return (cards: cards, mode: 'gemma', modelMissing: false);
      }
    } catch (e) {
      debugPrint('[KALAN AI] Gemma erreur : $e → heuristique');
    }

    return (cards: _smartHeuristic(text), mode: 'heuristic', modelMissing: false);
  }

  // ─── Instruction langue : écrite dans la langue du document ─────────────

  String _buildOnlineLangInstruction(String lang) {
    if (lang == 'anglais') {
      return 'The document is written in English.\n'
          'You MUST write every question and every answer in English.\n'
          'Do NOT translate to French or any other language.';
    }
    if (lang == 'espagnol') {
      return 'El documento está escrito en español.\n'
          'DEBES escribir cada pregunta y cada respuesta en español.\n'
          'No traduzcas al francés ni a ningún otro idioma.';
    }
    if (lang == 'arabe') {
      return 'الوثيقة مكتوبة باللغة العربية.\n'
          'يجب أن تكتب كل سؤال وكل إجابة باللغة العربية.\n'
          'لا تترجم إلى الفرنسية أو أي لغة أخرى.';
    }
    return 'Langue du document : $lang.\n'
        'Tu dois générer chaque question et chaque réponse en $lang.\n'
        'Ne traduis jamais dans une autre langue.';
  }

  // ─── Détection langue source ───────────────────────────────────────────────

  String _detectLanguage(String text) {
    final lower = text.toLowerCase();
    int frScore = 0, enScore = 0;
<<<<<<< HEAD
    const frWords = [' le ', ' la ', ' les ', ' de ', ' du ', ' des ', ' une ', ' et ', ' est ', ' sont ', ' dans ', ' pour ', ' avec ', ' qui ', ' que ', ' ce ', ' se ', ' sur ', ' au ', ' il ', ' elle ', ' nous ', ' vous '];
    const enWords = [' the ', ' is ', ' are ', ' was ', ' were ', ' have ', ' has ', ' had ', ' will ', ' would ', ' can ', ' could ', ' this ', ' that ', ' from ', ' with ', ' and ', ' but ', ' for ', ' in ', ' of ', ' to ', ' they ', ' their '];
    for (final w in frWords) {
      if (lower.contains(w)) frScore++;
    }
    for (final w in enWords) {
      if (lower.contains(w)) enScore++;
    }
=======
    const frWords = [
      ' le ',
      ' la ',
      ' les ',
      ' de ',
      ' du ',
      ' des ',
      ' une ',
      ' et ',
      ' est ',
      ' sont ',
      ' dans ',
      ' pour ',
      ' avec ',
      ' qui ',
      ' que ',
      ' ce ',
      ' se ',
      ' sur ',
      ' au ',
      ' il ',
      ' elle ',
      ' nous ',
      ' vous '
    ];
    const enWords = [
      ' the ',
      ' is ',
      ' are ',
      ' was ',
      ' were ',
      ' have ',
      ' has ',
      ' had ',
      ' will ',
      ' would ',
      ' can ',
      ' could ',
      ' this ',
      ' that ',
      ' from ',
      ' with ',
      ' and ',
      ' but ',
      ' for ',
      ' in ',
      ' of ',
      ' to ',
      ' they ',
      ' their '
    ];
    for (final w in frWords) if (lower.contains(w)) frScore++;
    for (final w in enWords) if (lower.contains(w)) enScore++;
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    return enScore > frScore ? 'anglais' : 'français';
  }

  // ─── Prompt Gemma : bilingue, contexte, format robuste ────────────────────

  String _buildGemmaPrompt(String text, String subject,
      {String? context, String lang = 'français'}) {
    final contextPart = (context != null && context.isNotEmpty)
        ? '\nCONTEXTE DE L\'ÉLÈVE : $context\n'
        : '';
    return '''Tu es un professeur expert en $subject.$contextPart
Langue du texte : $lang. Génère tes questions et réponses DANS CETTE MÊME LANGUE.
Réponse = 1 à 4 mots max. Ne répète jamais la question dans la réponse.

TEXTE :
$text

Format EXACT (5 paires) :
Q1: [question]
R1: [réponse]
Q2: [question]
R2: [réponse]
Q3: [question]
R3: [réponse]
Q4: [question]
R4: [réponse]
Q5: [question]
R5: [réponse]

Q1:''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÉNÉRATION FLASHCARD UNIQUE — 3 CAS (Qwen uniquement)
  // Cas 1 : notes + question    → extraction fragment depuis les notes
  // Cas 2 : notes + affirmation → transformation en paire Q/R minimale
  // Cas 3 : pas de notes        → connaissance Qwen + double source web
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateSingleFlashcard({
    required String input,
    String? notes,
  }) async {
    if (!await canUseOnlineAI()) {
      throw Exception('Connexion internet requise pour générer une flashcard.');
    }

    final trimmed = input.trim();
    final notesText = notes?.trim();
    final hasNotes = notesText != null && notesText.length >= 20;
    final isQuestion = _isQuestion(trimmed);

    final int casNum;
    final String prompt;

    if (hasNotes && isQuestion) {
      casNum = 1;
<<<<<<< HEAD
      prompt = _buildCas1Prompt(trimmed, notes.trim());
    } else if (hasNotes) {
      casNum = 2;
      prompt = _buildCas2Prompt(trimmed, notes.trim());
=======
      prompt = _buildCas1Prompt(trimmed, notesText);
    } else if (hasNotes) {
      casNum = 2;
      prompt = _buildCas2Prompt(trimmed, notesText);
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    } else {
      casNum = 3;
      prompt = _buildCas3Prompt(trimmed);
    }

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] generateSingleFlashcard cas $casNum via $model');
        final response = await http
            .post(
              Uri.parse(_hfBaseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_hfToken',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'Tu es un assistant pédagogique expert. Tu génères uniquement du JSON valide, sans markdown, sans explication.',
                  },
                  {'role': 'user', 'content': prompt},
                ],
                'temperature': 0.2,
                'max_tokens': 256,
              }),
            )
            .timeout(const Duration(seconds: 35));

        if (response.statusCode == 503 || response.statusCode == 429) {
          debugPrint(
              '[KALAN AI] $model indisponible (${response.statusCode}), suivant...');
          continue;
        }
        if (response.statusCode != 200) {
          debugPrint('[KALAN AI] $model erreur ${response.statusCode}');
          continue;
        }

        final raw = jsonDecode(response.body)['choices']?[0]?['message']
                    ?['content']
                ?.toString() ??
            '';
        if (raw.isNotEmpty) {
          final parsed = _parseSingleCard(raw, input: trimmed);
          if (parsed != null) return parsed;
        }
      } catch (e) {
        debugPrint('[KALAN AI] $model exception generateSingleFlashcard : $e');
      }
    }
    throw Exception('Impossible de générer la flashcard.');
  }

  bool _isQuestion(String text) {
    if (text.endsWith('?')) return true;
    final lower = text.toLowerCase();
    const interrogatives = [
      "qu'est",
      'quel ',
      'quelle ',
      'quels ',
      'quelles ',
      'comment ',
      'pourquoi ',
      'quand ',
      'où ',
      'qui ',
      'combien ',
      'est-ce que',
      'y a-t-il',
      'que ',
      'quoi ',
      'what ',
      'who ',
      'where ',
      'when ',
      'why ',
      'how ',
    ];
    return interrogatives.any((w) => lower.startsWith(w));
  }

  String _buildCas1Prompt(String question, String notes) => '''
Cours :
"""
$notes
"""
Question : "${question.replaceAll('"', '\\"')}"

### MISSION :
Cherche UNIQUEMENT dans le cours fourni le fragment minimal (1 à 5 mots max) qui répond.
NE RÉPÈTE PAS LA QUESTION. NE RÉPONDS PAS PAR UNE PHRASE COMPLÈTE.
Si la réponse n'est pas dans le cours, réponds "non trouvé".

### OUTPUT :
JSON : {"question": "${question.replaceAll('"', '\\"')}", "answer": "<réponse courte extraite>", "source": "cours"}''';

  String _buildCas2Prompt(String sentence, String notes) => '''
Cours :
"""
$notes
"""
Phrase clé à transformer : "${sentence.replaceAll('"', '\\"')}"

### MISSION :
Crée une flashcard :
1. "question" : Une question courte qui porte sur l'info de la phrase.
2. "answer" : Le fragment minimal (1 à 3 mots) extrait de la phrase.
NE RÉPÈTE PAS LA QUESTION DANS LA RÉPONSE.

### OUTPUT :
JSON : {"question": "<question>", "answer": "<fragment minimal>", "source": "cours"}''';

  String _buildCas3Prompt(String question) => '''
Question de culture générale : "${question.replaceAll('"', '\\"')}"

### MISSION :
1. Utilise ton Web Search interne.
2. Vérifie au moins 2 sources concordantes.
3. Si les sources sont concordantes → Retourne la réponse factuelle courte.
4. Si les sources sont contradictoires → Retourne null en answer et un warning.

### OUTPUT FORMAT :
JSON : {
  "question": "${question.replaceAll('"', '\\"')}", 
  "answer": "<réponse courte vérifiée>", 
  "source": "web", 
  "warning": "sources contradictoires (si applicable)"
}''';

  Map<String, dynamic>? _parseSingleCard(String raw, {required String input}) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}') + 1;
      if (start == -1 || end <= start) return null;
      final parsed =
          jsonDecode(raw.substring(start, end)) as Map<String, dynamic>;
      if (!parsed.containsKey('question') || !parsed.containsKey('source'))
        return null;

      final answer = parsed['answer']?.toString().trim() ?? '';
      if (answer.toLowerCase() == "non trouvé" || answer == input.trim())
        return null;

      return parsed;
    } catch (e) {
      debugPrint('[KALAN AI] _parseSingleCard : $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÉNÉRATION CONTENU BATAILLE (Qwen uniquement — jamais Gemma)
  // ═══════════════════════════════════════════════════════════════════════════

<<<<<<< HEAD
  /// Contenu de défi hors-ligne (compact pour QR) — templates par matière.
  /// Corrige les QCM avec « Option B » ou options invalides (défis déjà sauvegardés).
  Map<String, dynamic> repairBattleContent(
    Map<String, dynamic> content, {
    String? theme,
  }) =>
      _normalizeBattleContent(content, theme: theme);

  Future<Map<String, dynamic>> generateBattleContentOffline({required String theme}) async {
    if (await isOfflineGemmaReady()) {
      try {
        final prompt =
            'Thème: $theme. Donne 5 questions courtes avec réponses pour un quiz scolaire.';
        final result = await generateFlashcards(text: prompt, userSubject: theme);
        final rawCards = result['flashcards'] as List? ?? [];
        if (rawCards.length >= 3) {
          final flashcards = rawCards.take(5).map((c) {
            final m = Map<String, dynamic>.from(c as Map);
            return {
              'question': m['question']?.toString() ?? '',
              'answer': m['answer']?.toString() ?? '',
            };
          }).toList();
          final quizzes = _flashcardsToQuizzes(flashcards, theme: theme);
          return {'flashcards': flashcards, 'quizzes': quizzes};
        }
      } catch (e) {
        debugPrint('[KALAN AI] Offline battle Gemma: $e');
      }
    }
    return _templateBattleContent(theme);
  }

  bool _isPlaceholderOption(String option) {
    final t = option.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^Option\s+[A-Da-d]$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^[A-D]$').hasMatch(t)) return true;
    return false;
  }

  bool _quizzesHavePlaceholderOptions(List<Map<String, dynamic>> quizzes) {
    if (quizzes.isEmpty) return true;
    for (final quiz in quizzes) {
      final options = (quiz['options'] as List?)
              ?.map((e) => e.toString().trim())
              .where((o) => o.isNotEmpty)
              .toList() ??
          [];
      if (options.length < 4) return true;
      final bad = options.where(_isPlaceholderOption).length;
      if (bad >= 1) return true;
    }
    return false;
  }

  List<String> _buildOptionsForAnswer(
    String correct,
    List<Map<String, dynamic>> flashcards, {
    String? theme,
    String? excludeQuestion,
  }) {
    final used = <String>{correct};
    final options = <String>[correct];
    final pool = <String>[];

    for (final card in flashcards) {
      if (excludeQuestion != null &&
          card['question']?.toString() == excludeQuestion) {
        continue;
      }
      final a = card['answer']?.toString().trim() ?? '';
      if (a.isNotEmpty && a != correct) pool.add(a);
    }

    final bank = _themeQuestionBank[theme] ?? _themeQuestionBank['Mélange']!;
    for (final entry in bank) {
      final a = entry['a'] as String;
      if (a != correct) pool.add(a);
    }
    pool.shuffle();

    for (final w in pool) {
      if (options.length >= 4) break;
      if (!used.contains(w)) {
        options.add(w);
        used.add(w);
      }
    }

    while (options.length < 4) {
      final filler = 'Autre réponse ${options.length}';
      if (!used.contains(filler)) {
        options.add(filler);
        used.add(filler);
      } else {
        break;
      }
    }

    options.shuffle();
    return options.take(4).toList();
  }

  List<Map<String, dynamic>> _flashcardsToQuizzes(
    List<Map<String, dynamic>> flashcards, {
    String? theme,
  }) {
    final quizzes = <Map<String, dynamic>>[];
    for (final card in flashcards) {
      final q = card['question']?.toString() ?? '';
      final correct = card['answer']?.toString() ?? '';
      if (q.isEmpty || correct.isEmpty) continue;
      quizzes.add({
        'question': q,
        'options': _buildOptionsForAnswer(
          correct,
          flashcards,
          theme: theme,
          excludeQuestion: q,
        ),
        'correctAnswer': correct,
      });
    }
    return quizzes;
  }

  Map<String, dynamic> _normalizeBattleContent(
    Map<String, dynamic> parsed, {
    String? theme,
  }) {
    final rawCards = parsed['flashcards'] as List? ?? [];
    final flashcards = rawCards
        .map((c) {
          final m = Map<String, dynamic>.from(c as Map);
          return {
            'question': (m['question'] ?? m['q'] ?? '').toString().trim(),
            'answer': (m['answer'] ?? m['a'] ?? '').toString().trim(),
          };
        })
        .where(
          (c) =>
              c['question']!.toString().isNotEmpty &&
              c['answer']!.toString().isNotEmpty,
        )
        .toList();

    var quizzes = (parsed['quizzes'] as List?)
            ?.map((q) => Map<String, dynamic>.from(q as Map))
            .toList() ??
        [];

    if (_quizzesHavePlaceholderOptions(quizzes) && flashcards.length >= 3) {
      quizzes = _flashcardsToQuizzes(flashcards, theme: theme);
    } else {
      quizzes = quizzes
          .map(
            (q) => _ensureQuizOptions(q, flashcards, theme: theme),
          )
          .toList();
    }

    if (quizzes.length < 3 && flashcards.length >= 3) {
      quizzes = _flashcardsToQuizzes(flashcards, theme: theme);
    }

    return {
      'flashcards': flashcards.take(10).toList(),
      'quizzes': quizzes.take(5).toList(),
    };
  }

  Map<String, dynamic> _ensureQuizOptions(
    Map<String, dynamic> quiz,
    List<Map<String, dynamic>> flashcards, {
    String? theme,
  }) {
    final question = (quiz['question'] ?? '').toString();
    var correct =
        (quiz['correctAnswer'] ?? quiz['answer'] ?? '').toString().trim();
    var options = (quiz['options'] as List?)
            ?.map((e) => e.toString().trim())
            .where((o) => o.isNotEmpty && !_isPlaceholderOption(o))
            .toList() ??
        [];

    if (correct.isNotEmpty && !options.contains(correct)) {
      options.insert(0, correct);
    }
    if (correct.isEmpty && options.isNotEmpty) {
      correct = options.first;
    }

    final built = _buildOptionsForAnswer(
      correct,
      flashcards,
      theme: theme,
      excludeQuestion: question,
    );

    return {
      'question': question,
      'options': built,
      'correctAnswer': correct,
    };
  }

  Map<String, dynamic> _templateBattleContent(String theme) {
    final bank = _themeQuestionBank[theme] ?? _themeQuestionBank['Mélange']!;
    final flashcards = bank
        .take(5)
        .map((e) => {'question': e['q'], 'answer': e['a']})
        .toList();
    final quizzes = _flashcardsToQuizzes(flashcards, theme: theme);
    return {'flashcards': flashcards, 'quizzes': quizzes};
  }

  static const Map<String, List<Map<String, String>>> _themeQuestionBank = {
    'Mathématiques': [
      {'q': 'Combien font 7 × 8 ?', 'a': '56'},
      {'q': 'Quelle est la racine carrée de 81 ?', 'a': '9'},
      {'q': 'Un triangle dont deux côtés sont égaux est…', 'a': 'isocèle'},
      {'q': 'π arrondi à deux décimales ?', 'a': '3,14'},
      {'q': '15 % de 200 ?', 'a': '30'},
    ],
    'SVT': [
      {'q': 'Organe de la photosynthèse ?', 'a': 'chloroplaste'},
      {'q': 'Molécule porteuse de l\'information génétique ?', 'a': 'ADN'},
      {'q': 'Gaz absorbé par les plantes ?', 'a': 'CO₂'},
      {'q': 'Unité de base du vivant ?', 'a': 'cellule'},
      {'q': 'Organe qui pompe le sang ?', 'a': 'cœur'},
    ],
    'Physique-Chimie': [
      {'q': 'Symbole chimique de l\'eau ?', 'a': 'H₂O'},
      {'q': 'Unité de la force ?', 'a': 'newton'},
      {'q': 'Vitesse = distance / … ?', 'a': 'temps'},
      {'q': 'Planète la plus proche du Soleil ?', 'a': 'Mercure'},
      {'q': 'État de l\'eau à 100 °C (pression normale) ?', 'a': 'gaz'},
    ],
    'Français': [
      {'q': 'Synonyme de « rapide » ?', 'a': 'vite'},
      {'q': 'Nombre de syllabes dans « école » ?', 'a': '2'},
      {'q': 'Auteur des « Misérables » ?', 'a': 'Victor Hugo'},
      {'q': 'Nature du mot « belle » ?', 'a': 'adjectif'},
      {'q': 'Contraire de « ancien » ?', 'a': 'nouveau'},
    ],
    'Histoire-Géo': [
      {'q': 'Capitale du Sénégal ?', 'a': 'Dakar'},
      {'q': 'Continent du Mali ?', 'a': 'Afrique'},
      {'q': 'Année de l\'indépendance du Ghana (1957) — siècle ?', 'a': 'XXe'},
      {'q': 'Fleuve le plus long d\'Afrique ?', 'a': 'Nil'},
      {'q': 'Océan à l\'ouest de l\'Afrique ?', 'a': 'Atlantique'},
    ],
    'Anglais': [
      {'q': 'Traduction de « book » ?', 'a': 'livre'},
      {'q': 'Pluriel de « child » ?', 'a': 'children'},
      {'q': '« Hello » en français ?', 'a': 'bonjour'},
      {'q': 'Contraire de « hot » ?', 'a': 'cold'},
      {'q': '« Thank you » signifie…', 'a': 'merci'},
    ],
    'Mélange': [
      {'q': 'Capitale de la France ?', 'a': 'Paris'},
      {'q': '2 + 2 × 3 ?', 'a': '8'},
      {'q': 'Symbole chimique de l\'or ?', 'a': 'Au'},
      {'q': '« Bonjour » en anglais ?', 'a': 'hello'},
      {'q': 'Planète bleue ?', 'a': 'Terre'},
    ],
  };

  Future<Map<String, dynamic>> generateBattleContent({required String theme}) async {
    if (!await canUseOnlineAI()) {
      return generateBattleContentOffline(theme: theme);
=======
  Future<Map<String, dynamic>> generateBattleContent(
      {required String theme}) async {
    if (!await canUseOnlineAI()) {
      throw Exception(
          'Connexion internet requise pour générer le contenu du défi.');
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    }

    const systemMsg =
        'Tu es un expert en éducation spécialisé dans l\'extraction factuelle. Tu réponds uniquement en JSON.';

    final userMsg = '''Thème du défi : "$theme"

### MISSION :
Génère 5 flashcards et 5 QCM.
Pour chaque QCM : 4 options textuelles DIFFÉRENTES et plausibles (jamais "Option A/B/C/D").
La correctAnswer doit être EXACTEMENT l'une des 4 options (même texte).
Utilise les réponses des autres questions comme mauvaises réponses quand c'est cohérent.

### FORMAT JSON STRICT :
{
  "flashcards": [{"question": "...", "answer": "...", "source": "web", "warning": null}],
  "quizzes": [{"question": "...", "options": ["livre", "stylo", "table", "chaise"], "correctAnswer": "livre", "source": "web", "warning": null}]
}''';

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] Battle via $model');
        final response = await http
            .post(
              Uri.parse(_hfBaseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_hfToken',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'system', 'content': systemMsg},
                  {'role': 'user', 'content': userMsg},
                ],
                'temperature': 0.3, // Plus bas pour la précision
                'max_tokens': 3000,
              }),
            )
            .timeout(const Duration(seconds: 50));

        if (response.statusCode == 200) {
          final raw = jsonDecode(response.body)['choices']?[0]?['message']
                      ?['content']
                  ?.toString() ??
              '';

          final parsed = _extractJson(raw);
          if (parsed != null && parsed['flashcards'] != null) {
            return _normalizeBattleContent(parsed, theme: theme);
          }
        }
      } catch (e) {
        debugPrint('[KALAN AI] $model : $e');
      }
    }
    throw Exception('Impossible de générer le contenu du défi.');
  }

  Map<String, dynamic>? _extractJson(String text) {
    try {
      final s = text.indexOf('{');
      final e = text.lastIndexOf('}') + 1;
      if (s != -1 && e > s) {
        return jsonDecode(text.substring(s, e));
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARSERS
  // ═══════════════════════════════════════════════════════════════════════════

  List<Map<String, String>> _parseFlashcardsJson(String raw) {
    try {
      final s = raw.indexOf('[');
      final e = raw.lastIndexOf(']') + 1;
      if (s == -1 || e <= s) return [];
      final parsed = jsonDecode(raw.substring(s, e)) as List<dynamic>;
      final cards = parsed
          .map<Map<String, String>>((item) => {
                'question':
                    (item['question'] ?? item['q'] ?? '').toString().trim(),
                'answer': (item['answer'] ?? item['a'] ?? '').toString().trim(),
              })
          .where((c) => c['question']!.isNotEmpty && c['answer']!.isNotEmpty)
          .toList();
      if (cards.isNotEmpty)
        debugPrint('[KALAN AI] JSON parsé : ${cards.length} cartes');
      return cards;
    } catch (_) {
      return [];
    }
  }

  List<Map<String, String>> _parseFlashcardsQR(String raw) {
    try {
      final cards = <Map<String, String>>[];
      final qReg = RegExp(
          r'(?:Q\d*|Question\d*)\s*[:：]\s*(.*?)(?=(?:[RA]\d*|Rép\w*\d*|Answer\d*)\s*[:：]|$)',
          caseSensitive: false,
          dotAll: true);
      final aReg = RegExp(
          r'(?:[RA]\d*|Rép\w*\d*|Answer\d*)\s*[:：]\s*(.*?)(?=(?:Q\d*|Question\d*)\s*[:：]|$)',
          caseSensitive: false,
          dotAll: true);
      final qs = qReg.allMatches(raw).toList();
      final as_ = aReg.allMatches(raw).toList();
      final count = qs.length < as_.length ? qs.length : as_.length;
      for (var i = 0; i < count; i++) {
        final q = qs[i].group(1)?.trim() ?? '';
        final a = as_[i].group(1)?.trim() ?? '';
        if (q.isNotEmpty && a.isNotEmpty)
          cards.add({'question': q, 'answer': a});
      }
      if (cards.isNotEmpty)
        debugPrint('[KALAN AI] Q/R parsé : ${cards.length} cartes');
      return cards;
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEURISTIQUE INTELLIGENTE (offline sans Gemma)
  // Produit des questions ciblées selon le type de phrase détecté
  // ═══════════════════════════════════════════════════════════════════════════

  List<Map<String, String>> _smartHeuristic(String text) {
    final cards = <Map<String, String>>[];
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = clean
        .split(RegExp(r'(?<=[.!?;\n])\s+'))
        .map((s) => s.replaceAll(RegExp(r'^[\d\.\-\s•*+–—]+'), '').trim())
        .where((s) => s.length > 12)
        .toList();

    for (final s in sentences) {
      if (cards.length >= 5) break;
      final card = _extractCard(s);
      if (card != null) {
        final isDup = cards.any((c) => c['question'] == card['question']);
        if (!isDup) cards.add(card);
      }
    }

    // Complément si moins de 5 cartes
    if (cards.length < 5) {
      for (final s in sentences) {
        if (cards.length >= 5) break;
        final snippet = s.length > 60 ? '${s.substring(0, 60)}...' : s;
        final isDup = cards.any((c) => c['answer'] == s);
        if (!isDup && s.length > 20) {
          cards.add({
            'question': 'Que retenir de : "$snippet" ?',
            'answer': s,
          });
        }
      }
    }

    // Sécurité : toujours 5 cartes minimum
    while (cards.length < 5) {
      final snippet =
          clean.length > 80 ? '${clean.substring(0, 80)}...' : clean;
      cards.add({
        'question': 'Point clé ${cards.length + 1} du cours :',
        'answer': snippet,
      });
    }

    return cards.take(5).toList();
  }

  /// Analyse une phrase et retourne la carte Q/R la plus pertinente selon son type.
  Map<String, String>? _extractCard(String sentence) {
    final lower = sentence.toLowerCase();

    // 1. Définition : "X est/sont/signifie/désigne Y"
    const defKw = [
      'est ',
      'sont ',
      'signifie ',
      'désigne ',
      'correspond à ',
      'représente '
    ];
    for (final kw in defKw) {
      final idx = lower.indexOf(kw);
      if (idx > 3 && idx < sentence.length - 8) {
        final subj = sentence.substring(0, idx).trim();
        final def = sentence.substring(idx + kw.length).trim();
        if (subj.length > 2 && subj.length < 50 && def.length > 5) {
          final q = subj.endsWith('?') ? subj : 'Qu\'est-ce que $subj ?';
          return {'question': q, 'answer': def};
        }
      }
    }

    // 2. Année/date : contient 4 chiffres consécutifs
    final yearMatch = RegExp(r'\b(1\d{3}|20\d{2})\b').firstMatch(sentence);
    if (yearMatch != null) {
      final year = yearMatch.group(0)!;
      final context = sentence.replaceAll(year, '___');
      final q = context.length < 80
          ? 'En quelle année : "${context.trim()}" ?'
          : 'Quelle date est mentionnée dans cette phrase ?';
      return {'question': q, 'answer': year};
    }

    // 3. Quantité : "Il y a N / X comporte N / N ..."
    final numMatch =
        RegExp(r'\b(\d+(?:[.,]\d+)?)\s+(\w+)').firstMatch(sentence);
    if (numMatch != null) {
      final num = numMatch.group(1)!;
      final unit = numMatch.group(2)!;
      return {
        'question': 'Combien de $unit mentionne ce passage ?',
        'answer': '$num $unit',
      };
    }

    // 4. Processus/cause : "pour que", "afin de", "grâce à", "permet de"
    const processKw = [
      'permet de ',
      'grâce à ',
      'afin de ',
      'pour que ',
      'en raison de '
    ];
    for (final kw in processKw) {
      if (lower.contains(kw)) {
        final idx = lower.indexOf(kw);
        final before = sentence.substring(0, idx).trim();
        final after = sentence.substring(idx + kw.length).trim();
        if (before.isNotEmpty && after.isNotEmpty) {
          return {
            'question':
                'Comment / Pourquoi : "${before.length > 50 ? '${before.substring(0, 50)}...' : before}" ?',
            'answer':
                after.length > 80 ? '${after.substring(0, 80)}...' : after,
          };
        }
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DÉTECTION MATIÈRE
  // ═══════════════════════════════════════════════════════════════════════════

  String _detectSubjectHeuristic(String text) {
    final t = text.toLowerCase();
    if (_has(t, [
      'fraction',
      'équation',
      'calculer',
      'géométrie',
      'triangle',
      'théorème',
      'nombre',
      'fonction',
      'algèbre',
      'dérivée'
    ])) return 'Mathématiques';
    if (_has(t, [
      'cellule',
      'plante',
      'organe',
      'adn',
      'génétique',
      'reproduction',
      'chlorophylle',
      'mitose',
      'espèce',
      'chimie',
      'atome',
      'molécule',
      'force',
      'vitesse',
      'pesanteur',
      'électricité',
      'lumière',
      'réaction',
      'photosynthèse',
      'énergie'
    ])) return 'Sciences';
    if (_has(t, [
      'poème',
      'conjugaison',
      'verbe',
      'grammaire',
      'orthographe',
      'littérature',
      'adjectif',
      'roman',
      'auteur'
    ])) return 'Français';
    if (_has(t, [
      'histoire',
      'guerre',
      'siècle',
      'géographie',
      'climat',
      'carte',
      'afrique',
      'empire',
      'révolution'
    ])) return 'Histoire-Géo';
    if (_has(t, [
      'english',
      'vocabulary',
      'translate',
      'pronoun',
      'tense',
      'grammar',
      'verb',
      'noun',
      'arabe',
      'arabic',
      'allemand'
    ])) return 'Langues';
    return 'Autre';
  }

  bool _has(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  // ═══════════════════════════════════════════════════════════════════════════
  // NETTOYAGE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> unloadModel() async {
    await _gemmaService?.unloadModel();
    await _qwenService?.dispose();
    _qwenService = null;
  }
}
