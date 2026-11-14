"""API interna del scraper. Solo la llama n8n (WF04) con un token Bearer.

POST /extraer   descarga una fuente (RSS o HTML), respeta robots.txt y
                devuelve las noticias limpias y clasificadas. No escribe en
                la base de datos: eso lo hace n8n.
GET  /health    estado del servicio.
GET  /demo/...  boletín DEMO del CCD, para demostrar la extracción HTML.
"""

import hmac
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

import httpx
from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import FileResponse, PlainTextResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from .config import Configuracion
from .extractores import descargar, dominio_permitido, extraer_html, extraer_rss
from .limpieza import preparar
from .robots import revisar

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("scraper")

config = Configuracion()
DEMO = Path(__file__).parent / "demo"

app = FastAPI(title="Scraper de noticias", version="1.0.0", docs_url=None, redoc_url=None, openapi_url=None)
_bearer = HTTPBearer(auto_error=False)


def verificar_token(credenciales: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> None:
    if credenciales is None or not hmac.compare_digest(credenciales.credentials, config.token):
        raise HTTPException(status_code=401, detail="Token no válido")


class Fuente(BaseModel):
    fuente_id: int = Field(ge=1)
    nombre: str = Field(min_length=1, max_length=120)
    url: str = Field(pattern=r"^https?://", max_length=500)
    tipo: Literal["rss", "html"]
    configuracion: dict = Field(default_factory=dict)


def _resultado(fuente: Fuente, permitido_robots: bool, noticias: list[dict], error: str | None) -> dict:
    return {
        "fuente_id": fuente.fuente_id,
        "fuente": fuente.nombre,
        "permitido_robots": permitido_robots,
        "revisado_en": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "total": len(noticias),
        "noticias": noticias,
        "error": error,
    }


@app.post("/extraer", dependencies=[Depends(verificar_token)])
async def extraer(fuente: Fuente) -> dict:
    if not dominio_permitido(fuente.url, config.dominios_permitidos):
        log.warning("Dominio fuera de la lista blanca: %s", fuente.url)
        return _resultado(fuente, False, [], "El dominio de la fuente no está en la lista de dominios permitidos.")

    async with httpx.AsyncClient(headers={"User-Agent": config.agente}, timeout=config.timeout) as cliente:
        motivo = await revisar(fuente.url, cliente, config.agente)
        if motivo:
            log.info("%s: %s", fuente.url, motivo)
            return _resultado(fuente, False, [], motivo)
        try:
            texto = await descargar(fuente.url, cliente, config.max_bytes)
        except httpx.HTTPError as error:
            log.warning("No se pudo descargar %s: %s", fuente.url, error)
            return _resultado(fuente, True, [], f"No se pudo descargar la fuente ({type(error).__name__}).")

    try:
        crudos = extraer_rss(texto) if fuente.tipo == "rss" else extraer_html(texto, fuente.configuracion)
    except ValueError as error:
        return _resultado(fuente, True, [], str(error))

    noticias = preparar(crudos, fuente.url, fuente.configuracion, config.max_items)
    log.info("%s: %d entradas, %d noticias válidas", fuente.nombre, len(crudos), len(noticias))
    return _resultado(fuente, True, noticias, None)


@app.get("/health")
async def salud() -> dict:
    return {"servicio": "scraper", "estado": "ok"}


@app.get("/robots.txt", response_class=PlainTextResponse)
async def robots() -> str:
    return "User-agent: *\nAllow: /demo/\nDisallow: /\n"


@app.get("/demo/boletin-ccd.html")
async def boletin_demo() -> FileResponse:
    return FileResponse(DEMO / "boletin-ccd.html", media_type="text/html; charset=utf-8")
