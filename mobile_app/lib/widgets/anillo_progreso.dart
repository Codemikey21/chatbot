import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Anillo de avance animado (0 a 100) con el porcentaje en el centro.
class AnilloProgreso extends StatelessWidget {
  const AnilloProgreso({
    super.key,
    required this.porcentaje,
    this.tamano = 120,
    this.grosor = 12,
    this.etiqueta,
  });

  final double porcentaje;
  final double tamano;
  final double grosor;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: porcentaje.clamp(0, 100) / 100),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, valor, _) => SizedBox(
        width: tamano,
        height: tamano,
        child: CustomPaint(
          painter: _PintorAnillo(valor, grosor),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(valor * 100).round()}%',
                  style: TextStyle(
                    fontSize: tamano * 0.22,
                    fontWeight: FontWeight.w800,
                    color: Colores.texto,
                  ),
                ),
                if (etiqueta != null)
                  Text(etiqueta!, style: TextStyle(fontSize: tamano * 0.09, color: Colores.textoSuave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  _PintorAnillo(this.valor, this.grosor);

  final double valor;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = Colores.lavanda
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );
    if (valor <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * valor,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Colores.naranjaClaro, Colores.naranja, Colores.naranjaClaro],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = grosor,
    );
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) => anterior.valor != valor || anterior.grosor != grosor;
}
