"""Las pruebas usan la base de datos del .env (Supabase) con el rol chatbot_api.

n8n se reemplaza por respuestas simuladas (respx), así que no se gasta el
modelo de lenguaje. Los datos son los estudiantes DEMO de los seeds.
"""

import os
from datetime import datetime, timedelta, timezone

import jwt
import pytest

# n8n simulado y límites pequeños para probarlos; deben fijarse antes de importar la app
os.environ["N8N_INTERNAL_URL"] = "http://n8n-prueba:5678/webhook/"
os.environ["LIMITE_LOGIN_POR_IP"] = "8"
os.environ["LIMITE_CHAT_POR_MINUTO"] = "3"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

LAURA = "U00900100"
OTRO = "U00900101"
CONTRASENA_DEMO = "Demo2026*"


@pytest.fixture(scope="session")
def cliente():
    with TestClient(app) as c:
        yield c


@pytest.fixture(autouse=True)
def limites_limpios():
    app.state.limite_login.reiniciar()
    app.state.limite_chat.reiniciar()
    yield


@pytest.fixture(scope="session")
def config():
    return app.state.config


def firmar(codigo: str, config, minutos: int = 30, **cambios) -> str:
    ahora = datetime.now(timezone.utc)
    datos = {"sub": codigo, "iss": config.jwt_emisor, "aud": config.jwt_audiencia,
             "iat": ahora, "exp": ahora + timedelta(minutes=minutos)}
    datos.update(cambios)
    secreto = datos.pop("secreto", config.jwt_secreto)
    return jwt.encode(datos, secreto, algorithm="HS256")


@pytest.fixture(scope="session")
def token_laura(config):
    return firmar(LAURA, config)


@pytest.fixture(scope="session")
def token_otro(config):
    return firmar(OTRO, config)


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
