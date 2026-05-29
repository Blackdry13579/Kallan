import 'package:flutter_test/flutter_test.dart';
import 'package:kalan_app/core/constants/subject_categories.dart';
import 'package:kalan_app/services/ai_json_parser.dart';

void main() {
  group('AiJsonParser', () {
    test('parse un tableau JSON brut de flashcards', () {
      const raw = '''
[
  {"question":"What is photosynthesis?","answer":"Plants make glucose using light."},
  {"question":"Where does it occur?","answer":"In leaves and chloroplasts."}
]
''';

      final result = AiJsonParser.parseFlashcardResult(
        raw,
        fallbackCategory: SubjectCategories.sciences,
        fallbackLanguage: 'anglais',
      );

      expect(result.category, SubjectCategories.sciences);
      expect(result.language, 'anglais');
      expect(result.flashcards, hasLength(2));
      expect(result.flashcards.first['question'], 'What is photosynthesis?');
    });

    test('retire les fences markdown json de Qwen', () {
      const raw = '''
```json
{
  "domaine": "Biologie",
  "language": "français",
  "source_type": "questions",
  "flashcards": [
    {"question":"Quel gaz est libéré ?","answer":"Le dioxygène."}
  ]
}
```
''';

      final result = AiJsonParser.parseFlashcardResult(raw);

      expect(result.category, SubjectCategories.sciences);
      expect(result.domain, 'Biologie');
      expect(result.sourceType, 'questions');
      expect(result.flashcards.single['answer'], 'Le dioxygène.');
    });

    test('normalise les catégories techniques vers Autre', () {
      const raw = '''
{
  "category": "Technologie de l'information",
  "domain": "Réseaux",
  "flashcards": [
    {"question":"À quoi sert DNS ?","answer":"Il traduit les noms de domaine en adresses IP."}
  ]
}
''';

      final result = AiJsonParser.parseFlashcardResult(raw);

      expect(result.category, SubjectCategories.autre);
      expect(result.domain, 'Réseaux');
    });

    test('filtre les cartes vides ou invalides', () {
      const raw = '''
{
  "category": "Sciences",
  "flashcards": [
    {"question":"","answer":"Réponse"},
    {"question":"Même","answer":"Même"},
    {"question":"Question valide ?","answer":"Réponse valide."}
  ]
}
''';

      final result = AiJsonParser.parseFlashcardResult(raw);

      expect(result.flashcards, hasLength(1));
      expect(result.flashcards.single['question'], 'Question valide ?');
    });

    test('extrait le JSON même avec du texte parasite autour', () {
      const raw = '''
Voici le résultat:
{
  "category": "Maths",
  "flashcards": [
    {"question":"Qu'est-ce qu'une fraction ?","answer":"Une partie d'un tout."}
  ]
}
Fin.
''';

      final result = AiJsonParser.parseFlashcardResult(raw);

      expect(result.category, SubjectCategories.mathematiques);
      expect(result.flashcards, hasLength(1));
    });
  });
}
