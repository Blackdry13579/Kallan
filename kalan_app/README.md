# KALAN — Cahier Intelligent de l'Élève Burkinabè

---

## Le contexte : Burkina Faso, zones en difficulté

Au Burkina Faso, de nombreux élèves et étudiants apprennent dans des conditions où les outils éducatifs numériques classiques ne fonctionnent tout simplement pas :

- **La connexion internet est rare et chère** — les données mobiles représentent un coût réel, les coupures sont fréquentes, et de nombreuses zones ne sont pas couvertes par le réseau.
- **Les smartphones disponibles sont des appareils d'entrée de gamme** — peu de RAM, processeurs limités, stockage restreint. Les applications gourmandes en ressources ne tournent pas sur ces appareils.
- **Le matériel scolaire physique manque** — les cours se prennent en dictée dans des cahiers, peu de manuels sont accessibles à tous, les fiches de révision imprimées sont rares.
- **Les outils numériques éducatifs ne sont pas conçus pour ce contexte** — ils supposent une connexion permanente, des comptes cloud, et des appareils modernes.

L'élève burkinabè qui veut réviser son cours à 21h sans connexion, sur un smartphone bas de gamme, n'a aucun outil adapté à sa réalité. KALAN est fait pour lui.

---

## Le problème que KALAN résout

> **Comment permettre à un élève burkinabè de générer, organiser et réviser des flashcards intelligentes, sans connexion internet, sur un smartphone bas de gamme ?**

Trois problèmes concrets bloquent tout outil éducatif numérique dans ce contexte :

1. **Pas d'IA embarquée** — la génération automatique de fiches nécessite une connexion permanente
2. **Pas de mode hors-ligne complet** — le contenu est stocké dans le cloud, inaccessible sans internet
3. **Pas de dimension sociale locale** — pas de mode compétitif entre camarades de classe, pas de partage de contenu sans réseau

KALAN répond aux trois problèmes d'un coup.

---

## La solution : KALAN

KALAN est une **application mobile Flutter** (Android) qui combine :

- **Un générateur de flashcards alimenté par IA** — online avec Qwen 72B, offline avec Gemma 3 embarqué sur l'appareil
- **Un système de révision offline-first** — tout est stocké localement, le cloud est une sauvegarde optionnelle
- **Un mode Arène multijoueur** — duels de flashcards en temps réel entre élèves, ou en local via QR Code sans internet
- **Un système de gamification complet** — XP, niveaux (Graine → Baobab), badges, classement mondial

Le nom KALAN signifie *"apprendre"* en Dioula — la lingua franca commerciale du Burkina Faso, de la Côte d'Ivoire et du Mali, parlée par des dizaines de millions de personnes en Afrique de l'Ouest.

---

## Comment ça marche — le parcours complet de l'utilisateur

### 1. Inscription et profil

L'élève crée son compte avec un **pseudo + PIN** (en attendant la migration vers email + mot de passe). Un avatar lui est attribué parmi une collection de portraits illustrés. Son profil stocke ses points XP, son niveau, sa série de jours consécutifs (streak), et ses badges.

Toutes ces données sont sauvegardées **localement dans SQLite** et synchronisées avec Supabase cloud dès qu'une connexion est disponible.

### 2. Importer un cours

L'élève dispose de trois façons d'alimenter KALAN avec son contenu de cours :

**Coller du texte**
Il copie-colle un extrait de son cours dans le champ de texte de l'écran de génération.

**Importer un PDF**
Il sélectionne un fichier PDF depuis son téléphone. Le moteur Syncfusion Flutter PDF en extrait le texte automatiquement.

**Photographier une page**
Il pointe sa caméra vers une feuille de cours. L'OCR (Google ML Kit + Tesseract) lit le texte imprimé ou manuscrit et l'envoie à l'IA.

### 3. Génération des flashcards par l'IA

Une fois le texte extrait, l'IA entre en jeu selon une **cascade à 3 niveaux** :

