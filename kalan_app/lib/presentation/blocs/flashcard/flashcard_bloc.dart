import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/flashcard_repository.dart';
import 'flashcard_event.dart';
import 'flashcard_state.dart';

class FlashcardBloc extends Bloc<FlashcardEvent, FlashcardState> {
  final FlashcardRepository _repository;

  FlashcardBloc(this._repository) : super(FlashcardInitial()) {
    on<LoadFlashcards>((event, emit) async {
      emit(FlashcardLoading());
      try {
        final cards = await _repository.getFlashcardsByDeck(event.deckUuid);
        emit(FlashcardLoaded(event.deckUuid, cards));
      } catch (e) {
        emit(FlashcardError(e.toString()));
      }
    });

    on<AddFlashcard>((event, emit) async {
      try {
        await _repository.createFlashcard(event.deckUuid, event.question, event.answer);
        add(LoadFlashcards(event.deckUuid));
      } catch (e) {
        emit(FlashcardError(e.toString()));
      }
    });

    on<UpdateReview>((event, emit) async {
      try {
        await _repository.updateFlashcardReview(event.cardUuid, event.difficulty);
      } catch (e) {
        // Silent error or handle it
      }
    });
  }
}
