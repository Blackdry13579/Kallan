import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  @override
  List<Object?> get props => [];
}

class LoadUserProfile extends UserEvent {}

class AddPoints extends UserEvent {
  final int points;
  const AddPoints(this.points);
  @override
  List<Object?> get props => [points];
}

class UpdateUserProfile extends UserEvent {
  final String? pseudo;
  final String? avatar;
  final int? avatarId;
  final String? school;
  final String? className;
  final String? firstName;
  final String? lastName;

  const UpdateUserProfile({this.pseudo, this.avatar, this.avatarId, this.school, this.className, this.firstName, this.lastName});

  @override
  List<Object?> get props => [pseudo, avatar, avatarId, school, className, firstName, lastName];
}

class SearchFriends extends UserEvent {
  final String query;
  const SearchFriends(this.query);
  @override
  List<Object?> get props => [query];
}

class AddFriend extends UserEvent {
  final Map<String, dynamic> friend;
  const AddFriend(this.friend);
  @override
  List<Object?> get props => [friend];
}

class LoadFriends extends UserEvent {}

class RefreshBadges extends UserEvent {}
