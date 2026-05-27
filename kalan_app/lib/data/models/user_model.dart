class UserModel {
  final int? id;
  final String uuid;
  final String pseudo;
  final String? firstName;
  final String? lastName;
  final int? schoolId;
  final String? schoolName;
  final int? classId;
  final String? className;
  final String language;
  final int points;
  final int level;
  final int streak;
  final bool isGuest;
  final int? avatarId;
  final DateTime? lastActive;
  final DateTime createdAt;
  final String? pinHash;

  UserModel({
    this.id,
    required this.uuid,
    required this.pseudo,
    this.firstName,
    this.lastName,
    this.schoolId,
    this.schoolName,
    this.classId,
    this.className,
    this.language = 'fr',
    this.points = 0,
    this.level = 1,
    this.streak = 0,
    this.isGuest = false,
    this.avatarId,
    this.lastActive,
    required this.createdAt,
    this.pinHash,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'],
        uuid: map['uuid'],
        pseudo: map['pseudo'],
        firstName: map['first_name'] ?? map['firstName'],
        lastName: map['last_name'] ?? map['lastName'],
        schoolId: map['school_id'],
        schoolName: map['school_name'],
        classId: map['class_id'],
        className: map['class_name'] ?? map['class'],
        language: map['language'] ?? 'fr',
        points: map['points'] ?? 0,
        level: map['level'] ?? 1,
        streak: map['streak'] ?? 0,
        isGuest: (map['is_guest'] ?? 0) == 1,
        avatarId: map['avatar_id'],
        lastActive: map['last_active'] != null ? DateTime.tryParse(map['last_active']) : null,
        createdAt: DateTime.parse(map['created_at']),
        pinHash: map['pin_hash'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'pseudo': pseudo,
        'language': language,
        'points': points,
        'level': level,
        'streak': streak,
        'is_guest': isGuest ? 1 : 0,
        'avatar_id': avatarId,
        'last_active': lastActive?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'pin_hash': pinHash,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'uuid': uuid,
        'pseudo': pseudo,
        'language': language,
        'points': points,
        'level': level,
        'streak': streak,
        'avatar_id': avatarId,
        'avatar_url': avatarId != null ? 'assets/avatars/avatar$avatarId.png' : null,
        'last_active': lastActive?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'pin_hash': pinHash,
      };
}
