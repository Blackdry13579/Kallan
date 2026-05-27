import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/deck_repository.dart';
import 'deck_event.dart';
import 'deck_state.dart';

class DeckBloc extends Bloc<DeckEvent, DeckState> {
  final DeckRepository _repository;

  DeckBloc(this._repository) : super(DeckInitial()) {
    on<LoadDecks>(_onLoadDecks);
    on<CreateDeck>(_onCreateDeck);
    on<DeleteDeck>(_onDeleteDeck);
    on<ToggleDeckPublic>(_onTogglePublic);
  }

  Future<void> _onLoadDecks(LoadDecks event, Emitter<DeckState> emit) async {
    emit(DeckLoading());
    try {
      final decks = await _repository.getDecks();
      emit(DeckLoaded(decks));
    } catch (e) {
      emit(const DeckError('Erreur chargement decks'));
    }
  }

  Future<void> _onCreateDeck(CreateDeck event, Emitter<DeckState> emit) async {
    try {
      await _repository.createDeck(event.title, event.subject, event.level, cards: event.cards, uuid: event.uuid);
      emit(DeckSaved());
      add(const LoadDecks());
    } catch (e) {
      emit(const DeckError('Erreur création deck'));
    }
  }

  Future<void> _onDeleteDeck(DeleteDeck event, Emitter<DeckState> emit) async {
    try {
      await _repository.deleteDeck(event.uuid);
      add(const LoadDecks());
    } catch (e) {
      emit(const DeckError('Erreur suppression'));
    }
  }

  Future<void> _onTogglePublic(ToggleDeckPublic event, Emitter<DeckState> emit) async {
    try {
      await _repository.togglePublic(event.uuid);
      add(const LoadDecks());
    } catch (e) {
      emit(const DeckError('Erreur modification'));
    }
  }
}
