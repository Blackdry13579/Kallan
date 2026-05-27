import 'package:equatable/equatable.dart';

abstract class QuizEvent extends Equatable {
  const QuizEvent();
  @override
  List<Object?> get props => [];
}

class SubmitQuiz extends QuizEvent {
  final String? deckId;
  final int score;
  final int total;
  final int duration;
  final int xpGained;

  const SubmitQuiz({this.deckId, required this.score, required this.total, required this.duration, this.xpGained = 0});

  @override
  List<Object?> get props => [deckId, score, total, duration, xpGained];
}
