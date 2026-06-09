import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

double? distanciaKm(LatLng? desde, LatLng? hasta) {
  if (desde == null || hasta == null) return null;
  const r = 6371.0;
  final dLat = _rad(hasta.latitude - desde.latitude);
  final dLon = _rad(hasta.longitude - desde.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(desde.latitude)) *
          math.cos(_rad(hasta.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _rad(double d) => d * math.pi / 180.0;
