import 'package:kalan_app/core/utils/sqlite_map_utils.dart';

class FlashcardModel {
  final int? id;
  final String uuid;
  final String deckId;
  final String question;
  final String answer;
  final int difficulty;
  final DateTime? nextReview;
  final int interval;
  final int repetitions;
  final DateTime createdAt;
  final bool isSynced;

  FlashcardModel({
    this.id,
    required this.uuid,
    required this.deckId,
    required this.question,
    required this.answer,
    this.difficulty = 1,
    this.nextReview,
    this.interval = 0,
    this.repetitions = 0,
    required this.createdAt,
    this.isSynced = false,
  });

  factory FlashcardModel.fromMap(Map<String, dynamic> map) => FlashcardModel(
        id: SqliteMapUtils.localId(map['id']),
        uuid: SqliteMapUtils.uuidFromMap(map),
        deckId: SqliteMapUtils.requiredString(map['deck_id'], field: 'deck_id'),
        question: SqliteMapUtils.requiredString(map['question'], field: 'question'),
        answer: SqliteMapUtils.requiredString(map['answer'], field: 'answer'),
        difficulty: SqliteMapUtils.asInt(map['difficulty'], 1),
        nextReview: SqliteMapUtils.parseDateTime(map['next_review']),
        interval: SqliteMapUtils.asInt(map['interval']),
        repetitions: SqliteMapUtils.asInt(map['repetitions']),
        createdAt: SqliteMapUtils.parseDateTime(map['created_at']) ?? DateTime.now(),
        isSynced: SqliteMapUtils.asBool(map['is_synced']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'deck_id': deckId,
        'question': question,
        'answer': answer,
        'difficulty': difficulty,
        'next_review': nextReview?.toIso8601String(),
        'interval': interval,
        'repetitions': repetitions,
        'created_at': createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'uuid': uuid,
        'deck_id': deckId,
        'question': question,
        'answer': answer,
        'difficulty': difficulty,
        'next_review': nextReview?.toIso8601String(),
        'interval': interval,
        'repetitions': repetitions,
        'created_at': createdAt.toIso8601String(),
      };

  factory FlashcardModel.fromSupabaseJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['question'] ??= json['front'];
    normalized['answer'] ??= json['back'];
    normalized['deck_id'] ??= json['deck_uuid'];
    return FlashcardModel.fromMap({...normalized, 'is_synced': 1});
  }
}
