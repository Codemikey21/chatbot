import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/fechas.dart';
import '../widgets/comunes.dart';
import 'chat.dart';

(Color, IconData, String) estiloNoticia(String categoria) => switch (categoria) {
      'convocatoria' => (Colores.naranja, Icons.campaign_rounded, 'Convocatoria'),
      'curso' => (Colores.morado, Icons.school_rounded, 'Curso'),
      'certificacion' => (Colores.verde, Icons.workspace_premium_rounded, 'Certificación'),
      _ => (Colores.azul, Icons.newspaper_rounded, 'Noticia'),
    };

class PantallaNoticias extends StatefulWidget {
  const PantallaNoticias({super.key});

  @override
  State<PantallaNoticias> createState() => _PantallaNoticiasState();
}

class _PantallaNoticiasState extends State<PantallaNoticias> {
  static const _filtros = [
    (null, 'Todas'),
    ('convocatoria', 'Convocatorias'),
    ('curso', 'Cursos'),
    ('certificacion', 'Certificaciones'),
    ('noticia', 'Noticias'),
  ];

  String? _categoria;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BarraPantalla(titulo: 'Noticias y convocatorias', subtitulo: 'Recopiladas automáticamente cada 6 horas'),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              children: [
                for (final (valor, texto) in _filtros)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(texto),
                      selected: _categoria == valor,
                      onSelected: (_) => setState(() => _categoria = valor),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: VistaAsincrona<List<Noticia>>(
              key: ValueKey(_categoria),
              cargar: () => api.noticias(categoria: _categoria),
              construir: (context, noticias, recargar) => RefreshIndicator(
                onRefresh: recargar,
                child: noticias.isEmpty
                    ? ListView(children: const [
                        EstadoVacio(icono: Icons.inbox_rounded, mensaje: 'No hay noticias en esta categoría por ahora.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: noticias.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _TarjetaNoticia(noticia: noticias[i])
                            .animate()
                            .fadeIn(delay: (i.clamp(0, 6) * 60).ms)
                            .slideY(begin: 0.12),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaNoticia extends StatelessWidget {
  const _TarjetaNoticia({required this.noticia});

  final Noticia noticia;

  @override
  Widget build(BuildContext context) {
    final (color, icono, etiqueta) = estiloNoticia(noticia.categoria);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: Colores.sombraSuave),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 76,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -14,
                  child: Icon(icono, size: 96, color: Colors.white.withValues(alpha: 0.18)),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Icon(icono, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(etiqueta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (noticia.demostrativa)
                  const Positioned(right: 12, bottom: 12, child: EtiquetaDemo(texto: 'DEMO', clara: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(noticia.titulo, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.25)),
                if (noticia.resumen != null) ...[
                  const SizedBox(height: 6),
                  Text(noticia.resumen!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colores.textoSuave, height: 1.4, fontSize: 13.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.public_rounded, size: 14, color: Colores.textoSuave),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        noticia.fecha != null ? '${noticia.fuente} · ${fechaCorta(noticia.fecha!)}' : noticia.fuente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colores.textoSuave),
                      ),
                    ),
                    if (noticia.enlace != null)
                      TextButton.icon(
                        onPressed: () => abrirEnlace(context, noticia.enlace!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Ver fuente'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