```
L'appareil est connecté à internet ?
│
├── OUI → Qwen 72B (Hugging Face API)
│         Génère des flashcards riches, structurées, pédagogiques
│         Format JSON strict : question / réponse / type / options QCM
│
└── NON → Gemma 3 270M (embarqué sur l'appareil, TFLite)
          Le modèle est téléchargé ? (≈ 270 Mo, une seule fois)
          │
          ├── OUI → Génération locale, zéro données mobiles
          │
          └── NON → Extracteur heuristique (règles grammaticales)
                    Détecte les structures "X est Y", "X signifie Y"
                    et les transforme en paires question/réponse
```

Les flashcards générées sont immédiatement sauvegardées dans SQLite. L'élève peut les consulter, modifier, supprimer ou compléter manuellement.

### 4. Réviser

L'écran de révision affiche les flashcards une par une. L'élève lit la **question**, tente de formuler une réponse mentalement, puis retourne la carte (animation de flip 3D) pour voir la **réponse**.

Il s'auto-évalue : **Facile** ou **Difficile**. L'algorithme de révision espacée planifie la prochaine révision en fonction de cette évaluation — les cartes difficiles reviennent plus tôt, les cartes maîtrisées s'espacent dans le temps.

Une barre de progression horizontale en haut de l'écran indique l'avancement dans le deck. Les cartes sont mélangées aléatoirement à chaque session mais l'ordre reste stable pendant la révision.

L'élève peut aussi activer la **lecture audio** (Text-to-Speech) pour écouter la question et la réponse à voix haute.

### 5. Passer un quiz

À partir de n'importe quel deck, l'élève peut lancer un **quiz QCM**. L'IA génère des questions à choix multiples à partir des flashcards du deck. Chaque bonne réponse rapporte des points XP. Les résultats sont enregistrés et contribuent au classement.

### 6. Progresser et débloquer des récompenses

Chaque action (révision, quiz, victoire en Arène) rapporte des **points XP**. Les XP font progresser l'élève sur une **Roadmap en zigzag** qui représente son parcours d'apprentissage :

| Niveau | Nom | Points requis |
|---|---|---|
| 1 | Graine | 0 |
| 2 | Pousse | 500 |
| 3 | Arbre | 2 000 |
| 4 | Grand Arbre | 5 000 |
| 5 | Baobab | 10 000 |

Des **badges** se débloquent automatiquement selon les performances : premier deck créé, série de 7 jours, victoire en Arène, 100 cartes révisées, etc.

---

## Le mode Arène — apprendre en compétition

L'Arène est le mode multijoueur de KALAN. Elle transforme la révision en compétition amicale.

### Flux en ligne (avec internet)

```
Joueur A ouvre le Battle Lobby
    → Voit la liste des élèves en ligne (heartbeat < 10 min)
    → Sélectionne un adversaire
    → Choisit un thème (ex: "Mathématiques - Fonctions")
       ou active le mode "Maître Kalan IA" (thème généré par l'IA)
    → Mise d'XP (entre 50 et 500 XP)
    → Envoie le défi

Joueur B reçoit une notification temps réel (Supabase Realtime)
    → Accepte le défi

PHASE 1 — Révision (2 minutes)
    Les deux joueurs révisent les 10 flashcards du défi côte à côte

PHASE 2 — Quiz (chronomètre)
    Les deux joueurs répondent aux 10 QCM générés depuis ces flashcards
    Les scores se mettent à jour en temps réel

FIN
    Gagnant : +XP × 2
    Perdant  : -XP
    Égalité  : ±0
    Le classement mondial se met à jour
```

### Flux local (sans internet)

Quand les deux élèves sont dans la même pièce mais sans connexion :

```
Joueur A génère un QR Code depuis son téléphone
Joueur B scanne ce QR Code avec l'écran de scan
    → La partie démarre en local (Bluetooth ou réseau local)
    → Résultats stockés en SQLite
    → Synchronisation différée avec le cloud à la prochaine connexion
```

### Présence en ligne

