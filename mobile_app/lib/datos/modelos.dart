/// Modelos de los datos que entrega la API. Los constructores `desdeJson`
/// toleran campos vacíos para que una respuesta incompleta no rompa la pantalla.
library;

import '../utilidades/fechas.dart';

String _texto(Object? valor, [String defecto = '']) => valor?.toString() ?? defecto;
int _entero(Object? valor) => valor is num ? valor.toInt() : int.tryParse('$valor') ?? 0;
double _decimal(Object? valor) => valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0;
List<Map<String, dynamic>> _lista(Object? valor) =>
    valor is List ? valor.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

class Estudiante {
  const Estudiante({
    required this.codigo,
    required this.nombres,
    required this.apellidos,
    required this.programa,
    required this.semestre,
  });

  final String codigo;
  final String nombres;
  final String apellidos;
  final String programa;
  final int semestre;

  String get primerNombre => nombres.split(' ').first;
  String get nombreCompleto => '$nombres $apellidos';
  String get iniciales =>
      '${nombres.isNotEmpty ? nombres[0] : ''}${apellidos.isNotEmpty ? apellidos[0] : ''}'.toUpperCase();

  factory Estudiante.desdeJson(Map<String, dynamic> json) => Estudiante(
        codigo: _texto(json['codigo']),
        nombres: _texto(json['nombres']),
        apellidos: _texto(json['apellidos']),
        programa: _texto(json['programa']),
        semestre: _entero(json['semestre_actual']),
      );
}

class PilarProgreso {
  const PilarProgreso({
    required this.codigo,
    required this.nombre,
    required this.aprobado,
    required this.enCurso,
    this.cursoAprobado,
  });

  final String codigo;
  final String nombre;
  final bool aprobado;
  final bool enCurso;
  final String? cursoAprobado;

  factory PilarProgreso.desdeJson(Map<String, dynamic> json) => PilarProgreso(
        codigo: _texto(json['codigo']),
        nombre: _texto(json['nombre']),
        aprobado: json['aprobado'] == true,
        enCurso: json['en_curso'] == true,
        cursoAprobado: (json['curso_aprobado'] as String?)?.isNotEmpty == true ? json['curso_aprobado'] as String : null,
      );
}

class Resumen {
  const Resumen({
    required this.estudiante,
    required this.pilaresAprobados,
    required this.pilaresTotales,
    required this.insigniaObtenida,
    required this.pilares,
    required this.creditosTotales,
    required this.creditosAprobados,
    required this.asignaturasAprobadas,
    required this.asignaturasPendientes,
    required this.porcentajeAvance,
    required this.semestresEstimados,
    required this.creditosPendientes,
    required this.maxCreditosSemestre,
    required this.aviso,
  });

  final Estudiante estudiante;
  final int pilaresAprobados;
  final int pilaresTotales;
  final bool insigniaObtenida;
  final List<PilarProgreso> pilares;
  final int creditosTotales;
  final int creditosAprobados;
  final int asignaturasAprobadas;
  final int asignaturasPendientes;
  final double porcentajeAvance;
  final int semestresEstimados;
  final int creditosPendientes;
  final int maxCreditosSemestre;
  final String aviso;

  factory Resumen.desdeJson(Map<String, dynamic> json) {
    final insignia = Map<String, dynamic>.from(json['insignia'] as Map? ?? {});
    final plan = Map<String, dynamic>.from(json['plan_de_estudios'] as Map? ?? {});
    final proyeccion = Map<String, dynamic>.from(json['proyeccion'] as Map? ?? {});
    return Resumen(
      estudiante: Estudiante.desdeJson(Map<String, dynamic>.from(json['estudiante'] as Map)),
      pilaresAprobados: _entero(insignia['pilares_aprobados']),
      pilaresTotales: _entero(insignia['pilares_totales']),
      insigniaObtenida: insignia['insignia_obtenida'] == true,
      pilares: _lista(insignia['pilares']).map(PilarProgreso.desdeJson).toList(),
      creditosTotales: _entero(plan['creditos_totales']),
      creditosAprobados: _entero(plan['creditos_aprobados']),
      asignaturasAprobadas: _entero(plan['asignaturas_aprobadas']),
      asignaturasPendientes: _entero(plan['asignaturas_pendientes']),
      porcentajeAvance: _decimal(plan['porcentaje_avance']),
      semestresEstimados: _entero(proyeccion['semestres_estimados']),
      creditosPendientes: _entero(proyeccion['creditos_pendientes']),
      maxCreditosSemestre: _entero(proyeccion['max_creditos_semestre']),
      aviso: _texto(json['aviso']),
    );
  }
}

class CursoHistorial {
  const CursoHistorial({
    required this.periodo,
    required this.nrc,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.creditos,
    required this.estado,
    this.pilar,
    this.nota,
    this.modalidad,
  });

