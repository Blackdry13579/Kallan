import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/user_repository.dart';
import '../../core/utils/level_utils.dart';
import '../local/database_helper.dart';
import '../remote/supabase_service.dart';
import '../../services/connectivity_service.dart';
import '../leaderboard_sync_helper.dart';

class UserRepositoryImpl implements UserRepository {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivity;

  UserRepositoryImpl(this._dbHelper, this._connectivity);

  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    final db = await _dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_uuid');
    
    List<Map<String, dynamic>> maps;
    if (currentUserId != null) {
      // Chercher l'utilisateur spécifique
      maps = await db.query('users', where: 'uuid = ?', whereArgs: [currentUserId], limit: 1);
    } else {
      // Fallback au premier utilisateur si aucun n'est marqué (pour la compatibilité)
      maps = await db.query('users', limit: 1);
    }
    
    if (maps.isNotEmpty) {
      final userMap = Map<String, dynamic>.from(maps.first);

      // Si en ligne, s'assurer que le profil existe dans Supabase
      if (await _connectivity.isOnline() && userMap['uuid'] != null) {
        _ensureSupabaseProfile(userMap['uuid'] as String, userMap);
      }

      // Update streak if needed
      final updatedUserMap = await _checkAndUpdateStreak(userMap);
      return updatedUserMap;
    }
    