Un `PresenceService` envoie un **heartbeat toutes les 5 minutes** vers la colonne `last_active` de la table `users` dans Supabase. Avant d'afficher un joueur comme "en ligne" dans le lobby, l'application vérifie que son dernier heartbeat date de moins de 10 minutes. Ce mécanisme démarre automatiquement dès l'ouverture du Dashboard.

---

## Partager des decks

Trois mécanismes de partage sont disponibles :

**Lien profond (deep link)**
Chaque deck peut être partagé via l'URL `https://kalan-app.web.app/deck/<uuid>`. Ce lien peut être envoyé par WhatsApp, SMS ou email. Quand le destinataire clique, l'application s'ouvre directement sur le deck (géré par `app_links`).

**Bluetooth BLE**
Sans internet, deux élèves proches peuvent s'échanger un deck complet via Bluetooth Low Energy. Le service sérialise le deck en JSON, le découpe en chunks adaptés au MTU Bluetooth, et le reconstitue côté récepteur.

**QR Code local**
L'écran de partage QR affiche un code que le camarade scanne pour rejoindre directement une session de révision locale.

---

## L'intelligence artificielle en détail

### Qwen 72B — le modèle en ligne

Quand l'appareil est connecté, KALAN appelle le modèle `Qwen/Qwen2.5-72B-Instruct` via l'API Hugging Face Inference.

Le prompt demande une **structure JSON stricte** : question pédagogique, réponse claire, type de carte (directe ou QCM), liste des options si QCM, indice de la bonne réponse. Le modèle est paramétré à `temperature: 0.3` pour des réponses factuelles et déterministes. En cas d'indisponibilité du 72B, le service bascule automatiquement sur `Qwen2.5-7B`.

**Cas spécial — génération de flashcard unique**

La méthode `generateSingleFlashcard` détecte automatiquement trois cas :

| Input utilisateur | Notes de cours présentes | Comportement de l'IA |
|---|---|---|
| Question (`?` ou mot interrogatif) | Oui | Cherche la réponse **dans les notes uniquement** — pas d'invention |
| Phrase affirmative | Oui | Transforme la phrase en paire Q/R minimale depuis les notes |
| Toute entrée | Non | Répond depuis la connaissance générale de Qwen |

Si les sources sont contradictoires, l'IA retourne `{"answer": null, "warning": "sources contradictoires"}` et un avertissement s'affiche à l'élève.

### Gemma 3 270M — le modèle offline

Le modèle Gemma est exécuté directement sur le processeur du smartphone via **TensorFlow Lite** (plugin `flutter_gemma`). Il est téléchargé une seule fois (~270 Mo) depuis un dépôt de releases public, avec une barre de progression visible. Une fois installé, il se charge en moins d'une seconde.

Le prompt offline est volontairement simplifié (`Q1: / R1:`) pour maximiser la vitesse et minimiser la consommation batterie. La génération est limitée à **2 048 tokens** et le texte d'entrée est tronqué à **2 000 caractères** pour éviter les crashs mémoire sur les appareils d'entrée de gamme courants au Burkina Faso — le TECNO Spark utilisé comme appareil de test de référence déclenche un Signal 11 au-delà de cette limite.

### Extracteur heuristique — le filet de sécurité

Si aucun modèle n'est disponible, un algorithme maison analyse le texte à la recherche de structures définitoires :
- *"X est Y"*
- *"X sont Y"*
- *"X signifie Y"*
- *"X désigne Y"*

Chaque structure détectée devient une flashcard. Zéro latence, zéro dépendance.

---

## Architecture technique

