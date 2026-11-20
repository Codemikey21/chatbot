import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../datos/api.dart';
import '../datos/modelos.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/fechas.dart';
import '../utilidades/navegacion.dart';
import '../widgets/comunes.dart';
import '../widgets/emblema.dart';
import '../widgets/escribiendo.dart';
import 'conversaciones.dart';

// ---------------------------------------------------------------------------
// Estado del chat
// ---------------------------------------------------------------------------

enum TipoMensaje { usuario, asistente, error }

class MensajeVista {
  MensajeVista({
    required this.tipo,
    required this.texto,
    DateTime? hora,
    this.fuentes = const [],
    this.bloqueado = false,
    this.pregunta,
  }) : hora = hora ?? DateTime.now();

  final TipoMensaje tipo;
  final String texto;
  final DateTime hora;
  final List<Fuente> fuentes;
  final bool bloqueado;

  /// En los mensajes de error, la pregunta que se puede reintentar.
  final String? pregunta;
}

/// Mantiene la conversación activa. La memoria real vive en la base de datos:
/// aquí solo se guarda lo que se muestra y el id de la sesión.
class ControladorChat extends ChangeNotifier {
  final List<MensajeVista> mensajes = [];
  String? sesionId;
  bool enviando = false;
  bool cargando = false;

