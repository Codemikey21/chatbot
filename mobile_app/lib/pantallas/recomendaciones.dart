import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';

/// Curso recomendado por pilar pendiente, con las razones calculadas en la
/// base de datos (afinidad del curso con el pensum y el historial).
class PantallaRecomendaciones extends StatelessWidget {
  const PantallaRecomendaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Recomendaciones', subtitulo: 'Según tu pensum e historial'),
          Expanded(
            child: VistaAsincrona<List<Recomendacion>>(
              cargar: api.recomendaciones,
              construir: (context, recomendaciones, recargar) {
                final porPilar = <String, List<Recomendacion>>{};
                for (final r in recomendaciones) {
                  porPilar.putIfAbsent(r.pilar, () => []).add(r);
                }
                return RefreshIndicator(
                  onRefresh: recargar,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const _Encabezado(),
                      const SizedBox(height: 16),
                      if (recomendaciones.isEmpty)
                        const EstadoVacio(
                          icono: Icons.workspace_premium_rounded,
                          mensaje: '¡Ya aprobaste los tres pilares o estás cursando los que faltan! No hay recomendaciones pendientes.',
                        ),
                      for (final MapEntry(key: pilar, value: lista) in porPilar.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),
                          child: Text('Pilar: $pilar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        ...lista
                            .map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _TarjetaRecomendacion(recomendacion: r),
                                ))
                            .toList()
                            .animate(interval: 90.ms)
                            .fadeIn()
                            .slideX(begin: 0.1),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Row(
        children: [
          const IconoCirculo(icono: Icons.insights_rounded, color: Colores.naranja, tamano: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Cursos recomendados para ti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Un curso aprueba cada pilar y puedes cursarlos en cualquier orden. Te sugerimos los que más se relacionan con tu carrera.',
                  style: TextStyle(color: Colores.textoSuave, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaRecomendacion extends StatelessWidget {
  const _TarjetaRecomendacion({required this.recomendacion});

  final Recomendacion recomendacion;

  @override
  Widget build(BuildContext context) {
    final esPrimera = recomendacion.posicion == 1;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: esPrimera ? Colores.degradadoNaranja : null,
                  color: esPrimera ? null : Colores.lavanda,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  esPrimera ? '★ Recomendado' : 'Opción ${recomendacion.posicion}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: esPrimera ? Colors.white : Colores.morado,
                  ),
                ),
              ),
              const Spacer(),
              Text(recomendacion.codigo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(recomendacion.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (recomendacion.descripcion != null) ...[
            const SizedBox(height: 4),
            Text(recomendacion.descripcion!, style: const TextStyle(color: Colores.textoSuave, fontSize: 13, height: 1.35)),
          ],
          if (recomendacion.razones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('¿Por qué?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            for (final razon in recomendacion.razones)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_rounded, size: 16, color: Colores.verde),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(razon, style: const TextStyle(fontSize: 13, height: 1.35))),
                  ],
                ),
              ),
          ],
          if (recomendacion.nrcDisponibles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final nrc in recomendacion.nrcDisponibles)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colores.fondo, borderRadius: BorderRadius.circular(10)),
                    child: Text('NRC $nrc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => preguntarAlAsistente(
                context,
                '¿Por qué me recomiendas ${recomendacion.nombre} del pilar ${recomendacion.pilar}?',
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Preguntar al asistente'),
            ),
          ),
        ],
      ),
    );
  }
}
