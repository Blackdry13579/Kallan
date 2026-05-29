# Implémentation Qwen offline dans Flutter

Ce document décrit le plan complet pour intégrer Qwen2.5 1.5B offline dans l'application Flutter KALAN, en se concentrant uniquement sur le cas où l'application reçoit déjà du texte exploitable.

L'OCR des PDF scannés/images est volontairement hors périmètre ici. Cette partie sera traitée séparément.

## Objectif

Remplacer progressivement Gemma offline par Qwen2.5 1.5B Q4_K_M afin de générer de meilleures flashcards depuis :

- texte extrait d'un PDF texte ;
- texte collé manuellement ;
- texte OCR déjà fourni par un autre module ;
- liste de questions ;
- notes de cours structurées.

Le flux cible est :

```text
Texte reçu par l'app
        |
Analyse locale légère
        |
Détection langue + catégorie
        |
Contexte utilisateur facultatif
        |
Prompt Qwen strict
        |
Génération offline
        |
Nettoyage + parsing JSON
        |
Validation des flashcards
        |
Création du deck Flutter
        |
Rangement dans la catégorie détectée
```

## Modèle choisi

Modèle :

```text
Qwen2.5 1.5B Instruct
```

Version de test :

```text
enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF
```

Fichier :

```text
qwen2.5-1.5b-instruct-q4_k_m.gguf
```

URL :

```text
https://huggingface.co/enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf
```

Caractéristiques :

- 1.54B paramètres ;
- quantification Q4_K_M ;
- environ 986 Mo ;
- format GGUF ;
- licence Apache-2.0 ;
- exécution prévue via runtime compatible llama.cpp/GGUF.

## Catégories Flutter

KALAN doit ranger automatiquement les fiches dans une catégorie compréhensible pour l'élève. L'IA doit proposer une catégorie, mais l'app doit garder une liste fixe pour éviter les catégories incohérentes.

Catégories recommandées pour la v1 :

```dart
enum KalanSubjectCategory {
  sciences,
  langues,
  litterature,
  humanites,
  informatique,
  mathematiques,
  autre,
}
```

Labels affichés :

```dart
const kalanSubjectLabels = {
  KalanSubjectCategory.sciences: 'Sciences',
  KalanSubjectCategory.langues: 'Langues',
  KalanSubjectCategory.litterature: 'Littérature',
  KalanSubjectCategory.humanites: 'Humanités',
  KalanSubjectCategory.informatique: 'Informatique',
  KalanSubjectCategory.mathematiques: 'Mathématiques',
  KalanSubjectCategory.autre: 'Autre',
};
```

Pourquoi une liste fixe :

- facilite la recherche dans la bibliothèque ;
- évite les doublons comme "Biologie", "SVT", "Science", "Sciences naturelles" ;
- simplifie les badges et statistiques ;
- garde une UX claire pour les élèves.

L'IA peut retourner un domaine plus précis, par exemple :

```json
{
  "category": "Sciences",
  "domain": "Biologie",
  "flashcards": []
}
```

Dans l'app :

- `category` sert au rangement du deck ;
- `domain` peut être affiché comme sous-thème ou utilisé dans le titre/description.

## Schéma JSON cible

Le modèle doit retourner un objet JSON brut :

```json
{
  "category": "Sciences",
  "domain": "Biologie",
  "language": "français",
  "source_type": "course",
  "flashcards": [
    {
      "question": "Qu'est-ce que la photosynthèse ?",
      "answer": "La photosynthèse permet aux plantes de produire du glucose grâce à la lumière."
    }
  ]
}
```

Valeurs attendues :

```text
category: Sciences | Langues | Littérature | Humanités | Informatique | Mathématiques | Autre
language: français | anglais | autre
source_type: course | questions | mixed | notes
```

## Prompt Qwen recommandé

Prompt de base :

```text
Tu es KALAN, une IA éducative offline.
Tu génères des flashcards fiables pour des élèves.

Retourne uniquement un objet JSON brut.
Interdit: markdown, ```json, texte hors JSON.

Catégories autorisées:
- Sciences
- Langues
- Littérature
- Humanités
- Informatique
- Mathématiques
- Autre

Règles:
- Détecte la catégorie la plus adaptée.
- Détecte le domaine précis si possible.
- Détecte la langue du texte.
- Génère exactement 5 flashcards.
- Questions précises.
- Réponses courtes: 1 phrase maximum.
- Si une réponse n'est pas dans le texte et n'est pas certaine, écris "À vérifier avec le cours".
- N'invente pas de termes scientifiques ou techniques.
- Ne crée pas de markdown.

Format obligatoire:
{
  "category": "string",
  "domain": "string",
  "language": "string",
  "source_type": "course|questions|mixed|notes",
  "flashcards": [
    {"question":"string","answer":"string"}
  ]
}

