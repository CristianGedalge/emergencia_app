import 'package:url_launcher/url_launcher.dart';

/// Enlaces a Google Maps (navegador o app) sin SDK de Google.
abstract final class GoogleMapsLinks {
  /// Ruta en auto hacia un punto (origen: posición actual del usuario en Maps).
  static Uri drivingToDestination(double lat, double lng) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );

  /// Centrar / marcar un punto (p. ej. “dónde está el mecánico ahora”).
  static Uri searchLocation(double lat, double lng) => Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );

  /// Ruta entre dos coordenadas fijas.
  static Uri drivingFromTo(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) =>
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving',
      );

  static Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