```
┌─────────────────────────────────────────────────────────┐
│                  Application Flutter                     │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Présentation │  │   Domaine    │  │   Données    │  │
│  │              │  │              │  │              │  │
│  │  37 Écrans   │  │  Entités     │  │  SQLite      │  │
│  │  8 BLoCs     │◄─┤  Interfaces  │◄─┤  Supabase    │  │
│  │  Widgets     │  │  Repository  │  │  Hive        │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │                    Services                        │ │
│  │  AI · Battle · Presence · Sync · Notifications    │ │
│  │  Audio · Bluetooth · DeepLink · Connectivity      │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
         │ online sync               │ offline
         ▼                           ▼
  ┌─────────────┐              ┌──────────────┐
  │  Supabase   │              │  SQLite local │
  │ PostgreSQL  │              │  kalan.db     │
  │  Realtime   │              └──────────────┘
  │  RPC/RLS    │
  └─────────────┘
         │
         ▼
  ┌──────────────────┐
  │  Hugging Face    │
  │  Qwen 72B API    │
  └──────────────────┘
```

**Pattern** : Clean Architecture + BLoC  
**Principe de données** : SQLite est la source de vérité. Supabase est une sauvegarde cloud et un bus de communication temps réel. Tout ce que l'élève fait est d'abord écrit localement, puis synchronisé quand la connexion revient.

---

## Stack technique

| Catégorie | Technologie | Rôle |
|---|---|---|
| Framework | Flutter 3.x / Dart | Application mobile Android (iOS prévu) |
| State management | flutter_bloc 9.x | Gestion d'état réactive par fonctionnalité |
| Base de données locale | sqflite (SQLite) | Source de vérité offline |
| Base de données cloud | Supabase (PostgreSQL) | Sauvegarde, sync, temps réel |
| Cache clé-valeur | Hive, shared_preferences | Préférences, session utilisateur |
| IA online | Qwen 72B — Hugging Face API | Génération de haute qualité |
| IA offline | Gemma 3 270M — flutter_gemma (TFLite) | Génération embarquée sans réseau |
| OCR | Google ML Kit + Tesseract | Extraction de texte depuis photos |
| PDF | Syncfusion Flutter PDF | Extraction de texte depuis documents |
| Temps réel | Supabase Realtime (WebSocket) | Mode Arène, présence, notifications |
| Bluetooth | flutter_blue_plus (BLE) | Partage local de decks |
| Notifications | flutter_local_notifications + workmanager | Rappels de révision planifiés |
| Audio | flutter_tts, audioplayers | Lecture des cartes, effets sonores |
| Partage | share_plus, app_links | Deep links, partage système |
| QR Code | qr_flutter, mobile_scanner | Génération et scan de QR |
| HTTP | http, flutter_dotenv | Appels API, gestion des secrets |
| UI | Google Fonts (Plus Jakarta Sans) | Typographie cohérente |

---

## Structure du projet

