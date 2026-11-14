"""Configuración común de las pruebas.

Las pruebas de integración usan la base de datos indicada en el .env con el
rol chatbot_mcp (o la base de pruebas definida en las variables de entorno).
Si no hay base configurada, esas pruebas se omiten.
"""

import os
from datetime import datetime, timedelta, timezone

import jwt
import pytest

os.environ.setdefault("MCP_AUTH_TOKEN", "token-de-prueba")
os.environ.setdefault("JWT_SECRET", "secreto-de-prueba")

from app.config import Configuracion  # noqa: E402

BASE_CONFIGURADA = bool(os.getenv("SUPABASE_DB_HOST") and os.getenv("DB_MCP_USER"))


def crear_token(codigo: str, minutos: int = 30, secreto: str | None = None, **extra) -> str:
    config = Configuracion()
    ahora = datetime.now(timezone.utc)
    datos = {
        "sub": codigo,
        "iss": config.jwt_emisor,
        "aud": config.jwt_audiencia,
        "iat": ahora,
        "exp": ahora + timedelta(minutes=minutos),
        **extra,
    }
    return jwt.encode(datos, secreto or config.jwt_secreto, algorithm="HS256")


@pytest.fixture(scope="session")
def base_de_datos():
    if not BASE_CONFIGURADA:
        pytest.skip("No hay base de datos configurada (SUPABASE_DB_HOST y DB_MCP_USER).")
    from app.db import cerrar_pool, iniciar_pool

    iniciar_pool(Configuracion().conninfo)
    yield
    cerrar_pool()
