# Migration IA offline : de Gemma vers Qwen2.5 1.5B

Ce document explique pourquoi KALAN prévoit de remplacer l'IA offline actuelle basée sur Gemma par Qwen2.5 1.5B, et comment organiser l'implémentation proprement.

## Contexte

KALAN doit pouvoir générer des flashcards et des quiz même sans connexion internet. L'app actuelle utilise une cascade IA :

1. IA online Qwen via Hugging Face quand internet est disponible.
2. IA locale Gemma quand le modèle offline est installé.
3. Extracteur heuristique si aucun modèle offline n'est exploitable.

Le problème observé est que Gemma 3 1B reste trop faible pour le besoin principal de KALAN : transformer un cours, souvent imparfait ou extrait d'un PDF/OCR, en flashcards pédagogiques précises et en quiz structurés.

Les limites les plus gênantes sont :

- mauvaise régularité dans le respect du format demandé ;
- réponses parfois trop vagues ou mal ciblées ;
- difficulté à générer de bonnes questions à partir de notes scolaires ;
- qualité insuffisante sur les documents longs ou mal structurés ;
- suivi fragile des consignes comme "JSON strict", "réponse courte", "5 cartes exactement".

## Pourquoi Qwen2.5 1.5B

Le modèle retenu pour les tests est Qwen2.5 1.5B Instruct, en version quantifiée Q4_K_M au format GGUF.

Modèle de test :

```text
enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF
```

Fichier :

```text
qwen2.5-1.5b-instruct-q4_k_m.gguf
```

URL de téléchargement probable :

```text
https://huggingface.co/enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf
```

Raisons du choix :

- 1.54B paramètres : plus de capacité que Gemma 1B, sans passer à un modèle trop lourd.
- Q4_K_M : bon compromis entre qualité, taille et mémoire.
- Environ 986 Mo : lourd, mais acceptable pour une IA offline optionnelle.
- Meilleur suivi des instructions que Gemma 1B dans les tâches structurées.
- Bon candidat pour JSON, flashcards, quiz, français et documents scolaires.
- Licence Apache-2.0, cohérente avec une intégration produit.

## Ce que Qwen ne résout pas seul

Changer de modèle ne suffit pas. Même un meilleur modèle échouera si on lui donne un PDF entier brut, un OCR sale ou un contenu sans contexte.

La bonne approche est donc :

1. analyser le document avant l'IA ;
2. détecter la langue ;
3. détecter le type de contenu ;
4. extraire les zones utiles ;
5. demander à l'élève de préciser le contexte ;
6. découper le contenu en morceaux courts ;
7. générer les flashcards/quiz en petits lots ;
8. nettoyer et valider la sortie.

Qwen devient le moteur de génération, mais la qualité finale dépend surtout du pipeline autour du modèle.

## Logique PDF prévue

Après import d'un PDF, KALAN doit d'abord faire une analyse locale :

- nombre de pages ;
- texte extractible par page ;
- langue probable ;
- présence d'images ou PDF scanné ;
- indices de notes/listes ;
- indices de questions/exercices ;
- indices de schémas, diagrammes ou tableaux ;
- indices de définitions et notions clés.

Ensuite l'app affiche une page de contexte où l'élève précise :

- le domaine ou la catégorie du document ;
- un court texte libre expliquant le sujet.

Exemple :

```text
Cours de SVT sur l'oxygénation des plantes. Le document explique les échanges gazeux, les stomates et la photosynthèse.
```

Ce contexte est ajouté au prompt envoyé à l'IA. Il aide le modèle à poser les bonnes questions et à éviter les flashcards génériques.

## Téléchargement du modèle

L'utilisateur final ne doit pas brancher son téléphone à un ordinateur.

Le modèle doit être téléchargé directement par l'app quand l'utilisateur est online. Pour la phase de test, Hugging Face peut servir de source de téléchargement. Il n'est pas nécessaire d'avoir un VPS.

Le téléchargement doit rester reprenable :

