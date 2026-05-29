# À Faire Plus Tard — KALAN

---

## 1. Migration du système d'authentification (PRIORITAIRE)

### Problème actuel
L'app crée les comptes avec **pseudo + PIN uniquement**. L'UUID est généré localement (`Uuid().v4()`), Supabase Auth n'est jamais appelé. Résultat :
- Impossible de récupérer son compte si on réinstalle l'app ou change de téléphone
- Les politiques RLS Supabase ne fonctionnent pas (`auth.uid()` retourne null)
- Le PIN est un workaround fragile (stocké en hash dans la table `users`)

### Solution : Email + Pseudo + Mot de passe via Supabase Auth

**Fichiers à modifier :**

#### `lib/presentation/screens/onboarding_pseudo_screen.dart`
- Remplacer les champs **pseudo + PIN** par **email + pseudo + mot de passe**
- Appeler `SupabaseService.signUp(email, password)` au lieu de `Uuid().v4()`
- Utiliser `auth.currentUser!.id` comme UUID (plus de génération locale)
- Supprimer toute la logique `pin_hash`

#### `lib/presentation/screens/login_screen.dart`
- Remplacer **pseudo + PIN** par **email + mot de passe**
- Appeler `SupabaseService.signInWithPassword(email, password)`
- Supprimer la vérification `pin_hash` depuis la table `users`
- En cas de succès : charger les données depuis Supabase → SQLite local

#### `lib/data/local/database_helper.dart`
- Ajouter migration v9 : `ALTER TABLE users DROP COLUMN pin_hash` (optionnel, SQLite ne supporte pas DROP COLUMN nativement — laisser la colonne inutilisée)

#### RLS Supabase (déjà correct dans le schéma fourni)
- Toutes les policies utilisent `auth.uid()::text = uuid::text` — fonctionnera automatiquement une fois Supabase Auth utilisé

**Résultat attendu :**
- Compte récupérable depuis n'importe quel appareil
- Sync Supabase ↔ SQLite fonctionne avec RLS
- Plus de PIN, plus de `pin_hash`

---

## 2. Erreurs Flutter non corrigées (depuis README_ERRORS.md)

### 2a. RenderFlex overflow (190px en bas)
- **Suspects** : `QuizScreen`, `ProfileScreen`
- **Fix** : Envelopper les `Column` problématiques dans un `SingleChildScrollView`
- Nécessite une stack trace complète pour localiser l'écran exact

### 2b. ParentDataWidget mal placé
- **Cause** : Un `Expanded` ou `Flexible` utilisé hors d'une `Column`/`Row`
- **Fix** : Chercher les `Expanded` dans les écrans récents (Dashboard, Quiz, Profil)
- Nécessite une stack trace complète

### 2c. Blocage thread UI — Isolates pour l'IA (Davey! 40s)
- **Cause** : Le chargement du modèle Qwen GGUF bloque le thread principal
- **Fix** : Déplacer `_engine.loadModel()` et `_engine.generateText()` dans un `Isolate`
- Fichiers : `lib/ai/local_llm_engine.dart`, `lib/services/qwen_flashcard_service.dart`

### 2d. SELinux `avc: denied` (lib native LLM)
- **Cause** : La lib llamadart cherche des fichiers à la racine `/`
- **Fix** : Vérifier les chemins dans `local_llm_engine.dart`, s'assurer que le modèle est chargé depuis `getApplicationDocumentsDirectory()`
