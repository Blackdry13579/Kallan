import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/user_repository.dart';
import 'user_event.dart';
import 'user_state.dart';
import '../../../services/connectivity_service.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repository;

  UserBloc(this._repository) : super(UserInitial()) {
    on<LoadUserProfile>((event, emit) async {
      emit(UserLoading());
      try {
        final profile = await _repository.getUserProfile();
        final userId = profile['uuid'] ?? '';
        final statsMap = await _repository.getUserStats(userId);
        final recentDecks = await _repository.getRecentActivity(userId);
        
        final stats = Map<String, dynamic>.from(statsMap);
        stats['recentDecks'] = recentDecks;

        final badges = await _repository.getUserBadges(userId);
        
        // On check la connectivité (si disposible dans le repo ou via service)
        bool isOnline = true;
        try {
          final conn = await ConnectivityService().isOnline();
          isOnline = conn;
        } catch (_) {}

        emit(UserLoaded(profile, stats, badges, isOnline: isOnline));
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });

    on<UpdateUserProfile>((event, emit) async {
      try {
        await _repository.updateUserProfile(
          pseudo: event.pseudo,
          avatar: event.avatar,
          avatarId: event.avatarId,
          school: event.school,
          className: event.className,
          firstName: event.firstName,
          lastName: event.lastName,
        );
        add(LoadUserProfile());
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });

    on<AddPoints>((event, emit) async {
      try {
        await _repository.addPoints(event.points);
        add(LoadUserProfile());
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });

    on<SearchFriends>((event, emit) async {
      if (state is UserLoaded) {
        final currentState = state as UserLoaded;
        if (event.query.trim().isEmpty) {
          emit(currentState.copyWith(searchResults: []));
          return;
        }
        try {
          final results = await _repository.searchUsers(event.query);
          emit(currentState.copyWith(searchResults: results));
        } catch (_) {}
      }
    });

    on<AddFriend>((event, emit) async {
      try {
        await _repository.addFriend(event.friend);
        add(LoadFriends());
      } catch (_) {}
    });

    on<LoadFriends>((event, emit) async {
      if (state is UserLoaded) {
        final currentState = state as UserLoaded;
        try {
          final friends = await _repository.getFriends();
          emit(currentState.copyWith(friends: friends));
        } catch (_) {}
      }
    });

    on<RefreshBadges>((event, emit) async {
      if (state is UserLoaded) {
        final currentState = state as UserLoaded;
        try {
          final userId = currentState.profile['uuid'] ?? '';
          final badges = await _repository.getUserBadges(userId);
          emit(currentState.copyWith(badges: badges));
        } catch (_) {}
      }
    });
  }
}
