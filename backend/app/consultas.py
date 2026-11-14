"""Consultas de las pantallas de la app. Todas son parametrizadas.

Las que reciben `codigo` leen datos personales: el código sale del token
verificado y, además, las políticas RLS limitan las filas a ese estudiante.
"""

from typing import Any
from urllib.parse import urlsplit

from .db import consultar

AVISO_DEMO = "Datos académicos demostrativos (DEMO); no son registros oficiales de la UNAB."
HOSTS_INTERNOS = {"scraper", "localhost", "127.0.0.1", "n8n"}


# ---------------------------------------------------------------------
# Login y perfil
# ---------------------------------------------------------------------
def autenticar(codigo: str, contrasena: str) -> dict[str, Any] | None:
    """fn_autenticar valida con bcrypt y bloquea 15 min tras 5 intentos fallidos."""
    filas = consultar(
        "select codigo, nombres, apellidos, programa, semestre_actual from fn_autenticar(%s, %s)",
        (codigo, contrasena),
    )
    return filas[0] if filas else None


def perfil(codigo: str) -> dict[str, Any] | None:
    filas = consultar(
        """
        select e.codigo, e.nombres, e.apellidos, pr.nombre as programa, e.semestre_actual
        from estudiante e
        join programa pr on pr.id = e.programa_id
        where e.codigo = %s and e.estado = 'activo'
        """,
        (codigo,),
        estudiante=codigo,
    )
    return filas[0] if filas else None


# ---------------------------------------------------------------------
# Datos del estudiante autenticado
# ---------------------------------------------------------------------
def resumen(codigo: str) -> dict[str, Any] | None:
    datos = perfil(codigo)
    if not datos:
        return None
    insignia = consultar(
        "select pilares_aprobados, pilares_totales, insignia_obtenida from v_estado_insignia where estudiante_codigo = %s",
        (codigo,),
        estudiante=codigo,
    )
    pilares = consultar(
        """
        select pilar_codigo as codigo, pilar as nombre, pilar_aprobado as aprobado,
               cursos_aprobados_nombres as curso_aprobado, cursos_en_curso > 0 as en_curso
        from v_progreso_competencias
        where estudiante_codigo = %s
        order by pilar_id
        """,
        (codigo,),
        estudiante=codigo,
    )
    plan = consultar(
        """
        select creditos_totales, creditos_aprobados, asignaturas_aprobadas,
               asignaturas_pendientes, porcentaje_avance
        from v_avance_plan where estudiante_codigo = %s
        """,
        (codigo,),
        estudiante=codigo,
    )
    proyeccion = consultar(
        """
        select semestres_estimados, creditos_pendientes, max_creditos_semestre, cadena_prerrequisitos
        from v_proyeccion_semestres where estudiante_codigo = %s
        """,
        (codigo,),
        estudiante=codigo,
    )
    return {
        "estudiante": datos,
        "insignia": {**(insignia[0] if insignia else {}), "pilares": pilares},
        "plan_de_estudios": plan[0] if plan else None,
        "proyeccion": proyeccion[0] if proyeccion else None,
        "aviso": AVISO_DEMO,
    }


def historial(codigo: str, tipo: str) -> dict[str, Any]:
    cursos = consultar(
        """
        select periodo, nrc, curso_codigo, curso_nombre, curso_tipo, creditos, pilar,
               estado, nota_final, modalidad
        from v_historial_academico
        where estudiante_codigo = %(codigo)s
          and (%(tipo)s = 'todos' or curso_tipo = %(tipo)s)
        order by periodo desc, curso_tipo desc, curso_nombre
        """,
        {"codigo": codigo, "tipo": tipo},
        estudiante=codigo,
    )
    conteo = {e: sum(1 for c in cursos if c["estado"] == e) for e in ("aprobado", "reprobado", "inscrito", "retirado")}
    return {"resumen": conteo, "cursos": cursos, "aviso": AVISO_DEMO}


def recomendaciones(codigo: str) -> dict[str, Any]:
    filas = consultar(
        """
        select r.pilar, r.curso_codigo, r.curso_nombre, c.descripcion, r.posicion, r.puntaje,
               r.razones,
               coalesce((select array_agg(o.nrc order by o.nrc) from v_oferta_disponible o
                          where o.curso_codigo = r.curso_codigo), '{}') as nrc_disponibles
        from v_recomendacion_cursos r
        join curso c on c.id = r.curso_id
        where r.estudiante_codigo = %s
        order by r.pilar_id, r.posicion
        """,
        (codigo,),
        estudiante=codigo,
    )
    return {"recomendaciones": filas, "aviso": AVISO_DEMO}