Contexte utilisateur:
{{USER_CONTEXT}}

Texte:
{{TEXT}}
```

Important :

- `{{USER_CONTEXT}}` peut être vide.
- `{{TEXT}}` doit être limité et nettoyé.
- Pour un texte long, ne pas tout envoyer d'un coup.

## Pipeline texte

### 1. Nettoyage local

Avant l'IA :

- supprimer espaces multiples ;
- supprimer headers/footers répétitifs si possible ;
- conserver les sauts de ligne utiles ;
- limiter la taille envoyée au modèle ;
- détecter si le texte ressemble à une liste de questions.

Exemple heuristique :

```dart
bool looksLikeQuestionList(String text) {
  final questionMarks = RegExp(r'\?').allMatches(text).length;
  final numberedLines = RegExp(r'^\s*\d+[\).]', multiLine: true).allMatches(text).length;
  return questionMarks >= 3 || numberedLines >= 3;
}
```

### 2. Détection locale de langue

Même si Qwen peut détecter la langue, l'app doit l'aider :

```dart
String detectLanguage(String text) {
  // simple heuristique français/anglais pour commencer
}
```

Injecter ensuite dans le prompt :

```text
Langue détectée localement: français.
Tu dois générer les flashcards en français.
```

### 3. Détection locale de catégorie

L'app peut faire une première détection avec mots-clés, puis laisser Qwen confirmer.

Exemples :

```text
photosynthèse, cellule, plante -> Sciences
adresse IP, DNS, routeur -> Informatique
équation, fraction, théorème -> Mathématiques
poème, roman, grammaire -> Littérature
histoire, géographie, empire -> Humanités
english, vocabulary, traduction -> Langues
```

Si Qwen retourne une catégorie inconnue, mapper vers `Autre`.

### 4. Génération Qwen

Le service local reçoit :

```dart
GenerateFlashcardsInput(
  text: cleanText,
  userContext: userContext,
  detectedLanguage: language,
  detectedCategory: category,
)
```

Il retourne :

```dart
GenerateFlashcardsResult(
  category: category,
  domain: domain,
  language: language,
  sourceType: sourceType,
  flashcards: cards,
)
```

### 5. Nettoyage JSON

Qwen ajoute parfois :

```text
```json
...
```
```

Le code doit nettoyer :

- blocs Markdown ;
- texte avant/après JSON ;
- numérotation inutile ;
- virgules finales si possible.

Stratégie simple :

1. retirer ` ```json ` et ` ``` ` ;
2. chercher le premier `{` et le dernier `}` ;
3. décoder avec `jsonDecode` ;
4. valider les clés attendues.

### 6. Validation métier

Avant sauvegarde :

- 1 à 10 flashcards acceptées ;
- question non vide ;
- réponse non vide ;
- réponse pas identique à la question ;
- longueur question raisonnable ;
- longueur réponse raisonnable ;
- catégorie dans la liste autorisée.

Si moins de 3 flashcards valides :

- relancer une fois avec un prompt plus simple ;
- sinon fallback heuristique.

## Architecture Flutter proposée

### Fichiers à créer

```text
lib/ai/local_model_config.dart
lib/ai/local_llm_engine.dart
lib/ai/qwen_gguf_engine.dart
lib/services/qwen_flashcard_service.dart
lib/services/ai_json_parser.dart
lib/core/constants/subject_categories.dart
```

### Fichiers à modifier

```text
lib/ai/model_downloader.dart
lib/services/local_ai_service.dart
lib/presentation/screens/model_download_screen.dart
lib/presentation/screens/offline_context_screen.dart
lib/presentation/screens/generating_screen.dart
lib/data/local/database_helper.dart
lib/data/repositories/deck_repository_impl.dart
```

## Étape par étape

### Étape 1 : config modèle

Créer `local_model_config.dart` :

```dart
class LocalModelConfig {
  final String id;
  final String displayName;
  final String fileName;
  final String downloadUrl;
  final String sizeLabel;
  final String runtime;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadUrl,
    required this.sizeLabel,
    required this.runtime,
  });
}

