import 'package:equatable/equatable.dart';
import '../../../domain/entities/flashcard.dart';

abstract class FlashcardState extends Equatable {
  const FlashcardState();
  @override
  List<Object?> get props => [];
}

class FlashcardInitial extends FlashcardState {}
class FlashcardLoading extends FlashcardState {}
class FlashcardLoaded extends FlashcardState {
  final String deckUuid;
  final List<Flashcard> cards;
  const FlashcardLoaded(this.deckUuid, this.cards);
  @override
  List<Object?> get props => [deckUuid, cards];
}
class FlashcardError extends FlashcardState {
  final String message;
  const FlashcardError(this.message);
  @override
  List<Object?> get props => [message];
}
