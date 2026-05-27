import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai/gemma_service.dart';
import '../ai/model_downloader.dart';
import 'connectivity_service.dart';

class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  // LAZY : GemmaService n'est créé que si on en a vraiment besoin (offline).
  // Cela empêche TfLite/XNNPack de s'initialiser lors de l'ouverture de l'arène.
  GemmaService? _gemmaService;

  static String get _hfToken => dotenv.env['HF_TOKEN'] ?? '';
  static const String _hfBaseUrl = 'https://router.huggingface.co/v1/chat/completions';
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
        final cards = await _generateOnlineFlashcards(text, subject)
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

    final offline = await _generateOfflineFlashcards(text, subject, context: userContext);
    return {
      'subject': subject,
      'flashcards': offline.cards,
      'mode': offline.mode,
      if (offline.modelMissing) 'offlineModelMissing': true,
    };
  }

  // ─── Online : Qwen avec prompt structuré et système de rôle ───────────────

  Future<List<Map<String, String>>> _generateOnlineFlashcards(
      String text, String subject) async {
    final truncatedText = text.length > 6000 ? '${text.substring(0, 6000)}...' : text;

    final userPrompt = '''Texte de cours (matière : $subject) :
"""
$truncatedText
"""

### ÉTAPE 1 — DIAGNOSTIC QUALITÉ
Si le texte est illisible, trop court (< 15 mots) ou incohérent (caractères aléatoires),
retourne UNIQUEMENT : {"error": "image_floue"}

### ÉTAPE 2 — GÉNÉRATION (si texte lisible)
Génère exactement 5 flashcards de révision variées.
Règles :
- Questions précises et ciblées (jamais "Explique le cours...")
- Réponses courtes (1 à 2 phrases max)
- Varie les types : Qu'est-ce que / Comment / Pourquoi / Quel est / En quelle année / Qui / Combien
- JSON uniquement, sans markdown ni texte autour

[
  {"question": "...", "answer": "..."}
]''';

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] Flashcards online via $model');
        final response = await http.post(
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
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 503 || response.statusCode == 429) {
          debugPrint('[KALAN AI] $model indisponible (${response.statusCode}), suivant...');
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

  // ─── Offline : Gemma (lazy) → heuristique ─────────────────────────────────

  Future<
      ({
        List<Map<String, String>> cards,
        String mode,
        bool modelMissing
      })> _generateOfflineFlashcards(String text, String subject, {String? context}) async {
    if (text.trim().length < 10) {
      return (cards: _smartHeuristic(text), mode: 'heuristic', modelMissing: false);
    }

    final modelInstalled = await ModelDownloader.isModelDownloaded();
    if (!modelInstalled) {
      debugPrint('[KALAN AI] Gemma absent → heuristique');
      return (cards: _smartHeuristic(text), mode: 'heuristic', modelMissing: true);
    }

    try {
      debugPrint('[KALAN AI] Gemma offline...');
      // Création lazy : TfLite ne charge que maintenant, pas avant
      _gemmaService ??= GemmaService();
      final truncated = text.length > 4000 ? '${text.substring(0, 4000)}...' : text;
      final lang = _detectLanguage(truncated);
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

  // ─── Détection langue source ───────────────────────────────────────────────

  String _detectLanguage(String text) {
    final lower = text.toLowerCase();
    int frScore = 0, enScore = 0;
    const frWords = [' le ', ' la ', ' les ', ' de ', ' du ', ' des ', ' une ', ' et ', ' est ', ' sont ', ' dans ', ' pour ', ' avec ', ' qui ', ' que ', ' ce ', ' se ', ' sur ', ' au ', ' il ', ' elle ', ' nous ', ' vous '];
    const enWords = [' the ', ' is ', ' are ', ' was ', ' were ', ' have ', ' has ', ' had ', ' will ', ' would ', ' can ', ' could ', ' this ', ' that ', ' from ', ' with ', ' and ', ' but ', ' for ', ' in ', ' of ', ' to ', ' they ', ' their '];
    for (final w in frWords) if (lower.contains(w)) frScore++;
    for (final w in enWords) if (lower.contains(w)) enScore++;
    return enScore > frScore ? 'anglais' : 'français';
  }

  // ─── Prompt Gemma : bilingue, contexte, format robuste ────────────────────

  String _buildGemmaPrompt(String text, String subject, {String? context, String lang = 'français'}) {
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
    final hasNotes = notes != null && notes.trim().length >= 20;
    final isQuestion = _isQuestion(trimmed);

    final int casNum;
    final String prompt;

    if (hasNotes && isQuestion) {
      casNum = 1;
      prompt = _buildCas1Prompt(trimmed, notes!.trim());
    } else if (hasNotes) {
      casNum = 2;
      prompt = _buildCas2Prompt(trimmed, notes!.trim());
    } else {
      casNum = 3;
      prompt = _buildCas3Prompt(trimmed);
    }

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] generateSingleFlashcard cas $casNum via $model');
        final response = await http.post(
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
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode == 503 || response.statusCode == 429) {
          debugPrint('[KALAN AI] $model indisponible (${response.statusCode}), suivant...');
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
      "qu'est", 'quel ', 'quelle ', 'quels ', 'quelles ',
      'comment ', 'pourquoi ', 'quand ', 'où ', 'qui ',
      'combien ', 'est-ce que', 'y a-t-il', 'que ', 'quoi ',
      'what ', 'who ', 'where ', 'when ', 'why ', 'how ',
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
      final parsed = jsonDecode(raw.substring(start, end)) as Map<String, dynamic>;
      if (!parsed.containsKey('question') || !parsed.containsKey('source')) return null;
      
      final answer = parsed['answer']?.toString().trim() ?? '';
      if (answer.toLowerCase() == "non trouvé" || answer == input.trim()) return null;
      
      return parsed;
    } catch (e) {
      debugPrint('[KALAN AI] _parseSingleCard : $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÉNÉRATION CONTENU BATAILLE (Qwen uniquement — jamais Gemma)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateBattleContent({required String theme}) async {
    if (!await canUseOnlineAI()) {
      throw Exception('Connexion internet requise pour générer le contenu du défi.');
    }

    const systemMsg =
        'Tu es un expert en éducation spécialisé dans l\'extraction factuelle. Tu réponds uniquement en JSON.';

    final userMsg = '''Thème du défi : "$theme"

### MISSION :
Génère 10 flashcards et 10 QCM.
Pour chaque réponse :
1. Vérifie via Web Search.
2. Si contradiction -> mets "answer": null et un "warning".
3. RÉPONSE = FRAGMENT MINIMAL.

### FORMAT JSON STRICT :
{
  "flashcards": [{"question": "...", "answer": "...", "source": "web", "warning": null}],
  "quizzes": [{"question": "...", "options": ["A","B","C","D"], "correctAnswer": "...", "source": "web", "warning": null}]
}''';

    for (final model in _models) {
      try {
        debugPrint('[KALAN AI] Battle via $model');
        final response = await http.post(
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
        ).timeout(const Duration(seconds: 50));

        if (response.statusCode == 200) {
          final raw = jsonDecode(response.body)['choices']?[0]?['message']
                  ?['content']
                  ?.toString() ??
              '';
          
          final parsed = _extractJson(raw);
          if (parsed != null && parsed['flashcards'] != null) {
            return parsed;
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
      final cards = parsed.map<Map<String, String>>((item) => {
            'question': (item['question'] ?? item['q'] ?? '').toString().trim(),
            'answer': (item['answer'] ?? item['a'] ?? '').toString().trim(),
          }).where((c) => c['question']!.isNotEmpty && c['answer']!.isNotEmpty).toList();
      if (cards.isNotEmpty) debugPrint('[KALAN AI] JSON parsé : ${cards.length} cartes');
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
          caseSensitive: false, dotAll: true);
      final aReg = RegExp(
          r'(?:[RA]\d*|Rép\w*\d*|Answer\d*)\s*[:：]\s*(.*?)(?=(?:Q\d*|Question\d*)\s*[:：]|$)',
          caseSensitive: false, dotAll: true);
      final qs = qReg.allMatches(raw).toList();
      final as_ = aReg.allMatches(raw).toList();
      final count = qs.length < as_.length ? qs.length : as_.length;
      for (var i = 0; i < count; i++) {
        final q = qs[i].group(1)?.trim() ?? '';
        final a = as_[i].group(1)?.trim() ?? '';
        if (q.isNotEmpty && a.isNotEmpty) cards.add({'question': q, 'answer': a});
      }
      if (cards.isNotEmpty) debugPrint('[KALAN AI] Q/R parsé : ${cards.length} cartes');
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
      final snippet = clean.length > 80 ? '${clean.substring(0, 80)}...' : clean;
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
    const defKw = ['est ', 'sont ', 'signifie ', 'désigne ', 'correspond à ', 'représente '];
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
    final numMatch = RegExp(r'\b(\d+(?:[.,]\d+)?)\s+(\w+)').firstMatch(sentence);
    if (numMatch != null) {
      final num = numMatch.group(1)!;
      final unit = numMatch.group(2)!;
      return {
        'question': 'Combien de $unit mentionne ce passage ?',
        'answer': '$num $unit',
      };
    }

    // 4. Processus/cause : "pour que", "afin de", "grâce à", "permet de"
    const processKw = ['permet de ', 'grâce à ', 'afin de ', 'pour que ', 'en raison de '];
    for (final kw in processKw) {
      if (lower.contains(kw)) {
        final idx = lower.indexOf(kw);
        final before = sentence.substring(0, idx).trim();
        final after = sentence.substring(idx + kw.length).trim();
        if (before.isNotEmpty && after.isNotEmpty) {
          return {
            'question': 'Comment / Pourquoi : "${before.length > 50 ? '${before.substring(0, 50)}...' : before}" ?',
            'answer': after.length > 80 ? '${after.substring(0, 80)}...' : after,
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
    if (_has(t, ['fraction', 'équation', 'calculer', 'géométrie', 'triangle', 'théorème', 'nombre', 'fonction', 'algèbre', 'dérivée'])) return 'Mathématiques';
    if (_has(t, ['cellule', 'plante', 'organe', 'adn', 'génétique', 'reproduction', 'chlorophylle', 'mitose', 'espèce'])) return 'SVT';
    if (_has(t, ['chimie', 'atome', 'molécule', 'force', 'vitesse', 'pesanteur', 'électricité', 'lumière', 'réaction'])) return 'Physique-Chimie';
    if (_has(t, ['informatique', 'algorithme', 'code', 'programmation', 'variable', 'boucle', 'fonction', 'binaire'])) return 'Informatique';
    if (_has(t, ['poème', 'conjugaison', 'verbe', 'grammaire', 'orthographe', 'littérature', 'adjectif', 'roman', 'auteur'])) return 'Français';
    if (_has(t, ['histoire', 'guerre', 'siècle', 'géographie', 'climat', 'carte', 'afrique', 'empire', 'révolution'])) return 'Histoire-Géo';
    if (_has(t, ['english', 'vocabulary', 'translate', 'pronoun', 'tense', 'grammar', 'verb', 'noun'])) return 'Anglais';
    return 'Autre';
  }

  bool _has(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  // ═══════════════════════════════════════════════════════════════════════════
  // NETTOYAGE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> unloadModel() async {
    await _gemmaService?.unloadModel();
  }
}