  final String periodo;
  final int nrc;
  final String codigo;
  final String nombre;
  final String tipo;
  final int creditos;
  final String estado;
  final String? pilar;
  final double? nota;
  final String? modalidad;

  bool get esCompetenciaDigital => tipo == 'competencia_digital';

  factory CursoHistorial.desdeJson(Map<String, dynamic> json) => CursoHistorial(
        periodo: _texto(json['periodo']),
        nrc: _entero(json['nrc']),
        codigo: _texto(json['curso_codigo']),
        nombre: _texto(json['curso_nombre']),
        tipo: _texto(json['curso_tipo']),
        creditos: _entero(json['creditos']),
        estado: _texto(json['estado']),
        pilar: json['pilar'] as String?,
        nota: json['nota_final'] == null ? null : _decimal(json['nota_final']),
        modalidad: json['modalidad'] as String?,
      );
}

class Recomendacion {
  const Recomendacion({
    required this.pilar,
    required this.codigo,
    required this.nombre,
    required this.posicion,
    required this.puntaje,
    required this.razones,
    required this.nrcDisponibles,
    this.descripcion,
  });

  final String pilar;
  final String codigo;
  final String nombre;
  final int posicion;
  final int puntaje;
  final List<String> razones;
  final List<int> nrcDisponibles;
  final String? descripcion;

  factory Recomendacion.desdeJson(Map<String, dynamic> json) {
    final razones = <String>[];
    for (final r in (json['razones'] as List? ?? [])) {
      if (r is Map && r['razon'] != null) {
        razones.add(r['razon'].toString());
      } else if (r is String) {
        razones.add(r);
      }
    }
    return Recomendacion(
      pilar: _texto(json['pilar']),
      codigo: _texto(json['curso_codigo']),
      nombre: _texto(json['curso_nombre']),
      posicion: _entero(json['posicion']),
      puntaje: _entero(json['puntaje']),
      razones: razones,
      nrcDisponibles: (json['nrc_disponibles'] as List? ?? []).map(_entero).toList(),
      descripcion: json['descripcion'] as String?,
    );
  }
}

class Seccion {
  const Seccion({
    required this.nrc,
    required this.periodo,
    required this.grupo,
    required this.modalidad,
    required this.horario,
    required this.cupo,
    required this.cuposDisponibles,
  });

  final int nrc;
  final String periodo;
  final String grupo;
  final String modalidad;
  final String horario;
  final int cupo;
  final int cuposDisponibles;

  factory Seccion.desdeJson(Map<String, dynamic> json) => Seccion(
        nrc: _entero(json['nrc']),
        periodo: _texto(json['periodo']),
        grupo: _texto(json['grupo']),
        modalidad: _texto(json['modalidad']),
        horario: _texto(json['horario'], 'Por definir'),
        cupo: _entero(json['cupo']),
        cuposDisponibles: _entero(json['cupos_disponibles']),
      );
}

class CursoCatalogo {
  const CursoCatalogo({
    required this.codigo,
    required this.nombre,
    required this.secciones,
    this.descripcion,
  });

  final String codigo;
  final String nombre;
  final String? descripcion;
  final List<Seccion> secciones;

  factory CursoCatalogo.desdeJson(Map<String, dynamic> json) => CursoCatalogo(
        codigo: _texto(json['codigo']),
        nombre: _texto(json['nombre']),
        descripcion: json['descripcion'] as String?,
        secciones: _lista(json['secciones']).map(Seccion.desdeJson).toList(),
      );
}

class PilarCatalogo {
  const PilarCatalogo({
    required this.codigo,
    required this.nombre,
    required this.cursos,
    this.descripcion,
  });

  final String codigo;
  final String nombre;
  final String? descripcion;
  final List<CursoCatalogo> cursos;

  factory PilarCatalogo.desdeJson(Map<String, dynamic> json) => PilarCatalogo(
        codigo: _texto(json['codigo']),
        nombre: _texto(json['nombre']),
        descripcion: json['descripcion'] as String?,
        cursos: _lista(json['cursos']).map(CursoCatalogo.desdeJson).toList(),
      );
}

class Catalogo {
  const Catalogo({required this.regla, required this.pilares, required this.aviso});

  final String regla;
  final List<PilarCatalogo> pilares;
  final String aviso;

  factory Catalogo.desdeJson(Map<String, dynamic> json) => Catalogo(
        regla: _texto(json['regla_insignia']),
        pilares: _lista(json['pilares']).map(PilarCatalogo.desdeJson).toList(),
        aviso: _texto(json['aviso']),
      );
}

