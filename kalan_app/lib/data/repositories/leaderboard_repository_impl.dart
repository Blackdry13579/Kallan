import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../leaderboard_sync_helper.dart';
import '../local/database_helper.dart';
import '../remote/supabase_service.dart';
import '../../services/connectivity_service.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivity;

  LeaderboardRepositoryImpl(this._dbHelper, this._connectivity);

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({String scope = 'national'}) async {
    final db = await _dbHelper.database;

    if (await _connectivity.isOnline()) {
      try {
        // Vider le cache avant fetch pour éviter d'afficher des users supprimés
        await db.delete('leaderboard_entries', where: 'scope = ?', whereArgs: [scope]);

        // 1. Source principale : table users triée par points (toujours à jour)
        var entries = await _fetchFromUsersTable(scope);
        if (entries.isNotEmpty) {
          await _cacheEntries(db, scope, entries);
          return entries;
        }

        // 2. Fallback : RPC get_leaderboard si elle existe
        entries = await _fetchViaRpc(scope);
        if (entries.isNotEmpty) {
          await _cacheEntries(db, scope, entries);
          return entries;
        }
      } catch (e) {
        debugPrint('Erreur classement Supabase : $e');
      }
    }

    return _readLocalEntries(db, scope);
  }

  /// RPC fournie côté Supabase : get_leaderboard(scope_name)
  Future<List<LeaderboardEntry>> _fetchViaRpc(String scope) async {
    final response = await SupabaseService.client.rpc(
      'get_leaderboard',
      params: {'scope_name': scope},
    );

    final List<dynamic> rows = response as List;
    final List<LeaderboardEntry> entries = [];
    var index = 1;

    for (final item in rows) {
      final map = Map<String, dynamic>.from(item as Map);
      entries.add(LeaderboardEntry(
        userId: map['user_uuid']?.toString() ?? '',
        pseudo: map['pseudo'] as String? ?? 'Anonyme',
        points: (map['total_points'] as num?)?.toInt() ?? 0,
        position: index++,
        scope: scope,
        lastUpdated: DateTime.now(),
        avatar: map['avatar_url']?.toString(),
      ));
    }
    return entries;
  }

  Future<List<LeaderboardEntry>> _fetchViaTable(String scope) async {
    final response = await SupabaseService.client
        .from('leaderboard_entries')
        .select('user_id, points, scope, pseudo, avatar, last_updated')
        .eq('scope', scope)
        .order('points', ascending: false)
        .limit(100);

    final List<dynamic> rows = response as List;
    final List<LeaderboardEntry> entries = [];
    var index = 1;

    for (final item in rows) {
      entries.add(LeaderboardEntry(
        userId: item['user_id'].toString(),
        pseudo: item['pseudo'] as String? ?? 'Anonyme',
        points: (item['points'] as num?)?.toInt() ?? 0,
        position: index++,
        scope: scope,
        lastUpdated: DateTime.tryParse(item['last_updated']?.toString() ?? '') ?? DateTime.now(),
        avatar: item['avatar']?.toString(),
      ));
    }
    return entries;
  }

  Future<List<LeaderboardEntry>> _fetchFromUsersTable(String scope) async {
    final response = await SupabaseService.client
        .from('users')
        .select('uuid, pseudo, avatar_id, avatar_url, points')
        .order('points', ascending: false)
        .limit(100);

    final List<dynamic> rows = response as List;
    final List<LeaderboardEntry> entries = [];
    var index = 1;

    for (final item in rows) {
      final pts = (item['points'] as num?)?.toInt() ?? 0;
      // avatar_url en priorité, sinon avatar_id (numéro d'avatar local)
      final avatar = (item['avatar_url'] as String?)?.isNotEmpty == true
          ? item['avatar_url'] as String
          : item['avatar_id']?.toString();
      entries.add(LeaderboardEntry(
        userId: item['uuid'].toString(),
        pseudo: item['pseudo'] as String? ?? 'Anonyme',
        points: pts,
        position: index++,
        scope: scope,
        lastUpdated: DateTime.now(),
        avatar: avatar,
      ));
    }
    return entries;
  }

  Future<void> _cacheEntries(
    Database db,
    String scope,
    List<LeaderboardEntry> entries,
  ) async {
    await db.delete('leaderboard_entries', where: 'scope = ?', whereArgs: [scope]);
    for (final entry in entries) {
      await db.insert(
        'leaderboard_entries',
        {
          'user_id': entry.userId,
          'points': entry.points,
          'scope': scope,
          'pseudo': entry.pseudo,
          'avatar': entry.avatar,
          'last_updated': entry.lastUpdated.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<LeaderboardEntry>> _readLocalEntries(Database db, String scope) async {
    final maps = await db.query(
      'leaderboard_entries',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'points DESC',
    );

    var index = 1;
    return maps
        .map(
          (m) => LeaderboardEntry(
            userId: m['user_id'] as String,
            pseudo: m['pseudo'] as String? ?? 'Anonyme',
            points: m['points'] as int? ?? 0,
            position: index++,
            scope: m['scope'] as String? ?? scope,
            lastUpdated: DateTime.tryParse(m['last_updated'] as String? ?? '') ?? DateTime.now(),
            avatar: m['avatar'] as String?,
          ),
        )
        .toList();
  }

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard({String scope = 'national'}) async* {
    yield await getLeaderboard(scope: scope);
  }

  @override
  Future<void> updateUserPoints(int points) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final db = await _dbHelper.database;
    final maps = await db.query('users', where: 'uuid = ?', whereArgs: [user.id], limit: 1);
    final userProfile = maps.isNotEmpty ? maps.first : <String, dynamic>{};

    final payload = LeaderboardSyncHelper.entryPayload(
      userId: user.id,
      points: points,
      profile: userProfile,
    );

    await _upsertLeaderboard(db, payload);
  }

  /// Synchronise une entrée classement (appelée aussi depuis UserRepository).
  Future<void> syncLeaderboardEntry({
    required String userId,
    required int points,
    required Map<String, dynamic> profile,
    String scope = 'national',
  }) async {
    final db = await _dbHelper.database;
    final payload = LeaderboardSyncHelper.entryPayload(
      userId: userId,
      points: points,
      profile: profile,
      scope: scope,
    );
    await _upsertLeaderboard(db, payload);
  }

  Future<void> _upsertLeaderboard(Database db, Map<String, dynamic> payload) async {
    await db.insert(
      'leaderboard_entries',
      {
        'user_id': payload['user_id'],
        'points': payload['points'],
        'scope': payload['scope'],
        'pseudo': payload['pseudo'],
        'avatar': payload['avatar'],
        'last_updated': payload['last_updated'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (!await _connectivity.isOnline()) {
      await _addToSyncQueue('UPDATE_LEADERBOARD', payload);
      return;
    }

    try {
      await SupabaseService.client.from('leaderboard_entries').upsert(
        payload,
        onConflict: 'user_id,scope',
      );
    } catch (e) {
      debugPrint('Upsert leaderboard : $e');
      await _addToSyncQueue('UPDATE_LEADERBOARD', payload);
    }
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