- si la connexion coupe, l'app conserve les parties déjà téléchargées ;
- au prochain lancement ou nouvel essai, le téléchargement reprend au bon endroit ;
- le fichier final est fusionné et stocké localement ;
- une fois installé, le modèle fonctionne sans internet.

Le `ModelDownloader` actuel fait déjà une partie importante de ce travail avec des fichiers `.part` et des requêtes HTTP `Range`.

## Point technique principal : le runtime

Gemma actuel utilise `flutter_gemma` avec un modèle compatible `.task`.

Qwen2.5 1.5B Q4_K_M est au format `.gguf`. Ce format n'est pas exécuté directement par `flutter_gemma`.

Il faut donc ajouter ou remplacer le runtime local par un moteur compatible GGUF, généralement basé sur llama.cpp.

Architecture cible :

```text
PDF / OCR / texte manuel
        |
Analyse locale du document
        |
Page contexte utilisateur
        |
Prompt structuré KALAN
        |
LocalLlmService
        |
Runtime GGUF / llama.cpp
        |
Qwen2.5 1.5B Q4_K_M local
        |
JSON flashcards + quiz
```

## Plan d'implémentation

### Phase 1 : valider le modèle

Tester Qwen2.5 1.5B Q4_K_M sur ordinateur avec Ollama ou llama.cpp.

Objectif :

- vérifier la qualité des flashcards ;
- vérifier le français ;
- vérifier le respect du JSON ;
- comparer avec Gemma 1B sur les mêmes prompts.

Prompt de test :

```text
Tu es l'IA offline de KALAN.
Génère exactement 5 flashcards en JSON strict.
Chaque réponse doit être courte et pédagogique.
Sujet : photosynthèse.
Format : [{"question":"...","answer":"..."}]
```

### Phase 2 : rendre le téléchargement générique

Transformer `ModelDownloader` pour ne plus être codé en dur sur Gemma.

Prévoir une configuration :

```dart
class LocalModelConfig {
  final String id;
  final String displayName;
  final String fileName;
  final String downloadUrl;
  final String sizeLabel;
  final String runtime;
}
```

Exemple :

```dart
LocalModelConfig(
  id: 'qwen25_15b_q4km',
  displayName: 'Qwen2.5 1.5B',
  fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  downloadUrl: 'https://huggingface.co/enacimie/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
  sizeLabel: '986 Mo',
  runtime: 'gguf',
)
```

### Phase 3 : intégrer le runtime GGUF

Créer un service local abstrait :

```dart
abstract class LocalLlmEngine {
  Future<bool> isModelInstalled();
  Future<void> loadModel();
  Future<String> generateText(String prompt, {int maxTokens});
  Future<void> unloadModel();
}
```

Puis remplacer l'utilisation directe de `GemmaService` par :

```dart
LocalLlmService -> LocalLlmEngine
```

Cela permet de garder une architecture propre :

- Gemma peut rester temporairement comme fallback ;
- Qwen devient le moteur cible ;
- le reste de l'app ne dépend plus du runtime exact.

### Phase 4 : brancher Qwen dans la génération offline

Dans `LocalAIService`, remplacer :

```text
Gemma offline -> prompt Gemma -> parsing Q/R
```

par :

```text
Qwen offline -> prompt JSON strict -> validation JSON
```

Le prompt Qwen doit demander explicitement :

- un JSON strict ;
- 5 flashcards ;
- réponses courtes ;
- langue identique au document ;
- questions différentes ;
- pas de Markdown ;
- pas d'explication hors JSON.

### Phase 5 : pipeline PDF

Améliorer le flux PDF :

1. extraction texte par page ;
2. analyse langue/contenu ;
3. page de contexte ;
4. découpage du texte ;
5. génération par morceaux ;
6. fusion des meilleures cartes ;
7. validation et sauvegarde du deck.

Pour les PDF scannés, il faudra ensuite ajouter une vraie étape OCR page/image. Le modèle texte seul ne peut pas analyser directement un schéma ou une image.

### Phase 6 : tests sur téléphone réel

Tester sur au moins deux profils :

