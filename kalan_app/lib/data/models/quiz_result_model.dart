class QuizResultModel {
  final int? id;
  final String userId;
  final String? deckId;
  final int score;
  final int total;
  final int durationSeconds;
  final int xpGained;
  final DateTime createdAt;
  final bool isSynced;

  QuizResultModel({
    this.id,
    required this.userId,
    this.deckId,
    required this.score,
    required this.total,
    this.durationSeconds = 0,
    this.xpGained = 0,
    required this.createdAt,
    this.isSynced = false,
  });

  factory QuizResultModel.fromMap(Map<String, dynamic> map) => QuizResultModel(
        id: map['id'],
        userId: map['user_id'],
        deckId: map['deck_id']?.toString(),
        score: map['score'],
        total: map['total'],
        durationSeconds: map['duration_seconds'] ?? 0,
        xpGained: map['xp_gained'] ?? 0,
        createdAt: DateTime.parse(map['created_at']),
        isSynced: map['is_synced'] == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'deck_id': deckId,
        'score': score,
        'total': total,
        'duration_seconds': durationSeconds,
        'xp_gained': xpGained,
        'created_at': createdAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'user_id': userId,
        'deck_id': deckId,
        'score': score,
        'total': total,
        'duration_seconds': durationSeconds,
        'xp_gained': xpGained,
        'created_at': createdAt.toIso8601String(),
      };

  factory QuizResultModel.fromSupabaseJson(Map<String, dynamic> json) => QuizResultModel(
        userId: json['user_id'],
        deckId: json['deck_id']?.toString(),
        score: json['score'],
        total: json['total'],
        durationSeconds: json['duration_seconds'] ?? 0,
        xpGained: json['xp_gained'] ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        isSynced: true,
      );
}
