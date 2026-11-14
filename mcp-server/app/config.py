"""Configuración del servidor MCP, leída de variables de entorno."""

import os
from dataclasses import dataclass, field

from dotenv import find_dotenv, load_dotenv

# Busca el .env en la carpeta actual o en las superiores (raíz del repositorio).
load_dotenv(find_dotenv(usecwd=True))


def _obligatoria(nombre: str) -> str:
    valor = os.getenv(nombre, "").strip()
    if not valor:
        raise RuntimeError(f"Falta la variable de entorno {nombre}")
    return valor


def _lista(nombre: str) -> list[str]:
    return [v.strip() for v in os.getenv(nombre, "").split(",") if v.strip()]


@dataclass(frozen=True)
class Configuracion:
    db_host: str = field(default_factory=lambda: _obligatoria("SUPABASE_DB_HOST"))
    db_port: int = field(default_factory=lambda: int(os.getenv("SUPABASE_DB_PORT", "5432")))
    db_nombre: str = field(default_factory=lambda: os.getenv("SUPABASE_DB_NAME", "postgres"))
    db_usuario: str = field(default_factory=lambda: _obligatoria("DB_MCP_USER"))
    db_contrasena: str = field(default_factory=lambda: _obligatoria("DB_MCP_PASSWORD"))
    db_sslmode: str = field(default_factory=lambda: os.getenv("SUPABASE_DB_SSLMODE", "require"))
    puerto: int = field(default_factory=lambda: int(os.getenv("MCP_PORT", "9000")))
    token_acceso: str = field(default_factory=lambda: _obligatoria("MCP_AUTH_TOKEN"))
    jwt_secreto: str = field(default_factory=lambda: _obligatoria("JWT_SECRET"))
    jwt_emisor: str = field(default_factory=lambda: os.getenv("JWT_ISSUER", "chatbot-unab-api"))
    jwt_audiencia: str = field(default_factory=lambda: os.getenv("JWT_AUDIENCE", "chatbot-unab"))
    hosts_permitidos: list[str] = field(default_factory=lambda: _lista("MCP_ALLOWED_HOSTS"))

    @property
    def conninfo(self) -> str:
        return (
            f"host={self.db_host} port={self.db_port} dbname={self.db_nombre} "
            f"user={self.db_usuario} password={self.db_contrasena} sslmode={self.db_sslmode} "
            f"application_name=chatbot-mcp connect_timeout=10"
        )
