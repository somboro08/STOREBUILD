import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../payment.dart';
import 'catalog_service.dart';
import 'interfaces.dart';

/// Squelette de client API : voir docs/API_CONTRACT.md pour les routes attendues. À tester avec ton backend.
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final String base;
  String? token;
  ApiClient(this.base);

  Map<String, String> get headers => {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  Future<Map<String, dynamic>> send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$base$path'))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 300) {
      throw ApiException(res.statusCode, data is Map && data['message'] != null ? '${data['message']}' : 'Erreur ${res.statusCode}');
    }
    return data is Map<String, dynamic> ? data : {'data': data};
  }

  Future<void> loadToken() async {
    token = (await SharedPreferences.getInstance()).getString('api_token');
  }

  Future<void> saveToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t == null ? await p.remove('api_token') : await p.setString('api_token', t);
  }
}

class ApiAuthService implements AuthService {
  final ApiClient api;
  ApiAuthService(this.api);

  @override
  Future<void> requestCode(String phone) => api.send('POST', '/auth/request-code', {'phone': phone});

  @override
  Future<AppUser> verifyCode(String phone, String code, String name) async {
    final r = await api.send('POST', '/auth/verify', {'phone': phone, 'code': code, 'name': name});
    await api.saveToken(r['token'] as String?);
    final u = Map<String, dynamic>.from(r['user'] ?? {});
    return AppUser(u['name'] ?? name, u['phone'] ?? phone);
  }

  @override
  Future<AppUser> changePhone(String phone, String code) async {
    final r = await api.send('POST', '/me/phone', {'phone': phone, 'code': code});
    final u = Map<String, dynamic>.from(r['user'] ?? {});
    return AppUser(u['name'] ?? '', u['phone'] ?? phone);
  }

  @override
  Future<void> deleteAccount() async {
    await api.send('DELETE', '/me');
    await api.saveToken(null);
  }
}

class ApiMediaService implements MediaService {
  final ApiClient api;
  ApiMediaService(this.api);

  @override
  Future<String?> upload({Uint8List? bytes, String? path, required String kind}) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${api.base}/media'))
        ..headers.addAll({if (api.token != null) 'Authorization': 'Bearer ${api.token}'})
        ..fields['kind'] = kind;
      if (bytes != null) {
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'));
      } else if (path != null) {
        req.files.add(await http.MultipartFile.fromPath('file', path));
      } else {
        return null;
      }
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode >= 300) return null;
      return (jsonDecode(res.body) as Map)['url'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class ApiSyncService implements SyncService {
  final ApiClient api;
  ApiSyncService(this.api);

  @override
  Future<bool> push(SyncOp op) async {
    try {
      await api.send('POST', '/sync/ops', op.toJson());
      return true;
    } on ApiException catch (e) {
      // 4xx (sauf 401/408/429) : opération invalide, on l'abandonne pour ne pas bloquer la file.
      return e.status >= 400 && e.status < 500 && e.status != 401 && e.status != 408 && e.status != 429;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> pull() async {
    try {
      return await api.send('GET', '/sync/snapshot');
    } catch (_) {
      return null;
    }
  }
}

class ApiPaymentService implements PaymentService {
  final ApiClient api;
  ApiPaymentService(this.api);

  Future<PaymentResult> _call(String path, PaymentRequest r) async {
    try {
      final res = await api.send('POST', path, {'provider': r.provider, 'phone': r.phone, 'amount': r.amount, 'reference': r.reference});
      return PaymentResult(res['ok'] == true, res['message'] as String?);
    } on ApiException catch (e) {
      return PaymentResult(false, e.message);
    } catch (_) {
      return const PaymentResult(false, 'Réseau indisponible');
    }
  }

  @override
  Future<PaymentResult> pay(PaymentRequest r) => _call('/payments', r);
  @override
  Future<PaymentResult> refund(PaymentRequest r) => _call('/payments/refund', r);
}

class ApiCatalogService implements CatalogService {
  final ApiClient api;
  ApiCatalogService(this.api);

  @override
  Future<Map<String, dynamic>?> lookup(String channelId, String code) async {
    try {
      return await api.send('GET', '/catalog/${Uri.encodeComponent(channelId)}/${Uri.encodeComponent(code)}');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> channel(String channelId) async {
    try {
      return await api.send('GET', '/channels/${Uri.encodeComponent(channelId)}');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> registry(String barcode) async {
    try {
      final r = await api.send('GET', '/registry/${Uri.encodeComponent(barcode)}');
      return r['suggestion'] == null ? null : Map<String, dynamic>.from(r['suggestion']);
    } catch (_) {
      return null;
    }
  }
}
