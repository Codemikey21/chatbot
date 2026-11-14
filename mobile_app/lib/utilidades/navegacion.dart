import 'package:flutter/material.dart';

import '../datos/servicios.dart';
import '../pantallas/chat.dart';

/// Transición suave (desvanecer y deslizar) entre pantallas.
Route<T> ruta<T>(Widget pantalla) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => pantalla,
      transitionsBuilder: (_, animacion, _, hijo) {
        final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curva),
            child: hijo,
          ),
        );
      },
    );

/// Pestañas de la pantalla principal.
class Pestanas {
  static const inicio = 0;
  static const chat = 1;
  static const cursos = 2;
  static const progreso = 3;
  static const mas = 4;
}

final pestanaActual = ValueNotifier<int>(Pestanas.inicio);

/// Vuelve a la pantalla principal, abre el chat y envía la pregunta.
void preguntarAlAsistente(BuildContext context, String pregunta) {
  Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  pestanaActual.value = Pestanas.chat;
  controladorChat.enviar(pregunta);
}

/// Cierra sesión y deja la app en el inicio de sesión.
Future<void> cerrarSesion() async {
  controladorChat.limpiar();
  pestanaActual.value = Pestanas.inicio;
  await sesion.cerrar();
}
