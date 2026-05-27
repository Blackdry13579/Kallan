import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/badge_repository.dart';
import 'badge_event.dart';
import 'badge_state.dart';

class BadgeBloc extends Bloc<BadgeEvent, BadgeState> {
  final BadgeRepository _repository;

  BadgeBloc(this._repository) : super(BadgeInitial()) {
    on<LoadBadges>((event, emit) async {
      emit(BadgeLoading());
      try {
        final unlocked = await _repository.getUserBadges();
        final all = await _repository.getAllBadges();
        emit(BadgeLoaded(unlocked, all));
      } catch (e) {
        emit(BadgeError(e.toString()));
      }
    });

    on<UnlockBadge>((event, emit) async {
      try {
        // Récupère les détails du badge avant de le déverrouiller
        final allBadges = await _repository.getAllBadges();
        final badgeData = allBadges.firstWhere(
          (b) => b['id'] == event.badgeKey,
          orElse: () => <String, dynamic>{},
        );

        await _repository.unlockBadge(event.badgeKey);

        // Émet l'état "badge vient d'être débloqué" pour déclencher le popup
        if (badgeData.isNotEmpty) {
          emit(BadgeJustUnlocked(
            label: badgeData['label'] ?? event.badgeKey,
            emoji: badgeData['emoji'] ?? '🏆',
            imagePath: badgeData['image_path'] as String?,
            color: badgeData['color'] as int? ?? 0xFF2D6A2D,
            description: badgeData['description'] as String?,
          ));
        }

        // Recharge la liste des badges
        add(LoadBadges());
      } catch (e) {
        emit(BadgeError(e.toString()));
      }
    });

    on<CheckNewBadges>((event, emit) async {
      try {
        final newlyUnlockedKeys = await _repository.checkAndAwardBadges();
        if (newlyUnlockedKeys.isNotEmpty) {
          final allBadges = await _repository.getAllBadges();
          
          for (var key in newlyUnlockedKeys) {
            final badgeData = allBadges.firstWhere(
              (b) => b['id'] == key,
              orElse: () => <String, dynamic>{},
            );

            if (badgeData.isNotEmpty) {
              emit(BadgeJustUnlocked(
                label: badgeData['label'] ?? key,
                emoji: badgeData['emoji'] ?? '🏆',
                imagePath: badgeData['image_path'] as String?,
                color: badgeData['color'] as int? ?? 0xFF2D6A2D,
                description: badgeData['description'] as String?,
              ));
              // Petit délai si plusieurs badges débloqués en même temps
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
          add(LoadBadges());
        }
      } catch (e) {
        emit(BadgeError(e.toString()));
      }
    });
  }
}