const qwen25LocalModel = LocalModelConfig(
  id: 'qwen25_15b_q4km',
  displayName: 'Qwen2.5 1.5B',
  fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  downloadUrl: 'https://huggingface.co/enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
  sizeLabel: '986 Mo',
  runtime: 'gguf',
);
```

### Étape 2 : rendre `ModelDownloader` générique

Actuellement il est codé pour Gemma. Il faut remplacer les constantes internes par une config :

```dart
static Stream<double> downloadModel(LocalModelConfig config)
```

Et utiliser :

```dart
config.downloadUrl
config.fileName
```

Garder :

- fichiers `.part` ;
- reprise HTTP `Range` ;
- fusion finale ;
- stockage dans le dossier documents de l'app.

### Étape 3 : choisir/intégrer runtime GGUF

Qwen GGUF nécessite un runtime compatible llama.cpp.

Le service doit exposer :

```dart
abstract class LocalLlmEngine {
  Future<bool> isModelInstalled();
  Future<void> loadModel(String modelPath);
  Future<String> generateText(String prompt, {int maxTokens = 512});
  Future<void> unloadModel();
}
```

`QwenGgufEngine` implémentera cette interface avec le plugin/runtime choisi.

Important :

- Ollama sert uniquement à tester sur PC ;
- Ollama ne doit pas être une dépendance de l'app Android ;
- le modèle `.gguf` doit être exécuté localement dans l'app.

### Étape 4 : service de génération

Créer `qwen_flashcard_service.dart`.

Responsabilités :

- construire le prompt ;
- appeler le moteur local ;
- parser le JSON ;
- valider les flashcards ;
- retourner un résultat propre.

Pseudo-code :

```dart
final raw = await engine.generateText(prompt, maxTokens: 900);
final parsed = AiJsonParser.parseFlashcardResult(raw);
final validCards = validateCards(parsed.flashcards);
return parsed.copyWith(flashcards: validCards);
```

### Étape 5 : brancher dans `LocalAIService`

Le flux offline devient :

```text
si online -> Qwen cloud
sinon si Qwen local installé -> Qwen local GGUF
sinon -> heuristique
```

Pendant la transition :

```text
si Qwen local installé -> Qwen
sinon si Gemma installé -> Gemma
sinon -> heuristique
```

Cela évite de casser l'app avant que Qwen mobile soit validé.

### Étape 6 : sauvegarde dans la bonne catégorie

Quand le résultat revient :

```dart
result.category
result.domain
result.flashcards
```

Créer le deck avec :

```dart
subject: result.category
description: result.domain
```

Si le modèle retourne une catégorie inconnue :

```dart
subject: 'Autre'
```

### Étape 7 : écran de contexte

Après réception du texte, afficher une page où l'élève peut confirmer :

- catégorie détectée ;
- domaine ;
- contexte libre.

Exemple :

```text
Catégorie détectée: Sciences
Domaine: Biologie
Contexte: Ce cours parle de l'oxygénation des plantes.
```

L'utilisateur peut modifier la catégorie avant génération.

### Étape 8 : tests

Créer des tests unitaires pour :

- parsing JSON avec Markdown ;
- catégorie inconnue ;
- réponses trop longues ;
- question vide ;
- liste de questions ;
- texte anglais ;
- texte informatique ;
- texte biologie.

Exemples à tester :

```text
```json
{"category":"Sciences","flashcards":[]}
```
```

doit être parsé correctement.

## Guide pour refaire l'intégration

Pour un collaborateur qui reprend le travail :

1. Installer Ollama sur PC.
2. Tester le modèle :

```text
ollama run qwen2.5:1.5b-instruct-q4_K_M
```

3. Valider les prompts avec des textes simples.
4. Ajouter `LocalModelConfig`.
5. Rendre `ModelDownloader` générique.
6. Ajouter un runtime GGUF Android.
7. Créer `LocalLlmEngine`.
8. Créer `QwenGgufEngine`.
9. Créer `AiJsonParser`.
10. Créer `QwenFlashcardService`.
11. Brancher `LocalAIService`.
12. Brancher `GeneratingScreen`.
13. Sauvegarder `category` dans `deck.subject`.
14. Tester sur téléphone réel.

## Contraintes importantes

- Le modèle ne doit jamais être commité dans Git.
- Le modèle doit être téléchargé depuis Hugging Face en test.
- Le téléchargement doit être reprenable.
- La génération doit marcher sans internet une fois le modèle installé.
- Le JSON doit toujours être nettoyé et validé.
- La catégorie IA doit être mappée vers une catégorie Flutter autorisée.
- Les réponses de connaissances générales peuvent halluciner.
- Pour les documents de cours, prioriser les réponses tirées du texte.

## Définition de fini

La migration est considérée fonctionnelle quand :

- l'app télécharge Qwen depuis Hugging Face ;
- le téléchargement reprend après interruption ;
- le modèle se charge sur Android ;
- un texte de cours génère au moins 5 flashcards ;
- la sortie est sauvegardée en deck ;
- le deck apparaît dans la bonne catégorie ;
- la génération fonctionne sans internet après installation ;
- les erreurs modèle sont gérées sans crash ;
- Gemma peut être retiré ou gardé comme fallback selon les tests.

## Résumé

Pour cette phase, KALAN ne traite pas encore les PDF scannés. L'app reçoit du texte exploitable, détecte la catégorie et la langue, demande éventuellement un contexte à l'élève, puis utilise Qwen2.5 1.5B Q4_K_M offline pour générer des flashcards. La réussite dépend de trois points : un runtime GGUF Android stable, un prompt strict et un parseur JSON robuste.
