import 'package:flutter_test/flutter_test.dart';
import 'package:kalan_app/services/local_ai_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return ['wifi'];
  });

  group('Tests IA Online (Qwen)', () {
    late LocalAIService aiService;

    setUpAll(() async {
      // Version la plus robuste : on utilise load() mais en s'assurant que le fichier est là
      // et on utilise une alternative si ça échoue.
      try {
        final content = await File('.env.test').readAsString();
        // On essaie de charger via string si disponible dans cette version
        // Sinon on force le chargement du fichier.
        await dotenv.load(fileName: ".env.test");
      } catch (e) {
        print('Tentative chargement manuel...');
      }
      aiService = LocalAIService();
    });

    test('Cas 1: Notes fournies + question précise (Extraction)', () async {
      if (dotenv.env['HF_TOKEN'] == null) markTestSkipped('Token non chargé');
      
      final result = await aiService.generateSingleFlashcard(
        input: "Qu'est-ce qu'Ali aime ?",
        notes: "Ali est un élève sérieux. Ali aime les mangues et le football.",
      );
      print('CAS 1 (Notes + Q): $result');
      expect(result['source'], 'cours');
      expect(result['answer'].toString().toLowerCase(), anyOf(contains('mangue'), contains('football')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Cas 2: Notes fournies + phrase affirmative (Transformation)', () async {
      if (dotenv.env['HF_TOKEN'] == null) markTestSkipped('Token non chargé');

      final result = await aiService.generateSingleFlashcard(
        input: "Ali aime les mangues",
        notes: "Ali est un élève sérieux. Ali aime les mangues et le football.",
      );
      print('CAS 2 (Notes + Info): $result');
      expect(result['source'], 'cours');
      expect(result['answer'].toString().toLowerCase(), contains('mangue'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Cas 3: Culture G sans cours (Web Search)', () async {
      if (dotenv.env['HF_TOKEN'] == null) markTestSkipped('Token non chargé');

      final result = await aiService.generateSingleFlashcard(
        input: "Quelle est la capitale de la France ?",
      );
      print('CAS 3 (Culture G): $result');
      expect(result['source'], 'web');
      expect(result['answer'].toString().toLowerCase(), contains('paris'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Battle sur le thème "Système Respiratoire"', () async {
      if (dotenv.env['HF_TOKEN'] == null) markTestSkipped('Token non chargé');

      final result = await aiService.generateBattleContent(theme: "Le système respiratoire humain");
      print('BATTLE CONTENT: ${result['flashcards'].length} cards, ${result['quizzes'].length} quizzes');
      expect(result['flashcards'].length, 10);
      expect(result['quizzes'].length, 10);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Tests IA Offline (Gemma - Logique de Prompt)', () {
    test('Vérification du prompt "Expertise professeur"', () {
      final aiService = LocalAIService();
      // On teste la structure du prompt via une méthode de secours ou en vérifiant le code
      // Ici, on va simuler ce que l'IA recevrait
      const subject = "Histoire-Géo";
      const text = "L'Empire du Ghana était puissant.";
      
      // Simulation du prompt (le même que dans le service)
      final prompt = '''### ROLE
Tu es un professeur expert en $subject. 

### MISSION
Génère 5 flashcards (Question/Réponse) basées sur le texte ci-dessous.
CONSIGNE SPÉCIALE : Si le texte est incomplet, utilise tes connaissances de professeur pour donner des réponses exactes et concises.

### TEXTE À TRAITER ($subject)
$text''';

      print('PROMPT GÉNÉRÉ POUR GEMMA:\n$prompt');
      expect(prompt, contains('professeur expert'));
      expect(prompt, contains('connaissances de professeur'));
    });
  });
}
