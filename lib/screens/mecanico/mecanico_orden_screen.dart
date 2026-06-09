import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io' as io;

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../mock/mock_data_store.dart';
import '../../models/pago.dart';
import '../../models/solicitud_auxilio.dart';
import '../../repositories/solicitudes_repository.dart';
import '../../utils/geo.dart';
import '../../utils/marker_utils.dart';
import '../../utils/tarifa_auxilio.dart';
import '../../utils/telefono_launch.dart';
import '../../widgets/cobro_desglose_mock_card.dart';

/// Detalle de orden + cobro por distancia (QR o efectivo).
class MecanicoOrdenScreen extends StatefulWidget {
  const MecanicoOrdenScreen({
    super.key,
    required this.mecanicoId,
    required this.solicitudId,
  });

  final int mecanicoId;
  final int solicitudId;

  @override
  State<MecanicoOrdenScreen> createState() => _MecanicoOrdenScreenState();
}

class _MecanicoOrdenScreenState extends State<MecanicoOrdenScreen> {
  final _montoCtrl = TextEditingController();
  bool _busy = false;
  /// Precarga sugerido una vez por solicitud (al abrir o cambiar de orden).
  int? _montoPrecargadoParaSolicitud;

  StreamSubscription<Position>? _posSub;
  int? _geoStartedForSolicitudId;
  Future<SolicitudAuxilioVm?>? _apiServicioFuture;

  LatLng? _mecanicoPos;
  List<LatLng> _routePoints = [];
  BitmapDescriptor _mecanicoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  StreamSubscription<Position>? _realGpsSub;
  GoogleMapController? _mapController;
  Timer? _broadcastTimer;

  void _refrescarOrdenApi() {
    if (mounted) {
      setState(() {
        _apiServicioFuture = _cargarOrdenEspecifica();
      });
    }
  }

  void _connectWs() {
    try {
      _channel?.sink.close();
      _wsSub?.cancel();
      
      final base = Uri.parse(ApiConfig.baseUrl);
      final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = Uri(
        scheme: wsScheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '${base.path}/ws/${widget.mecanicoId}',
      );
      
      final uriStr = wsUri.toString();
      debugPrint("WS Mecanico conectando a $uriStr");
      
      io.WebSocket.connect(uriStr).then((ws) {
        _channel = IOWebSocketChannel(ws);
        _wsSub = _channel!.stream.listen(
          (msg) => debugPrint("WS Mecanico msg: $msg"),
          onError: (err) => debugPrint("WS Mecanico err: $err"),
          onDone: () => debugPrint("WS Mecanico stream done"),
        );
      }).catchError((e) {
        debugPrint("WS Mecanico CONNECT ERROR: $e");
      });
    } catch (e) {
      debugPrint("WS Mecanico catch error: $e");
    }
  }

  void _enviarUbicacionWs(double lat, double lng, int clienteId, int? tallerId) {
    if (_channel == null) return;
    try {
      final msg = jsonEncode({
        "evento": "ACTUALIZAR_UBICACION",
        "datos": {
          "cliente_id": clienteId,
          "taller_id": tallerId,
          "lat": lat,
          "lng": lng,
        }
      });
      _channel!.sink.add(msg);
      debugPrint("WS: Ubicacion enviada: $lat, $lng");
    } catch (e) {
      debugPrint("Error enviando ubicacion WS: $e");
    }
  }

