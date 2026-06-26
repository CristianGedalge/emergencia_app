/// URL del FastAPI **sin** barra final.
///
/// - **Por defecto**: `https://emergeciavehicularapi-production.up.railway.app`
/// - **Chrome / web local**: podés override con `--dart-define=API_BASE=http://localhost:8010`.
/// - **Emulador Android local**: podés override con `--dart-define=API_BASE=http://10.0.2.2:8010`.
/// - **Dispositivo físico / emulador con API en el PC**: IP **LAN** de tu PC,
///   p. ej. `http://192.168.1.10:8010` (`localhost` en el teléfono es el propio teléfono).
///   El backend debe escuchar en `0.0.0.0`, no solo `127.0.0.1`.
/// - Override: `flutter run --dart-define=API_BASE=http://TU_IP:PUERTO`
///
/// ## Datos de demostración (sin backend)
/// Por defecto [useMockData] es **false** para usar backend real.
///
/// `MOCK=false`: **talleres** y **vehículos** llaman al FastAPI (`API_BASE`);
/// solicitudes/pagos siguen sin endpoints en el backend → listas vacías o avisos.
///
/// `flutter run --dart-define=MOCK=false --dart-define=API_BASE=http://localhost:8010`
class ApiConfig {
  /// Vacío si no pasaste `API_BASE` por `--dart-define`.
  static const String _apiBaseEnv = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (_apiBaseEnv.isNotEmpty) return _apiBaseEnv;
    //return 'http://10.5.206.227:8000/api'; // IP de tu PC para el dispositivo físico
    //return 'https://emergeciavehicularapi-production.up.railway.app';
    return 'http://emergencia-alb-1298699143.us-east-1.elb.amazonaws.com/api';
  }

  /// `true` = repositorios en memoria + sesión demo opcional en login.
  static const bool useMockData = bool.fromEnvironment(
    'MOCK',
    defaultValue: false,
  );

  /// Mock solo por compilación (sin activar demo por sesión guardada).
  static bool get effectiveMockData => useMockData;
}
