import 'package:flutter/foundation.dart';
import '../ai/local_llm_engine.dart';
import 'ai_json_parser.dart';
import '../core/constants/subject_categories.dart';

class QwenFlashcardService {
  final LocalLlmEngine _engine;
  String? _loadedPath;

  QwenFlashcardService(this._engine);

  /// Charge le modèle si ce n'est pas déjà fait (idempotent).
  Future<void> ensureLoaded(String modelPath) async {
    if (_loadedPath == modelPath) return;
    await _engine.loadModel(modelPath);
    _loadedPath = modelPath;
  }

  /// Génère des flashcards depuis un texte de cours.
  Future<AiFlashcardResult> generateFlashcards({
    required String text,
    required String subject,
    String? context,
    String? language,
    int count = 5,
  }) async {
    final lang = language ?? 'français';
    final cleanText = _cleanText(text);
    final prompt = _buildPrompt(cleanText, subject, lang, context, count);

    debugPrint('[QwenFlashcardService] Génération offline — sujet: $subject, langue: $lang');

    final raw = await _engine.generateText(prompt, maxTokens: 400);

    debugPrint('[QwenFlashcardService] Réponse brute (${raw.length} chars)');

    return AiJsonParser.parseFlashcardResult(
      raw,
      fallbackCategory: subject,
      fallbackLanguage: lang,
    );
  }

  Future<void> dispose() => _engine.dispose();

  // ─────────────────────────────────────────────────────────────────────────
  // Prompt Qwen structuré (cf. README_IMPLEMENTATION_QWEN_FLUTTER.md)
  // ─────────────────────────────────────────────────────────────────────────

  String _buildPrompt(
    String text,
    String subject,
    String lang,
    String? context,
    int count,
  ) {
    final contextBlock = (context != null && context.trim().isNotEmpty)
        ? 'Contexte du document : ${context.trim()}\n\n'
        : '';

    final categoriesAllowed = SubjectCategories.all.join(', ');
    final sourceType = _detectSourceType(text);
    final sourceInstruction = _buildSourceInstruction(sourceType);
    final mixRule = count >= 4
        ? '${count - 2} questions ouvertes + 2 questions Vrai/Faux'
        : 'questions ouvertes uniquement';
    final langInstruction = _buildLanguageInstruction(lang);

    return '''Tu es KALAN, une IA éducative offline.
Tu génères des flashcards fiables pour des élèves du secondaire.

$langInstruction

RETOURNE UNIQUEMENT UN OBJET JSON BRUT.
INTERDIT ABSOLU : markdown, backtick, \`\`\`json, tout texte avant ou après le JSON.

Catégories autorisées : $categoriesAllowed

RÈGLES STRICTES (à respecter dans l'ordre) :
1. LANGUE : voir instruction ci-dessus. Respecte-la absolument.
2. QUANTITÉ : Génère exactement $count flashcards. Ni plus, ni moins.
3. MÉLANGE : $mixRule.
4. QUESTIONS OUVERTES : Commence OBLIGATOIREMENT par un mot interrogatif : Quelle, Comment, Pourquoi, Quand, Qui, Où, Qu'est-ce que, De quoi, En quoi.
5. QUESTIONS VRAI/FAUX : La réponse doit TOUJOURS contenir une explication courte (ex: "Vrai, car..." ou "Faux, car...").
6. INTERDIT dans les questions : les points de suspension "..." et les blancs à remplir. Formule une vraie question.
7. LONGUEUR QUESTION : maximum 30 mots. Phrase complète, claire, bien formulée.
8. LONGUEUR RÉPONSE : maximum 30 mots. Phrase complète, grammaticalement correcte.
9. TEXTE BRUITÉ : Si le texte contient des symboles parasites (|, #, @, 0 à la place de o, 1 à la place de l), ignore-les et concentre-toi sur le sens du contenu.
10. FIABILITÉ : Si une réponse n'est pas clairement dans le texte, écris exactement : "À vérifier avec le cours".
11. N'invente JAMAIS de termes scientifiques ou techniques absents du texte.
12. CATÉGORIE : Détecte la plus adaptée parmi les catégories autorisées.
13. DOMAINE : Précise le sous-domaine si possible (ex: Biologie, Physique, Algèbre).

$sourceInstruction

Format obligatoire :
{"category":"string","domain":"string","language":"string","source_type":"course|questions|mixed|notes","flashcards":[{"question":"string","answer":"string"}]}

${contextBlock}Texte :
"""
$text
"""''';
  }

  // Détecte si le texte est principalement une liste de questions
  String _detectSourceType(String text) {
    final questionMarks = RegExp(r'\?').allMatches(text).length;
    final numberedLines =
        RegExp(r'^\s*\d+[\).]', multiLine: true).allMatches(text).length;
    if (questionMarks >= 3 || numberedLines >= 3) return 'questions';
    return 'course';
  }

  // Instruction spécifique selon le type de source détecté
  String _buildSourceInstruction(String sourceType) {
    if (sourceType == 'questions') {
      return '''TYPE DÉTECTÉ : liste de questions sans réponses.
INSTRUCTION SPÉCIALE :
- Utilise les questions du texte comme base pour créer les flashcards.
- Reformule-les en vraies questions pédagogiques si nécessaire.
- Si la réponse n'est pas dans le texte, utilise tes connaissances générales ET marque la réponse "À vérifier avec le cours".''';
    }
    return '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Nettoyage du texte avant envoi au modèle
  // ─────────────────────────────────────────────────────────────────────────

  String _buildLanguageInstruction(String lang) {
    final l = lang.toLowerCase();
    final isEnglish = l.contains('anglais') || l.contains('english');
    final isSpanish = l.contains('espagnol') || l.contains('spanish');
    final isArabic = l.contains('arabe') || l.contains('arabic');

    if (isEnglish) {
      return 'The document is written in English.\n'
          'You MUST write every question and every answer in English.\n'
          'Do NOT translate to French or any other language.';
    }
    if (isSpanish) {
      return 'El documento está escrito en español.\n'
          'DEBES escribir cada pregunta y cada respuesta en español.\n'
          'No traduzcas al francés ni a ningún otro idioma.';
    }
    if (isArabic) {
      return 'الوثيقة مكتوبة باللغة العربية.\n'
          'يجب أن تكتب كل سؤال وكل إجابة باللغة العربية.\n'
          'لا تترجم إلى الفرنسية أو أي لغة أخرى.';
    }
    // Default: French (and any other language — rule written in French)
    return 'Langue du document : $lang.\n'
        'Tu dois générer chaque question et chaque réponse en $lang.\n'
        'Ne traduis jamais dans une autre langue.';
  }

  String _cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
