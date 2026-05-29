# Rapport d'Erreurs Identifiées - KALAN (Infinix X669)

Ce document répertorie les erreurs critiques et les problèmes de performance identifiés à partir des logs de l'application sur ton appareil Infinix.

## 1. Erreurs de Base de Données (SQLite) - CRITIQUE
L'erreur la plus bloquante pour ton système de progression.

*   **Erreur :** `table quiz_results has no column named xp_gained`
*   **Description :** Tu as ajouté un champ `xpGained` dans ton code (modèle `QuizResultModel`), mais la table dans la base de données locale (`kalan.db`) n'a pas été mise à jour.
*   **Impact :** Impossible d'enregistrer les résultats de quiz. L'application échoue lors de chaque insertion après un quiz.
*   **Fichier concerné :** `lib/data/local/database_helper.dart`.
*   **Solution :** Ajouter une migration `ALTER TABLE quiz_results ADD COLUMN xp_gained INTEGER DEFAULT 0` dans la fonction `_upgradeDB`.

## 2. Erreurs de Structure Flutter (Hiérarchie)
*   **Erreur :** `Incorrect use of ParentDataWidget`
*   **Description :** Un widget `Expanded`, `Flexible` ou `Positioned` est mal placé. Par exemple, un `Expanded` utilisé directement dans un `Stack` ou un `Container` au lieu d'une `Column` ou `Row`.
*   **Impact :** L'interface peut bugger ou ne pas s'afficher correctement sur certains écrans.
*   **Analyse :** Il faut vérifier les écrans récents (Dashboard, Quiz, Profil) pour s'assurer que les `Expanded` sont bien des enfants directs de `Column` ou `Row`.

## 3. Débordements d'Interface (Overflow)
*   **Erreur :** `RenderFlex overflowed by 190 pixels on the bottom`
*   **Description :** Le contenu d'un écran dépasse la taille physique de ton téléphone (Infinix X669).
*   **Impact :** Bandes jaunes et noires visibles. Boutons ou textes inaccessibles en bas de l'écran.
*   **Fichiers suspects :** 
    *   `QuizScreen` : Si la question est trop longue.
    *   `ProfileScreen` : Si beaucoup d'amis ou de badges sont affichés sans scroll suffisant.
*   **Solution :** Envelopper les `Column` problématiques dans un `SingleChildScrollView`.

## 4. Performance & Blocage du Thread Principal
*   **Erreur :** `Davey! duration=40550ms` (Blocage de 40 secondes !)
*   **Description :** L'application fige totalement pendant le chargement du modèle d'IA local (GGUF).
*   **Cause :** Le chargement du modèle 1.5B (Qwen) est très lourd pour le processeur de ton téléphone. S'il est fait sur le thread principal (UI Thread), l'app ne répond plus.
*   **Impact :** L'utilisateur croit que l'app a planté.
*   **Solution :** Utiliser des `Isolates` pour le chargement et l'inférence de l'IA.

## 5. Problème de Fallback IA (Gemma)
*   **Constat :** L'IA bascule sur "Gemma" après un timeout de Qwen.
*   **Cause :** Dans `local_ai_service.dart`, la logique de secours (catch) redirige vers Gemma si Qwen met plus de 2 minutes à répondre.
*   **Action :** Si tu ne veux plus du tout de Gemma, il faut supprimer l'appel à `_generateOfflineFlashcards` (version Gemma) dans le bloc `catch` de `generateFlashcards`.

## 6. Sécurité & Permissions (Android)
*   **Erreur :** `avc: denied { read } for name="/" ...`
*   **Description :** Ton application tente de lire des fichiers à la racine du système, ce qu'Android interdit (SELinux).
*   **Cause :** Probablement la bibliothèque native LLM qui cherche ses dépendances ou des fichiers de configuration au mauvais endroit.

---
*Rapport généré le 28 mai 2026 par Gemini CLI.*
