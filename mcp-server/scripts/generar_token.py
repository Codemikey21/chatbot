"""Genera un token de sesión de prueba para un estudiante DEMO.

Uso (desde mcp-server/):
    python scripts/generar_token.py U00900100

Sirve para probar las herramientas personales desde el MCP Inspector o
desde un cliente MCP sin pasar por la API. Usa JWT_SECRET del archivo .env.
"""

import os
import sys
from datetime import datetime, timedelta, timezone

import jwt
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv(usecwd=True))


def main() -> None:
    codigo = (sys.argv[1] if len(sys.argv) > 1 else "U00900100").upper()
    ahora = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": codigo,
            "rol": "estudiante",
            "iss": os.getenv("JWT_ISSUER", "chatbot-unab-api"),
            "aud": os.getenv("JWT_AUDIENCE", "chatbot-unab"),
            "iat": ahora,
            "exp": ahora + timedelta(minutes=int(os.getenv("JWT_EXPIRES_MINUTES", "120"))),
        },
        os.environ["JWT_SECRET"],
        algorithm="HS256",
    )
    print(token)


if __name__ == "__main__":
    main()
