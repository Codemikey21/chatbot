"""Consultas académicas que exponen las herramientas MCP.

Todas las consultas son parametrizadas y de solo lectura. Las funciones que
reciben `codigo` consultan datos personales: el código ya viene verificado
desde el token de sesión y, además, el RLS de la base limita las filas.
"""

import unicodedata
from typing import Any

from .db import consultar

AVISO_DEMO = "Datos académicos demostrativos (DEMO); no son registros oficiales de la UNAB."


def normalizar(texto: str) -> str:
    """Minúsculas y sin tildes, para comparar nombres escritos por el usuario."""
    sin_tildes = unicodedata.normalize("NFKD", texto or "")
    return "".join(c for c in sin_tildes if not unicodedata.combining(c)).lower().strip()


# ---------------------------------------------------------------------
# Catálogo y pilares
# ---------------------------------------------------------------------
def resolver_pilar(pilar: str | None) -> dict[str, Any] | None:
    """Encuentra un pilar por código o por parte de su nombre."""
    if not pilar:
        return None
    buscado = normalizar(pilar)
    pilares = consultar("select id, codigo, nombre from pilar_competencia order by orden_visual")
    for p in pilares:
        if buscado in (normalizar(p["codigo"]), normalizar(p["nombre"])):
            return p
    for p in pilares:
        if buscado in normalizar(p["nombre"]) or buscado in normalizar(p["codigo"]):
            return p
    raise ValueError(
        "Pilar no reconocido. Opciones: " + ", ".join(p["nombre"] for p in pilares)
    )


def resolver_curso(curso: str) -> dict[str, Any]:
    """Encuentra un curso por código exacto o por nombre (sin importar tildes)."""
    buscado = normalizar(curso)
    if not buscado:
        raise ValueError("Indica el nombre o el código del curso.")
    cursos = consultar(
        """
        select c.id, c.codigo, c.nombre, c.tipo, c.creditos, c.descripcion,
               p.nombre as pilar, pe.semestre, pe.creditos_minimos_previos
        from curso c
        left join pilar_competencia p on p.id = c.pilar_id
        left join plan_estudio pe on pe.curso_id = c.id
        where c.activo
        """
    )
    exactos = [c for c in cursos if buscado in (normalizar(c["codigo"]), normalizar(c["nombre"]))]
    if exactos:
        return exactos[0]
    parciales = [c for c in cursos if buscado in normalizar(c["nombre"])]
    if len(parciales) == 1:
        return parciales[0]
    if len(parciales) > 1:
        raise ValueError(
            "Hay varios cursos que coinciden: " + ", ".join(c["nombre"] for c in parciales[:8])
        )
    raise ValueError(f"No encontré un curso llamado '{curso}'.")


def cursos_disponibles(pilar: str | None = None, incluir_asignaturas: bool = False) -> dict[str, Any]:
    pilar_info = resolver_pilar(pilar)
    filas = consultar(
        """
        select o.nrc, o.periodo, o.curso_codigo, o.curso_nombre, o.curso_tipo, o.pilar,
               o.creditos, o.grupo, o.modalidad, o.horario, o.cupo, o.cupos_disponibles,
               c.descripcion
        from v_oferta_disponible o
        join curso c on c.codigo = o.curso_codigo
        where (%(tipo)s::text is null or o.curso_tipo = %(tipo)s)
          and (%(pilar)s::text is null or o.pilar = %(pilar)s)
        order by o.curso_tipo desc, o.pilar nulls last, o.curso_nombre
        """,
        {
            "tipo": None if incluir_asignaturas else "competencia_digital",
            "pilar": pilar_info["nombre"] if pilar_info else None,
        },
    )
    pilares = consultar(
        """
        select p.codigo, p.nombre, p.descripcion, p.cursos_requeridos,
               array_agg(c.nombre order by c.nombre) as cursos
        from pilar_competencia p
        join curso c on c.pilar_id = p.id and c.activo
        group by p.id
        order by p.orden_visual
        """
    )
    return {
        "regla_insignia": (
            "La insignia de competencias digitales se obtiene aprobando un curso de cada uno de "
            "los tres pilares, en cualquier orden. Los cursos digitales no tienen prerrequisitos."
        ),
        "pilares": pilares,
        "oferta": filas,
        "total_secciones": len(filas),
        "aviso": AVISO_DEMO,
    }


