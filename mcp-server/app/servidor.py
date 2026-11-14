"""Servidor MCP (FastMCP) con las herramientas de consulta académica.

Transporte: HTTP streamable en el puerto MCP_PORT (9000), ruta /mcp.
Acceso: token Bearer (MCP_AUTH_TOKEN). Datos personales: token de sesión
del estudiante (JWT firmado por la API) + RLS en la base de datos.
"""

import logging
import time
from functools import wraps
from typing import Annotated, Any, Literal

from fastmcp import FastMCP
from fastmcp.exceptions import ToolError
from pydantic import Field
from starlette.requests import Request
from starlette.responses import JSONResponse

from . import herramientas as h
from .config import Configuracion
from .db import cerrar_pool, iniciar_pool, verificar_conexion
from .seguridad import TokenDeServicio, estudiante_desde_token

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("mcp")

config = Configuracion()

INSTRUCCIONES = (
    "Herramientas de solo lectura del chatbot de apoyo académico (Ingeniería de Sistemas). "
    "Las herramientas que reciben token_sesion devuelven datos del estudiante autenticado; "
    "el token lo entrega la API y no debe pedirse ni inventarse. Los datos son DEMO."
)

mcp = FastMCP(
    name="chatbot-academico",
    instructions=INSTRUCCIONES,
    auth=TokenDeServicio(config.token_acceso),
    mask_error_details=True,
)

SOLO_LECTURA = {"readOnlyHint": True, "destructiveHint": False, "openWorldHint": False}

TokenSesion = Annotated[str, Field(description="Token de sesión (JWT) del estudiante emitido por la API.")]
Pilar = Annotated[
    str | None,
    Field(description="Pilar: 'basicas', 'analitica' o 'tecnologias' (o parte de su nombre)."),
]


def registrar(nombre: str):
    """Mide la duración de cada herramienta y convierte errores esperados en ToolError."""

    def decorador(funcion):
        @wraps(funcion)
        def envoltura(*args, **kwargs):
            inicio = time.perf_counter()
            try:
                return funcion(*args, **kwargs)
            except ToolError:
                log.warning("herramienta=%s resultado=rechazada", nombre)
                raise
            except ValueError as error:
                log.info("herramienta=%s resultado=dato_invalido", nombre)
                raise ToolError(str(error)) from error
            finally:
                log.info("herramienta=%s duracion_ms=%.0f", nombre, (time.perf_counter() - inicio) * 1000)

        return envoltura

    return decorador


def _estudiante(token_sesion: str) -> str:
    return estudiante_desde_token(
        token_sesion, config.jwt_secreto, config.jwt_emisor, config.jwt_audiencia
    )


# ---------------------------------------------------------------------
# Herramientas públicas (sin datos personales)
# ---------------------------------------------------------------------
@mcp.tool(annotations=SOLO_LECTURA)
@registrar("consultar_cursos_disponibles")
def consultar_cursos_disponibles(
    pilar: Pilar = None,
    incluir_asignaturas: Annotated[
        bool, Field(description="Si es verdadero, incluye también las asignaturas del pensum.")
    ] = False,
) -> dict[str, Any]:
    """Cursos de competencias digitales disponibles para inscripción (NRC, cupos, modalidad),
    los tres pilares y la regla para obtener la insignia."""
    return h.cursos_disponibles(pilar, incluir_asignaturas)


@mcp.tool(annotations=SOLO_LECTURA)
@registrar("obtener_requisitos")
def obtener_requisitos(
    curso: Annotated[str, Field(description="Nombre o código del curso, por ejemplo 'Cálculo Integral'.")],
    token_sesion: Annotated[
        str | None,
        Field(description="Opcional. Si se envía, indica qué requisitos le faltan al estudiante."),
    ] = None,
) -> dict[str, Any]:
    """Prerrequisitos, correquisitos y créditos mínimos de un curso. Con token de sesión,
    también dice si el estudiante ya puede matricularlo."""
    codigo = _estudiante(token_sesion) if token_sesion else None
    return h.requisitos_de_curso(curso, codigo)