    // Default if nothing in local
    return {
      'pseudo': 'Élève KALAN',
      'points': 0,
      'level': 1,
      'streak': 0,
      'class': 'Non définie',
    };
  }

  // Crée le profil dans Supabase s'il est absent (comptes anciens, changement de téléphone)
  Future<void> _ensureSupabaseProfile(String uuid, Map<String, dynamic> localMap) async {
    try {
      final existing = await SupabaseService.client
          .from('users')
          .select('uuid')
          .eq('uuid', uuid)
          .maybeSingle();
      if (existing == null) {
        await SupabaseService.client.from('users').upsert({
          'uuid':        uuid,
          'pseudo':      localMap['pseudo'] ?? 'Joueur',
          'email':       localMap['email'] ?? '',
          'avatar_id':   localMap['avatar_id'] ?? 1,
          'points':      localMap['points'] ?? 0,
          'level':       localMap['level'] ?? 1,
          'streak':      localMap['streak'] ?? 0,
          'created_at':  localMap['created_at'] ?? DateTime.now().toIso8601String(),
          'last_active': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _checkAndUpdateStreak(Map<String, dynamic> userMap) async {
    final db = await _dbHelper.database;
    final String? lastActiveStr = userMap['last_active'];
    final int currentStreak = userMap['streak'] ?? 0;
    final String uuid = userMap['uuid'];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (lastActiveStr != null) {
      final lastActive = DateTime.parse(lastActiveStr);
      final lastActiveDate = DateTime(lastActive.year, lastActive.month, lastActive.day);
      
      final difference = today.difference(lastActiveDate).inDays;
      
      if (difference == 0) {
        // Déjà actif aujourd'hui, pas de changement de série
        return userMap;
      } else if (difference == 1) {
        // Actif hier, on incrémente la série
        final newStreak = currentStreak + 1;
        final updates = {
          'streak': newStreak,
          'last_active': today.toIso8601String(),
        };
        await db.update('users', updates, where: 'uuid = ?', whereArgs: [uuid]);
        
        // Sync online if possible
        if (await _connectivity.isOnline()) {
           try {
             await SupabaseService.client.from('users').update(updates).eq('uuid', uuid);
           } catch (_) {}
        }
        
        return {...userMap, ...updates};
      } else {
        // Plus d'un jour d'inactivité, on réinitialise à 1 (pour aujourd'hui)
        final updates = {
          'streak': 1,
          'last_active': today.toIso8601String(),
        };
        await db.update('users', updates, where: 'uuid = ?', whereArgs: [uuid]);
        
        if (await _connectivity.isOnline()) {
           try {
             await SupabaseService.client.from('users').update(updates).eq('uuid', uuid);
           } catch (_) {}
        }
        return {...userMap, ...updates};
      }
    } else {
      // Première activité enregistrée
      final updates = {
        'streak': 1,
        'last_active': today.toIso8601String(),
      };
      await db.update('users', updates, where: 'uuid = ?', whereArgs: [uuid]);
      
      if (await _connectivity.isOnline()) {
         try {
           await SupabaseService.client.from('users').update(updates).eq('uuid', uuid);
         } catch (_) {}
      }
      return {...userMap, ...updates};
    }
  }

  @override
  Future<void> updateUserProfile({String? pseudo, String? avatar, int? avatarId, String? school, String? className, String? firstName, String? lastName}) async {
    final db = await _dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final String currentUserId = prefs.getString('current_user_uuid') ?? 'guest';
    
    final Map<String, dynamic> updates = {};
    if (pseudo != null) updates['pseudo'] = pseudo;
    if (className != null) updates['class_name'] = className;
    if (avatarId != null) updates['avatar_id'] = avatarId;
    if (avatar != null) updates['avatar_url'] = avatar;
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (school != null) updates['school_name'] = school;
    updates['updated_at'] = DateTime.now().toIso8601String();
    
    final bool isOnline = await _connectivity.isOnline();
    if (isOnline && SupabaseService.currentUser != null) {
      updates['sync_status'] = 'synced';
    } else {
      updates['sync_status'] = 'pending';
    }

    // 1. Local
    if (updates.isNotEmpty) {
      await db.update('users', updates, where: 'uuid = ?', whereArgs: [currentUserId]);
    }

    // 2. Supabase
    final user = SupabaseService.currentUser;
    if (user != null) {
      final Map<String, dynamic> supabasePayload = {
        'uuid': user.id,
        if (pseudo != null) 'pseudo': pseudo,
        if (avatarId != null) 'avatar_id': avatarId,
        if (avatar != null) 'avatar_url': avatar,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isOnline) {
        try {
          await SupabaseService.client.auth.updateUser(
            UserAttributes(
              data: {
                if (pseudo != null) 'pseudo': pseudo,
                if (avatarId != null) 'avatar_id': avatarId,
                if (avatar != null) 'avatar_url': avatar,
                if (firstName != null) 'firstName': firstName,
                if (lastName != null) 'last_name': lastName,
              },
            ),
          );
          await SupabaseService.client.from('users').update(Map.from(supabasePayload)..remove('uuid')).eq('uuid', user.id);
        } catch (e) {
          await _addToSyncQueue('UPDATE_USER', supabasePayload);
        }
      } else {
        await _addToSyncQueue('UPDATE_USER', supabasePayload);
      }
    }
  }

  @override
  Future<void> addPoints(int points) async {
    final db = await _dbHelper.database;
    final profile = await getUserProfile();
    final currentPoints = profile['points'] as int? ?? 0;
    
    // Calcul des nouveaux points (pas moins de 0)
    int newPoints = currentPoints + points;
    if (newPoints < 0) newPoints = 0;
    
    final userId = profile['uuid'];
    if (userId == null) return;

    // Use LevelUtils for level calculation
    final currentLevelInfo = LevelUtils.getLevelInfo(currentPoints);
    final newLevelInfo = LevelUtils.getLevelInfo(newPoints);
    
    int newLevel = newLevelInfo.level;
    final int currentLevel = currentLevelInfo.level;

    // Bonus reward on level up
    if (newLevel > currentLevel) {
      newPoints += 50; // Cadeau de 50 points
      final finalLevelInfo = LevelUtils.getLevelInfo(newPoints);
      newLevel = finalLevelInfo.level;
    }

    if (newLevel > currentLevel) {
      final nowStr = DateTime.now().toIso8601String();
      final notifId = 'levelup-$newLevel-${DateTime.now().millisecondsSinceEpoch}';
      
      final notificationPayload = {
        'id': notifId,
        'user_id': userId,
        'type': 'leaderboard',
        'title': 'Niveau Supérieur ! 🎉',
        'message': 'Félicitations ! Tu as atteint le niveau $newLevel : ${LevelUtils.getLevelTitle(newLevel)}.',
        'is_read': 0,
        'created_at': nowStr,
      };

      await _dbHelper.insertNotification(notificationPayload);

      await db.insert('sync_queue', {
        'action': 'CREATE_NOTIFICATION',
        'payload': jsonEncode({
          'id': notifId,
          'user_id': userId,
          'type': 'leaderboard',
          'title': 'Niveau Supérieur ! 🎉',
          'message': 'Félicitations ! Tu as atteint le niveau $newLevel : ${LevelUtils.getLevelTitle(newLevel)}.',
          'is_read': false,
          'created_at': nowStr,
        }),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'created_at': nowStr,
      });
    }

    // --- Streak Logic ---
    int currentStreak = profile['streak'] as int? ?? 0;
    final String? lastActiveStr = profile['last_active']?.toString();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int newStreak = currentStreak;
    if (lastActiveStr == null || lastActiveStr.isEmpty) {
      newStreak = 1;
    } else {
      try {
        final lastActive = DateTime.parse(lastActiveStr);
        final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
        final difference = today.difference(lastActiveDay).inDays;
        
        if (difference == 1) {
          newStreak = currentStreak + 1;
        } else if (difference > 1) {
          newStreak = 1;
        }
        // Si difference == 0 (même jour), on ne change pas le streak
      } catch (_) {
        newStreak = 1;
      }
    }
    // ---------------------

    final Map<String, dynamic> updates = {
      'points': newPoints,
      'level': newLevel,
      'streak': newStreak,
      'last_active': now.toIso8601String(),
    };

    // 1. Local
    await db.update('users', updates, where: 'uuid = ?', whereArgs: [userId]);

    // 2. Supabase
    final bool isOnline = await _connectivity.isOnline();
    final Map<String, dynamic> syncPayload = {
      'uuid': userId,
      ...updates,
    };

    final leaderboardPayload = LeaderboardSyncHelper.entryPayload(
      userId: userId,
      points: newPoints,
      profile: profile,
    );

    await db.insert(
      'leaderboard_entries',
      {
        'user_id': userId,
        'points': newPoints,
        'scope': 'national',
        'pseudo': leaderboardPayload['pseudo'],
        'avatar': leaderboardPayload['avatar'],
        'last_updated': leaderboardPayload['last_updated'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (isOnline) {
      try {
        await SupabaseService.client
            .from('users')
            .update(updates)
            .eq('uuid', userId);

        await SupabaseService.client.from('leaderboard_entries').upsert(
          leaderboardPayload,
          onConflict: 'user_id,scope',
        );
      } catch (e) {
        await _addToSyncQueue('UPDATE_USER_POINTS', {
          ...syncPayload,
          'leaderboard': leaderboardPayload,
        });
      }
    } else {
      await _addToSyncQueue('UPDATE_USER_POINTS', {
        ...syncPayload,
        'leaderboard': leaderboardPayload,
      });
    }
  }

  @override
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    return await _dbHelper.getUserStats(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentActivity(String userId) async {
    return await _dbHelper.getRecentActivity(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    return await _dbHelper.getUserBadges(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String pseudo) async {
    if (pseudo.trim().isEmpty) return [];
    if (!await _connectivity.isOnline()) return [];
    
    try {
      final List<dynamic> response = await SupabaseService.client
          .from('users')
          .select('uuid, pseudo, avatar_id, avatar_url, last_active, points')
          .ilike('pseudo', '%$pseudo%')
          .limit(10);
      
      return response.map((u) => Map<String, dynamic>.from(u)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> addFriend(Map<String, dynamic> friendData) async {
    final prefs = await SharedPreferences.getInstance();
    final String currentUserId = prefs.getString('current_user_uuid') ?? 'guest';
    
    // Save locally
    await _dbHelper.addFriend(currentUserId, friendData);
    
    // Sync online if possible
    if (await _connectivity.isOnline() && currentUserId != 'guest') {
      try {
        await SupabaseService.client.from('friends').upsert({
          'user_id': currentUserId,
          'friend_uuid': friendData['uuid'],
        });
      } catch (_) {}
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final String currentUserId = prefs.getString('current_user_uuid') ?? 'guest';
    return await _dbHelper.getFriends(currentUserId);
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
