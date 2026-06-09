import 'package:flutter/material.dart';

import 'package:jwt_decoder/jwt_decoder.dart';



import '../models/mock_session.dart';

import '../services/session_service.dart';

import 'cliente/cliente_shell.dart';

import 'mecanico/mecanico_shell.dart';

import 'stub_role_screen.dart';



class RoleShell extends StatelessWidget {

  const RoleShell({

    super.key,

    required this.token,

    required this.mockSession,

    required this.onLogout,

  });



  final String? token;

  final MockSession? mockSession;

  final VoidCallback onLogout;



  String get _rol {

    if (mockSession != null) {

      return mockSession!.rol.toLowerCase();

    }

    final claims = JwtDecoder.decode(token!);

    return (claims['rol'] as String?)?.toLowerCase() ?? 'cliente';

  }



  int _clienteId() {

    if (mockSession != null) return mockSession!.userId;

    final id = SessionService.instance.clienteIdFromToken(token!);

    return id ?? 0;

  }



  int? _mecanicoId() {

    if (mockSession?.mecanicoId != null) return mockSession!.mecanicoId;

    if (token == null) return null;

    final c = JwtDecoder.decode(token!);

    final m = c['mecanicoId'];

    if (m is int) return m;

    if (m is num) return m.toInt();

    if (m != null) return int.tryParse(m.toString());

    return null;

  }

  String? _nombreSesion() {
    if (mockSession?.nombre != null && mockSession!.nombre.trim().isNotEmpty) {
      return mockSession!.nombre.trim();
    }
    if (token == null) return null;
    final c = JwtDecoder.decode(token!);
    final nombre = c['nombre'] as String?;
    if (nombre != null && nombre.trim().isNotEmpty) return nombre.trim();
    final correo = c['correo'] as String?;
    if (correo != null && correo.contains('@')) {
      final local = correo.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return null;
  }



  @override

  Widget build(BuildContext context) {

    switch (_rol) {

      case 'cliente':

        final id = _clienteId();

        if (id == 0) {

          return StubRoleScreen(

            title: 'Cliente',

            subtitle: 'No se pudo obtener el id de usuario del token.',

            onLogout: onLogout,

          );

        }

        return ClienteShell(

          clienteId: id,

          onLogout: onLogout,

          isMockSession: mockSession != null,

          nombreCliente: _nombreSesion(),

        );

      case 'admin':

        return StubRoleScreen(

          title: 'Administrador de taller',

          subtitle:

              'Esta app móvil es solo para cliente y mecánico en ruta. '

              'Los pedidos llegan a varios talleres; el que acepta desde la web asigna al mecánico. '

              'Cerrá sesión y usá la aplicación web del taller para notificaciones, aceptación y asignación.',

          onLogout: onLogout,

        );

      case 'mecanico':

        final mid = _mecanicoId();

        if (mid == null) {

          return StubRoleScreen(

            title: 'Mecánico',

            subtitle:

                'Tu sesión no trae mecanicoId. En el login usá “Mecánico mock” o iniciá sesión con un usuario mecánico del API.',

            onLogout: onLogout,

          );

        }

        return MecanicoShell(

          mecanicoId: mid,

          onLogout: onLogout,

          isMockSession: mockSession != null,

          nombre: _nombreSesion(),

        );

      case 'superadmin':

        return StubRoleScreen(

          title: 'Superadministración',

          subtitle:

              'La administración de plataforma (SaaS, varios talleres, etc.) no está en la app móvil. '

              'Usá la consola web.',

          onLogout: onLogout,

        );

      default:

        return StubRoleScreen(

          title: 'Rol no soportado en móvil',

          subtitle: 'Rol recibido: $_rol',

          onLogout: onLogout,

        );

    }

  }

}