  Future<void> _cargarRutaInicial(SolicitudAuxilio s) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final aqui = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _mecanicoPos = aqui;
        });
      }
      _cargarRutaOSRM(aqui, LatLng(s.latitud, s.longitud));
    } catch (_) {}
  }

  Future<void> _cargarRutaOSRM(LatLng origen, LatLng destino) async {
    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origen.latitude},${origen.longitude}&destination=${destino.latitude},${destino.longitude}&key=AIzaSyCfif_NZC8wwhsuqHPV4xFim_bSCDVFqW8';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final encoded = routes[0]['overview_polyline']['points'] as String;
          final decoded = PolylinePoints.decodePolyline(encoded);
          final pts = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
          if (mounted) {
            setState(() {
              _routePoints = pts;
              if (_mapController != null && pts.isNotEmpty) {
                // Optional: bounds calculation to fit route could go here.
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _iniciarRastreoReal(SolicitudAuxilio s, int clienteId, int? tallerId) async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    _connectWs();
    await _realGpsSub?.cancel();
    
    try {
      final posIni = await Geolocator.getCurrentPosition();
      final aquiIni = LatLng(posIni.latitude, posIni.longitude);
      if (mounted) {
        setState(() {
          _mecanicoPos = aquiIni;
        });
      }
      _enviarUbicacionWs(posIni.latitude, posIni.longitude, clienteId, tallerId);
      _cargarRutaOSRM(aquiIni, LatLng(s.latitud, s.longitud));
    } catch (_) {}

    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_mecanicoPos != null) {
        _enviarUbicacionWs(_mecanicoPos!.latitude, _mecanicoPos!.longitude, clienteId, tallerId);
      }
    });

    _realGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      final aqui = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _mecanicoPos = aqui;
      });
      _enviarUbicacionWs(pos.latitude, pos.longitude, clienteId, tallerId);
      _cargarRutaOSRM(aqui, LatLng(s.latitud, s.longitud));

      // Auto-arrive check if within 120m (COMENTADO para que el usuario deba apretar el botón manualmente)
      /*
      final km = distanciaKm(aqui, LatLng(s.latitud, s.longitud));
      if (km != null && km <= 0.12 && s.estado == EstadoSolicitud.enCamino) {
        await _realGpsSub?.cancel();
        _realGpsSub = null;
        try {
          await ApiService.instance.llegarASitioMecanico(s.id);
          _refrescarOrdenApi();
        } catch (_) {}
      }
      */
    });
  }

  Future<void> _iniciarViajeApi(SolicitudAuxilio s, int clienteId, int? tallerId) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.iniciarViajeMecanico(s.id);
      _iniciarRastreoReal(s, clienteId, tallerId);
      _refrescarOrdenApi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar viaje: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _llegarSitioApi(SolicitudAuxilio s) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.llegarASitioMecanico(s.id);
      _broadcastTimer?.cancel();
      await _realGpsSub?.cancel();
      _realGpsSub = null;
      _channel?.sink.close();
      _wsSub?.cancel();
      _refrescarOrdenApi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al llegar al sitio: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const List<EstadoSolicitud> _pasosEstado = [
    EstadoSolicitud.asignado,
    EstadoSolicitud.enCamino,
    EstadoSolicitud.enSitio,
    EstadoSolicitud.finalizado,
  ];

  Future<SolicitudAuxilioVm?> _cargarOrdenEspecifica() async {
    try {
      final list = await ApiService.instance.fetchServiciosMecanico();
      for (final vm in list) {
        if (vm.solicitud.id == widget.solicitudId) return vm;
      }
    } catch (e) {
      debugPrint("Error cargando orden especifica: $e");
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cargarIconoMecanico();
    if (!ApiConfig.effectiveMockData) {
      _apiServicioFuture = _cargarOrdenEspecifica();
      _apiServicioFuture!.then((vm) {
        if (vm != null) {
          if (vm.solicitud.estado == EstadoSolicitud.enCamino) {
            _iniciarRastreoReal(vm.solicitud, vm.solicitud.clienteId, vm.tallerId);
          } else if (vm.solicitud.estado == EstadoSolicitud.asignado) {
            _cargarRutaInicial(vm.solicitud);
          }
        }
      });
    } else {
      final vm = MockDataStore.instance.solicitudVmParaMecanico(widget.solicitudId, widget.mecanicoId);
      if (vm != null) {
        _cargarRutaInicial(vm.solicitud);
      }
    }
  }

  Future<void> _cargarIconoMecanico() async {
    try {
      final icon = await getBytesFromIcon(Icons.directions_car, Colors.green, 60);
      if (mounted) {
        setState(() {
          _mecanicoIcon = icon;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(MecanicoOrdenScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.solicitudId != widget.solicitudId) {
      _montoPrecargadoParaSolicitud = null;
      if (!ApiConfig.effectiveMockData) {
        _apiServicioFuture = _cargarOrdenEspecifica();
      } else {
        final vm = MockDataStore.instance.solicitudVmParaMecanico(widget.solicitudId, widget.mecanicoId);
        if (vm != null) {
          _cargarRutaInicial(vm.solicitud);
        }
      }
    }
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _posSub?.cancel();
    _realGpsSub?.cancel();
    _channel?.sink.close();
    _wsSub?.cancel();
    _montoCtrl.dispose();
    super.dispose();
  }

  bool _puedeCobrar(EstadoSolicitud e) =>
      e == EstadoSolicitud.enSitio || e == EstadoSolicitud.finalizado;

  bool _muestraTrayecto(EstadoSolicitud e) =>
      e == EstadoSolicitud.asignado ||
      e == EstadoSolicitud.enCamino ||
      e == EstadoSolicitud.enSitio ||
      e == EstadoSolicitud.finalizado;

  Future<void> _llamarCliente(BuildContext context, String telefono) async {
    try {
      final ok = await abrirLlamadaTelefono(telefono);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada.')),
        );
      }
    }
  }



  Future<void> _registrarCobro(BuildContext context, int solicitudId) async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto válido')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await solicitudesRepository().registrarPago(
        solicitudId: solicitudId,
        monto: monto,
        metodo: MetodoPago.tarjeta, // Siempre tarjeta para que el cliente pague
      );
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio finalizado. Esperando el pago del cliente.'),
        ),
      );
      HapticFeedback.mediumImpact();
      
      if (!ApiConfig.effectiveMockData) {
        _refrescarOrdenApi();
      } else {
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _programarGeocerca(SolicitudAuxilio s) {
    if (kIsWeb || !ApiConfig.effectiveMockData) return;
    if (s.estado != EstadoSolicitud.enCamino) {
      _posSub?.cancel();
      _posSub = null;
      _geoStartedForSolicitudId = null;
      return;
    }
    if (_geoStartedForSolicitudId == s.id) return;
    _geoStartedForSolicitudId = s.id;
    Geolocator.requestPermission().then((perm) async {
      if (!mounted || perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      await _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          distanceFilter: 25,
          accuracy: LocationAccuracy.high,
        ),
      ).listen((pos) {
        final dest = LatLng(s.latitud, s.longitud);
        final aqui = LatLng(pos.latitude, pos.longitude);
        final km = distanciaKm(aqui, dest);
        if (km != null && km <= 0.12) {
          final ok = MockDataStore.instance.marcarEnSitioSiProximo(s.id, km);
          if (ok) {
            HapticFeedback.heavyImpact();
            _posSub?.cancel();
            _posSub = null;
            if (mounted) setState(() {});
          }
        }
      });
    });
  }

  Future<void> _marcarCobrado(BuildContext context, int solicitudId) async {
    setState(() => _busy = true);
    try {
      await solicitudesRepository().completarPago(solicitudId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago marcado como completado')),
        );
      }
      setState(() {});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildFotoCliente(BuildContext context, String url) {
    final scheme = Theme.of(context).colorScheme;
    final cleanUrl = url.trim();
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.network(
            cleanUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No se pudo cargar la imagen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Text(
      'Foto adjunta (Demo/Local): $cleanUrl',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }

  bool _pasoCompleto(EstadoSolicitud actual, EstadoSolicitud paso) {
    return _pasosEstado.indexOf(actual) >= _pasosEstado.indexOf(paso);
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.effectiveMockData) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'Orden #${widget.solicitudId}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _refrescarOrdenApi,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        body: FutureBuilder<SolicitudAuxilioVm?>(
          future: _apiServicioFuture,
          builder: (context, snapshot) {
            final vm = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || vm == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay orden asignada en este momento.'),
                ),
              );
            }

            final s = vm.solicitud;
            final nombreCliente = (vm.clienteNombre ?? '').trim().isNotEmpty
                ? vm.clienteNombre!.trim()
                : 'Cliente #${s.clienteId}';

            return Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(s.latitud, s.longitud),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    polylines: {
                      if (_routePoints.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routePoints,
                          color: Colors.blueAccent,
                          width: 5,
                        ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('cliente'),
                        position: LatLng(s.latitud, s.longitud),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                      if (_mecanicoPos != null)
                        Marker(
                          markerId: const MarkerId('mecanico'),
                          position: _mecanicoPos!,
                          icon: _mecanicoIcon,
                        ),
                    },
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.2,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombreCliente, style: Theme.of(context).textTheme.titleMedium),
                                  if (s.vehiculoPlaca != null && s.vehiculoPlaca!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vehículo: Placa ${s.vehiculoPlaca}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(
                                    'Descripción del problema:',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (s.descripcion ?? '').trim().isNotEmpty
                                        ? s.descripcion!.trim()
                                        : 'Sin descripción registrada.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (s.urlImg != null && s.urlImg!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    _buildFotoCliente(context, s.urlImg!),
                                  ],
                                  if (vm.clienteTelefono != null && vm.clienteTelefono!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _llamarCliente(context, vm.clienteTelefono!),
                                      icon: const Icon(Icons.call),
                                      label: const Text('Llamar al cliente'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (s.estado == EstadoSolicitud.enCamino) ...[
                            const SizedBox(height: 12),
                            Card(
                              elevation: 0,
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Compartiendo tu trayecto en tiempo real con el cliente...',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Estado del servicio', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 10),
                                  for (final paso in _pasosEstado)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _pasoCompleto(s.estado, paso)
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 18,
                                            color: _pasoCompleto(s.estado, paso)
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.outline,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(paso.valorApi),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  if (s.estado == EstadoSolicitud.asignado)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _busy ? null : () => _iniciarViajeApi(s, s.clienteId, vm.tallerId),
                                        icon: const Icon(Icons.directions_car),
                                        label: const Text('Iniciar viaje'),
                                      ),
                                    )
                                  else if (s.estado == EstadoSolicitud.enCamino)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _busy ? null : () => _llegarSitioApi(s),
                                        icon: const Icon(Icons.place),
                                        label: const Text('Ya llegué (Marcar en sitio)'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (s.estado == EstadoSolicitud.enSitio || s.estado == EstadoSolicitud.finalizado)
                            Card(
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Resumen de Cobro Extra', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    ...solicitudesRepository().lineasExtraCobro(s.id).map(
                                      (e) => Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text('• ${e.concepto}')),
                                          Text('${e.monto.toStringAsFixed(2)} Bs'),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                            onPressed: () async {
                                              await solicitudesRepository().eliminarLineaExtraCobro(
                                                  solicitudId: s.id, lineaId: e.id);
                                              setState(() {});
                                            },
                                          )
                                        ],
                                      ),
                                    ),
                                    if (s.estado == EstadoSolicitud.enSitio)
                                      TextButton.icon(
                                        onPressed: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (_) => _AgregarExtraCobroDialog(solicitudId: s.id),
                                          );
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Agregar reparación/repuesto'),
                                      ),
                                    const SizedBox(height: 16),
                                    Text('Monto Total Final (Bs)', style: Theme.of(context).textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _montoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Ej: 150.00',
                                        border: OutlineInputBorder(),
                                        prefixText: 'Bs ',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                    const SizedBox(height: 16),
                                    if (s.estado == EstadoSolicitud.enSitio)
                                      FilledButton.icon(
                                        onPressed: _busy ? null : () => _registrarCobro(context, s.id),
                                        icon: _busy 
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.check_circle_outline),
                                        label: const Text('Finalizar Servicio y Cobrar'),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'El cobro y registro de extras se habilitará cuando estés en el sitio.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      );
    }

    return ListenableBuilder(
      listenable: MockDataStore.instance,
      builder: (context, _) {
        final vm = MockDataStore.instance.solicitudVmParaMecanico(widget.solicitudId, widget.mecanicoId);
        if (vm == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Orden')),
            body: const Center(child: Text('No encontrada o no está asignada a tu usuario.')),
          );
        }

        final s = vm.solicitud;
        final v = MockDataStore.instance.vehiculoPorIdGlobal(s.vehiculoId);
        final vehTxt = v != null ? '${v.marca} ${v.modelo} · ${v.placa}' : 'Vehículo #${s.vehiculoId}';
        final km = MockDataStore.instance.kilometrosRutaAuxilio(s);
        final totalSugerido = MockDataStore.instance.montoTotalSugeridoCobro(s);
        final pago = MockDataStore.instance.pagoDeSolicitud(s.id);

        if (pago == null && _puedeCobrar(s.estado) && _montoPrecargadoParaSolicitud != s.id) {
          _montoPrecargadoParaSolicitud = s.id;
          final t = totalSugerido.toStringAsFixed(2);
          Future<void>.microtask(() {
            if (!mounted) return;
            _montoCtrl.text = t;
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _programarGeocerca(s);
        });

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Orden #${s.id}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(s.latitud, s.longitud),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  polylines: {
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('route_mock'),
                        points: _routePoints,
                        color: Colors.blueAccent,
                        width: 5,
                      ),
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('cliente_mock'),
                      position: LatLng(s.latitud, s.longitud),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                    if (_mecanicoPos != null)
                      Marker(
                        markerId: const MarkerId('mecanico_mock'),
                        position: _mecanicoPos!,
                        icon: _mecanicoIcon,
                      ),
                  },
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.4,
                minChildSize: 0.2,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 420),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Card(
                                    key: ValueKey(s.estado),
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.flag_circle_outlined, color: Theme.of(context).colorScheme.primary),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Estado: ${s.estado.valorApi}',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(vehTxt, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Cliente #${s.clienteId} · ${s.estado.valorApi}'),
                                ),
                                if (s.descripcion != null && s.descripcion!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Descripción:',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.descripcion!,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                                if (s.urlImg != null && s.urlImg!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildFotoCliente(context, s.urlImg!),
                                ],
                                if (vm.mecanicoId != null) ...[
                                  if (vm.clienteTelefono != null && vm.clienteTelefono!.trim().isNotEmpty)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.phone_in_talk_outlined),
                                      title: Text(vm.clienteTelefono!.trim()),
                                      subtitle: const Text('Teléfono del cliente'),
                                      trailing: FilledButton.tonalIcon(
                                        onPressed: () => _llamarCliente(context, vm.clienteTelefono!),
                                        icon: const Icon(Icons.call_rounded),
                                        label: const Text('Llamar'),
                                      ),
                                    )
                                  else
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.phone_disabled_outlined, color: Theme.of(context).colorScheme.outline),
                                      title: const Text('Sin teléfono del cliente'),
                                      subtitle: const Text(
                                        'Si el cliente registró número en su cuenta, el backend lo incluirá en la orden.',
                                      ),
                                    ),
                                ],
                                if (vm.tallerNombreAsignado != null)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.storefront_outlined),
                                    title: Text(vm.tallerNombreAsignado!),
                                    subtitle: const Text('Taller'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 32),
                        if (_muestraTrayecto(s.estado)) ...[
                          Text('Cobro', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Tarifa trayecto: ${TarifaAuxilio.precioPorKmBs} Bs/km · mínimo ${TarifaAuxilio.minimoBs} Bs · '
                            'distancia estimada ${km.toStringAsFixed(2)} km.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          CobroDesgloseMockCard(
                            solicitud: s,
                            subtitulo:
                                'Agregá lo que se reparó o repuestos; el cliente ve el mismo desglose al instante.',
                            onEliminarLinea: pago == null && _puedeCobrar(s.estado)
                                ? (lineaId) {
                                    solicitudesRepository()
                                        .eliminarLineaExtraCobro(solicitudId: s.id, lineaId: lineaId)
                                        .then((ok) {
                                      if (!mounted) return;
                                      if (ok) {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _montoCtrl.text = MockDataStore.instance
                                              .montoTotalSugeridoCobro(s)
                                              .toStringAsFixed(2);
                                        });
                                      }
                                    });
                                  }
                                : null,
                          ),
                          if (pago == null && _puedeCobrar(s.estado)) ...[
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final r = await showDialog<({String concepto, double monto})>(
                                        context: context,
                                        builder: (ctx) => _AgregarExtraCobroDialog(solicitudId: s.id),
                                      );
                                      if (r == null || !mounted) return;
                                      try {
                                        await solicitudesRepository().agregarLineaExtraCobro(
                                          solicitudId: s.id,
                                          concepto: r.concepto,
                                          monto: r.monto,
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                        }
                                        return;
                                      }
                                      if (!mounted) return;
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _montoCtrl.text =
                                            MockDataStore.instance.montoTotalSugeridoCobro(s).toStringAsFixed(2);
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Línea de cobro agregada')),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Agregar cobro por reparación o repuesto'),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Cuando estés en sitio o el servicio finalice, podrás registrar el cobro según la distancia recorrida.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        if (ApiConfig.effectiveMockData) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        solicitudesRepository().demoAvanzarEstado(s.id);
                                        setState(() {});
                                      },
                                icon: const Icon(Icons.skip_next_outlined),
                                label: const Text('Avanzar estado (demo)'),
                              ),
                              if (kIsWeb && s.estado == EstadoSolicitud.enCamino)
                                FilledButton.tonalIcon(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          MockDataStore.instance.marcarEnSitioDemo(s.id);
                                          setState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Marcado EN_SITIO (demo sin GPS)')),
                                          );
                                        },
                                  icon: const Icon(Icons.place_outlined),
                                  label: const Text('Llegué al lugar (web)'),
                                ),
                            ],
                          ),
                          if (!kIsWeb && s.estado == EstadoSolicitud.enCamino)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Con GPS: al acercarte al auxilio (~120 m) el estado pasará a EN_SITIO solo.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                        if (pago != null) ...[
                          Text('Pago registrado', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${pago.monto} Bs · ${pago.metodoPago.valorApi}'),
                            subtitle: Text('Estado: ${pago.estadoPago.valorApi}'),
                          ),
                          if (pago.estadoPago == EstadoPago.pendiente)
                            FilledButton(
                              onPressed: _busy ? null : () => _marcarCobrado(context, s.id),
                              child: const Text('Confirmar cobro recibido (completar)'),
                            ),
                        ] else if (s.estado == EstadoSolicitud.enSitio) ...[
                          Text('Finalizar Servicio y Cobrar', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _montoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Monto a cobrar (Bs.)',
                              helperText:
                                  'Total sugerido (trayecto + extras): ${totalSugerido.toStringAsFixed(2)} Bs. Podés ajustarlo.',
                              border: const OutlineInputBorder(),
                              prefixText: 'Bs ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),

                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : () => _registrarCobro(context, s.id),
                            child: _busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline),
                                      SizedBox(width: 8),
                                      Text('Finalizar Servicio y Cobrar'),
                                    ],
                                  ),
                          ),
                        ] else
                          Text(
                            'El cobro se habilita cuando el estado sea EN_SITIO o FINALIZADO.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgregarExtraCobroDialog extends StatefulWidget {
  const _AgregarExtraCobroDialog({required this.solicitudId});

  final int solicitudId;

  @override
  State<_AgregarExtraCobroDialog> createState() => _AgregarExtraCobroDialogState();
}

