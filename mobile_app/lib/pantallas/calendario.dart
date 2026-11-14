import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/fechas.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';

/// Color e ícono de cada tipo de evento del calendario.
(Color, IconData, String) estiloEvento(String tipo) => switch (tipo) {
      'inscripcion' => (Colores.morado, Icons.how_to_reg_rounded, 'Inscripción'),
      'prueba_diagnostica' => (Colores.azul, Icons.quiz_rounded, 'Prueba diagnóstica'),
      'resultados' => (Colores.azul, Icons.fact_check_rounded, 'Resultados'),
      'inicio_curso' || 'inicio_clases' => (Colores.verde, Icons.play_circle_rounded, 'Inicio'),
      'fin_curso' => (Colores.textoSuave, Icons.flag_rounded, 'Cierre'),
      'certificacion' => (Colores.naranja, Icons.workspace_premium_rounded, 'Insignias'),
      'matricula' => (Colores.moradoClaro, Icons.app_registration_rounded, 'Matrícula'),
      'evaluacion' => (Colores.rojo, Icons.edit_note_rounded, 'Evaluación'),
      'retiro' => (Colores.amarillo, Icons.exit_to_app_rounded, 'Retiro'),
      'receso' => (Colores.textoSuave, Icons.beach_access_rounded, 'Receso'),
      _ => (Colores.morado, Icons.event_rounded, 'Evento'),
    };

class PantallaCalendario extends StatefulWidget {
  const PantallaCalendario({super.key});

  @override
  State<PantallaCalendario> createState() => _PantallaCalendarioState();
}

class _PantallaCalendarioState extends State<PantallaCalendario> {
  late DateTime _mes;
  DateTime? _diaElegido;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Calendario académico', subtitulo: 'Fechas desde Google Sheets'),
          Expanded(
            child: VistaAsincrona<List<Evento>>(
              cargar: () => api.calendario(soloProximos: false),
              construir: (context, eventos, recargar) {
                final hoy = DateTime.now();
                final lista = _diaElegido != null
                    ? eventos.where((e) => e.ocurreEl(_diaElegido!)).toList()
                    : eventos.where((e) => e.estado != 'finalizado').toList();
                return RefreshIndicator(
                  onRefresh: recargar,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _Mes(
                        mes: _mes,
                        eventos: eventos,
                        hoy: hoy,
                        elegido: _diaElegido,
                        alCambiarMes: (delta) => setState(() {
                          _mes = DateTime(_mes.year, _mes.month + delta);
                          _diaElegido = null;
                        }),
                        alElegir: (dia) => setState(() => _diaElegido = _diaElegido != null && mismoDia(_diaElegido!, dia) ? null : dia),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _diaElegido != null ? fechaLarga(_diaElegido!) : 'Próximos eventos',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_diaElegido != null)
                            TextButton(onPressed: () => setState(() => _diaElegido = null), child: const Text('Ver todos')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (lista.isEmpty)
                        const EstadoVacio(icono: Icons.event_busy_rounded, mensaje: 'No hay eventos para este día.')
                      else
                        ...lista
                            .map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TarjetaEvento(evento: e)))
                            .toList()
                            .animate(interval: 60.ms)
                            .fadeIn()
                            .slideY(begin: 0.15),
                      const SizedBox(height: 8),
                      Tarjeta(
                        color: Colores.lavanda,
                        onTap: () => preguntarAlAsistente(context, '¿Qué actividades académicas tengo próximas?'),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colores.naranja),
                            SizedBox(width: 12),
                            Expanded(child: Text('Pregúntale al asistente por las próximas fechas',
                                style: TextStyle(fontWeight: FontWeight.w600))),
                            Icon(Icons.chevron_right_rounded, color: Colores.morado),
                          ],
                        ),
                      ),
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

class _Mes extends StatelessWidget {
  const _Mes({
    required this.mes,
    required this.eventos,
    required this.hoy,
    required this.elegido,
    required this.alCambiarMes,
    required this.alElegir,
  });

  final DateTime mes;
  final List<Evento> eventos;
  final DateTime hoy;
  final DateTime? elegido;
  final ValueChanged<int> alCambiarMes;
  final ValueChanged<DateTime> alElegir;

  @override
  Widget build(BuildContext context) {
    final diasDelMes = DateTime(mes.year, mes.month + 1, 0).day;
    final desfase = DateTime(mes.year, mes.month, 1).weekday - 1; // lunes = 0
    final celdas = desfase + diasDelMes;

    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => alCambiarMes(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(mesAnio(mes),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => alCambiarMes(1), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          Row(
            children: [
              for (final d in diasSemanaCortos)
                Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (celdas / 7).ceil() * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
            itemBuilder: (context, i) {
              final numero = i - desfase + 1;
              if (numero < 1 || numero > diasDelMes) return const SizedBox.shrink();
              final dia = DateTime(mes.year, mes.month, numero);
              final delDia = eventos.where((e) => e.ocurreEl(dia)).toList();
              final esHoy = mismoDia(dia, hoy);
              final esElegido = elegido != null && mismoDia(dia, elegido!);
              return GestureDetector(
                onTap: () => alElegir(dia),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: esElegido ? Colores.morado : (esHoy ? Colores.lavanda : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$numero',
                        style: TextStyle(
                          fontWeight: esHoy || esElegido ? FontWeight.w800 : FontWeight.w500,
                          color: esElegido ? Colors.white : Colores.texto,
                        ),
                      ),
                      if (delDia.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: delDia.take(3).map((e) {
                            final (color, _, _) = estiloEvento(e.tipo);
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 2, left: 1, right: 1),
                              decoration: BoxDecoration(
                                color: esElegido ? Colors.white : color,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final (color, icono, etiqueta) = estiloEvento(evento.tipo);
    final (estadoTexto, estadoColor) = switch (evento.estado) {
      'en_curso' => ('En curso', Colores.verde),
      'finalizado' => ('Finalizado', Colores.textoSuave),
      _ => (cuandoEmpieza(evento.diasParaInicio), Colores.naranja),
    };
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text('${evento.inicio.day}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(mesCorto(evento.inicio), style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(etiqueta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(estadoTexto, style: TextStyle(color: estadoColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(evento.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(rangoFechas(evento.inicio, evento.fin),
                    style: const TextStyle(color: Colores.textoSuave, fontSize: 12.5)),
                if (evento.descripcion != null) ...[
                  const SizedBox(height: 4),
                  Text(evento.descripcion!, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
