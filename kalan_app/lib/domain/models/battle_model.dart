class Battle {
  final String id;
  final String inviterId;
  final String invitedId;
  final String status;
  final String? theme;
  final int xpBet;
  final DateTime createdAt;
  final DateTime? phaseStartTime;
  final List<dynamic>? flashcards;
  final List<dynamic>? quizQuestions;
  final int currentQuestionIndex;
  final int inviterScore;
  final int invitedScore;
  final String? realTheme;
  final String? turnUserId;
  final String? winnerId;

  Battle({
    required this.id,
    required this.inviterId,
    required this.invitedId,
    required this.status,
    this.theme,
    required this.xpBet,
    required this.createdAt,
    this.phaseStartTime,
    this.flashcards,
    this.quizQuestions,
    required this.currentQuestionIndex,
    required this.inviterScore,
    required this.invitedScore,
    this.realTheme,
    this.turnUserId,
    this.winnerId,
  });

  /// Contenu JSON du défi (Map ou List selon la source / plateforme).
  static Map<String, dynamic>? parseContent(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) return {'quizzes': raw};
    return null;
  }

  static List<dynamic>? _asList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value;
    return null;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  factory Battle.fromJson(Map<String, dynamic> json) {
    final content = parseContent(json['content']);
    return Battle(
      id: json['id'].toString(),
      inviterId: json['inviter_id'].toString(),
      invitedId: json['invited_id'].toString(),
      status: json['status'].toString(),
      theme: json['theme'] as String?,
      xpBet: json['xp_bet'] is int
          ? json['xp_bet'] as int
          : int.tryParse(json['xp_bet']?.toString() ?? '') ?? 0,
      createdAt: _parseDate(json['created_at']),
      phaseStartTime: json['phase_start_time'] != null
          ? _parseDate(json['phase_start_time'])
          : null,
      flashcards: _asList(content?['flashcards']),
      quizQuestions: _asList(content?['quizzes'] ?? content?['quiz_questions']),
      currentQuestionIndex: json['current_question_index'] is int
          ? json['current_question_index'] as int
          : int.tryParse(json['current_question_index']?.toString() ?? '') ?? 0,
      inviterScore: json['inviter_score'] is int
          ? json['inviter_score'] as int
          : int.tryParse(json['inviter_score']?.toString() ?? '') ?? 0,
      invitedScore: json['invited_score'] is int
          ? json['invited_score'] as int
          : int.tryParse(json['invited_score']?.toString() ?? '') ?? 0,
      realTheme: json['real_theme'] as String?,
      turnUserId: json['turn_user_id']?.toString(),
      winnerId: json['winner_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inviter_id': inviterId,
      'invited_id': invitedId,
      'status': status,
      'theme': theme,
      'xp_bet': xpBet,
      'current_question_index': currentQuestionIndex,
      'inviter_score': inviterScore,
      'invited_score': invitedScore,
      'real_theme': realTheme,
      'turn_user_id': turnUserId,
      'winner_id': winnerId,
    };
  }
}