@mcp.tool(annotations=SOLO_LECTURA)
@registrar("consultar_calendario")
def consultar_calendario(
    tipo_evento: Annotated[
        str | None,
        Field(description=(
            "Filtra por tipo: inscripcion, prueba_diagnostica, resultados, inicio_curso, fin_curso, "
            "evaluacion, retiro, certificacion, matricula, inicio_clases o receso."
        )),
    ] = None,
    solo_proximos: Annotated[bool, Field(description="Solo eventos que no han terminado.")] = True,
    limite: Annotated[int, Field(ge=1, le=30, description="Máximo de eventos.")] = 10,
) -> dict[str, Any]:
    """Eventos del calendario académico (inscripciones, pruebas diagnósticas, inicio de cursos,
    entrega de insignias) con sus fechas."""
    return h.calendario(tipo_evento, solo_proximos, limite)


@mcp.tool(annotations=SOLO_LECTURA)
@registrar("consultar_noticias")
def consultar_noticias(
    categoria: Annotated[
        Literal["curso", "convocatoria", "certificacion", "noticia"] | None,
        Field(description="Filtra por categoría."),
    ] = None,
    limite: Annotated[int, Field(ge=1, le=20, description="Máximo de noticias.")] = 5,
) -> dict[str, Any]:
    """Noticias, convocatorias y nuevos cursos recopilados por el scraper, con su enlace y fecha."""
    return h.noticias(categoria, limite)


# ---------------------------------------------------------------------
# Herramientas personales (requieren el token de sesión del estudiante)
# ---------------------------------------------------------------------
@mcp.tool(annotations=SOLO_LECTURA)
@registrar("consultar_historial")
def consultar_historial(
    token_sesion: TokenSesion,
    tipo: Annotated[
        Literal["todos", "competencia_digital", "asignatura"],
        Field(description="Filtra el historial por tipo de curso."),
    ] = "todos",
) -> dict[str, Any]:
    """Historial académico del estudiante autenticado: cursos por periodo, NRC, estado y nota."""
    return h.historial(_estudiante(token_sesion), tipo)


@mcp.tool(annotations=SOLO_LECTURA)
@registrar("consultar_progreso")
def consultar_progreso(token_sesion: TokenSesion) -> dict[str, Any]:
    """Progreso del estudiante autenticado: pilares e insignia de competencias digitales,
    avance del pensum, semestres restantes estimados y asignaturas que puede matricular."""
    return h.progreso(_estudiante(token_sesion))


@mcp.tool(annotations=SOLO_LECTURA)
@registrar("obtener_recomendaciones")
def obtener_recomendaciones(token_sesion: TokenSesion, pilar: Pilar = None) -> dict[str, Any]:
    """Cursos de competencias digitales recomendados para el estudiante autenticado en sus
    pilares pendientes, con la razón de cada recomendación según su pensum e historial."""
    return h.recomendaciones(_estudiante(token_sesion), pilar)


# ---------------------------------------------------------------------
# Salud del servicio
# ---------------------------------------------------------------------
@mcp.custom_route("/health", methods=["GET"])
async def salud(_: Request) -> JSONResponse:
    base_ok = verificar_conexion()
    return JSONResponse(
        {"servicio": "mcp", "estado": "ok" if base_ok else "degradado", "base_de_datos": base_ok},
        status_code=200 if base_ok else 503,
    )


def main() -> None:
    iniciar_pool(config.conninfo)
    try:
        mcp.run(
            transport="http",
            host="0.0.0.0",
            port=config.puerto,
            path="/mcp",
            allowed_hosts=config.hosts_permitidos or None,
            show_banner=False,
        )
    finally:
        cerrar_pool()


if __name__ == "__main__":
    main()
