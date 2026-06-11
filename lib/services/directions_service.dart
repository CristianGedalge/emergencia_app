import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteInfo {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;

  RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
  });
}

class DirectionsService {
  DirectionsService._();
  static final DirectionsService instance = DirectionsService._();

  static const String _googleApiKey = 'AIzaSyCfif_NZC8wwhsuqHPV4xFim_bSCDVFqW8';

  Future<RouteInfo?> getRoute(LatLng origin, LatLng destination) async {
    if (_googleApiKey.isEmpty) {
      debugPrint('Error: GOOGLE_MAP_KEY is missing');
      return null;
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_googleApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final String distance = leg['distance']['text'];
          final String duration = leg['duration']['text'];
          final String polyline = route['overview_polyline']['points'];

          List<LatLng> polylineCoordinates = [];
          List<PointLatLng> result = PolylinePoints.decodePolyline(polyline);

          if (result.isNotEmpty) {
            for (var point in result) {
              polylineCoordinates.add(LatLng(point.latitude, point.longitude));
            }
          }

          return RouteInfo(
            polylinePoints: polylineCoordinates,
            distance: distance,
            duration: duration,
          );
        } else {
          debugPrint('Directions API Status: ${data['status']}');
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetch route: $e');
    }
    return null;
  }
}
