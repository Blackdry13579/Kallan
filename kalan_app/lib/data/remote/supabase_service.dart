import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
    );
  }

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentUser != null;

  // Helpers CRUD Supabase
  static PostgrestFilterBuilder<PostgrestList> from(String table) {
    return client.from(table).select();
  }

  static Future<dynamic> insert(String table, Map<String, dynamic> data) async {
    return await client.from(table).insert(data).select().single();
  }

  static Future<dynamic> update(
    String table,
    Map<String, dynamic> data, {
    required String column,
    required dynamic value,
  }) async {
    return await client.from(table).update(data).eq(column, value).select().single();
  }

  static Future<dynamic> delete(
    String table, {
    required String column,
    required dynamic value,
  }) async {
    return await client.from(table).delete().eq(column, value).select().single();
  }
}
