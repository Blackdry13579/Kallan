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
  final String? email;
  final String? pinHash;

  UserModel({
    this.id,
    required this.uuid,
    required this.pseudo,
    this.email,
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
        id: _localIdFromMap(map),
        uuid: _uuidFromMap(map),
        pseudo: map['pseudo'] as String,
        firstName: map['first_name'] ?? map['firstName'],
        lastName: map['last_name'] ?? map['lastName'],
        schoolId: _asIntOrNull(map['school_id']),
        schoolName: map['school_name'],
        classId: _asIntOrNull(map['class_id']),
        className: map['class_name'] ?? map['class'],
        language: map['language'] ?? 'fr',
<<<<<<< HEAD
        points: _asInt(map['points']),
        level: _asInt(map['level'], 1),
        streak: _asInt(map['streak']),
        isGuest: _asBool(map['is_guest']),
        avatarId: _asIntOrNull(map['avatar_id']),
        lastActive: _parseDateTime(map['last_active']),
        createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
        pinHash: map['pin_hash'] as String?,
=======
        points: map['points'] ?? 0,
        level: map['level'] ?? 1,
        streak: map['streak'] ?? 0,
        isGuest: (map['is_guest'] ?? 0) == 1,
        avatarId: map['avatar_id'],
        lastActive: map['last_active'] != null ? DateTime.tryParse(map['last_active']) : null,
        email: map['email'],
        createdAt: DateTime.parse(map['created_at']),
        pinHash: map['pin_hash'],
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
      );

  /// SQLite row id (int). Supabase may expose a UUID in `id` — ignore it here.
  static int? _localIdFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is int) return id;
    return null;
  }

  static String _uuidFromMap(Map<String, dynamic> map) {
    final uuid = map['uuid'];
    if (uuid is String && uuid.isNotEmpty) return uuid;
    final id = map['id'];
    if (id is String && id.isNotEmpty) return id;
    throw ArgumentError('User map missing uuid');
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int _asInt(dynamic value, [int fallback = 0]) =>
      _asIntOrNull(value) ?? fallback;

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'pseudo': pseudo,
        'email': email,
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
        'email': email,
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
