import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/vehiculo.dart';
import '../../repositories/vehiculos_repository.dart';
import 'vehiculo_form_screen.dart';

class VehiculosListScreen extends StatefulWidget {
  const VehiculosListScreen({super.key, required this.clienteId});

  final int clienteId;

  @override
  State<VehiculosListScreen> createState() => _VehiculosListScreenState();
}

class _VehiculosListScreenState extends State<VehiculosListScreen> {
  final _repo = vehiculosRepository();
  Future<List<Vehiculo>>? _futureApi;

  @override
  void initState() {
    super.initState();
    if (!ApiConfig.effectiveMockData) {
      _futureApi = _repo.listarPorCliente(widget.clienteId);
    }
  }

  void _refreshApi() {
    if (!ApiConfig.effectiveMockData) {
      setState(() {
        _futureApi = _repo.listarPorCliente(widget.clienteId);
      });
    }
  }

  Widget _listBody(List<Vehiculo> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                ApiConfig.effectiveMockData
                    ? 'No tenés vehículos activos. Tocá + para agregar uno.'
                    : 'Sin datos: el backend aún no expone el listado de vehículos del cliente.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final v = list[i];
        final scheme = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.directions_car_filled, color: scheme.onPrimaryContainer),
            ),
            title: Text(
              '${v.marca} ${v.modelo}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${v.anio} · Placa ${v.placa}${v.color != null ? ' · ${v.color}' : ''}',
            ),
            isThreeLine: false,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VehiculoFormScreen(
                      clienteId: widget.clienteId,
                      vehiculo: v,
                    ),
                  ),
                );
                if (mounted) _refreshApi();
              },
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VehiculoFormScreen(
                    clienteId: widget.clienteId,
                    vehiculo: v,
                  ),
                ),
              );
              if (mounted) _refreshApi();
            },
            onLongPress: () => _confirmarBaja(context, v),
          ),
        );
      },
    );
  }

  Future<void> _confirmarBaja(BuildContext context, Vehiculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Desactivar vehículo'),
        content: Text('¿Dar de baja lógica el vehículo ${v.placa}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _repo.desactivar(v.id, widget.clienteId);
    if (mounted) _refreshApi();
  }

  Future<void> _abrirAlta() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehiculoFormScreen(clienteId: widget.clienteId),
      ),
    );
    if (mounted) _refreshApi();
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('Mis vehículos'),
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _abrirAlta),
      ],
    );

    if (ApiConfig.effectiveMockData) {
      return ListenableBuilder(
        listenable: MockDataStore.instance,
        builder: (context, _) {
          final list = MockDataStore.instance.vehiculosActivosDeCliente(widget.clienteId);
          return Scaffold(appBar: appBar, body: _listBody(list));
        },
      );
    }

    return Scaffold(
      appBar: appBar,
      body: FutureBuilder<List<Vehiculo>>(
        future: _futureApi,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          return _listBody(snap.data ?? []);
        },
      ),
    );
  }
}
