/// Tarifa demo por trayecto (Bs.). En producción vendría del taller / backend.
class TarifaAuxilio {
  TarifaAuxilio._();

  /// Precio por kilómetro recorrido (ida hacia el incidente).
  static const double precioPorKmBs = 12.0;

  /// Mínimo cobrable cuando hay servicio con distancia > 0.
  static const double minimoBs = 35.0;

  /// `km` = distancia estimada de la ruta (taller → punto del auxilio).
  static double montoSugerido(double km) {
    if (km <= 0) return minimoBs;
    final raw = km * precioPorKmBs;
    final v = raw < minimoBs ? minimoBs : raw;
    return double.parse(v.toStringAsFixed(2));
  }
}
