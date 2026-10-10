import 'package:url_launcher/url_launcher.dart';
import '../brand.dart';

/// Chiffres seuls avec indicatif pays : "0197669861" -> "2290197669861".
String normalizePhone(String raw) {
  final plus = raw.trim().startsWith('+');
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return '';
  if (plus) return d;
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith(Brand.countryCode) && d.length > 10) return d;
  return '${Brand.countryCode}$d';
}

Future<bool> callPhone(String phone) async {
  final n = normalizePhone(phone);
  if (n.isEmpty) return false;
  try {
    return await launchUrl(Uri.parse('tel:+$n'));
  } catch (_) {
    return false;
  }
}

Future<bool> openWhatsApp(String phone, [String message = '']) async {
  final n = normalizePhone(phone);
  if (n.isEmpty) return false;
  try {
    final q = message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}';
    return await launchUrl(Uri.parse('https://wa.me/$n$q'), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
