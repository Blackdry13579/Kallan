import 'package:supabase_flutter/supabase_flutter.dart';

class ChallengeService {
  final supabase = Supabase.instance.client;

  // Créer un défi
  Future<Map<String, dynamic>> createChallenge({
    required String userId,
    required int deckId,
    int maxPlayers = 2,
  }) async {
    // 1. Récupérer 5 flashcards aléatoires du deck
    final cards = await supabase
        .from('flashcards')
        .select()
        .eq('deck_id', deckId)
        .limit(5); // simplifié : à terme il faut de l'aléatoire

    if (cards.length < 5) throw Exception('Pas assez de flashcards');

    // 2. Créer un quiz (à adapter si ta table quizzes a plus de colonnes)
    final quizResponse = await supabase.from('quizzes').insert({
      'user_id': userId,
      'deck_id': deckId,
      'type': 'challenge',
      'status': 'active',
      'total_questions': cards.length,
      'time_per_question': 15,
      'total_time_limit': cards.length * 15,
    }).select().single();
    final quizId = quizResponse['id'];

    // 3. Insérer les questions du quiz
    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      // Générer options (bonne réponse + 3 mauvaises)
      final otherBacks = cards.where((c) => c['id'] != card['id']).map((c) => c['back']).toList();
      while (otherBacks.length < 3) otherBacks.add('Inconnu');
      final options = [card['back'], ...otherBacks.take(3)]..shuffle();
      final correctIndex = options.indexOf(card['back']);

      await supabase.from('quiz_questions').insert({
        'quiz_id': quizId,
        'flashcard_id': card['id'],
        'question': card['front'],
        'options': options,
        'correct_answer': correctIndex,
        'display_order': i,
      });
    }

    // 4. Générer un code à 6 chiffres
    final code = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

    // 5. Insérer le défi
    final challengeResponse = await supabase.from('challenges').insert({
      'code': code,
      'challenger_id': userId,
      'deck_id': deckId,
      'quiz_id': quizId,
      'max_players': maxPlayers,
      'current_players': 1,
      'status': 'pending',
    }).select().single();

    // 6. Ajouter le créateur comme participant
    await supabase.from('challenge_participants').insert({
      'challenge_id': challengeResponse['id'],
      'user_id': userId,
    });

    return {
      'code': code,
      'challenge_id': challengeResponse['id'],
      'quiz_id': quizId,
    };
  }

  // Rejoindre un défi
  Future<Map<String, dynamic>?> joinChallenge(String code, String userId) async {
    // Trouver le défi
    final challenge = await supabase
        .from('challenges')
        .select()
        .eq('code', code)
        .eq('status', 'pending')
        .maybeSingle();

    if (challenge == null) return null; // défi inexistant ou déjà commencé

    // Vérifier qu'il reste de la place
    if (challenge['current_players'] >= challenge['max_players']) {
      throw Exception('Défi complet');
    }

    // Ajouter le participant
    await supabase.from('challenge_participants').insert({
      'challenge_id': challenge['id'],
      'user_id': userId,
    });

    // Incrémenter le compteur
    await supabase
        .from('challenges')
        .update({'current_players': challenge['current_players'] + 1})
        .eq('id', challenge['id']);

    // Récupérer le quiz
    final questions = await supabase
        .from('quiz_questions')
        .select()
        .eq('quiz_id', challenge['quiz_id'])
        .order('display_order');

    return {
      'challenge_id': challenge['id'],
      'quiz_id': challenge['quiz_id'],
      'questions': questions,
    };
  }

  // Soumettre un score
  Future<void> submitScore(int challengeId, String userId, int score, int time) async {
    await supabase
        .from('challenge_participants')
        .update({'score': score, 'time_spent': time})
        .eq('challenge_id', challengeId)
        .eq('user_id', userId);

    // Optionnel : vérifier si tous ont joué et déterminer le gagnant
  }
}