def requisitos_de_curso(curso: str, codigo: str | None = None) -> dict[str, Any]:
    info = resolver_curso(curso)
    if info["tipo"] == "competencia_digital":
        return {
            "curso": info["nombre"],
            "tipo": "competencia digital",
            "pilar": info["pilar"],
            "requisitos": [],
            "explicacion": (
                "Los cursos de competencias digitales no tienen prerrequisitos. Cada pilar se "
                "aprueba con un curso y los pilares se pueden cursar en cualquier orden."
            ),
            "aviso": AVISO_DEMO,
        }

    requisitos = consultar(
        """
        select rc.codigo, rc.nombre, r.tipo
        from requisito r
        join curso rc on rc.id = r.requiere_curso_id
        where r.curso_id = %s
        order by r.tipo, rc.nombre
        """,
        (info["id"],),
    )
    respuesta: dict[str, Any] = {
        "curso": info["nombre"],
        "codigo": info["codigo"],
        "creditos": info["creditos"],
        "semestre_sugerido": info["semestre"],
        "prerrequisitos": [r["nombre"] for r in requisitos if r["tipo"] == "prerrequisito"],
        "correquisitos": [r["nombre"] for r in requisitos if r["tipo"] == "correquisito"],
        "creditos_minimos_previos": info["creditos_minimos_previos"] or 0,
        "aviso": "Prerrequisitos DEMO. " + AVISO_DEMO,
    }

    if codigo:
        estado = consultar(
            """
            select en_curso, prerrequisitos_faltantes, creditos_aprobados, habilitada
            from v_asignaturas_pendientes
            where estudiante_codigo = %s and curso_id = %s
            """,
            (codigo, info["id"]),
            estudiante=codigo,
        )
        if estado:
            respuesta["estado_estudiante"] = {
                "aprobada": False,
                "en_curso": estado[0]["en_curso"],
                "prerrequisitos_faltantes": estado[0]["prerrequisitos_faltantes"],
                "creditos_aprobados": estado[0]["creditos_aprobados"],
                "puede_matricularla": estado[0]["habilitada"],
            }
        else:
            respuesta["estado_estudiante"] = {"aprobada": True}
    return respuesta


# ---------------------------------------------------------------------
# Datos personales del estudiante autenticado
# ---------------------------------------------------------------------
def historial(codigo: str, tipo: str = "todos") -> dict[str, Any]:
    if tipo not in ("todos", "competencia_digital", "asignatura"):
        raise ValueError("tipo debe ser 'todos', 'competencia_digital' o 'asignatura'.")
    filas = consultar(
        """
        select periodo, nrc, curso_codigo, curso_nombre, curso_tipo, creditos, pilar,
               estado, nota_final, modalidad
        from v_historial_academico
        where estudiante_codigo = %(codigo)s
          and (%(tipo)s = 'todos' or curso_tipo = %(tipo)s)
        order by periodo, curso_tipo desc, curso_nombre
        """,
        {"codigo": codigo, "tipo": tipo},
        estudiante=codigo,
    )
    resumen = {
        estado: sum(1 for f in filas if f["estado"] == estado)
        for estado in ("aprobado", "reprobado", "inscrito", "retirado")
    }
    return {"estudiante": codigo, "resumen": resumen, "cursos": filas, "aviso": AVISO_DEMO}


def progreso(codigo: str) -> dict[str, Any]:
    perfil = consultar(
        """
        select e.codigo, e.nombres, e.apellidos, e.semestre_actual, pr.nombre as programa
        from estudiante e join programa pr on pr.id = e.programa_id
        where e.codigo = %s
        """,
        (codigo,),
        estudiante=codigo,
    )
    if not perfil:
        raise ValueError("No se encontró información para este estudiante.")

    insignia = consultar(
        "select * from v_estado_insignia where estudiante_codigo = %s", (codigo,), estudiante=codigo
    )
    pilares = consultar(
        """
        select pilar, cursos_requeridos, cursos_aprobados, cursos_aprobados_nombres,
               cursos_en_curso, pilar_aprobado
        from v_progreso_competencias
        where estudiante_codigo = %s
        order by pilar_id
        """,
        (codigo,),
        estudiante=codigo,
    )
    plan = consultar(
        "select * from v_avance_plan where estudiante_codigo = %s", (codigo,), estudiante=codigo
    )
    proyeccion = consultar(
        "select * from v_proyeccion_semestres where estudiante_codigo = %s",
        (codigo,),
        estudiante=codigo,
    )
    habilitadas = consultar(
        """
        select curso_nombre, creditos, semestre
        from v_asignaturas_pendientes
        where estudiante_codigo = %s and habilitada and not en_curso
        order by semestre, curso_nombre
        """,
        (codigo,),
        estudiante=codigo,
    )
    # Próximo semestre: supone que aprueba lo que cursa ahora y respeta el máximo de créditos
    proximas = consultar(
        """
        select curso_nombre, creditos, semestre, depende_de_en_curso
        from v_asignaturas_pendientes
        where estudiante_codigo = %s and habilitada_proximo_periodo and not en_curso
        order by semestre, curso_nombre
        """,
        (codigo,),
        estudiante=codigo,
    )
    maximo = int(proyeccion[0]["max_creditos_semestre"]) if proyeccion else 20
    sugeridas, otras, total = [], [], 0
    for asignatura in proximas:
        if total + asignatura["creditos"] <= maximo:
            sugeridas.append(asignatura)
            total += asignatura["creditos"]
        else:
            otras.append(asignatura)

    return {
        "estudiante": perfil[0],
        "competencias_digitales": {
            "insignia_obtenida": insignia[0]["insignia_obtenida"],
            "pilares_aprobados": insignia[0]["pilares_aprobados"],
            "pilares_totales": insignia[0]["pilares_totales"],
            "pilares_pendientes": insignia[0]["pilares_pendientes"],
            "detalle_por_pilar": pilares,
        },
        "plan_de_estudios": plan[0],
        "proyeccion": {
            **proyeccion[0],
            "explicacion": (
                "Estimación: el mayor valor entre los créditos pendientes divididos por el máximo "
                "de créditos por semestre y la cadena de prerrequisitos pendientes más larga. "
                "Incluye las asignaturas que cursa actualmente."
            ),
        },
        "asignaturas_que_puede_matricular": habilitadas,
        "matricula_proximo_semestre": {
            "supuesto": "Supone que el estudiante aprueba las asignaturas que cursa este semestre.",
            "maximo_creditos": maximo,
            "creditos_sugeridos": total,
            "asignaturas_sugeridas": sugeridas,
            "otras_habilitadas": otras,
        },
        "aviso": AVISO_DEMO,
    }


