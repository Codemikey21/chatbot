"""Configuración de la API, leída de variables de entorno."""

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


def _entero(nombre: str, defecto: int) -> int:
    return int(os.getenv(nombre, str(defecto)))


@dataclass(frozen=True)
class Configuracion:
    # Base de datos (rol chatbot_api: login, sesiones de chat y lecturas con RLS)
    db_host: str = field(default_factory=lambda: _obligatoria("SUPABASE_DB_HOST"))
    db_port: int = field(default_factory=lambda: _entero("SUPABASE_DB_PORT", 5432))
    db_nombre: str = field(default_factory=lambda: os.getenv("SUPABASE_DB_NAME", "postgres"))
    db_usuario: str = field(default_factory=lambda: _obligatoria("DB_API_USER"))
    db_contrasena: str = field(default_factory=lambda: _obligatoria("DB_API_PASSWORD"))
    db_sslmode: str = field(default_factory=lambda: os.getenv("SUPABASE_DB_SSLMODE", "require"))

    # Tokens de sesión (los verifican también n8n y el servidor MCP)
    jwt_secreto: str = field(default_factory=lambda: _obligatoria("JWT_SECRET"))
    jwt_emisor: str = field(default_factory=lambda: os.getenv("JWT_ISSUER", "chatbot-unab-api"))
    jwt_audiencia: str = field(default_factory=lambda: os.getenv("JWT_AUDIENCE", "chatbot-unab"))
    jwt_minutos: int = field(default_factory=lambda: _entero("JWT_EXPIRES_MINUTES", 120))

    # Webhook interno de n8n (WF01)
    n8n_url: str = field(default_factory=lambda: os.getenv("N8N_INTERNAL_URL", "http://n8n:5678/webhook/"))
    n8n_secreto: str = field(default_factory=lambda: _obligatoria("N8N_WEBHOOK_SECRET"))
    n8n_timeout: float = field(default_factory=lambda: float(os.getenv("N8N_TIMEOUT", "90")))

    # Límites de uso por ventana de tiempo
    login_intentos: int = field(default_factory=lambda: _entero("LIMITE_LOGIN_POR_IP", 10))
    login_ventana: int = field(default_factory=lambda: _entero("LIMITE_LOGIN_VENTANA_S", 300))
    chat_mensajes: int = field(default_factory=lambda: _entero("LIMITE_CHAT_POR_MINUTO", 12))

    documentacion: bool = field(default_factory=lambda: os.getenv("API_DOCS", "true").lower() == "true")

    # Orígenes web que pueden llamar la API desde un navegador (separados por coma).
    # Vacío = sin CORS: la app Android no lo necesita, solo la versión web de la app.
    origenes_cors: tuple[str, ...] = field(
        default_factory=lambda: tuple(o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip())
    )

    @property
    def conninfo(self) -> str:
        return (
            f"host={self.db_host} port={self.db_port} dbname={self.db_nombre} "
            f"user={self.db_usuario} password={self.db_contrasena} sslmode={self.db_sslmode} "
            f"application_name=chatbot-api connect_timeout=10"
        )

    @property
    def url_chat(self) -> str:
        return self.n8n_url.rstrip("/") + "/chat-academico"

    @property
    def url_salud_n8n(self) -> str:
        base = self.n8n_url.split("/webhook")[0]
        return base.rstrip("/") + "/healthz"