```
kalan_app/
│
├── lib/
│   ├── main.dart                    # Initialisation : dotenv, Supabase, deep links, BLoCs
│   ├── app.dart                     # MaterialApp, routes nommées, thème global
│   │
│   ├── ai/                          # Moteurs IA
│   │   ├── gemma_engine.dart        # Wrapper flutter_gemma (TFLite)
│   │   ├── llama_engine.dart        # Wrapper llamadart (GGUF)
│   │   └── model_downloader.dart    # Téléchargement du modèle avec progression
│   │
│   ├── core/
│   │   ├── theme/                   # Couleurs, typographie, thème Material
│   │   └── utils/                   # level_utils, text_scale, helpers
│   │
│   ├── data/
│   │   ├── local/database_helper.dart   # SQLite : schéma, migrations, requêtes
│   │   ├── remote/supabase_service.dart # Client Supabase initialisé
│   │   ├── models/                      # DTOs sérialisables (User, Deck, Flashcard…)
│   │   └── repositories/               # Implémentations : local + remote + sync
│   │
│   ├── domain/
│   │   ├── entities/               # Entités métier pures (sans dépendance Flutter)
│   │   └── repositories/           # Interfaces abstraites
│   │
│   ├── presentation/
│   │   ├── blocs/                  # 8 modules BLoC
│   │   │   ├── user/               # Chargement profil, stats
│   │   │   ├── deck/               # CRUD decks
│   │   │   ├── flashcard/          # CRUD flashcards, révision
│   │   │   ├── quiz/               # Génération et résultats quiz
│   │   │   ├── badge/              # Déclenchement et affichage badges
│   │   │   ├── leaderboard/        # Classement global
│   │   │   ├── notification/       # Rappels de révision
│   │   │   └── sync/               # Sync locale ↔ cloud
│   │   │
│   │   ├── screens/                # 37 écrans
│   │   │   ├── splash_screen.dart
│   │   │   ├── welcome_carousel_screen.dart
│   │   │   ├── onboarding_pseudo_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── home_dashboard.dart          # Dashboard principal
│   │   │   ├── flashcard_study_screen.dart  # Révision cartes
│   │   │   ├── quiz_screen.dart             # Mode Quiz QCM
│   │   │   ├── generating_screen.dart       # Génération IA
│   │   │   ├── camera_ocr_screen.dart       # OCR caméra
│   │   │   ├── battle_lobby_screen.dart     # Lobby Arène
│   │   │   ├── duel_game_screen.dart        # Duel temps réel
│   │   │   ├── local_battle_qr_screen.dart  # Arène locale QR
│   │   │   ├── leaderboard_screen.dart
│   │   │   ├── profile_screen.dart
│   │   │   ├── roadmap_screen.dart          # Parcours ZigZag
│   │   │   ├── badges_screen.dart
│   │   │   ├── share_screen.dart
│   │   │   ├── model_download_screen.dart   # Téléchargement Gemma
│   │   │   └── … (37 au total)
│   │   │
│   │   └── widgets/                # Composants réutilisables
│   │       ├── flashcard_view.dart  # Carte avec animation flip
│   │       ├── zone_banner.dart     # Bannière de niveau roadmap
│   │       ├── celebration_listener.dart
│   │       └── notification_signal_banner.dart
│   │
│   └── services/                   # Services applicatifs transversaux
│       ├── local_ai_service.dart    # Orchestration cascade IA
│       ├── battle_service.dart      # Gestion duels Supabase Realtime
│       ├── presence_service.dart    # Heartbeat statut en ligne
│       ├── sync_service.dart        # Réconciliation SQLite ↔ Supabase
│       ├── audio_service.dart       # TTS + sons
│       ├── notification_scheduler.dart
│       ├── bluetooth_share_service.dart
│       ├── deep_link_service.dart
│       └── connectivity_service.dart
│
├── assets/
│   ├── audio/      # correct.mp3, swipe.mp3, wrong.wav
│   ├── avatars/    # 12 avatars PNG
│   └── images/     # epe.png (icône Arène), mascotte Bonome
│
├── android/        # Config Android native, deep links, permissions
├── pubspec.yaml
└── .env            # Clés secrètes — ne jamais committer
```

---

## Base de données Supabase

| Table | Rôle |
|---|---|
| `users` | Profils : pseudo, XP, niveau, streak, avatar, `last_active` (heartbeat) |
| `subjects` | Matières scolaires (Maths, Français, Histoire…) |
| `decks` | Decks de flashcards : titre, matière, niveau, visibilité |
| `flashcards` | Cartes : question, réponse, type, niveau de maîtrise, prochaine révision |
| `quiz_results` | Résultats de quiz : score, durée, XP gagné |
| `badges` | Catalogue de badges disponibles |
| `user_badges` | Badges débloqués par utilisateur |
| `battles` | Duels : joueurs, thème, scores, phase, `phase_start_time` |
| `leaderboard_entries` | Classement mondial |

**Fonctions RPC Supabase (mode Arène)**

| Fonction | Description |
|---|---|
| `create_battle` | Crée un défi entre deux joueurs, retourne l'UUID |
| `submit_answer` | Vérifie une réponse QCM, incrémente le score |
| `finish_battle` | Clôture le duel, compare les scores, distribue les XP (idempotente) |
| `abandon_battle` | Clôture en cas d'abandon, l'adversaire gagne automatiquement |

---

## Installation et démarrage

### Prérequis

