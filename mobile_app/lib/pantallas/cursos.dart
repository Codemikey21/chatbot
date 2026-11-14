import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';

/// Pilares de la insignia, sus cursos y las secciones (NRC) abiertas,
/// con el estado del estudiante en cada pilar.
class PantallaCursos extends StatelessWidget {
  const PantallaCursos({super.key});

  Future<(Catalogo, Resumen)> _cargar() async {
    final datos = await Future.wait([api.cursos(), api.resumen()]);
    return (datos[0] as Catalogo, datos[1] as Resumen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Competencias digitales', subtitulo: 'Pilares, cursos y secciones'),
          Expanded(
            child: VistaAsincrona<(Catalogo, Resumen)>(
              cargar: _cargar,
              construir: (context, datos, recargar) {
                final (catalogo, resumen) = datos;
                return RefreshIndicator(
                  onRefresh: recargar,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _Regla(regla: catalogo.regla),
                      const SizedBox(height: 16),
                      ...[
                        for (var i = 0; i < catalogo.pilares.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _TarjetaPilar(
                              pilar: catalogo.pilares[i],
                              numero: i + 1,
                              progreso: resumen.pilares
                                  .where((p) => p.codigo == catalogo.pilares[i].codigo)
                                  .firstOrNull,
                            ),
                          ),
                      ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.1),
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

class _Regla extends StatelessWidget {
  const _Regla({required this.regla});

  final String regla;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: Colores.degradadoNaranja, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(regla, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPilar extends StatelessWidget {
  const _TarjetaPilar({required this.pilar, required this.numero, required this.progreso});

  final PilarCatalogo pilar;
  final int numero;
  final PilarProgreso? progreso;

  @override
  Widget build(BuildContext context) {
    final aprobado = progreso?.aprobado ?? false;
    final enCurso = progreso?.enCurso ?? false;
    final (texto, color) = aprobado
        ? ('Aprobado', Colores.verde)
        : enCurso
            ? ('En curso', Colores.naranja)
            : ('Pendiente', Colores.textoSuave);
    return Tarjeta(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !aprobado,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: aprobado ? Colores.verde : Colores.lavanda,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: aprobado
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : Text('$numero', style: const TextStyle(color: Colores.morado, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
          ),
          title: Text(pilar.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            aprobado && progreso?.cursoAprobado != null ? '$texto con ${progreso!.cursoAprobado}' : texto,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          children: [
            if (pilar.descripcion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(pilar.descripcion!, style: const TextStyle(color: Colores.textoSuave, fontSize: 13, height: 1.35)),
              ),
            for (final curso in pilar.cursos) _FilaCurso(curso: curso, pilar: pilar.nombre),
          ],
        ),
      ),
    );
  }
}

class _FilaCurso extends StatelessWidget {
  const _FilaCurso({required this.curso, required this.pilar});

  final CursoCatalogo curso;
  final String pilar;

  @override
  Widget build(BuildContext context) {
    final cupos = curso.secciones.fold<int>(0, (total, s) => total + s.cuposDisponibles);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colores.fondo,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _verDetalle(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Colores.morado),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(curso.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        curso.secciones.isEmpty
                            ? 'Sin secciones abiertas'
                            : '${curso.secciones.length} secciones · $cupos cupos',
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colores.moradoClaro),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verDetalle(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (contextoHoja) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controlador) => ListView(
          controller: controlador,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(curso.codigo, style: const TextStyle(color: Colores.textoSuave)),
            Text(curso.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Pilar: $pilar', style: const TextStyle(color: Colores.morado, fontWeight: FontWeight.w600)),
            if (curso.descripcion != null) ...[
              const SizedBox(height: 10),
              Text(curso.descripcion!, style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 16),
            const Text('Secciones abiertas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            if (curso.secciones.isEmpty)
              const Text('No hay secciones abiertas en este momento.', style: TextStyle(color: Colores.textoSuave)),
            for (final s in curso.secciones)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colores.fondo, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NRC ${s.nrc}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${s.periodo} · Grupo ${s.grupo}', style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(s.modalidad, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(s.horario,
                              textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
                          Text('${s.cuposDisponibles} de ${s.cupo} cupos',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: s.cuposDisponibles > 0 ? Colores.verde : Colores.rojo,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(contextoHoja).pop();
                preguntarAlAsistente(context, '¿Me recomiendas tomar ${curso.nombre}? ¿Qué se ve en ese curso?');
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Preguntar al asistente'),
            ),
          ],
        ),
      ),
    );
  }
}
