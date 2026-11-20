import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import 'bienvenida.dart';
import 'principal.dart';

/// Pantalla inicial: arma el logo de la universidad con una animación
/// mientras recupera la sesión guardada, y luego abre la pantalla principal
/// o la de bienvenida.
class PantallaArranque extends StatefulWidget {
  const PantallaArranque({super.key});

  @override
  State<PantallaArranque> createState() => _PantallaArranqueState();
}

class _PantallaArranqueState extends State<PantallaArranque> with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 2600);

  late final AnimationController _control = AnimationController(vsync: this, duration: _duracion);

  @override
  void initState() {
    super.initState();
    _control.forward();
    _decidir();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _decidir() async {
    final resultados = await Future.wait([
      sesion.restaurar(),
      Future<void>.delayed(_duracion + const Duration(milliseconds: 600)),
    ]);
    if (!mounted) return;
    final activa = resultados.first as bool;
    Navigator.of(context).pushReplacement(
      ruta(activa ? const PantallaPrincipal() : const PantallaBienvenida()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = math.min(MediaQuery.sizeOf(context).width * 0.74, 320.0);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: Colores.degradadoMorado),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Universidad Autónoma de Bucaramanga',
              image: true,
              child: _LogoAnimado(control: _control, ancho: ancho)
                  .animate(delay: 2100.ms)
                  .shimmer(duration: 900.ms, color: Colores.naranjaClaro),
            ),
            SizedBox(height: ancho * 0.16),
            const Text(
              'Asistente Académico',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ).animate(delay: 1900.ms).fadeIn(duration: 500.ms).slideY(begin: 0.5, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

/// Logo de la UNAB armado por piezas: el edificio entra girando como un
/// carrusel en el centro, se corre a su lugar, aparece «Universidad» y las
/// letras de «unab» se voltean una por una hasta formar la palabra.
class _LogoAnimado extends StatelessWidget {
  const _LogoAnimado({required this.control, required this.ancho});

  final AnimationController control;
  final double ancho;

  // Medidas del logo original (1201 x 378 px) para ubicar cada pieza.
  static const _anchoOriginal = 1201.0;
  static const _altoOriginal = 378.0;
  static const _simbolo = Rect.fromLTWH(0, 0, 345, 378);
  static const _universidad = Rect.fromLTWH(400, 20, 801, 112);
  static const _letras = [
    Rect.fromLTWH(409, 140, 175, 238),
    Rect.fromLTWH(608, 140, 174, 238),
    Rect.fromLTWH(806, 140, 185, 238),
    Rect.fromLTWH(1015, 140, 185, 238),
  ];

  /// Avance de 0 a 1 dentro de un tramo de la animación, con su curva.
  double _tramo(double inicio, double fin, Curve curva) =>
      curva.transform(((control.value - inicio) / (fin - inicio)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final escala = ancho / _anchoOriginal;
    return AnimatedBuilder(
      animation: control,
      builder: (context, _) {
        // 1. El edificio aparece en el centro dando una vuelta completa y crece
        final giro = _tramo(0.0, 0.38, Curves.easeOutCubic);
        final crece = _tramo(0.0, 0.38, Curves.easeOutBack);
        // 2. Se corre del centro a su lugar en el logo
        final corre = _tramo(0.36, 0.58, Curves.easeInOutCubic);
        final centroX = (ancho - _simbolo.width * escala) / 2;
        // 3. «Universidad» entra deslizándose desde el edificio
        final universidad = _tramo(0.50, 0.72, Curves.easeOutCubic);

        return SizedBox(
          width: ancho,
          height: _altoOriginal * escala,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _universidad.left * escala,
                top: _universidad.top * escala,
                width: _universidad.width * escala,
                height: _universidad.height * escala,
                child: Opacity(
                  opacity: universidad,
                  child: Transform.translate(
                    offset: Offset(-28 * (1 - universidad), 0),
                    child: Image.asset('assets/imagenes/logo_universidad_blanco.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              for (var i = 0; i < _letras.length; i++) _letra(i, escala),
              Positioned(
                left: centroX * (1 - corre),
                top: 0,
                width: _simbolo.width * escala,
                height: _simbolo.height * escala,
                child: Opacity(
                  opacity: _tramo(0.0, 0.12, Curves.easeOut),
                  child: Transform.scale(
                    scale: 0.55 + 0.45 * crece,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(2 * math.pi * (1 - giro)),
                      child: Image.asset('assets/imagenes/logo_simbolo_blanco.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Cada letra de «unab» se levanta girando sobre su base, una tras otra.
  Widget _letra(int indice, double escala) {
    final caja = _letras[indice];
    final inicio = 0.56 + indice * 0.07;
    final levanta = _tramo(inicio, inicio + 0.2, Curves.easeOutBack);
    final aparece = _tramo(inicio, inicio + 0.08, Curves.easeOut);
    return Positioned(
      left: caja.left * escala,
      top: caja.top * escala,
      width: caja.width * escala,
      height: caja.height * escala,
      child: Opacity(
        opacity: aparece,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(-math.pi / 2 * (1 - levanta)),
          child: Image.asset('assets/imagenes/logo_letra_${indice + 1}_blanco.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
