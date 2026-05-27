import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../local/database_helper.dart';
import '../models/quiz_result_model.dart';
import '../remote/supabase_service.dart';
import '../../services/connectivity_service.dart';

class QuizRepositoryImpl implements QuizRepository {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivity;

  QuizRepositoryImpl(this._dbHelper, this._connectivity);

  @override
  Future<void> saveQuizResult(String? deckId, int score, int total, int duration, int xpGained) async {
    final db = await _dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final String userId = prefs.getString('current_user_uuid') ?? 'guest';

    final model = QuizResultModel(
      userId: userId,
      deckId: deckId,
      score: score,
      total: total,
      durationSeconds: duration,
      xpGained: xpGained,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    // 1. Local SQLite
    await db.insert('quiz_results', model.toMap());

    // 2. Supabase Sync
    if (await _connectivity.isOnline() && userId != 'guest') {
      try {
        await SupabaseService.client.from('quiz_results').insert(model.toSupabaseJson());
        await db.update('quiz_results', {'is_synced': 1}, 
            where: 'user_id = ? AND created_at = ?', 
            whereArgs: [userId, model.createdAt.toIso8601String()]);
      } catch (e) {
        await _addToSyncQueue('CREATE_QUIZ_RESULT', model.toSupabaseJson());
      }
    } else if (userId != 'guest') {
      await _addToSyncQueue('CREATE_QUIZ_RESULT', model.toSupabaseJson());
    }
  }

  @override
  Future<List<QuizResult>> getQuizHistory() async {
    final db = await _dbHelper.database;
    final maps = await db.query('quiz_results', orderBy: 'created_at DESC');
    
    return maps.map((m) {
      final model = QuizResultModel.fromMap(m);
      return QuizResult(
        id: model.id?.toString(),
        userId: model.userId,
        deckId: model.deckId,
        score: model.score,
        total: model.total,
        durationSeconds: model.durationSeconds,
        createdAt: model.createdAt,
      );
    }).toList();
  }

  Future<void> _addToSyncQueue(String action, Map<String, dynamic> payload) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'action': action,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
