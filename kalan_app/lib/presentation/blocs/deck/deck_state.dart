import 'package:equatable/equatable.dart';
import '../../../domain/entities/deck.dart';

abstract class DeckState extends Equatable {
  const DeckState();
  @override
  List<Object?> get props => [];
}

class DeckInitial extends DeckState {}
class DeckLoading extends DeckState {}
class DeckLoaded extends DeckState {
  final List<Deck> decks;
  const DeckLoaded(this.decks);
  @override
  List<Object?> get props => [decks];
}
class DeckSaved extends DeckState {}

class DeckError extends DeckState {
  final String message;
  const DeckError(this.message);
  @override
  List<Object?> get props => [message];
}