  Future<void> enviar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || enviando) return;
    mensajes.add(MensajeVista(tipo: TipoMensaje.usuario, texto: pregunta));
    await _consultar(pregunta);
  }

  Future<void> reintentar(MensajeVista error) async {
    if (enviando || error.pregunta == null) return;
    mensajes.remove(error);
    await _consultar(error.pregunta!);
  }

  Future<void> _consultar(String pregunta) async {
    enviando = true;
    notifyListeners();
    try {
      final respuesta = await api.enviarMensaje(pregunta, sesionId: sesionId);
      sesionId = respuesta.sesionId;
      mensajes.add(MensajeVista(
        tipo: TipoMensaje.asistente,
        texto: respuesta.respuesta,
        fuentes: respuesta.fuentes,
        bloqueado: respuesta.bloqueado,
      ));
    } on ApiError catch (error) {
      if (!error.sesionVencida) {
        mensajes.add(MensajeVista(tipo: TipoMensaje.error, texto: error.mensaje, pregunta: pregunta));
      }
    } finally {
      enviando = false;
      notifyListeners();
    }
  }

  /// Abre una conversación guardada y la continúa.
  Future<void> abrir(String id) async {
    cargando = true;
    mensajes.clear();
    sesionId = id;
    notifyListeners();
    try {
      final guardados = await api.mensajes(id);
      mensajes.addAll(guardados.map((m) => MensajeVista(
            tipo: m.rol == 'usuario' ? TipoMensaje.usuario : TipoMensaje.asistente,
            texto: m.contenido,
            hora: m.creado,
            fuentes: m.fuentes,
            bloqueado: m.bloqueado && m.rol == 'asistente',
          )));
    } on ApiError catch (error) {
      mensajes.add(MensajeVista(tipo: TipoMensaje.error, texto: error.mensaje));
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  void nueva() {
    if (enviando) return;
    mensajes.clear();
    sesionId = null;
    notifyListeners();
  }

  void limpiar() {
    mensajes.clear();
    sesionId = null;
    enviando = false;
    notifyListeners();
  }
}

final controladorChat = ControladorChat();

const sugerencias = [
  '¿Qué me falta para obtener la insignia de competencias digitales?',
  '¿Cuál me recomiendas del pilar de tecnologías y por qué?',
  '¿Cuándo son las inscripciones y la prueba diagnóstica?',
  '¿Qué cursos de competencias digitales he aprobado?',
  '¿Cuántos semestres me faltan para terminar la carrera?',
  '¿Hay convocatorias o cursos nuevos?',
];

// ---------------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------------

class PantallaChat extends StatefulWidget {
  const PantallaChat({super.key});

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _texto = TextEditingController();
  final _desplazamiento = ScrollController();

  @override
  void initState() {
    super.initState();
    controladorChat.addListener(_alCambiar);
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controladorChat.removeListener(_alCambiar);
    _texto.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_desplazamiento.hasClients) {
        _desplazamiento.animateTo(0, duration: 300.ms, curve: Curves.easeOut);
      }
    });
  }

  void _enviar([String? texto]) {
    final pregunta = (texto ?? _texto.text).trim();
    if (pregunta.isEmpty || controladorChat.enviando) return;
    _texto.clear();
    FocusScope.of(context).unfocus();
    controladorChat.enviar(pregunta);
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = controladorChat.mensajes;
    final enviando = controladorChat.enviando;
    return Scaffold(
      body: Column(
        children: [
          _Cabecera(
            alNueva: controladorChat.nueva,
            alHistorial: () => Navigator.of(context).push(ruta(const PantallaConversaciones())),
          ),
          Expanded(
            child: controladorChat.cargando
                ? const Center(child: CircularProgressIndicator())
                : mensajes.isEmpty && !enviando
                    ? _Bienvenida(alElegir: _enviar)
                    : ListView.builder(
                        controller: _desplazamiento,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: mensajes.length + (enviando ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (enviando && i == 0) return const _BurbujaEscribiendo();
                          final mensaje = mensajes[mensajes.length - 1 - (enviando ? i - 1 : i)];
                          return _Burbuja(mensaje: mensaje, key: ObjectKey(mensaje));
                        },
                      ),
          ),
          _Entrada(
            controlador: _texto,
            habilitado: !enviando,
            alEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.alNueva, required this.alHistorial});

  final VoidCallback alNueva;
  final VoidCallback alHistorial;

  @override
  Widget build(BuildContext context) {
    return EncabezadoCurvo(
      child: Row(
        children: [
          const Emblema(tamano: 42, claro: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Asistente académico',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.4, end: 1, duration: 900.ms),
                    const SizedBox(width: 6),
                    Text('En línea', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Conversaciones anteriores',
            onPressed: alHistorial,
            icon: const Icon(Icons.history_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: alNueva,
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.alElegir});

  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    final nombre = sesion.estudiante?.primerNombre ?? '';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        const Center(child: Emblema(tamano: 76))
            .animate()
            .scale(begin: const Offset(0.6, 0.6), duration: 500.ms, curve: Curves.easeOutBack)
            .then()
            .shimmer(duration: 1200.ms, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          '¡Hola${nombre.isNotEmpty ? ', $nombre' : ''}! Soy tu asistente académico',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
        const SizedBox(height: 6),
        const Text(
          'Respondo con tus datos académicos, los reglamentos, el calendario y las novedades. Prueba con una de estas preguntas:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colores.textoSuave, height: 1.4),
        ).animate().fadeIn(delay: 250.ms),
        const SizedBox(height: 18),
        ...sugerencias.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onTap: () => alElegir(s),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colores.naranja, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Icon(Icons.north_east_rounded, color: Colores.moradoClaro, size: 18),
                  ],
                ),
              ),
            )).toList().animate(interval: 70.ms, delay: 300.ms).fadeIn().slideX(begin: 0.08),
      ],
    );
  }
}

class _BurbujaEscribiendo extends StatelessWidget {
  const _BurbujaEscribiendo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Avatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              boxShadow: Colores.sombraSuave,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PuntosEscribiendo(),
                SizedBox(width: 10),
                Text('Consultando mis fuentes…', style: TextStyle(color: Colores.textoSuave, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.3);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(gradient: Colores.degradadoMorado, shape: BoxShape.circle),
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({super.key, required this.mensaje});

  final MensajeVista mensaje;

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.tipo == TipoMensaje.usuario;
    final ancho = MediaQuery.sizeOf(context).width * 0.8;

    final Widget contenido = switch (mensaje.tipo) {
      TipoMensaje.usuario => Container(
          constraints: BoxConstraints(maxWidth: ancho),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: Colores.degradadoMorado,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(mensaje.texto, style: const TextStyle(color: Colors.white, height: 1.35)),
        ),
      TipoMensaje.asistente => _ContenidoAsistente(mensaje: mensaje, ancho: ancho),
      TipoMensaje.error => _ContenidoError(mensaje: mensaje, ancho: ancho),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!esUsuario) ...[const _Avatar(), const SizedBox(width: 8)],
              Flexible(child: contenido),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, left: esUsuario ? 0 : 42),
            child: Text(hora(mensaje.hora), style: const TextStyle(fontSize: 11, color: Colores.textoSuave)),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: esUsuario ? 0.15 : -0.15, curve: Curves.easeOutCubic);
  }
}

