import 'dart:convert';

import '../core/constants/subject_categories.dart';

class AiFlashcardResult {
  final String category;
  final String domain;
  final String language;
  final String sourceType;
  final List<Map<String, String>> flashcards;

  const AiFlashcardResult({
    required this.category,
    required this.domain,
    required this.language,
    required this.sourceType,
    required this.flashcards,
  });

  bool get hasEnoughCards => flashcards.length >= 3;
}

class AiJsonParser {
  static AiFlashcardResult parseFlashcardResult(
    String raw, {
    String fallbackCategory = SubjectCategories.autre,
    String fallbackLanguage = 'français',
  }) {
    final decoded = _decodeJson(raw);

    if (decoded is List) {
      return AiFlashcardResult(
        category: SubjectCategories.normalize(fallbackCategory),
        domain: '',
        language: fallbackLanguage,
        sourceType: 'course',
        flashcards: _parseCards(decoded),
      );
    }

    if (decoded is Map<String, dynamic>) {
      final category = SubjectCategories.normalize(
        decoded['category'] ?? decoded['subject'] ?? decoded['domaine'],
      );
      final cardsSource = decoded['flashcards'] ?? decoded['cards'];
      return AiFlashcardResult(
        category: category,
        domain: (decoded['domain'] ?? decoded['domaine'] ?? '').toString(),
        language: (decoded['language'] ?? decoded['langue'] ?? fallbackLanguage)
            .toString(),
        sourceType:
            (decoded['source_type'] ?? decoded['sourceType'] ?? 'course')
                .toString(),
        flashcards: cardsSource is List ? _parseCards(cardsSource) : const [],
      );
    }

    throw const FormatException(
        'La réponse IA ne contient pas de JSON valide.');
  }

  static dynamic _decodeJson(String raw) {
    final cleaned = _cleanMarkdown(raw);
    final jsonText = _extractJsonText(cleaned);
    return jsonDecode(jsonText);
  }

  static String _cleanMarkdown(String raw) {
    return raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
  }

  static String _extractJsonText(String text) {
    final objectStart = text.indexOf('{');
    final arrayStart = text.indexOf('[');

    if (objectStart == -1 && arrayStart == -1) {
      throw const FormatException('Aucun JSON détecté.');
    }

    final startsWithArray =
        arrayStart != -1 && (objectStart == -1 || arrayStart < objectStart);

    if (startsWithArray) {
      final end = text.lastIndexOf(']');
      if (end <= arrayStart) {
        throw const FormatException('Tableau JSON incomplet.');
      }
      return text.substring(arrayStart, end + 1);
    }

    final end = text.lastIndexOf('}');
    if (end <= objectStart) {
      throw const FormatException('Objet JSON incomplet.');
    }
    return text.substring(objectStart, end + 1);
  }

  static List<Map<String, String>> _parseCards(List<dynamic> rawCards) {
    final cards = <Map<String, String>>[];

    for (final item in rawCards) {
      if (item is! Map) continue;
      final question = (item['question'] ?? item['q'] ?? '').toString().trim();
      final answer = (item['answer'] ?? item['a'] ?? '').toString().trim();
      if (!_isValidCard(question, answer)) continue;

      cards.add({
        'question': _limit(question, 220),
        'answer': _limit(answer, 280),
      });
    }

    return cards;
  }

  static bool _isValidCard(String question, String answer) {
    if (question.isEmpty || answer.isEmpty) return false;
    if (question.toLowerCase() == answer.toLowerCase()) return false;
    if (question.length < 4 || answer.length < 2) return false;
    return true;
  }

  static String _limit(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength).trimRight()}...';
  }
}
