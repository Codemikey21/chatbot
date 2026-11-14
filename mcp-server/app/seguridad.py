"""Autenticación del cliente MCP y verificación del token de sesión del estudiante."""

import hmac
import re

import jwt
from fastmcp.exceptions import ToolError
from fastmcp.server.auth import AccessToken, TokenVerifier

PATRON_CODIGO = re.compile(r"^U00[0-9]{6}$")


class TokenDeServicio(TokenVerifier):
    """Valida el token Bearer que comparten n8n y los clientes MCP autorizados."""

    def __init__(self, token_esperado: str):
        super().__init__()
        self._token = token_esperado

    async def verify_token(self, token: str) -> AccessToken | None:
        if token and hmac.compare_digest(token, self._token):
            return AccessToken(token=token, client_id="cliente-mcp", scopes=[])
        return None


def estudiante_desde_token(token_sesion: str, secreto: str, emisor: str, audiencia: str) -> str:
    """Devuelve el código del estudiante si el JWT emitido por la API es válido.

    El modelo de lenguaje nunca elige a qué estudiante consultar: la identidad
    sale de un token firmado que no puede fabricar ni modificar.
    """
    if not token_sesion:
        raise ToolError("Se requiere el token de sesión del estudiante.")
    try:
        datos = jwt.decode(
            token_sesion,
            secreto,
            algorithms=["HS256"],
            issuer=emisor,
            audience=audiencia,
            options={"require": ["sub", "exp", "iat"]},
        )
    except jwt.ExpiredSignatureError as error:
        raise ToolError("La sesión del estudiante venció. Debe iniciar sesión de nuevo.") from error
    except jwt.InvalidTokenError as error:
        raise ToolError("El token de sesión no es válido.") from error

    codigo = str(datos.get("sub", "")).upper()
    if not PATRON_CODIGO.match(codigo):
        raise ToolError("El token de sesión no identifica a un estudiante válido.")
    return codigo