# ---------------------------------------------------------------------
# Catálogo, calendario y noticias
# ---------------------------------------------------------------------
def cursos() -> dict[str, Any]:
    pilares = consultar(
        """
        select p.codigo, p.nombre, p.descripcion, p.cursos_requeridos
        from pilar_competencia p
        order by p.orden_visual
        """
    )
    catalogo = consultar(
        """
        select c.codigo, c.nombre, c.descripcion, p.codigo as pilar_codigo
        from curso c
        join pilar_competencia p on p.id = c.pilar_id
        where c.activo and c.tipo = 'competencia_digital'
        order by c.nombre
        """
    )
    oferta = consultar(
        """
        select curso_codigo, nrc, periodo, grupo, modalidad, horario, cupo, cupos_disponibles
        from v_oferta_disponible
        where curso_tipo = 'competencia_digital'
        order by curso_codigo, nrc
        """
    )
    for pilar in pilares:
        pilar["cursos"] = [
            {**c, "secciones": [o for o in oferta if o["curso_codigo"] == c["codigo"]]}
            for c in catalogo
            if c["pilar_codigo"] == pilar["codigo"]
        ]
    return {
        "regla_insignia": (
            "La insignia se obtiene aprobando un curso de cada uno de los tres pilares, "
            "en cualquier orden. Los cursos de competencias digitales no tienen prerrequisitos."
        ),
        "pilares": pilares,
        "aviso": AVISO_DEMO,
    }


def calendario(tipo: str | None, solo_proximos: bool) -> dict[str, Any]:
    eventos = consultar(
        """
        with hoy as (select (now() at time zone 'America/Bogota')::date as fecha)
        select e.id_evento, e.titulo, e.tipo_evento, e.fecha_inicio, e.fecha_fin, e.periodo,
               e.dirigido_a, e.descripcion,
               case when e.fecha_fin < hoy.fecha then 'finalizado'
                    when e.fecha_inicio <= hoy.fecha then 'en_curso'
                    else 'proximo' end as estado,
               e.fecha_inicio - hoy.fecha as dias_para_inicio
        from calendario_evento e, hoy
        where (%(tipo)s::text is null or e.tipo_evento = %(tipo)s)
          and (not %(solo_proximos)s or e.fecha_fin >= hoy.fecha)
        order by e.fecha_inicio, e.id_evento
        """,
        {"tipo": tipo, "solo_proximos": solo_proximos},
    )
    return {"eventos": eventos, "fuente": "Calendario académico DEMO (Google Sheets)"}


def _enlace_publico(url: str) -> str | None:
    """Las noticias DEMO apuntan al scraper interno: no se pueden abrir desde el celular."""
    host = (urlsplit(url).hostname or "").lower()
    return None if host in HOSTS_INTERNOS else url


def noticias(categoria: str | None, limite: int) -> dict[str, Any]:
    filas = consultar(
        """
        select id, titulo, resumen, url, categoria, fecha_publicacion, fuente
        from v_noticias_recientes
        where (%(categoria)s::text is null or categoria = %(categoria)s)
        order by fecha_publicacion desc nulls last, recopilado_en desc
        limit %(limite)s
        """,
        {"categoria": categoria, "limite": limite},
    )
    for fila in filas:
        fila["enlace"] = _enlace_publico(fila.pop("url"))
        fila["demostrativa"] = "DEMO" in (fila["fuente"] or "")
    return {"noticias": filas, "total": len(filas)}


# ---------------------------------------------------------------------
# Conversaciones guardadas (memoria del chat)
# ---------------------------------------------------------------------
def sesiones(codigo: str, limite: int) -> list[dict[str, Any]]:
    return consultar(
        """
        select s.id, s.titulo, s.creada_en, s.ultima_actividad,
               (select count(*) from mensaje_chat m where m.sesion_id = s.id) as mensajes,
               (select left(m.contenido, 140) from mensaje_chat m
                 where m.sesion_id = s.id and m.rol = 'asistente'
                 order by m.creado_en desc, m.id desc limit 1) as ultima_respuesta
        from sesion_chat s
        where s.estudiante_codigo = %s and s.activa
        order by s.ultima_actividad desc
        limit %s
        """,
        (codigo, limite),
        estudiante=codigo,
    )


def mensajes(codigo: str, sesion_id: str) -> list[dict[str, Any]] | None:
    """None si la sesión no existe o es de otro estudiante (RLS la oculta)."""
    existe = consultar(
        "select 1 from sesion_chat where id = %s and activa", (sesion_id,), estudiante=codigo
    )
    if not existe:
        return None
    return consultar(
        """
        select id, rol, contenido, intencion, fuentes, bloqueado, creado_en
        from mensaje_chat
        where sesion_id = %s
        order by creado_en, id
        """,
        (sesion_id,),
        estudiante=codigo,
    )


def archivar_sesion(codigo: str, sesion_id: str) -> bool:
    filas = consultar(
        "update sesion_chat set activa = false where id = %s and activa returning id",
        (sesion_id,),
        estudiante=codigo,
    )
    return bool(filas)
