import 'package:flutter_test/flutter_test.dart';
import 'package:kalan_app/services/local_ai_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock connectivité
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return ['wifi'];
  });

  final List<String> testQuestions = [
    "Quelle est la capitale du Burkina Faso ?",
    "Qui est l'auteur de 'L'Enfant Noir' ?",
    "Quelle est la formule chimique de l'eau ?",
    "En quelle année le Mali a-t-il eu son indépendance ?",
    "Quel est le plus grand désert du monde ?"
  ];

  group('Simulation Duel IA (Questions nues)', () {
    late LocalAIService aiService;

    setUpAll(() async {
      try {
        await dotenv.load(fileName: ".env.test");
      } catch (_) {}
      aiService = LocalAIService();
    });

    test('Simulation Qwen (Online + Web Search)', () async {
      print('\n--- SIMULATION QWEN (ONLINE) ---');
      for (var q in testQuestions) {
        // Simulation du prompt final qui serait envoyé à Qwen
        final prompt = '''Question de culture générale : "$q"
### MISSION :
1. Utilise ton Web Search interne.
2. Vérifie au moins 2 sources concordantes.
3. Si concordant -> Réponse factuelle courte.
JSON : {"question": "$q", "answer": "<réponse>", "source": "web"}''';
        
        print('Input: $q');
        print('Stratégie attendue: Web Search + Validation double');
        print('Réponse type (JSON): {"question": "$q", "answer": "Ouagadougou", "source": "web"}\n');
      }
    });

    test('Simulation Gemma (Offline + Expertise)', () {
      print('\n--- SIMULATION GEMMA (OFFLINE) ---');
      const subject = "Culture Générale";
      
      // On simule le prompt "Expertise" que j'ai créé
      for (var q in testQuestions) {
        final prompt = '''### ROLE
Tu es un professeur expert en $subject. 

### MISSION
Génère une flashcard basées sur la question ci-dessous.
CONSIGNE SPÉCIALE : Utilise tes connaissances de professeur pour donner des réponses exactes et concises.

### RÈGLES D'OR
1. Réponse = FRAGMENT MINIMAL (1 à 3 mots).
2. NE RÉPÈTE JAMAIS la question dans la réponse.

### QUESTION À TRAITER
$q

Q: $q
R:''';
        
        print('Input: $q');
        print('Stratégie: Extraction depuis mémoire interne (No Web)');
        // Exemple de ce que Gemma 1.1B/2B produit avec ce genre de prompt
        String simulatedAnswer = "";
        if (q.contains("Burkina")) simulatedAnswer = "Ouagadougou";
        if (q.contains("L'Enfant Noir")) simulatedAnswer = "Camara Laye";
        if (q.contains("eau")) simulatedAnswer = "H2O";
        
        print('Réponse attendue: $simulatedAnswer\n');
      }
    });
  });
}
