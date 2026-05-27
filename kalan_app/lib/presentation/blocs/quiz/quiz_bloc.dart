import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/quiz_repository.dart';
import 'quiz_event.dart';
import 'quiz_state.dart';

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  final QuizRepository _repository;

  QuizBloc(this._repository) : super(QuizInitial()) {
    on<SubmitQuiz>((event, emit) async {
      emit(QuizSubmitting());
      try {
        await _repository.saveQuizResult(event.deckId, event.score, event.total, event.duration, event.xpGained);
        // Les points sont déjà crédités question par question pendant le quiz.
        emit(const QuizSubmitted(true));
      } catch (e) {
        emit(QuizError(e.toString()));
      }
    });
  }
}
