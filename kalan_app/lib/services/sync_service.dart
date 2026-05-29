import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';
import '../data/models/deck_model.dart';
import '../data/models/flashcard_model.dart';
import '../data/models/user_model.dart';
import '../data/remote/supabase_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isProcessing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void init() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Récupère toutes les données du cloud vers le téléphone (Pull)
  Future<void> syncAllFromCloud(String userId) async {
    try {
      debugPrint('[SyncService] Démarrage du Pull depuis Supabase...');
      final db = await DatabaseHelper.instance.database;

      // 1. Récupérer le profil utilisateur
      final userProfile = await SupabaseService.client
          .from('users')
          .select()
          .eq('uuid', userId)
          .single();
      
      await db.insert(
        'users',
        UserModel.fromMap(userProfile).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Récupérer les Decks
      final decks = await SupabaseService.client
          .from('decks')
          .select()
          .eq('user_id', userId);
      
      for (final deck in decks) {
        await db.insert(
          'decks',
          DeckModel.fromSupabaseJson(Map<String, dynamic>.from(deck)).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. Récupérer les Flashcards associées
      final deckUuids = decks
          .map((d) => (d['uuid'] ?? d['id']) as String)
          .toList();
      if (deckUuids.isNotEmpty) {
        final cards = await SupabaseService.client
            .from('flashcards')
            .select()
            .inFilter('deck_id', deckUuids);

        for (final card in cards) {
          await db.insert(
            'flashcards',
            FlashcardModel.fromSupabaseJson(Map<String, dynamic>.from(card))
                .toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      debugPrint('[SyncService] Pull terminé avec succès !');
    } catch (e) {
      debugPrint('[SyncService] Erreur lors du Pull depuis Supabase : $e');
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> pendingItems = await db.query(
        'sync_queue',
        where: "status = 'pending'",
        orderBy: 'timestamp ASC',
      );

      for (var item in pendingItems) {
        final int id = item['id'];
        final String action = item['action'];
        final Map<String, dynamic> payload = jsonDecode(item['payload']);
        bool success = false;

        try {
          switch (action) {
            case 'CREATE_DECK':
              await SupabaseService.client.from('decks').insert(payload);
              // Update local deck as synced
              await db.update('decks', {'is_synced': 1}, 
                  where: 'uuid = ?', whereArgs: [payload['uuid']]);
              success = true;
              break;
            case 'UPDATE_DECK':
              final uuid = payload['uuid'];
              final Map<String, dynamic> updateData = Map.from(payload)..remove('uuid');
              await SupabaseService.client.from('decks').update(updateData).eq('uuid', uuid);
              // Update local deck as synced
              await db.update('decks', {'is_synced': 1}, 
                  where: 'uuid = ?', whereArgs: [uuid]);
              success = true;
              break;
            case 'DELETE_DECK':
              await SupabaseService.client.from('decks').delete().eq('uuid', payload['uuid']);
              success = true;
              break;
            case 'CREATE_FLASHCARD':
              await SupabaseService.client.from('flashcards').insert(payload);
              await db.update('flashcards', {'is_synced': 1}, 
                  where: 'uuid = ?', whereArgs: [payload['uuid']]);
              success = true;
              break;
            case 'DELETE_FLASHCARD':
              await SupabaseService.client.from('flashcards').delete().eq('uuid', payload['uuid']);
              success = true;
              break;
            case 'UPDATE_FLASHCARD':
              final uuid = payload['uuid'];
              final Map<String, dynamic> updateData = Map.from(payload)..remove('uuid');
              await SupabaseService.client.from('flashcards').update(updateData).eq('uuid', uuid);
              await db.update('flashcards', {'is_synced': 1}, 
                  where: 'uuid = ?', whereArgs: [uuid]);
              success = true;
              break;
            case 'CREATE_QUIZ_RESULT':
              await SupabaseService.client.from('quiz_results').insert(payload);
              await db.update('quiz_results', {'is_synced': 1}, 
                  where: 'user_id = ? AND created_at = ?', 
                  whereArgs: [payload['user_id'], payload['created_at']]);
              success = true;
              break;
            case 'UPDATE_LEADERBOARD':
              await SupabaseService.client.from('leaderboard_entries').upsert(
                payload,
                onConflict: 'user_id,scope',
              );
              success = true;
              break;
            case 'UPDATE_USER':
              final uuid = payload['uuid'];
              final Map<String, dynamic> updateData = Map.from(payload)..remove('uuid');
              await SupabaseService.client.from('users').update(updateData).eq('uuid', uuid);
              await db.update('users', {'sync_status': 'synced'}, 
                  where: 'uuid = ?', whereArgs: [uuid]);
              success = true;
              break;
            case 'UPDATE_USER_POINTS':
              final uuid = payload['uuid'];
              final int points = payload['points'];
              await SupabaseService.client.from('users').update({'points': points}).eq('uuid', uuid);
              final leaderboard = payload['leaderboard'] as Map<String, dynamic>?;
              if (leaderboard != null) {
                await SupabaseService.client.from('leaderboard_entries').upsert(
                  leaderboard,
                  onConflict: 'user_id,scope',
                );
              } else {
                await SupabaseService.client.from('leaderboard_entries').upsert({
                  'user_id': uuid,
                  'points': points,
                  'last_updated': DateTime.now().toIso8601String(),
                  'scope': 'national',
                }, onConflict: 'user_id,scope');
              }
              success = true;
              break;
            case 'UNLOCK_BADGE':
              await SupabaseService.client.from('user_badges').insert(payload);
              success = true;
              break;
            case 'CREATE_NOTIFICATION':
              await SupabaseService.client.from('notifications').insert(payload);
              success = true;
              break;
            case 'MARK_NOTIFICATION_READ':
              await SupabaseService.client.from('notifications').update({'is_read': true}).eq('id', payload['id']);
              success = true;
              break;
            case 'MARK_ALL_NOTIFICATIONS_READ':
              await SupabaseService.client.from('notifications').update({'is_read': true}).eq('user_id', payload['user_id']);
              success = true;
              break;
            default:
              debugPrint('Action inconnue dans sync_queue: $action');
              success = true; // Mark as success to skip it
          }
        } catch (e) {
          debugPrint('Erreur lors de la sync de l\'item $id: $e');
          success = false;
        }

        if (success) {
          await db.update(
            'sync_queue',
            {'status': 'completed'},
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          final int retryCount = (item['retry_count'] ?? 0) + 1;
          await db.update(
            'sync_queue',
            {
              'retry_count': retryCount,
              'status': retryCount >= 3 ? 'failed' : 'pending',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du process de la sync queue: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
