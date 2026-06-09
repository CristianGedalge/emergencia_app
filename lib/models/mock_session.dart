/// Sesión local de demostración (no es JWT). Activa [ApiConfig.effectiveMockData] en la app.
class MockSession {
  const MockSession({
    required this.userId,
    required this.rol,
    required this.nombre,
    this.correo,
    /// Demo mecánico → coincide con `mecanico.id` en datos mock.
    this.mecanicoId,
    /// Demo admin de taller → coincide con `taller.id` asociado en el backend.
    this.tallerId,
  });

  final int userId;
  final String rol;
  final String nombre;
  final String? correo;
  final int? mecanicoId;
  final int? tallerId;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'rol': rol,
        'nombre': nombre,
        if (correo != null) 'correo': correo,
        if (mecanicoId != null) 'mecanicoId': mecanicoId,
        if (tallerId != null) 'tallerId': tallerId,
      };

  factory MockSession.fromJson(Map<String, dynamic> j) {
    return MockSession(
      userId: (j['userId'] as num).toInt(),
      rol: j['rol'] as String,
      nombre: j['nombre'] as String,
      correo: j['correo'] as String?,
      mecanicoId: j['mecanicoId'] != null ? (j['mecanicoId'] as num).toInt() : null,
      tallerId: j['tallerId'] != null ? (j['tallerId'] as num).toInt() : null,
    );
  }
}
