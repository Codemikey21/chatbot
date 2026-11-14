"""Datos académicos del estudiante autenticado."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException

from .. import consultas
from ..seguridad import Sesion, sesion_actual

router = APIRouter(prefix="/estudiante", tags=["Estudiante"])


@router.get("/resumen")
def resumen(actual: Sesion = Depends(sesion_actual)):
    """Perfil, insignia por pilares, avance del plan y semestres restantes estimados."""
    datos = consultas.resumen(actual.codigo)
    if not datos:
        raise HTTPException(status_code=404, detail="No se encontró información del estudiante.")
    return datos


@router.get("/historial")
def historial(
    tipo: Literal["todos", "competencia_digital", "asignatura"] = "todos",
    actual: Sesion = Depends(sesion_actual),
):
    """Cursos realizados por periodo, con NRC, estado y nota."""
    return consultas.historial(actual.codigo, tipo)


@router.get("/recomendaciones")
def recomendaciones(actual: Sesion = Depends(sesion_actual)):
    """Cursos recomendados en los pilares pendientes, con sus razones y NRC disponibles."""
    return consultas.recomendaciones(actual.codigo)
