/// Consultation à distance d'un produit scanné qui n'est pas encore dans l'app (client qui scanne une étiquette
/// d'une boutique inconnue). Local : rien. API : GET /catalog/:channelId/:code et GET /channels/:id.
abstract class CatalogService {
  Future<Map<String, dynamic>?> lookup(String channelId, String code);
  Future<Map<String, dynamic>?> channel(String channelId);

  /// Suggestion de fiche (nom, description, usage) pour un code-barres déjà connu d'autres boutiques.
  Future<Map<String, dynamic>?> registry(String barcode);
}

class LocalCatalogService implements CatalogService {
  @override
  Future<Map<String, dynamic>?> lookup(String channelId, String code) async => null;
  @override
  Future<Map<String, dynamic>?> channel(String channelId) async => null;
  @override
  Future<Map<String, dynamic>?> registry(String barcode) async => null;
}
