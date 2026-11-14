import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/api.dart';
import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/fechas.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';
import 'chat.dart';

/// Conversaciones anteriores guardadas en la memoria del chat.
class PantallaConversaciones extends StatelessWidget {
  const PantallaConversaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Conversaciones', subtitulo: 'Retoma una conversación anterior'),
          Expanded(
            child: VistaAsincrona<List<SesionChat>>(
              cargar: api.conversaciones,
              construir: (context, sesiones, recargar) => RefreshIndicator(
                onRefresh: recargar,
                child: sesiones.isEmpty
                    ? ListView(children: const [
                        EstadoVacio(icono: Icons.forum_outlined, mensaje: 'Todavía no tienes conversaciones guardadas.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: sesiones.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _FilaConversacion(sesion: sesiones[i], alArchivar: recargar)
                            .animate()
                            .fadeIn(delay: (i * 50).ms)
                            .slideY(begin: 0.15),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colores.naranja,
        foregroundColor: Colors.white,
        onPressed: () {
          controladorChat.nueva();
          Navigator.of(context).pop();
          pestanaActual.value = Pestanas.chat;
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nueva conversación'),
      ),
    );
  }
}

class _FilaConversacion extends StatelessWidget {
  const _FilaConversacion({required this.sesion, required this.alArchivar});

  final SesionChat sesion;
  final Future<void> Function() alArchivar;

  Future<bool> _confirmar(BuildContext context) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar conversación'),
        content: const Text('Dejará de aparecer en la lista y el asistente no la usará como memoria.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    return respuesta ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(sesion.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmar(context),
      onDismissed: (_) async {
        try {
          await api.archivarConversacion(sesion.id);
        } on ApiError catch (error) {
          if (context.mounted) mostrarMensaje(context, error.mensaje);
        }
        await alArchivar();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colores.rojoClaro, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.archive_outlined, color: Colores.rojo),
      ),
      child: Tarjeta(
        onTap: () {
          controladorChat.abrir(sesion.id);
          Navigator.of(context).pop();
          pestanaActual.value = Pestanas.chat;
        },
        child: Row(
          children: [
            const IconoCirculo(icono: Icons.chat_bubble_outline_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sesion.titulo,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (sesion.ultimaRespuesta != null)
                    Text(
                      sesion.ultimaRespuesta!.replaceAll(RegExp(r'[*#_`]'), ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colores.textoSuave, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(haceCuanto(sesion.ultimaActividad), style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
                const SizedBox(height: 4),
                Text('${sesion.mensajes} msj', style: const TextStyle(fontSize: 11, color: Colores.moradoClaro)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
