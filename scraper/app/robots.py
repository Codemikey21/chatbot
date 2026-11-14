"""Revisión de robots.txt antes de descargar cualquier página."""

import time
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser

import httpx

# Se guarda el robots.txt de cada sitio por 6 horas para no pedirlo en cada ejecución
_DURACION_CACHE = 6 * 60 * 60
_cache: dict[str, tuple[float, RobotFileParser, str | None]] = {}

NO_PERMITE = "El archivo robots.txt del sitio no permite extraer esta página."


def _base(url: str) -> str:
    partes = urlsplit(url)
    return f"{partes.scheme}://{partes.netloc}"


async def _leer(base: str, cliente: httpx.AsyncClient) -> tuple[RobotFileParser, str | None]:
    """Reglas del sitio y, si no se pudieron leer, el motivo."""
    reglas = RobotFileParser(base + "/robots.txt")
    try:
        respuesta = await cliente.get(base + "/robots.txt", follow_redirects=True)
    except httpx.HTTPError as error:
        # Sin respuesta no se puede confirmar el permiso: por prudencia no se extrae
        reglas.disallow_all = True
        return reglas, f"No se pudo leer el robots.txt del sitio ({type(error).__name__}); no se extrae."
    if respuesta.status_code in (401, 403):
        reglas.disallow_all = True
    elif respuesta.status_code >= 400:
        # Si el sitio no publica robots.txt, se entiende que no hay restricciones
        reglas.allow_all = True
    else:
        reglas.parse(respuesta.text.splitlines())
    return reglas, None


async def revisar(url: str, cliente: httpx.AsyncClient, agente: str) -> str | None:
    """None si robots.txt permite descargar la URL; si no, el motivo."""
    base = _base(url)
    ahora = time.monotonic()
    guardado = _cache.get(base)
    if guardado is None or ahora - guardado[0] > _DURACION_CACHE:
        guardado = (ahora, *await _leer(base, cliente))
        _cache[base] = guardado
    _, reglas, motivo = guardado
    if reglas.can_fetch(agente, url):
        return None
    return motivo or NO_PERMITE


def limpiar_cache() -> None:
    _cache.clear()
