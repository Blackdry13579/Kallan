/// Helpers pour convertir les lignes Supabase/Postgres vers SQLite local.
class SqliteMapUtils {
  SqliteMapUtils._();

  static int? localId(dynamic value) {
    if (value is int) return value;
    return null;
  }

  static String requiredString(dynamic value, {String field = 'field'}) {
    if (value is String && value.isNotEmpty) return value;
    throw ArgumentError('Missing $field');
  }

  static String uuidFromMap(Map<String, dynamic> map) {
    final uuid = map['uuid'];
    if (uuid is String && uuid.isNotEmpty) return uuid;
    final id = map['id'];
    if (id is String && id.isNotEmpty) return id;
    throw ArgumentError('Map missing uuid');
  }

  static int? asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int asInt(dynamic value, [int fallback = 0]) =>
      asIntOrNull(value) ?? fallback;

  static bool asBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
