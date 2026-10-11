import '../brand.dart';
import '../payment.dart';
import 'api_services.dart';
import 'interfaces.dart';

export 'interfaces.dart';

/// Registre des services. Mode local par défaut ; Brand.apiBaseUrl non vide = mode API.
class Services {
  static AuthService auth = LocalAuthService();
  static MediaService media = LocalMediaService();
  static SyncService sync = LocalSyncService();
  static ApiClient? api;

  static bool get remote => Brand.apiBaseUrl.isNotEmpty;

  static Future<void> init() async {
    if (!remote) return;
    final c = api = ApiClient(Brand.apiBaseUrl);
    await c.loadToken();
    auth = ApiAuthService(c);
    media = ApiMediaService(c);
    sync = ApiSyncService(c);
    paymentService = ApiPaymentService(c);
  }
}