class _ContenidoAsistente extends StatelessWidget {
  const _ContenidoAsistente({required this.mensaje, required this.ancho});

  final MensajeVista mensaje;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final estilo = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(fontSize: 14.5, height: 1.45, color: Colores.texto),
      strong: const TextStyle(fontWeight: FontWeight.w800, color: Colores.moradoOscuro),
      listBullet: const TextStyle(color: Colores.morado),
      h1: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      blockSpacing: 8,
    );
    return Container(
      constraints: BoxConstraints(maxWidth: ancho),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mensaje.bloqueado ? Colores.lavanda : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
        ),
        boxShadow: Colores.sombraSuave,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mensaje.bloqueado)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Colores.morado),
                  SizedBox(width: 6),
                  Text('Protección de datos',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colores.morado)),
                ],
              ),
            ),
          MarkdownBody(
            data: mensaje.texto,
            styleSheet: estilo,
            onTapLink: (texto, enlace, titulo) {
              if (enlace != null) abrirEnlace(context, enlace);
            },
          ),
          if (mensaje.fuentes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Fuentes', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colores.textoSuave)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mensaje.fuentes.map((f) => _ChipFuente(fuente: f)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipFuente extends StatelessWidget {
  const _ChipFuente({required this.fuente});

  final Fuente fuente;

  IconData get _icono => switch (fuente.tipo) {
        'calendario' => Icons.event_rounded,
        'historial' => Icons.school_rounded,
        'noticias' => Icons.campaign_rounded,
        _ => Icons.description_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final detalle = fuente.pagina != null ? ' · p. ${fuente.pagina}' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _verFuente(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colores.lavanda,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colores.borde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono, size: 14, color: Colores.morado),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${fuente.titulo}$detalle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.moradoOscuro),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verFuente(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconoCirculo(icono: _icono),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(fuente.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (fuente.seccion != null) _Dato(etiqueta: 'Sección', valor: fuente.seccion!),
              if (fuente.pagina != null) _Dato(etiqueta: 'Página', valor: '${fuente.pagina}'),
              _Dato(
                etiqueta: 'Origen',
                valor: fuente.demostrativa ? 'Fuente interna del asistente' : 'Documento público',
              ),
              if (fuente.url != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => abrirEnlace(context, fuente.url!),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir documento'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(etiqueta, style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

class _ContenidoError extends StatelessWidget {
  const _ContenidoError({required this.mensaje, required this.ancho});

  final MensajeVista mensaje;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: ancho),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colores.rojoClaro,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colores.rojo, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje.texto, style: const TextStyle(color: Colores.rojo, height: 1.35))),
            ],
          ),
          if (mensaje.pregunta != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => controladorChat.reintentar(mensaje),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(foregroundColor: Colores.rojo),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.controlador, required this.habilitado, required this.alEnviar});

  final TextEditingController controlador;
  final bool habilitado;
  final ValueChanged<String?> alEnviar;

  @override
  Widget build(BuildContext context) {
    final puedeEnviar = habilitado && controlador.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colores.moradoOscuro.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controlador,
                enabled: habilitado,
                minLines: 1,
                maxLines: 4,
                maxLength: Config.maxCaracteresMensaje,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => alEnviar(null),
                decoration: InputDecoration(
                  hintText: habilitado ? 'Escribe tu pregunta…' : 'El asistente está respondiendo…',
                  counterText: '',
                  fillColor: Colores.fondo,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colores.moradoClaro),
                  ),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: puedeEnviar ? 1 : 0.88,
              duration: 200.ms,
              child: IconButton.filled(
                onPressed: puedeEnviar ? () => alEnviar(null) : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colores.naranja,
                  disabledBackgroundColor: Colores.borde,
                  minimumSize: const Size(50, 50),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> abrirEnlace(BuildContext context, String enlace) async {
  final uri = Uri.tryParse(enlace);
  final abierto = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!abierto && context.mounted) {
    mostrarMensaje(context, 'No se pudo abrir el enlace.');
  }
}
