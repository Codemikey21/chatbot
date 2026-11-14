"""API segura del chatbot académico.

La app móvil solo habla con esta API. La API autentica al estudiante,
emite el token de sesión, lee sus datos con RLS y reenvía el chat a n8n.
"""

import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import Configuracion
from .db import BaseDeDatosNoDisponible, cerrar_pool, iniciar_pool, verificar_conexion
from .rutas import auth, chat, contenido, estudiante
from .seguridad import LimiteDeUso

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("api")

PREFIJO = "/api/v1"


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    config: Configuracion = app.state.config
    iniciar_pool(config.conninfo)
    app.state.http = httpx.AsyncClient()
    log.info("API lista")
    yield
    await app.state.http.aclose()
    cerrar_pool()


def crear_app(config: Configuracion | None = None) -> FastAPI:
    config = config or Configuracion()
    app = FastAPI(
        title="API del chatbot académico",
        version="1.0.0",
        description="API segura entre la app móvil, la base de datos y el orquestador n8n. Datos DEMO.",
        lifespan=ciclo_de_vida,
        docs_url="/docs" if config.documentacion else None,
        redoc_url=None,
        openapi_url="/openapi.json" if config.documentacion else None,
    )
    app.state.config = config
    app.state.limite_login = LimiteDeUso(config.login_intentos, config.login_ventana)
    app.state.limite_chat = LimiteDeUso(config.chat_mensajes, 60)

    @app.middleware("http")
    async def cabeceras_de_seguridad(request: Request, siguiente):
        respuesta = await siguiente(request)
        respuesta.headers["X-Content-Type-Options"] = "nosniff"
        respuesta.headers["X-Frame-Options"] = "DENY"
        respuesta.headers["Referrer-Policy"] = "no-referrer"
        if request.url.path.startswith(PREFIJO):
            respuesta.headers["Cache-Control"] = "no-store"
        return respuesta

    # CORS solo para los orígenes de CORS_ORIGINS (la versión web de la app).
    # Se agrega después de las cabeceras para que responda primero las peticiones OPTIONS.
    if config.origenes_cors:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(config.origenes_cors),
            allow_methods=["GET", "POST", "DELETE"],
            allow_headers=["Authorization", "Content-Type"],
            expose_headers=["Retry-After"],
            max_age=600,
        )

    @app.exception_handler(BaseDeDatosNoDisponible)
    async def base_no_disponible(_: Request, __: BaseDeDatosNoDisponible):
        return JSONResponse(status_code=503, content={"detail": "El servicio de datos no está disponible. Intenta más tarde."})

    for router in (auth.router, estudiante.router, contenido.router, chat.router):
        app.include_router(router, prefix=PREFIJO)

    @app.get("/health", tags=["Salud"])
    async def salud():
        base_ok = verificar_conexion()
        try:
            n8n_ok = (await app.state.http.get(config.url_salud_n8n, timeout=5)).status_code == 200
        except httpx.HTTPError:
            n8n_ok = False
        return JSONResponse(
            status_code=200 if base_ok else 503,
            content={"servicio": "api", "estado": "ok" if base_ok and n8n_ok else "degradado",
                     "base_de_datos": base_ok, "n8n": n8n_ok},
        )

    return app


app = crear_app()
