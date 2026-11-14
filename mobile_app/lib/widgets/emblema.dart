import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Emblema propio de la app: birrete sobre un recuadro morado y una burbuja
/// de chat naranja. No usa el logo oficial de la universidad.
class Emblema extends StatelessWidget {
  const Emblema({super.key, this.tamano = 88, this.claro = false});

  final double tamano;

  /// Versión clara (fondo blanco translúcido) para usar sobre fondos morados.
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final radio = tamano * 0.3;
    return SizedBox(
      width: tamano * 1.12,
      height: tamano * 1.12,
      child: Stack(
        children: [
          Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              gradient: claro ? null : Colores.degradadoMorado,
              color: claro ? Colors.white.withValues(alpha: 0.16) : null,
              borderRadius: BorderRadius.circular(radio),
              border: claro ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5) : null,
              boxShadow: claro ? null : Colores.sombraSuave,
            ),
            child: Icon(Icons.school_rounded, color: Colors.white, size: tamano * 0.56),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: tamano * 0.46,
              height: tamano * 0.46,
              decoration: BoxDecoration(
                gradient: Colores.degradadoNaranja,
                shape: BoxShape.circle,
                border: Border.all(color: claro ? Colores.moradoOscuro : Colores.fondo, width: tamano * 0.05),
              ),
              child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: tamano * 0.22),
            ),
          ),
        ],
      ),
    );
  }
}
