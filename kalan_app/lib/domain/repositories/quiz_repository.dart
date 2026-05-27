import '../entities/quiz_result.dart';

abstract class QuizRepository {
  Future<void> saveQuizResult(String? deckId, int score, int total, int duration, int xpGained);
  Future<List<QuizResult>> getQuizHistory();
}