class _AgregarExtraCobroDialogState extends State<_AgregarExtraCobroDialog> {
  final _concepto = TextEditingController();
  final _monto = TextEditingController();

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cobro extra · orden #${widget.solicitudId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _concepto,
              decoration: const InputDecoration(
                labelText: 'Qué se cobra (reparación, repuesto…)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _monto,
              decoration: const InputDecoration(
                labelText: 'Monto (Bs.)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final m = double.tryParse(_monto.text.replaceAll(',', '.'));
            if (_concepto.text.trim().isEmpty || m == null || m <= 0) return;
            Navigator.pop(context, (concepto: _concepto.text.trim(), monto: m));
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

/// Hoja inferior: QR grande + “acreditación” automática simulada (como webhook del banco).
class _QrPagoConfirmacionSheet extends StatefulWidget {
  const _QrPagoConfirmacionSheet({
    required this.payloadQr,
    required this.onSimularAcreditacion,
  });

  final String payloadQr;
  final Future<void> Function() onSimularAcreditacion;

  @override
  State<_QrPagoConfirmacionSheet> createState() => _QrPagoConfirmacionSheetState();
}

class _QrPagoConfirmacionSheetState extends State<_QrPagoConfirmacionSheet> {
  Timer? _timer;
  bool _acreditado = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2900), () async {
      if (!mounted || _acreditado) return;
      await widget.onSimularAcreditacion();
      if (!mounted) return;
      setState(() => _acreditado = true);
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 20,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cobro con QR',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mostrá este código al cliente. En producción el banco avisaría al servidor; '
                'en esta demo la acreditación se confirma sola al cabo de unos segundos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: QrImageView(
                    data: widget.payloadQr,
                    size: 228,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                widget.payloadQr,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!_acreditado) ...[
                const LinearProgressIndicator(minHeight: 4),
                const SizedBox(height: 12),
                Text(
                  'Esperando confirmación del pago…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else ...[
                Icon(Icons.check_circle_rounded, color: scheme.primary, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Acreditado (demo)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Cerrar sin esperar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
