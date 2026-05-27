import 'package:equatable/equatable.dart';
import '../../../domain/entities/user_badge.dart';

abstract class BadgeState extends Equatable {
  const BadgeState();
  @override
  List<Object?> get props => [];
}

class BadgeInitial extends BadgeState {}
class BadgeLoading extends BadgeState {}
class BadgeLoaded extends BadgeState {
  final List<UserBadge> unlockedBadges;
  final List<Map<String, dynamic>> allBadges;
  const BadgeLoaded(this.unlockedBadges, this.allBadges);
  @override
  List<Object?> get props => [unlockedBadges, allBadges];
}
class BadgeError extends BadgeState {
  final String message;
  const BadgeError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Émis juste après qu'un badge est débloqué — déclenche le popup
class BadgeJustUnlocked extends BadgeState {
  final String label;
  final String emoji;
  final String? imagePath;
  final int color;
  final String? description;
  const BadgeJustUnlocked({
    required this.label,
    required this.emoji,
    this.imagePath,
    required this.color,
    this.description,
  });
  @override
  List<Object?> get props => [label, emoji, imagePath, color, description];
}
