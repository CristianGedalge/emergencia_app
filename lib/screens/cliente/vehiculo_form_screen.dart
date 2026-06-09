import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vehiculo.dart';
import '../../repositories/vehiculos_repository.dart';

class VehiculoFormScreen extends StatefulWidget {
  const VehiculoFormScreen({super.key, required this.clienteId, this.vehiculo});

  final int clienteId;
  final Vehiculo? vehiculo;

  bool get esEdicion => vehiculo != null;

  @override
  State<VehiculoFormScreen> createState() => _VehiculoFormScreenState();
}

class _VehiculoFormScreenState extends State<VehiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _placa = TextEditingController();
  final _color = TextEditingController();
  final _repo = vehiculosRepository();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    if (v != null) {
      _marca.text = v.marca;
      _modelo.text = v.modelo;
      _anio.text = '${v.anio}';
      _placa.text = v.placa;
      _color.text = v.color ?? '';
    }
  }

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _placa.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final anio = int.parse(_anio.text.trim());
      if (widget.esEdicion) {
        await _repo.actualizar(
          id: widget.vehiculo!.id,
          clienteId: widget.clienteId,
          marca: _marca.text.trim(),
          modelo: _modelo.text.trim(),
          anio: anio,
          placa: _placa.text.trim(),
          color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        );
      } else {
        await _repo.crear(
          clienteId: widget.clienteId,
          marca: _marca.text.trim(),
          modelo: _modelo.text.trim(),
          anio: anio,
          placa: _placa.text.trim(),
          color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar vehículo' : 'Nuevo vehículo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _marca,
              decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelo,
              decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _anio,
              decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1950 || n > 2100) return 'Año inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placa,
              decoration: const InputDecoration(labelText: 'Placa', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _color,
              decoration: const InputDecoration(
                labelText: 'Color (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
