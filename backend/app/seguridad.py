"""Tokens de sesión (JWT), dependencia de autenticación y límites de uso."""

import re
import threading
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Configuracion

PATRON_CODIGO = re.compile(r"^U00[0-9]{6}$")
_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Sesion:
    codigo: str
    token: str


def crear_token(codigo: str, config: Configuracion) -> tuple[str, int]:
    """Firma el token de sesión del estudiante. Devuelve el token y su vigencia en segundos."""
    ahora = datetime.now(timezone.utc)
    vigencia = timedelta(minutes=config.jwt_minutos)
    token = jwt.encode(
        {
            "sub": codigo,
            "rol": "estudiante",
            "iss": config.jwt_emisor,
            "aud": config.jwt_audiencia,
            "iat": ahora,
            "exp": ahora + vigencia,
            "jti": str(uuid.uuid4()),
        },
        config.jwt_secreto,
        algorithm="HS256",
    )
    return token, int(vigencia.total_seconds())


def _no_autorizado(detalle: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detalle,
        headers={"WWW-Authenticate": "Bearer"},
    )


def obtener_config(request: Request) -> Configuracion:
    return request.app.state.config


def sesion_actual(
    credenciales: HTTPAuthorizationCredentials | None = Depends(_bearer),
    config: Configuracion = Depends(obtener_config),
) -> Sesion:
    """Valida el token Bearer y devuelve el estudiante autenticado.

    El código del estudiante sale siempre del token firmado, nunca de un
    parámetro de la petición.
    """
    if credenciales is None:
        raise _no_autorizado("Inicia sesión para continuar.")
    try:
        datos = jwt.decode(
            credenciales.credentials,
            config.jwt_secreto,
            algorithms=["HS256"],
            issuer=config.jwt_emisor,
            audience=config.jwt_audiencia,
            options={"require": ["sub", "exp", "iat"]},
        )
    except jwt.ExpiredSignatureError:
        raise _no_autorizado("Tu sesión venció. Inicia sesión de nuevo.") from None
    except jwt.InvalidTokenError:
        raise _no_autorizado("La sesión no es válida. Inicia sesión de nuevo.") from None

    codigo = str(datos.get("sub", "")).upper()
    if not PATRON_CODIGO.match(codigo):
        raise _no_autorizado("La sesión no es válida. Inicia sesión de nuevo.")
    return Sesion(codigo=codigo, token=credenciales.credentials)


class LimiteDeUso:
    """Ventana deslizante en memoria: máximo N eventos por clave en S segundos.

    Suficiente para una sola instancia de la API. Con varias instancias se
    usaría un almacén compartido (por ejemplo, Redis).
    """

    def __init__(self, maximo: int, ventana_segundos: int):
        self.maximo = maximo
        self.ventana = ventana_segundos
        self._eventos: dict[str, deque[float]] = defaultdict(deque)
        self._candado = threading.Lock()

    def registrar(self, clave: str) -> int | None:
        """Registra un evento. Si se superó el límite devuelve los segundos de espera."""
        ahora = time.monotonic()
        with self._candado:
            eventos = self._eventos[clave]
            while eventos and ahora - eventos[0] > self.ventana:
                eventos.popleft()
            if len(eventos) >= self.maximo:
                return int(self.ventana - (ahora - eventos[0])) + 1
            eventos.append(ahora)
            return None

    def reiniciar(self) -> None:
        with self._candado:
            self._eventos.clear()


def demasiadas_peticiones(espera: int, mensaje: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=mensaje,
        headers={"Retry-After": str(espera)},
    )
