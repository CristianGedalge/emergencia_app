import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Convierte un IconData (ej. Icons.local_shipping) a BitmapDescriptor
/// para ser usado como marcador en Google Maps.
Future<BitmapDescriptor> getBytesFromIcon(IconData iconData, Color color, int size) async {
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  final textPainter = TextPainter(textDirection: TextDirection.ltr);

  // Dibujar el icono
  final iconStr = String.fromCharCode(iconData.codePoint);
  textPainter.text = TextSpan(
    text: iconStr,
    style: TextStyle(
      letterSpacing: 0.0,
      fontSize: size.toDouble(),
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      color: color,
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, const Offset(0.0, 0.0));

  final picture = pictureRecorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  // En nuevas versiones de google_maps_flutter se usa BitmapDescriptor.bytes
  // Si da error, usar BitmapDescriptor.fromBytes
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}
