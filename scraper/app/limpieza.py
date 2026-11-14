"""Limpieza, normalización y clasificación de las noticias extraídas."""

import hashlib
import html
import re
import unicodedata
from datetime import date, datetime
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit

from bs4 import BeautifulSoup

MESES = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7,
    "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
}

# Parámetros de seguimiento que no cambian el contenido de la página
_RASTREO = re.compile(r"^(utm_\w+|fbclid|gclid|mc_cid|mc_eid)$", re.I)

# El orden importa: la primera categoría que coincide es la que queda
CATEGORIAS = [
    ("convocatoria", r"convocatoria|inscripci[oó]n(es)? abiertas?|post[uú]late|becas?\b|llamado a"),
    ("certificacion", r"certificaci[oó]n|certificado|insignia|badge|credencial digital"),
    ("curso", r"\bcursos?\b|diplomado|\btaller(es)?\b|bootcamp|seminario|capacitaci[oó]n"),
]


def sin_tildes(texto: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", texto) if unicodedata.category(c) != "Mn")


def limpiar_texto(valor: str | None, maximo: int | None = None) -> str:
    """Quita etiquetas HTML y espacios sobrantes; recorta en un límite de palabra."""
    if not valor:
        return ""
    texto = BeautifulSoup(valor, "html.parser").get_text(" ") if "<" in valor else valor
    texto = re.sub(r"\s+", " ", html.unescape(texto)).strip()
    # WordPress cierra los extractos con "[…]"
    texto = re.sub(r"\s*\[(…|\.\.\.)\]$", "…", texto)
    if maximo and len(texto) > maximo:
        corte = texto[: maximo + 1]
        corte = corte.rsplit(" ", 1)[0] if " " in corte else texto[:maximo]
        texto = corte.rstrip(",;:. ") + "…"
    return texto


def normalizar_url(url: str | None, base: str, conservar_fragmento: bool = False) -> str | None:
    """URL absoluta, sin parámetros de rastreo y (por defecto) sin fragmento."""
    if not url:
        return None
    absoluta = urljoin(base, url.strip())
    partes = urlsplit(absoluta)
    if partes.scheme not in ("http", "https") or not partes.netloc:
        return None
    consulta = urlencode([(k, v) for k, v in parse_qsl(partes.query) if not _RASTREO.match(k)])
    fragmento = partes.fragment if conservar_fragmento else ""
    return urlunsplit((partes.scheme, partes.netloc.lower(), partes.path or "/", consulta, fragmento))


def parsear_fecha(valor: str | None) -> date | None:
    """Acepta AAAA-MM-DD (con o sin hora), DD/MM/AAAA y '14 de noviembre de 2026'."""
    if not valor:
        return None
    texto = sin_tildes(valor.strip().lower())
    if m := re.search(r"(\d{4})-(\d{2})-(\d{2})", texto):
        partes = (int(m[1]), int(m[2]), int(m[3]))
    elif m := re.search(r"\b(\d{1,2})/(\d{1,2})/(\d{4})\b", texto):
        partes = (int(m[3]), int(m[2]), int(m[1]))
    elif m := re.search(r"\b(\d{1,2})\s+de\s+([a-z]+)\s+(?:de\s+|del\s+)?(\d{4})\b", texto):
        if m[2] not in MESES:
            return None
        partes = (int(m[3]), MESES[m[2]], int(m[1]))
    else:
        return None
    try:
        return date(*partes)
    except ValueError:
        return None


def clasificar(titulo: str, resumen: str) -> str:
    texto = f"{titulo} {resumen}".lower()
    for categoria, patron in CATEGORIAS:
        if re.search(patron, texto):
            return categoria
    return "noticia"


def es_relevante(titulo: str, resumen: str, palabras: list[str]) -> bool:
    """Sin palabras clave, todo es relevante; con ellas, basta que aparezca una."""
    if not palabras:
        return True
    texto = sin_tildes(f"{titulo} {resumen}".lower())
    return any(sin_tildes(p.lower()) in texto for p in palabras)


def huella(titulo: str, resumen: str, fecha: date | None) -> str:
    contenido = f"{titulo}\n{resumen}\n{fecha.isoformat() if fecha else ''}"
    return hashlib.sha256(contenido.encode("utf-8")).hexdigest()


def preparar(crudos: list[dict], url_fuente: str, configuracion: dict, maximo: int) -> list[dict]:
    """Convierte lo extraído en noticias limpias, relevantes y sin URL repetidas."""
    conservar = bool(configuracion.get("conservar_fragmento", False))
    palabras = configuracion.get("palabras_clave") or []
    excluidas = {c.strip().lower() for c in configuracion.get("categorias_excluidas") or []}
    categoria_fija = configuracion.get("categoria")
    vistas: set[str] = set()
    noticias: list[dict] = []
    for crudo in crudos:
        titulo = limpiar_texto(crudo.get("titulo"), 300)
        url = normalizar_url(crudo.get("url"), url_fuente, conservar)
        if not titulo or not url or url in vistas:
            continue
        if excluidas & {c.strip().lower() for c in crudo.get("categorias") or []}:
            continue
        resumen = limpiar_texto(crudo.get("resumen"), 500)
        if not es_relevante(titulo, resumen, palabras):
            continue
        fecha = crudo.get("fecha")
        if isinstance(fecha, datetime):
            fecha = fecha.date()
        elif not isinstance(fecha, date):
            fecha = parsear_fecha(fecha)
        vistas.add(url)
        noticias.append({
            "titulo": titulo,
            "url": url,
            "resumen": resumen or None,
            "categoria": categoria_fija or clasificar(titulo, resumen),
            "fecha_publicacion": fecha.isoformat() if fecha else None,
            "hash_contenido": huella(titulo, resumen, fecha),
        })
        if len(noticias) >= maximo:
            break
    return noticias
