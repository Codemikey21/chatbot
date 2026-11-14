"""Contratos de entrada y salida de la API (se publican en /docs)."""

from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class LoginEntrada(BaseModel):
    codigo: str = Field(pattern=r"^[Uu]00[0-9]{6}$", examples=["U00900100"])
    contrasena: str = Field(min_length=1, max_length=128, examples=["Demo2026*"])

    @field_validator("codigo")
    @classmethod
    def mayusculas(cls, valor: str) -> str:
        return valor.upper()


class Estudiante(BaseModel):
    codigo: str
    nombres: str
    apellidos: str
    programa: str
    semestre_actual: int


class LoginSalida(BaseModel):
    token: str
    tipo: str = "Bearer"
    expira_en: int = Field(description="Segundos de vigencia del token")
    estudiante: Estudiante


class ChatEntrada(BaseModel):
    mensaje: str = Field(min_length=1, max_length=1500)
    sesion_id: UUID | None = Field(default=None, description="Vacío para empezar una conversación nueva")

    @field_validator("mensaje")
    @classmethod
    def sin_espacios_sobrantes(cls, valor: str) -> str:
        limpio = valor.strip()
        if not limpio:
            raise ValueError("El mensaje está vacío")
        return limpio


class ChatSalida(BaseModel):
    sesion_id: str
    sesion_nueva: bool = False
    mensaje_id: str | None = None
    respuesta: str
    intencion: str | None = None
    intenciones: list[str] = []
    fuentes: list[dict[str, Any]] = []
    herramientas: list[str] = []
    bloqueado: bool = False


class Error(BaseModel):
    detail: str
