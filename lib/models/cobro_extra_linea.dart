/// Línea adicional de cobro (trabajo en sitio / repuesto). Demo MOCK; en API sería tabla hija del cobro.
class CobroExtraLinea {
  const CobroExtraLinea({
    required this.id,
    required this.solicitudId,
    required this.concepto,
    required this.monto,
  });

  final int id;
  final int solicitudId;
  final String concepto;
  final double monto;
}