- Flutter >= 3.19 ([installer Flutter](https://flutter.dev/docs/get-started/install))
- Android Studio ou VS Code avec l'extension Flutter
- Compte [Supabase](https://supabase.com) (gratuit)
- Compte [Hugging Face](https://huggingface.co) pour le token API (gratuit)

### Étapes

```bash
# 1. Cloner
git clone https://github.com/<org>/kalan.git
cd kalan/kalan_app

# 2. Dépendances
flutter pub get

# 3. Variables d'environnement
cp .env.example .env
# Renseigner dans .env :
#   SUPABASE_URL=https://xxxx.supabase.co
#   SUPABASE_ANON_KEY=eyJ...
#   HF_TOKEN=hf_...

# 4. Schéma Supabase
# Ouvrir Supabase Dashboard → SQL Editor
# Exécuter le contenu de kalan_backend/schema.sql

# 5. Lancer
flutter run
```

### Obtenir un token Hugging Face

1. Créer un compte sur [huggingface.co](https://huggingface.co)
2. Settings → Access Tokens → New Token (rôle : Read)
3. Copier la valeur `hf_...` dans `.env` sous `HF_TOKEN`

L'application fonctionne sans ce token — elle bascule automatiquement sur Gemma offline ou l'extracteur heuristique.

### Construire un APK

```bash
# APK unique
flutter build apk --release

# APKs séparés par ABI (plus légers, recommandés pour la distribution)
flutter build apk --split-per-abi --release
```

---

## État du projet

### Fonctionnel

- [x] Génération IA (Qwen online → Gemma offline → heuristique)
- [x] Génération de flashcard unique avec contexte de notes
- [x] Détection d'image floue (OCR) avec message d'erreur ciblé
- [x] Révision avec mémorisation espacée et shuffle stable
- [x] Mode Quiz QCM auto-généré
- [x] Mode Arène en ligne (Supabase Realtime, RPC)
- [x] Mode Arène local (QR Code)
- [x] Présence en ligne (heartbeat 5 min, vérification avant défi)
- [x] Système XP / niveaux / roadmap ZigZag
- [x] Badges débloqués automatiquement
- [x] Classement mondial
- [x] Partage deep link (WhatsApp, SMS)
- [x] Partage Bluetooth BLE (chunks MTU)
- [x] Notifications de rappel de révision
- [x] Sync SQLite ↔ Supabase (offline-first)
- [x] OCR depuis caméra et PDF
- [x] TTS lecture des cartes

### Problèmes connus

| # | Problème | Impact | Fix planifié |
|---|---|---|---|
| 1 | Colonne `xp_gained` absente de `quiz_results` SQLite | Crash sur certaines requêtes quiz | Migration SQLite v9 |
| 2 | RenderFlex overflow ~190px (QuizScreen, ProfileScreen) | Overflow visuel sur petits écrans | Envelopper dans `SingleChildScrollView` |
| 3 | Chargement modèle LLM bloque le thread principal (~40 s) | UI gelée au premier lancement offline | Déplacer dans un `Isolate` Dart |
| 4 | Authentification par PIN (pas de récupération de compte) | Compte perdu si désinstallation | Migration vers Supabase Auth email/mdp |
| 5 | SELinux `avc: denied` sur certains Android | Crash lib LLM native | Vérifier les chemins dans `local_llm_engine.dart` |

### Feuille de route

- [ ] Migration authentification → Supabase Auth (email + mot de passe)
- [ ] Isolates Dart pour l'inférence IA (UI non bloquante)
- [ ] Support iOS
- [ ] Mode collaboratif (decks d'équipe, révision partagée)
- [ ] Synthèse vocale multilingue (Dioula, Mooré, Fulfuldé — langues nationales du Burkina Faso)
- [ ] Validation des IDs de deep links (sécurité RLS)

---

## Licence

MIT — voir [LICENSE](../LICENSE)

---

*KALAN — parce que chaque élève burkinabè mérite un outil d'apprentissage intelligent, même sans internet, même sur un TECNO Spark.*
