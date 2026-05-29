import 'package:kalan_app/domain/entities/deck.dart';

class DeepLinkService {
  static const String baseUrl = "https://kalan-app.web.app/deck";

  /// Génère un lien de partage pour un deck.
  /// Si le deck n'est pas encore synchronisé (public ou privé sur Supabase),
  /// on pourrait forcer sa synchronisation ici.
  static Future<String> generateDeckLink(Deck deck) async {
    // Dans l'idéal, on vérifie si le deck existe sur Supabase.
    // Pour l'instant, on utilise son UUID.
    return "$baseUrl/${deck.uuid}";
  }

  /// Logique pour traiter le lien entrant (à appeler dans main.dart ou un listener global)
  static void handleIncomingLink(Uri uri) {
    if (uri.pathSegments.contains('deck')) {
      final deckId = uri.pathSegments.last;
      // TODO: Naviguer vers l'écran de prévisualisation/import du deck
      // Navigator.push(...)
    }
  }
}
