import 'package:flutter/material.dart';

/// Logo de la universidad tomado del manual de marca (versión horizontal).
///
/// Según el manual, sobre fondos de color va la versión blanca y sobre fondo
/// blanco la versión a color.
class LogoUnab extends StatelessWidget {
  const LogoUnab({super.key, this.ancho = 190, this.blanco = false});

  final double ancho;
  final bool blanco;

  static const _rutaBlanco = 'assets/imagenes/logo_unab_blanco.png';
  static const _rutaColor = 'assets/imagenes/logo_unab_color.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Universidad Autónoma de Bucaramanga',
      child: Image.asset(
        blanco ? _rutaBlanco : _rutaColor,
        width: ancho,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}
