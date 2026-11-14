import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tema/colores.dart';

/// Tres puntos que rebotan mientras el asistente prepara la respuesta.
class PuntosEscribiendo extends StatelessWidget {
  const PuntosEscribiendo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(color: Colores.moradoClaro, shape: BoxShape.circle),
        )
            .animate(onPlay: (control) => control.repeat())
            .moveY(begin: 0, end: -6, duration: 300.ms, delay: (i * 150).ms, curve: Curves.easeOut)
            .then()
            .moveY(begin: -6, end: 0, duration: 300.ms, curve: Curves.easeIn);
      }),
    );
  }
}