class Evento {
  const Evento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.inicio,
    required this.fin,
    required this.estado,
    required this.diasParaInicio,
    this.periodo,
    this.dirigidoA,
    this.descripcion,
  });

  final String id;
  final String titulo;
  final String tipo;
  final DateTime inicio;
  final DateTime fin;
  final String estado;
  final int diasParaInicio;
  final String? periodo;
  final String? dirigidoA;
  final String? descripcion;

  bool ocurreEl(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return !d.isBefore(DateTime(inicio.year, inicio.month, inicio.day)) &&
        !d.isAfter(DateTime(fin.year, fin.month, fin.day));
  }

  factory Evento.desdeJson(Map<String, dynamic> json) {
    final inicio = leerFecha(json['fecha_inicio']) ?? DateTime.now();
    return Evento(
      id: _texto(json['id_evento']),
      titulo: _texto(json['titulo']),
      tipo: _texto(json['tipo_evento']),
      inicio: inicio,
      fin: leerFecha(json['fecha_fin']) ?? inicio,
      estado: _texto(json['estado'], 'proximo'),
      diasParaInicio: _entero(json['dias_para_inicio']),
      periodo: json['periodo'] as String?,
      dirigidoA: json['dirigido_a'] as String?,
      descripcion: json['descripcion'] as String?,
    );
  }
}

class Noticia {
  const Noticia({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.fuente,
    required this.demostrativa,
    this.resumen,
    this.fecha,
    this.enlace,
  });

  final int id;
  final String titulo;
  final String categoria;
  final String fuente;
  final bool demostrativa;
  final String? resumen;
  final DateTime? fecha;
  final String? enlace;

  factory Noticia.desdeJson(Map<String, dynamic> json) => Noticia(
        id: _entero(json['id']),
        titulo: _texto(json['titulo']),
        categoria: _texto(json['categoria'], 'noticia'),
        fuente: _texto(json['fuente']),
        demostrativa: json['demostrativa'] == true,
        resumen: json['resumen'] as String?,
        fecha: leerFecha(json['fecha_publicacion']),
        enlace: json['enlace'] as String?,
      );
}

class Fuente {
  const Fuente({required this.tipo, required this.titulo, this.pagina, this.seccion, this.url, this.origen});

  final String tipo;
  final String titulo;
  final int? pagina;
  final String? seccion;
  final String? url;
  final String? origen;

  bool get demostrativa => origen == 'demostrativo';

  factory Fuente.desdeJson(Map<String, dynamic> json) => Fuente(
        tipo: _texto(json['tipo'], 'documento'),
        titulo: _texto(json['titulo'], 'Fuente'),
        pagina: json['pagina'] == null ? null : _entero(json['pagina']),
        seccion: json['seccion'] as String?,
        url: json['url'] as String?,
        origen: json['origen'] as String?,
      );
}

class RespuestaChat {
  const RespuestaChat({
    required this.sesionId,
    required this.respuesta,
    required this.intenciones,
    required this.fuentes,
    required this.herramientas,
    required this.bloqueado,
    this.intencion,
  });

  final String sesionId;
  final String respuesta;
  final String? intencion;
  final List<String> intenciones;
  final List<Fuente> fuentes;
  final List<String> herramientas;
  final bool bloqueado;

  factory RespuestaChat.desdeJson(Map<String, dynamic> json) => RespuestaChat(
        sesionId: _texto(json['sesion_id']),
        respuesta: _texto(json['respuesta']),
        intencion: json['intencion'] as String?,
        intenciones: (json['intenciones'] as List? ?? []).map((e) => e.toString()).toList(),
        fuentes: _lista(json['fuentes']).map(Fuente.desdeJson).toList(),
        herramientas: (json['herramientas'] as List? ?? []).map((e) => e.toString()).toList(),
        bloqueado: json['bloqueado'] == true,
      );
}

class SesionChat {
  const SesionChat({
    required this.id,
    required this.titulo,
    required this.ultimaActividad,
    required this.mensajes,
    this.ultimaRespuesta,
  });

  final String id;
  final String titulo;
  final DateTime ultimaActividad;
  final int mensajes;
  final String? ultimaRespuesta;

  factory SesionChat.desdeJson(Map<String, dynamic> json) => SesionChat(
        id: _texto(json['id']),
        titulo: _texto(json['titulo'], 'Conversación'),
        ultimaActividad: leerFecha(json['ultima_actividad']) ?? DateTime.now(),
        mensajes: _entero(json['mensajes']),
        ultimaRespuesta: json['ultima_respuesta'] as String?,
      );
}

class MensajeGuardado {
  const MensajeGuardado({
    required this.rol,
    required this.contenido,
    required this.fuentes,
    required this.bloqueado,
    required this.creado,
  });

  final String rol;
  final String contenido;
  final List<Fuente> fuentes;
  final bool bloqueado;
  final DateTime creado;

  factory MensajeGuardado.desdeJson(Map<String, dynamic> json) => MensajeGuardado(
        rol: _texto(json['rol']),
        contenido: _texto(json['contenido']),
        fuentes: _lista(json['fuentes']).map(Fuente.desdeJson).toList(),
        bloqueado: json['bloqueado'] == true,
        creado: leerFecha(json['creado_en']) ?? DateTime.now(),
      );
}
