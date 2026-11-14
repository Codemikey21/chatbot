import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import '../widgets/anillo_progreso.dart';
import '../widgets/comunes.dart';

class PantallaProgreso extends StatefulWidget {
  const PantallaProgreso({super.key});

  @override
  State<PantallaProgreso> createState() => _PantallaProgresoState();
}

class _PantallaProgresoState extends State<PantallaProgreso> with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Mi progreso', subtitulo: 'Plan de estudios e historial'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Colores.sombraSuave),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _pestanas,
                indicator: BoxDecoration(color: Colores.morado, borderRadius: BorderRadius.circular(12)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colores.textoSuave,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [Tab(text: 'Plan de estudios'), Tab(text: 'Historial')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _pestanas,
              children: const [_Plan(), _Historial()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan();

  @override
  Widget build(BuildContext context) {
    return VistaAsincrona<Resumen>(
      cargar: api.resumen,
      construir: (context, r, recargar) => RefreshIndicator(
        onRefresh: recargar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Tarjeta(
              child: Row(
                children: [
                  AnilloProgreso(porcentaje: r.porcentajeAvance, tamano: 130, etiqueta: 'Avance general'),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        _Dato(icono: Icons.school_rounded, valor: '${r.creditosAprobados} / ${r.creditosTotales}', etiqueta: 'Créditos'),
                        _Dato(icono: Icons.check_circle_outline_rounded, valor: '${r.asignaturasAprobadas}', etiqueta: 'Asignaturas aprobadas'),
                        _Dato(icono: Icons.pending_actions_rounded, valor: '${r.asignaturasPendientes}', etiqueta: 'Asignaturas pendientes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              child: Row(
                children: [
                  const IconoCirculo(icono: Icons.timelapse_rounded, color: Colores.naranja, tamano: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('≈ ${r.semestresEstimados} semestres restantes',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Te faltan ${r.creditosPendientes} créditos. Con un máximo de ${r.maxCreditosSemestre} '
                          'créditos por semestre y la cadena de prerrequisitos pendientes, esa es la estimación.',
                          style: const TextStyle(color: Colores.textoSuave, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Competencias digitales', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const Spacer(),
                      Text('${r.pilaresAprobados}/${r.pilaresTotales} pilares',
                          style: const TextStyle(color: Colores.morado, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final p in r.pilares)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            p.aprobado ? Icons.check_circle_rounded : (p.enCurso ? Icons.timelapse_rounded : Icons.radio_button_unchecked),
                            color: p.aprobado ? Colores.verde : (p.enCurso ? Colores.naranja : Colores.textoSuave),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(p.cursoAprobado ?? (p.enCurso ? 'En curso' : 'Pendiente'),
                              style: const TextStyle(color: Colores.textoSuave, fontSize: 12.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              color: Colores.lavanda,
              onTap: () => preguntarAlAsistente(context, '¿Qué asignaturas puedo matricular el próximo semestre?'),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colores.naranja),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('¿Qué puedo matricular el próximo semestre?', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colores.morado),
                ],
              ),
            ),
          ].animate(interval: 80.ms).fadeIn().slideY(begin: 0.1),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.etiqueta});

  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, color: Colores.morado, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(etiqueta, style: const TextStyle(color: Colores.textoSuave, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Historial extends StatefulWidget {
  const _Historial();

  @override
  State<_Historial> createState() => _HistorialState();
}

class _HistorialState extends State<_Historial> {
  static const _filtros = [
    ('todos', 'Todos'),
    ('competencia_digital', 'Competencias digitales'),
    ('asignatura', 'Asignaturas'),
  ];

  String _tipo = 'todos';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            children: [
              for (final (valor, texto) in _filtros)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(texto),
                    selected: _tipo == valor,
                    onSelected: (_) => setState(() => _tipo = valor),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: VistaAsincrona<List<CursoHistorial>>(
            key: ValueKey(_tipo),
            cargar: () => api.historial(tipo: _tipo),
            construir: (context, cursos, recargar) {
              final periodos = <String, List<CursoHistorial>>{};
              for (final c in cursos) {
                periodos.putIfAbsent(c.periodo, () => []).add(c);
              }
              return RefreshIndicator(
                onRefresh: recargar,
                child: cursos.isEmpty
                    ? ListView(children: const [
                        EstadoVacio(icono: Icons.history_edu_rounded, mensaje: 'No hay cursos en este filtro.'),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          for (final MapEntry(key: periodo, value: lista) in periodos.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text('Periodo $periodo',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colores.morado)),
                            ),
                            Tarjeta(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  for (var i = 0; i < lista.length; i++) ...[
                                    _FilaHistorial(curso: lista[i]),
                                    if (i < lista.length - 1) const Divider(indent: 56),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ].animate(interval: 50.ms).fadeIn(),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.curso});

  final CursoHistorial curso;

  @override
  Widget build(BuildContext context) {
    final (icono, color, texto) = switch (curso.estado) {
      'aprobado' => (Icons.check_circle_rounded, Colores.verde, 'Aprobado'),
      'reprobado' => (Icons.cancel_rounded, Colores.rojo, 'Reprobado'),
      'inscrito' => (Icons.timelapse_rounded, Colores.naranja, 'En curso'),
      _ => (Icons.remove_circle_outline_rounded, Colores.textoSuave, 'Retirado'),
    };
    final detalle = [
      texto,
      if (curso.nota != null) 'Nota ${curso.nota!.toStringAsFixed(1)}',
      'NRC ${curso.nrc}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icono, color: color, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(curso.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (curso.esCompetenciaDigital) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.bolt_rounded, size: 16, color: Colores.naranja),
                    ],
                  ],
                ),
                Text(detalle, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(curso.esCompetenciaDigital ? 'CCD' : '${curso.creditos} cr',
              style: const TextStyle(color: Colores.textoSuave, fontSize: 12.5)),
        ],
      ),
    );
  }
}
