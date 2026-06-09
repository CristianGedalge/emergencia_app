import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../utils/geo.dart';
import '../../utils/marker_utils.dart';

/// Vista del mecánico: incidente del cliente + posición simulada en ruta (misma fórmula que ve el cliente).
class MecanicoMapaRutaScreen extends StatefulWidget {
  const MecanicoMapaRutaScreen({super.key, required this.mecanicoId});

  final int mecanicoId;

  @override
  State<MecanicoMapaRutaScreen> createState() => _MecanicoMapaRutaScreenState();
}

class _MecanicoMapaRutaScreenState extends State<MecanicoMapaRutaScreen> {
  LatLng? _miGps;
  Timer? _tick;
  BitmapDescriptor _mecanicoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  @override
  void initState() {
    super.initState();
    _cargarIconoMecanico();
    MockDataStore.instance.addListener(_onStore);
    _tick = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() {});
    });
    _cargarGps();
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

  Future<void> _cargarGps() async {
    try {
      final permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _miGps = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MockDataStore.instance.removeListener(_onStore);
    _tick?.cancel();
    super.dispose();
  }

  LatLng _centro(SolicitudAuxilio s, LatLng simMecanico) {
    final incidente = LatLng(s.latitud, s.longitud);
    if (_miGps != null) {
      return LatLng(
        (_miGps!.latitude + simMecanico.latitude + incidente.latitude) / 3,
        (_miGps!.longitude + simMecanico.longitude + incidente.longitude) / 3,
      );
    }
    return LatLng(
      (simMecanico.latitude + incidente.latitude) / 2,
      (simMecanico.longitude + incidente.longitude) / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.effectiveMockData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruta al cliente')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Cuando el API exponga la solicitud activa y posiciones en tiempo real, acá verás el mapa hacia el cliente. '
            'El taller asigna el caso desde la web; vos recibís la orden en Órdenes y navegás con esta pantalla.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: MockDataStore.instance,
      builder: (context, _) {
        final vm = MockDataStore.instance.solicitudSeguimientoPrioritariaMecanico(widget.mecanicoId);
        if (vm == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ruta al cliente')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tenés un caso asignado en asignado, en camino o en sitio.\n\n'
                  'Revisá la pestaña Órdenes: cuando el admin del taller te asigne desde la web, el mapa se activará acá.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        final s = vm.solicitud;
        final simMecanico = MockDataStore.instance.posicionMecanicoSimulada(s);
        final incidente = LatLng(s.latitud, s.longitud);
        final kmRest = distanciaKm(simMecanico, incidente);

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('incidente'),
            position: incidente,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Cliente / incidente'),
          ),
          Marker(
            markerId: const MarkerId('mecanico_sim'),
            position: simMecanico,
            icon: _mecanicoIcon,
            infoWindow: const InfoWindow(title: 'Tu posición en ruta'),
          ),
        };
        if (_miGps != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('mi_gps'),
              position: _miGps!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'GPS real'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Ruta al cliente')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitud #${s.id} · ${s.estado.valorApi}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      kmRest != null
                          ? '~ ${kmRest.toStringAsFixed(2)} km al punto del auxilio (demo)'
                          : 'Calculando…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _centro(s, simMecanico),
                    zoom: 13,
                  ),
                  markers: markers,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Demostración: el ícono verde usa la misma posición que ve el cliente hasta que el servidor reciba tu GPS real.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
