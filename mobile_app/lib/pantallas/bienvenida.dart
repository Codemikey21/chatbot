import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades/navegacion.dart';
import '../widgets/logo_unab.dart';
import 'login.dart';

/// Pantalla de bienvenida: foto del campus con capa morada, logo de la
/// universidad, accesos principales y botón para iniciar sesión.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  static const _funciones = [
    (Icons.school_outlined, 'Cursos'),
    (Icons.calendar_month_outlined, 'Calendario'),
    (Icons.bar_chart_rounded, 'Progreso'),
  ];

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colores.moradoOscuro,
        body: Stack(
          children: [
            // Foto del campus, recortada para que se vea la torre.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: alto * 0.68,
              child: ClipRect(
                child: Image.asset(
                  'assets/imagenes/campus.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.26, 0),
                  excludeFromSemantics: true,
                )
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(1.08, 1.08),
                      end: const Offset(1, 1),
                      duration: 2400.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
            ),
            // Capa morada: deja ver la foto arriba y se vuelve sólida abajo.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.24, 0.5, 0.66, 1],
                    colors: [
                      Color(0x9E2E0B6B),
                      Color(0x473B0F80),
                      Color(0xB83B0F80),
                      Colores.moradoOscuro,
                      Colores.moradoNoche,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: const CustomPaint(size: Size(190, 170), painter: _EsquinaNaranja())
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideX(begin: 0.4, duration: 800.ms, curve: Curves.easeOutCubic),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: CustomPaint(painter: _OlaInferior()),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, limites) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: limites.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(child: LogoUnab(ancho: 190, blanco: true))
                                .animate()
                                .fadeIn(duration: 600.ms)
                                .slideY(begin: -0.3, curve: Curves.easeOutCubic),
                            const Spacer(),
                            Semantics(
                              header: true,
                              child: const Text(
                                'Asistente\nAcadémico UNAB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.3, curve: Curves.easeOutCubic),
                            const SizedBox(height: 12),
                            Text(
                              'Tu compañero inteligente para tu vida universitaria',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 16, height: 1.5),
                            ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideY(begin: 0.3),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                for (final (i, (icono, texto)) in _funciones.indexed) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: _ChipFuncion(icono: icono, texto: texto)
                                        .animate(delay: (650 + i * 120).ms)
                                        .fadeIn()
                                        .slideY(begin: 0.4, curve: Curves.easeOutBack),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 28),
                            _BotonComenzar(
                              onPressed: () => Navigator.of(context).pushReplacement(ruta(const PantallaLogin())),
                            )
                                .animate()
                                .fadeIn(delay: 950.ms)
                                .slideY(begin: 0.5, curve: Curves.easeOutCubic)
                                .then(delay: 400.ms)
                                .shimmer(duration: 1600.ms, color: Colors.white54),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                'Ingeniería de Sistemas · UNAB',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 12),
                              ),
                            ).animate().fadeIn(delay: 1100.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acceso con efecto de vidrio (Cursos, Calendario, Progreso).
class _ChipFuncion extends StatelessWidget {
  const _ChipFuncion({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Column(
            children: [
              Icon(icono, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón naranja en forma de píldora con sombra.
class _BotonComenzar extends StatelessWidget {
  const _BotonComenzar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colores.naranjaFuerte.withValues(alpha: 0.42),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colores.naranjaFuerte,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: fuenteApp, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('Comenzar'), SizedBox(width: 10), Icon(Icons.arrow_forward_rounded, size: 22)],
        ),
      ),
    );
  }
}

/// Esquina naranja de la parte superior derecha (como en el mockup).
class _EsquinaNaranja extends CustomPainter {
  const _EsquinaNaranja();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 190;
    final sy = size.height / 170;
    final grande = Path()
      ..moveTo(70 * sx, 0)
      ..lineTo(190 * sx, 0)
      ..lineTo(190 * sx, 160 * sy)
      ..cubicTo(170 * sx, 96 * sy, 128 * sx, 36 * sy, 70 * sx, 0)
      ..close();
    final pequena = Path()
      ..moveTo(122 * sx, 0)
      ..lineTo(190 * sx, 0)
      ..lineTo(190 * sx, 86 * sy)
      ..cubicTo(174 * sx, 52 * sy, 152 * sx, 22 * sy, 122 * sx, 0)
      ..close();
    canvas.drawPath(grande, Paint()..color = Colores.naranja);
    canvas.drawPath(pequena, Paint()..color = Colores.naranjaClaro);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ondas moradas del borde inferior.
class _OlaInferior extends CustomPainter {
  const _OlaInferior();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 160;
    final atras = Path()
      ..moveTo(0, 74 * sy)
      ..cubicTo(96 * sx, 128 * sy, 236 * sx, 18 * sy, 390 * sx, 62 * sy)
      ..lineTo(390 * sx, 160 * sy)
      ..lineTo(0, 160 * sy)
      ..close();
    final adelante = Path()
      ..moveTo(0, 116 * sy)
      ..cubicTo(124 * sx, 150 * sy, 262 * sx, 86 * sy, 390 * sx, 110 * sy)
      ..lineTo(390 * sx, 160 * sy)
      ..lineTo(0, 160 * sy)
      ..close();
    canvas.drawPath(atras, Paint()..color = Colores.moradoMedio.withValues(alpha: 0.55));
    canvas.drawPath(adelante, Paint()..color = Colores.moradoVivo.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