- téléphone milieu de gamme ;
- téléphone plus ancien/faible RAM.

Points à mesurer :

- taille téléchargée ;
- reprise après coupure ;
- temps de chargement du modèle ;
- temps pour générer 5 flashcards ;
- mémoire utilisée ;
- stabilité après plusieurs générations ;
- qualité des réponses.

## Décision actuelle

Décision recommandée :

- garder Qwen online comme IA cloud ;
- remplacer Gemma offline par Qwen2.5 1.5B Q4_K_M ;
- utiliser Hugging Face comme source de téléchargement pendant les tests ;
- introduire un runtime GGUF compatible Android ;
- garder l'heuristique comme dernier fallback ;
- construire la qualité autour du pipeline PDF + contexte utilisateur.

## Tests Ollama réalisés

Le modèle Qwen2.5 1.5B Q4_K_M a été installé localement avec Ollama :

```text
ollama run qwen2.5:1.5b-instruct-q4_K_M
```

Le téléchargement a confirmé la taille du modèle principal :

```text
986 MB
```

Ces tests ne valident pas encore l'intégration mobile Flutter, mais ils permettent d'évaluer le comportement du modèle offline.

### Test 1 : cours court en français sur la photosynthèse

Objectif :

- générer 5 flashcards depuis un petit cours clair ;
- vérifier la qualité pédagogique ;
- vérifier la capacité à produire du JSON.

Résultat observé :

- les questions générées sont globalement utiles ;
- les réponses sont compréhensibles ;
- le modèle a parfois répondu sous forme d'objets numérotés au lieu d'un tableau JSON strict ;
- une erreur scientifique a été observée dans certaines réponses autour du dioxygène/énergie ;
- les réponses peuvent être trop longues.

Conclusion :

Qwen est capable de produire des flashcards utiles, mais il faut un prompt strict et un validateur de sortie. La sortie brute ne doit pas être acceptée sans contrôle.

### Test 2 : cours en anglais avec règle de langue

Objectif :

- vérifier si le modèle respecte la langue du document ;
- tester un prompt JSON plus strict.

Premier comportement :

- même avec un cours en anglais, le modèle a répondu en français si la règle était seulement "Use the same language as the course".

Après ajout d'une règle explicite :

```text
The course is written in English.
You MUST write every question and every answer in English.
Do not translate to French.
```

Résultat :

- le modèle a bien répondu en anglais ;
- le JSON était mieux structuré ;
- une erreur de contenu restait possible.

Conclusion :

La langue doit être fixée explicitement dans le prompt à partir de la détection locale :

```text
Langue détectée du document: anglais.
Tu dois générer les flashcards en anglais.
```

ou :

```text
Langue détectée du document: français.
Tu dois générer les flashcards en français.
```

### Test 3 : liste de questions sans réponses, domaine biologie

Objectif :

- donner uniquement des questions ;
- demander au modèle d'identifier le domaine ;
- lui demander de répondre avec ses connaissances générales.

Résultat observé :

- le modèle a identifié le domaine comme "Biologie" ;
- il a produit une structure JSON exploitable ;
- il a ajouté du Markdown malgré l'interdiction (` ```json `) ;
- il a halluciné une réponse fausse : "dioxyde d'azote (N2)" au lieu de dioxygène ;
- il a produit une réponse confuse sur les chloroplastes.

Conclusion :

Le mode "réponds avec tes connaissances générales" est risqué. Il doit être utilisé avec prudence, et seulement quand l'utilisateur comprend que la réponse peut nécessiter vérification.

Pour KALAN, le mode le plus sûr reste :

```text
document fourni + contexte utilisateur + réponses tirées du contenu
```

Si le document contient seulement des questions sans réponses, l'app doit idéalement proposer deux modes :

- créer des flashcards à compléter ;
- tenter une réponse IA, avec mention "à vérifier".

### Test 4 : liste de questions réseau/informatique

Objectif :

- tester un domaine plus technique ;
- vérifier les définitions courtes ;
- observer la fiabilité du modèle hors biologie.

Questions testées :

