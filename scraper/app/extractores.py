"""Descarga y extracción de entradas desde fuentes RSS o páginas HTML."""

from datetime import date, datetime, timedelta, timezone
from urllib.parse import urlsplit

import feedparser
import httpx
from bs4 import BeautifulSoup


# Colombia no tiene horario de verano: UTC-5 todo el año
BOGOTA = timezone(timedelta(hours=-5))


def dominio_permitido(url: str, dominios: tuple[str, ...]) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    return any(host == d or host.endswith("." + d) for d in dominios)


async def descargar(url: str, cliente: httpx.AsyncClient, max_bytes: int) -> str:
    async with cliente.stream("GET", url, follow_redirects=True) as respuesta:
        respuesta.raise_for_status()
        contenido = bytearray()
        async for parte in respuesta.aiter_bytes():
            contenido.extend(parte)
            if len(contenido) > max_bytes:
                raise httpx.HTTPError("La página supera el tamaño máximo permitido")
        return contenido.decode(respuesta.encoding or "utf-8", errors="replace")


def extraer_rss(texto: str) -> list[dict]:
    """Entradas de un feed RSS o Atom (por ejemplo, el /feed/ de WordPress)."""
    feed = feedparser.parse(texto)
    entradas = []
    for entrada in feed.entries:
        fecha = entrada.get("published_parsed") or entrada.get("updated_parsed")
        entradas.append({
            "titulo": entrada.get("title"),
            "url": entrada.get("link"),
            "resumen": entrada.get("summary") or entrada.get("description"),
            # feedparser entrega la fecha en UTC; se guarda el día en hora de Bogotá
            "fecha": datetime(*fecha[:6], tzinfo=timezone.utc).astimezone(BOGOTA).date() if fecha else None,
            "categorias": [t.get("term", "") for t in entrada.get("tags", []) if t.get("term")],
        })
    return entradas


def extraer_html(texto: str, configuracion: dict) -> list[dict]:
    """Entradas de una página HTML usando los selectores CSS de la fuente."""
    sopa = BeautifulSoup(texto, "html.parser")
    selector_item = configuracion.get("selector_item")
    if not selector_item:
        raise ValueError("La fuente HTML no tiene 'selector_item' en su configuración")
    entradas = []
    for item in sopa.select(selector_item):
        titulo = item.select_one(configuracion.get("selector_titulo", "h2, h3"))
        enlace = item.select_one(configuracion.get("selector_enlace", "a[href]"))
        resumen = item.select_one(configuracion.get("selector_resumen", "p"))
        fecha = item.select_one(configuracion.get("selector_fecha", "time"))
        entradas.append({
            "titulo": titulo.get_text(" ", strip=True) if titulo else None,
            "url": enlace.get("href") if enlace else None,
            "resumen": resumen.get_text(" ", strip=True) if resumen else None,
            "fecha": (fecha.get("datetime") or fecha.get_text(" ", strip=True)) if fecha else None,
        })
    return entradas