def recomendaciones(codigo: str, pilar: str | None = None) -> dict[str, Any]:
    pilar_info = resolver_pilar(pilar)
    filas = consultar(
        """
        select r.pilar, r.curso_codigo, r.curso_nombre, r.posicion, r.puntaje,
               r.afinidad_maxima, r.razones, c.descripcion,
               (select array_agg(o.nrc order by o.nrc) from v_oferta_disponible o
                 where o.curso_codigo = r.curso_codigo) as nrc_disponibles
        from v_recomendacion_cursos r
        join curso c on c.id = r.curso_id
        where r.estudiante_codigo = %(codigo)s
          and (%(pilar)s::text is null or r.pilar = %(pilar)s)
        order by r.pilar_id, r.posicion
        """,
        {"codigo": codigo, "pilar": pilar_info["nombre"] if pilar_info else None},
        estudiante=codigo,
    )
    if not filas:
        estado = consultar(
            "select insignia_obtenida from v_estado_insignia where estudiante_codigo = %s",
            (codigo,),
            estudiante=codigo,
        )
        mensaje = (
            "El estudiante ya obtuvo la insignia: no tiene pilares pendientes."
            if estado and estado[0]["insignia_obtenida"]
            else "El pilar indicado ya está aprobado o ya cursa un curso de ese pilar."
        )
        return {"estudiante": codigo, "recomendaciones": [], "mensaje": mensaje, "aviso": AVISO_DEMO}
    return {
        "estudiante": codigo,
        "criterio": (
            "Se recomiendan cursos de los pilares pendientes, ordenados por su relación con las "
            "asignaturas del pensum: pesa más si el estudiante ya aprobó o está cursando esas "
            "asignaturas."
        ),
        "recomendaciones": filas,
        "aviso": AVISO_DEMO,
    }


# ---------------------------------------------------------------------
# Calendario y noticias
# ---------------------------------------------------------------------
def calendario(tipo_evento: str | None = None, solo_proximos: bool = True, limite: int = 10) -> dict[str, Any]:
    limite = max(1, min(int(limite), 30))
    tabla = "v_proximos_eventos" if solo_proximos else "calendario_evento"
    filas = consultar(
        f"""
        select id_evento, titulo, tipo_evento, fecha_inicio, fecha_fin, periodo,
               dirigido_a, descripcion
        from {tabla}
        where (%(tipo)s::text is null or tipo_evento = %(tipo)s)
        order by fecha_inicio
        limit %(limite)s
        """,
        {"tipo": tipo_evento, "limite": limite},
    )
    hoy = consultar("select (now() at time zone 'America/Bogota')::date as hoy")[0]["hoy"]
    return {
        "fecha_de_hoy": hoy,
        "eventos": filas,
        "fuente": "Calendario académico DEMO sincronizado desde Google Sheets.",
    }


def noticias(categoria: str | None = None, limite: int = 5) -> dict[str, Any]:
    limite = max(1, min(int(limite), 20))
    filas = consultar(
        """
        select titulo, resumen, url, categoria, fecha_publicacion, fuente
        from v_noticias_recientes
        where (%(categoria)s::text is null or categoria = %(categoria)s)
        order by fecha_publicacion desc nulls last, recopilado_en desc
        limit %(limite)s
        """,
        {"categoria": categoria, "limite": limite},
    )
    return {"noticias": filas, "total": len(filas)}
