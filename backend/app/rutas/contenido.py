"""Catálogo de cursos, calendario académico y noticias (requieren sesión)."""

from typing import Literal

from fastapi import APIRouter, Depends, Query

from .. import consultas
from ..seguridad import Sesion, sesion_actual

router = APIRouter(tags=["Contenido"])

TipoEvento = Literal[
    "inscripcion", "prueba_diagnostica", "resultados", "inicio_curso", "fin_curso", "evaluacion",
    "retiro", "certificacion", "matricula", "inicio_clases", "receso",
]


@router.get("/cursos")
def cursos(_: Sesion = Depends(sesion_actual)):
    """Pilares de la insignia con sus cursos y las secciones (NRC) abiertas."""
    return consultas.cursos()


@router.get("/calendario")
def calendario(
    tipo: TipoEvento | None = None,
    solo_proximos: bool = True,
    _: Sesion = Depends(sesion_actual),
):
    """Eventos del calendario académico con su estado respecto a hoy."""
    return consultas.calendario(tipo, solo_proximos)


@router.get("/noticias")
def noticias(
    categoria: Literal["curso", "convocatoria", "certificacion", "noticia"] | None = None,
    limite: int = Query(default=20, ge=1, le=50),
    _: Sesion = Depends(sesion_actual),
):
    """Noticias y convocatorias recopiladas por el scraper, de la más reciente a la más antigua."""
    return consultas.noticias(categoria, limite)
