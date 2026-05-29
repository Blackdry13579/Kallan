import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/repositories/notification_repository.dart';
import '../local/database_helper.dart';
import '../remote/supabase_service.dart';
import '../../services/connectivity_service.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivity;
  final Uuid _uuid = const Uuid();

  NotificationRepositoryImpl(this._dbHelper, this._connectivity);

  @override
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final db = await _dbHelper.database;

    // 1. Fetch remote notifications if online
    if (await _connectivity.isOnline() && userId != 'guest') {
      try {
        final remoteData = await SupabaseService.client
            .from('notifications')
            .select()
            .eq('user_id', userId);

        for (var item in remoteData as List) {
          var message = item['message']?.toString() ?? '';
          if (item['type'] == 'battle' && item['data'] != null) {
            final data = item['data'];
            final battleId = data is Map
                ? data['battle_id']?.toString()
                : null;
            if (battleId != null && !message.contains('battle:')) {
              message = '$message · battle:$battleId';
            }
          }
          await db.insert(
            'notifications',
            {
              'id': item['id'],
              'user_id': item['user_id'],
              'type': item['type'],
              'title': item['title'],
              'message': message,
              'is_read': item['is_read'] == true ? 1 : 0,
              'created_at': item['created_at'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
            } catch (e) {
        // En cas d'erreur de Supabase, on ignore silencieusement et utilise le cache local
      }
    }

    // 2. Fetch locally
    return await _dbHelper.getNotifications(userId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    // 1. Local
    await _dbHelper.markNotificationsAsRead(userId);

    // 2. Supabase / Sync Queue
    if (await _connectivity.isOnline() && userId != 'guest') {
      try {
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
      } catch (e) {
        await _addToSyncQueue('MARK_ALL_NOTIFICATIONS_READ', {'user_id': userId});
      }
    } else if (userId != 'guest') {
      await _addToSyncQueue('MARK_ALL_NOTIFICATIONS_READ', {'user_id': userId});
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    // 1. Local
    await _dbHelper.markNotificationAsRead(id);

    // 2. Supabase / Sync Queue
    final db = await _dbHelper.database;
    final results = await db.query('notifications', columns: ['user_id'], where: 'id = ?', whereArgs: [id]);
    final String userId = results.isNotEmpty ? (results.first['user_id'] as String? ?? 'guest') : 'guest';

    if (await _connectivity.isOnline() && userId != 'guest') {
      try {
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id);
      } catch (e) {
        await _addToSyncQueue('MARK_NOTIFICATION_READ', {'id': id});
      }
    } else if (userId != 'guest') {
      await _addToSyncQueue('MARK_NOTIFICATION_READ', {'id': id});
    }
  }

  @override
  Future<void> addNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
  }) async {
    final String notifId = _uuid.v4();
    final nowStr = DateTime.now().toIso8601String();

    final notification = {
      'id': notifId,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'is_read': 0,
      'created_at': nowStr,
    };

    // 1. Local
    await _dbHelper.insertNotification(notification);

    // 2. Supabase / Sync Queue
    if (userId != 'guest') {
      final supabasePayload = {
        'id': notifId,
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'is_read': false,
        'created_at': nowStr,
      };

      if (await _connectivity.isOnline()) {
        try {
          await SupabaseService.client.from('notifications').insert(supabasePayload);
        } catch (e) {
          await _addToSyncQueue('CREATE_NOTIFICATION', supabasePayload);
        }
      } else {
        await _addToSyncQueue('CREATE_NOTIFICATION', supabasePayload);
      }
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
