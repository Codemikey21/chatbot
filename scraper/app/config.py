"""Configuración del scraper, leída de variables de entorno."""

import os
from dataclasses import dataclass, field


def _obligatoria(nombre: str) -> str:
    valor = os.getenv(nombre, "").strip()
    if not valor:
        raise RuntimeError(f"Falta la variable de entorno {nombre}")
    return valor


def _lista(nombre: str, defecto: str) -> tuple[str, ...]:
    return tuple(v.strip().lower() for v in os.getenv(nombre, defecto).split(",") if v.strip())


@dataclass(frozen=True)
class Configuracion:
    # Token Bearer que debe enviar n8n
    token: str = field(default_factory=lambda: _obligatoria("SCRAPER_TOKEN"))
    # Solo se descargan páginas de estos dominios (y sus subdominios)
    dominios_permitidos: tuple[str, ...] = field(
        default_factory=lambda: _lista("SCRAPER_DOMINIOS_PERMITIDOS", "unab.edu.co,scraper")
    )
    # Identificación honesta del bot ante los sitios consultados
    agente: str = "ChatbotAcademicoUNAB/1.0 (proyecto academico de Ciencia de Datos)"
    timeout: float = field(default_factory=lambda: float(os.getenv("SCRAPER_TIMEOUT", "20")))
    max_items: int = field(default_factory=lambda: int(os.getenv("SCRAPER_MAX_ITEMS", "20")))
    max_bytes: int = 5 * 1024 * 1024
