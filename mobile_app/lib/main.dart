import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datos/servicios.dart';
import 'pantallas/arranque.dart';
import 'pantallas/chat.dart';
import 'pantallas/login.dart';
import 'tema/tema.dart';
import 'utilidades/navegacion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const AppAsistente());
}

class AppAsistente extends StatefulWidget {
  const AppAsistente({super.key});

  @override
  State<AppAsistente> createState() => _AppAsistenteState();
}

class _AppAsistenteState extends State<AppAsistente> {
  bool _habiaSesion = false;

  @override
  void initState() {
    super.initState();
    sesion.addListener(_alCambiarSesion);
  }

  @override
  void dispose() {
    sesion.removeListener(_alCambiarSesion);
    super.dispose();
  }

  /// Si la sesión se cierra (por el usuario o porque venció), vuelve al login.
  void _alCambiarSesion() {
    if (_habiaSesion && !sesion.activa) {
      controladorChat.limpiar();
      pestanaActual.value = Pestanas.inicio;
      navegador.currentState?.pushAndRemoveUntil(ruta(const PantallaLogin()), (_) => false);
    }
    _habiaSesion = sesion.activa;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistente Académico',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      navigatorKey: navegador,
      home: const PantallaArranque(),
    );
  }
}
