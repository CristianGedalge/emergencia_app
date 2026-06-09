import 'package:url_launcher/url_launcher.dart';

/// Quita espacios y separadores comunes; deja dígitos y el prefijo +.
String? telefonoNormalizado(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
  if (t.isEmpty) return null;
  return t;
}

/// Abre el marcador del sistema (`tel:`). En web puede depender del navegador.
Future<bool> abrirLlamadaTelefono(String telefono) async {
  final n = telefonoNormalizado(telefono);
  if (n == null) return false;
  final uri = Uri(scheme: 'tel', path: n);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
