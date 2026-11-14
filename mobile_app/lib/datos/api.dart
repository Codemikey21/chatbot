import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'modelos.dart';

/// Error de la API con un mensaje listo para mostrar al estudiante.
class ApiError implements Exception {
  const ApiError(this.mensaje, {this.estado});

  final String mensaje;
  final int? estado;

  bool get sesionVencida => estado == 401;

  @override
  String toString() => mensaje;
}

/// Cliente de la API segura (FastAPI). La app no habla con ningún otro servicio.
class ApiCliente {
  ApiCliente({http.Client? cliente}) : _http = cliente ?? http.Client();

  final http.Client _http;

  /// Token de sesión (JWT). Lo pone SesionApp al iniciar sesión.
  String? token;

  /// Se llama cuando una petición con token responde 401 (sesión vencida).
  void Function()? alVencerSesion;

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
    Map<String, String>? consulta,
    Duration? tiempo,
  }) async {
    final uri = Uri.parse('${Config.apiUrl}$ruta').replace(queryParameters: consulta);
    final cabeceras = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response respuesta;
    try {
      final peticion = switch (metodo) {
        'POST' => _http.post(uri, headers: cabeceras, body: jsonEncode(cuerpo ?? {})),
        'DELETE' => _http.delete(uri, headers: cabeceras),
        _ => _http.get(uri, headers: cabeceras),
      };
      respuesta = await peticion.timeout(tiempo ?? Config.tiempoNormal);
    } on TimeoutException {
      throw const ApiError('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } catch (_) {
      throw const ApiError('No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.');
    }

    final texto = utf8.decode(respuesta.bodyBytes);
    dynamic datos;
    if (texto.isNotEmpty) {
      try {
        datos = jsonDecode(texto);
      } on FormatException {
        datos = null;
      }
    }
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return datos;
    }

    final detalle = datos is Map && datos['detail'] is String ? datos['detail'] as String : null;
    if (respuesta.statusCode == 401 && token != null) {
      alVencerSesion?.call();
    }
    throw ApiError(detalle ?? _mensajePorEstado(respuesta.statusCode), estado: respuesta.statusCode);
  }

  static String _mensajePorEstado(int estado) => switch (estado) {
        401 => 'Tu sesión venció. Inicia sesión de nuevo.',
        404 => 'No se encontró la información solicitada.',
        422 => 'Revisa los datos ingresados.',
        429 => 'Estás haciendo muchas solicitudes. Espera un momento.',
        502 || 503 || 504 => 'El servicio no está disponible en este momento. Intenta más tarde.',
        _ => 'Ocurrió un error inesperado ($estado).',
      };

  Map<String, dynamic> _mapa(dynamic datos) => Map<String, dynamic>.from(datos as Map);

  List<Map<String, dynamic>> _listaDe(dynamic datos, String clave) =>
      ((_mapa(datos)[clave] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  // ---------------------------------------------------------------- sesión
  Future<({String token, Estudiante estudiante})> login(String codigo, String contrasena) async {
    final datos = _mapa(await _enviar('POST', '/auth/login', cuerpo: {
      'codigo': codigo.trim().toUpperCase(),
      'contrasena': contrasena,
    }));
    return (
      token: datos['token'] as String,
      estudiante: Estudiante.desdeJson(Map<String, dynamic>.from(datos['estudiante'] as Map)),
    );
  }

  Future<Estudiante> sesion() async => Estudiante.desdeJson(_mapa(await _enviar('GET', '/auth/sesion')));

  // ------------------------------------------------------------ estudiante
  Future<Resumen> resumen() async => Resumen.desdeJson(_mapa(await _enviar('GET', '/estudiante/resumen')));

  Future<List<CursoHistorial>> historial({String tipo = 'todos'}) async =>
      _listaDe(await _enviar('GET', '/estudiante/historial', consulta: {'tipo': tipo}), 'cursos')
          .map(CursoHistorial.desdeJson)
          .toList();

  Future<List<Recomendacion>> recomendaciones() async =>
      _listaDe(await _enviar('GET', '/estudiante/recomendaciones'), 'recomendaciones')
          .map(Recomendacion.desdeJson)
          .toList();

  // ------------------------------------------------------------- contenido
  Future<Catalogo> cursos() async => Catalogo.desdeJson(_mapa(await _enviar('GET', '/cursos')));

  Future<List<Evento>> calendario({bool soloProximos = false}) async =>
      _listaDe(await _enviar('GET', '/calendario', consulta: {'solo_proximos': '$soloProximos'}), 'eventos')
          .map(Evento.desdeJson)
          .toList();

  Future<List<Noticia>> noticias({String? categoria}) async => _listaDe(
        await _enviar('GET', '/noticias', consulta: {'limite': '30', 'categoria': ?categoria}),
        'noticias',
      ).map(Noticia.desdeJson).toList();

  // ------------------------------------------------------------------ chat
  Future<RespuestaChat> enviarMensaje(String mensaje, {String? sesionId}) async => RespuestaChat.desdeJson(
        _mapa(await _enviar(
          'POST',
          '/chat',
          cuerpo: {'mensaje': mensaje, 'sesion_id': sesionId},
          tiempo: Config.tiempoChat,
        )),
      );

  Future<List<SesionChat>> conversaciones() async =>
      _listaDe(await _enviar('GET', '/chat/sesiones'), 'sesiones').map(SesionChat.desdeJson).toList();

  Future<List<MensajeGuardado>> mensajes(String sesionId) async =>
      _listaDe(await _enviar('GET', '/chat/sesiones/$sesionId/mensajes'), 'mensajes')
          .map(MensajeGuardado.desdeJson)
          .toList();

  Future<void> archivarConversacion(String sesionId) async {
    await _enviar('DELETE', '/chat/sesiones/$sesionId');
  }
}