```text
1. Qu'est-ce qu'une adresse IP ?
2. À quoi sert le protocole DNS ?
3. Quelle est la différence entre un routeur et un switch ?
4. Que signifie le modèle client-serveur ?
5. Pourquoi utilise-t-on un pare-feu dans un réseau ?
```

Résultat observé :

- le modèle a identifié le domaine comme "Technologie de l'information" ;
- DNS, client-serveur et pare-feu étaient globalement compréhensibles ;
- il a encore ajouté du Markdown (` ```json `) ;
- certaines réponses étaient trop longues ;
- il a inventé une mauvaise expansion pour IP : "Adresse de Type Internet" ;
- la distinction routeur/switch était confuse.

Conclusion :

Le modèle est utilisable pour générer une première version de flashcards, mais il a besoin de contraintes fortes :

- réponses très courtes ;
- définitions standard ;
- pas d'expansion inutile ;
- validation/parsing côté application ;
- fallback "À vérifier avec le cours" si incertitude.

### Comportement général observé

Points forts :

- comprend bien les consignes générales ;
- détecte souvent le domaine scolaire ;
- produit une structure proche du JSON attendu ;
- fonctionne en français et en anglais si la langue est explicitement fixée ;
- semble meilleur que Gemma 1B pour suivre une tâche de génération pédagogique.

Points faibles :

- ajoute parfois du Markdown malgré l'interdiction ;
- peut halluciner sur des faits scientifiques ou techniques ;
- réponses parfois trop longues ;
- ne respecte pas toujours le JSON strict sans nettoyage ;
- peut être influencé par la langue du prompt plutôt que celle du document.

Conséquences pour l'app :

- toujours extraire le JSON depuis la réponse brute ;
- supprimer automatiquement les blocs Markdown ;
- valider que le résultat est bien une liste ou un objet attendu ;
- limiter la longueur des réponses ;
- privilégier les réponses tirées du document ;
- marquer les réponses générées par connaissances générales comme à vérifier ;
- injecter explicitement la langue détectée ;
- garder une étape d'édition avant ou après sauvegarde si possible.

### Dernières observations (Tests terminaux mai 2026)

De nouveaux tests intensifs via le terminal (Ollama) ont permis d'affiner la stratégie de prompt :

1.  **Tendance "Vrai/Faux" par défaut** : Si on ne lui donne pas de mélange précis, Qwen choisit souvent la facilité en ne produisant que des questions "Vrai/Faux".
2.  **Mélange intelligent** : Un ratio de 3 questions ouvertes pour 2 questions "Vrai/Faux" fonctionne très bien et dynamise l'apprentissage.
3.  **Besoin d'explications** : Pour les questions "Vrai/Faux", il est crucial de demander à l'IA d'inclure une courte explication dans la réponse (ex: "Faux, car...").
4.  **Nettoyage Markdown impératif** : Malgré l'instruction "JSON uniquement", le modèle continue d'encapsuler sa réponse dans des balises ` ```json `. L'application Flutter devra obligatoirement intégrer une fonction de nettoyage Regex pour extraire le contenu entre `{` et `}`.
5.  **Limitation de longueur** : Une consigne de "15 mots maximum par réponse" est efficace pour garder les flashcards lisibles sur mobile.

## À ne pas faire

- Ne pas intégrer le fichier `.gguf` dans le dépôt Git.
- Ne pas télécharger le modèle à chaque génération.
- Ne pas envoyer un PDF entier brut au modèle.
- Ne pas dépendre d'Ollama dans l'app mobile.
- Ne pas supprimer Gemma avant que Qwen soit validé sur téléphone réel.

## Résumé court

Gemma 1B est trop faible pour générer de bonnes flashcards scolaires offline. Qwen2.5 1.5B Q4_K_M offre un meilleur compromis qualité/taille. L'utilisateur téléchargera le modèle directement depuis internet, sans câble ni VPS. La difficulté principale n'est pas le téléchargement, mais l'intégration d'un runtime GGUF mobile et la construction d'un bon pipeline PDF + contexte.
