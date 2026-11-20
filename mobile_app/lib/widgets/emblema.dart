import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Emblema de la app: el símbolo de la UNAB en su versión blanca (manual de
/// marca). Sobre fondos morados se muestra tal cual; sobre fondos claros va
/// dentro de un recuadro morado para que se vea.
class Emblema extends StatelessWidget {
  const Emblema({super.key, this.tamano = 88, this.claro = false});

  final double tamano;

  /// Versión para fondos morados (sin recuadro).
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Universidad Autónoma de Bucaramanga',
      image: true,
      child: Container(
        width: tamano,
        height: tamano,
        padding: EdgeInsets.all(claro ? 0 : tamano * 0.16),
        decoration: claro
            ? null
            : BoxDecoration(
                gradient: Colores.degradadoMorado,
                borderRadius: BorderRadius.circular(tamano * 0.24),
                boxShadow: Colores.sombraSuave,
              ),
        child: Image.asset('assets/imagenes/logo_simbolo_blanco.png', fit: BoxFit.contain),
      ),
    );
  }
}
