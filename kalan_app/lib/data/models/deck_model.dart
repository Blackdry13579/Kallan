import 'package:kalan_app/core/utils/sqlite_map_utils.dart';

class DeckModel {
  final int? id;
  final String uuid;
  final String userId;
  final String title;
  final String? description;
  final String? subject;
  final String? level;
  final bool isPublic;
  final int downloadCount;
  final DateTime createdAt;
  final bool isSynced;

  DeckModel({
    this.id,
    required this.uuid,
    required this.userId,
    required this.title,
    this.description,
    this.subject,
    this.level,
    this.isPublic = false,
    this.downloadCount = 0,
    required this.createdAt,
    this.isSynced = false,
  });

  factory DeckModel.fromMap(Map<String, dynamic> map) => DeckModel(
        id: SqliteMapUtils.localId(map['id']),
        uuid: SqliteMapUtils.uuidFromMap(map),
        userId: SqliteMapUtils.requiredString(map['user_id'], field: 'user_id'),
        title: SqliteMapUtils.requiredString(map['title'], field: 'title'),
        description: map['description'] as String?,
        subject: map['subject'] as String?,
        level: map['level'] as String?,
        isPublic: SqliteMapUtils.asBool(map['is_public']),
        downloadCount: SqliteMapUtils.asInt(map['download_count']),
        createdAt: SqliteMapUtils.parseDateTime(map['created_at']) ?? DateTime.now(),
        isSynced: SqliteMapUtils.asBool(map['is_synced']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'user_id': userId,
        'title': title,
        'description': description,
        'subject': subject,
        'level': level,
        'is_public': isPublic ? 1 : 0,
        'download_count': downloadCount,
        'created_at': createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'uuid': uuid,
        'user_id': userId,
        'title': title,
        'description': description,
        'subject': subject,
        'level': level,
        'is_public': isPublic,
        'download_count': downloadCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory DeckModel.fromSupabaseJson(Map<String, dynamic> json) =>
      DeckModel.fromMap({...json, 'is_synced': 1});
}
