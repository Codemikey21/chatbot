import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';
import '../widgets/emblema.dart';
import 'calendario.dart';
import 'conversaciones.dart';
import 'noticias.dart';
import 'recomendaciones.dart';

class PantallaMas extends StatelessWidget {
  const PantallaMas({super.key});

  @override
  Widget build(BuildContext context) {
    final estudiante = sesion.estudiante;
    final opciones = [
      (Icons.forum_rounded, 'Conversaciones anteriores', () => Navigator.of(context).push(ruta(const PantallaConversaciones()))),
      (Icons.insights_rounded, 'Recomendaciones', () => Navigator.of(context).push(ruta(const PantallaRecomendaciones()))),
      (Icons.event_note_rounded, 'Calendario académico', () => Navigator.of(context).push(ruta(const PantallaCalendario()))),
      (Icons.campaign_rounded, 'Noticias y convocatorias', () => Navigator.of(context).push(ruta(const PantallaNoticias()))),
      (Icons.info_outline_rounded, 'Acerca del proyecto', () => _acercaDe(context)),
    ];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const BarraPantalla(titulo: 'Más'),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Tarjeta(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colores.lavanda,
                        child: Text(estudiante?.iniciales ?? '',
                            style: const TextStyle(color: Colores.morado, fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(estudiante?.nombreCompleto ?? '',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            Text(estudiante?.programa ?? '', style: const TextStyle(color: Colores.textoSuave)),
                            Text('Código ${estudiante?.codigo ?? ''} · Semestre ${estudiante?.semestre ?? ''}',
                                style: const TextStyle(color: Colores.textoSuave, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Tarjeta(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < opciones.length; i++) ...[
                        ListTile(
                          leading: Icon(opciones[i].$1, color: Colores.morado),
                          title: Text(opciones[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: opciones[i].$3,
                        ),
                        if (i < opciones.length - 1) const Divider(indent: 56),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Tarjeta(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colores.rojo),
                    title: const Text('Cerrar sesión', style: TextStyle(color: Colores.rojo, fontWeight: FontWeight.w700)),
                    onTap: () => _confirmarSalida(context),
                  ),
                ),
              ].animate(interval: 70.ms).fadeIn().slideY(begin: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalida(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta en este dispositivo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44), backgroundColor: Colores.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir == true) await cerrarSesion();
  }

  void _acercaDe(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, controlador) => ListView(
          controller: controlador,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const Center(child: Emblema(tamano: 64)),
            const SizedBox(height: 12),
            const Text('Asistente académico',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Text('Proyecto final de Ciencia de Datos · Ingeniería de Sistemas',
                textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
            const SizedBox(height: 16),
            const Text(
              'Chatbot de apoyo académico con un agente que combina búsqueda en documentos (RAG con pgvector), '
              'herramientas MCP sobre la base académica, el calendario en Google Sheets y noticias recopiladas por un scraper. '
              'n8n orquesta los flujos y Claude genera las respuestas.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 16),
            for (final (icono, texto) in const [
              (Icons.phone_android_rounded, 'App Flutter'),
              (Icons.shield_rounded, 'API FastAPI con JWT'),
              (Icons.account_tree_rounded, 'Orquestación con n8n'),
              (Icons.hub_rounded, 'Servidor MCP (FastMCP)'),
              (Icons.storage_rounded, 'Supabase PostgreSQL + pgvector'),
              (Icons.cloud_rounded, 'Docker y AWS EC2'),
            ])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(icono, color: Colores.morado),
                title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colores.amarilloClaro, borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'Entorno de demostración: los estudiantes, notas, cursos, NRC, el calendario y algunos documentos '
                'son datos sintéticos. No son información oficial de la universidad.',
                style: TextStyle(color: Colores.amarillo, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Text('Servidor: ${Config.apiUrl}',
                textAlign: TextAlign.center, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
