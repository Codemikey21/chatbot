import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/fechas.dart';
import '../utilidades/navegacion.dart';
import '../widgets/anillo_progreso.dart';
import '../widgets/comunes.dart';
import 'calendario.dart';
import 'noticias.dart';
import 'recomendaciones.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  Future<(Resumen, List<Evento>)> _cargar() async {
    final resultados = await Future.wait([api.resumen(), api.calendario(soloProximos: true)]);
    return (resultados[0] as Resumen, resultados[1] as List<Evento>);
  }

  @override
  Widget build(BuildContext context) {
    final estudiante = sesion.estudiante;
    return Scaffold(
      body: VistaAsincrona<(Resumen, List<Evento>)>(
        cargar: _cargar,
        cargando: Column(
          children: [
            _Saludo(nombre: estudiante?.primerNombre ?? '', detalle: estudiante?.programa ?? ''),
            const Padding(padding: EdgeInsets.all(20), child: Esqueleto(bloques: 3, alto: 120)),
          ],
        ),
        construir: (context, datos, recargar) {
          final (resumen, eventos) = datos;
          final secciones = <Widget>[
            _TarjetaAsistente(),
            _TarjetaInsignia(resumen: resumen),
            _TarjetaAvance(resumen: resumen),
            const _Accesos(),
            if (eventos.isNotEmpty) _ProximoEvento(evento: eventos.first),
          ];
          return RefreshIndicator(
            onRefresh: recargar,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Saludo(
                  nombre: resumen.estudiante.primerNombre,
                  detalle: '${resumen.estudiante.programa} · Semestre ${resumen.estudiante.semestre}',
                ),
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final seccion in secciones)
                          Padding(padding: const EdgeInsets.only(bottom: 14), child: seccion),
                      ].animate(interval: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.12, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre, required this.detalle});

  final String nombre;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return EncabezadoCurvo(
      altoExtra: 40,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inicio', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Hola, $nombre',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 24))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .rotate(begin: -0.04, end: 0.06, duration: 700.ms),
                  ],
                ),
                Text(detalle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => pestanaActual.value = Pestanas.mas,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                sesion.estudiante?.iniciales ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAsistente extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      onTap: () => pestanaActual.value = Pestanas.chat,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(gradient: Colores.degradadoMorado, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -4, duration: 1400.ms, curve: Curves.easeInOut),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asistente académico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(
                  'Pregúntame por tus cursos, la insignia, el calendario y más',
                  style: TextStyle(color: Colores.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colores.morado, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _TarjetaInsignia extends StatelessWidget {
  const _TarjetaInsignia({required this.resumen});

  final Resumen resumen;

  @override
  Widget build(BuildContext context) {
    final pendientes = resumen.pilares.where((p) => !p.aprobado).toList();
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoCirculo(
                icono: resumen.insigniaObtenida ? Icons.workspace_premium_rounded : Icons.military_tech_rounded,
                color: Colores.naranja,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Insignia de competencias digitales',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      resumen.insigniaObtenida
                          ? '¡Insignia obtenida!'
                          : '${resumen.pilaresAprobados} de ${resumen.pilaresTotales} pilares aprobados',
                      style: const TextStyle(color: Colores.textoSuave, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < resumen.pilares.length; i++) ...[
                Expanded(child: _PasoPilar(pilar: resumen.pilares[i], numero: i + 1)),
                if (i < resumen.pilares.length - 1)
                  Container(
                    width: 18,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 34),
                    color: resumen.pilares[i].aprobado ? Colores.verde : Colores.borde,
                  ),
              ],
            ],
          ),
          if (pendientes.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Te falta: ${pendientes.map((p) => p.nombre).join(', ')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(ruta(const PantallaRecomendaciones())),
                  child: const Text('Ver recomendación'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PasoPilar extends StatelessWidget {
  const _PasoPilar({required this.pilar, required this.numero});

  final PilarProgreso pilar;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final color = pilar.aprobado ? Colores.verde : (pilar.enCurso ? Colores.naranja : Colores.textoSuave);
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pilar.aprobado ? Colores.verde : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: pilar.aprobado
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : Text('$numero', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
        ).animate().scale(delay: (numero * 150).ms, duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 6),
        Text(
          pilar.nombre,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2),
        ),
        Text(
          pilar.aprobado ? (pilar.cursoAprobado ?? 'Aprobado') : (pilar.enCurso ? 'En curso' : 'Pendiente'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: color),
        ),
      ],
    );
  }
}

class _TarjetaAvance extends StatelessWidget {
  const _TarjetaAvance({required this.resumen});

  final Resumen resumen;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      onTap: () => pestanaActual.value = Pestanas.progreso,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu avance en la carrera', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                Text(
                  '${resumen.creditosAprobados} de ${resumen.creditosTotales} créditos',
                  style: const TextStyle(fontSize: 13, color: Colores.textoSuave),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 16, color: Colores.naranja),
                    const SizedBox(width: 6),
                    Text(
                      '≈ ${resumen.semestresEstimados} semestres restantes',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnilloProgreso(porcentaje: resumen.porcentajeAvance, tamano: 96, grosor: 10, etiqueta: 'del plan'),
        ],
      ),
    );
  }
}

class _Accesos extends StatelessWidget {
  const _Accesos();

  @override
  Widget build(BuildContext context) {
    final accesos = [
      (Icons.layers_rounded, 'Cursos digitales', 'Pilares y NRC', Colores.morado,
          () => pestanaActual.value = Pestanas.cursos),
      (Icons.event_note_rounded, 'Calendario', 'Fechas clave', Colores.naranja,
          () => Navigator.of(context).push(ruta(const PantallaCalendario()))),
      (Icons.campaign_rounded, 'Noticias', 'Convocatorias', Colores.azul,
          () => Navigator.of(context).push(ruta(const PantallaNoticias()))),
      (Icons.insights_rounded, 'Recomendados', 'Para ti', Colores.verde,
          () => Navigator.of(context).push(ruta(const PantallaRecomendaciones()))),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.75,
      padding: EdgeInsets.zero,
      children: [
        for (final (icono, titulo, detalle, color, accion) in accesos)
          Tarjeta(
            padding: const EdgeInsets.all(14),
            onTap: accion,
            child: Row(
              children: [
                IconoCirculo(icono: icono, color: color, tamano: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProximoEvento extends StatelessWidget {
  const _ProximoEvento({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      onTap: () => Navigator.of(context).push(ruta(const PantallaCalendario())),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(gradient: Colores.degradadoNaranja, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text('${evento.inicio.day}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(mesCorto(evento.inicio), style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Próximo evento', style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                Text(evento.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(cuandoEmpieza(evento.diasParaInicio),
                    style: const TextStyle(color: Colores.naranja, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
