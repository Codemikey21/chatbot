"""Inicio de sesión y validación de la sesión guardada en la app."""

from fastapi import APIRouter, Depends, HTTPException, Request, status

from .. import consultas
from ..config import Configuracion
from ..esquemas import Error, Estudiante, LoginEntrada, LoginSalida
from ..seguridad import Sesion, crear_token, demasiadas_peticiones, obtener_config, sesion_actual

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/login", response_model=LoginSalida,
             responses={401: {"model": Error}, 429: {"model": Error}})
def login(entrada: LoginEntrada, request: Request, config: Configuracion = Depends(obtener_config)):
    """Valida código y contraseña y entrega el token de sesión (JWT) del estudiante."""
    ip = request.client.host if request.client else "desconocida"
    espera = request.app.state.limite_login.registrar(ip)
    if espera:
        raise demasiadas_peticiones(espera, "Demasiados intentos de inicio de sesión. Espera unos minutos.")

    estudiante = consultas.autenticar(entrada.codigo, entrada.contrasena)
    if not estudiante:
        # Mismo mensaje si el código no existe, la contraseña falla o la cuenta
        # está bloqueada: así no se revela qué códigos existen.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Código o contraseña incorrectos. Tras 5 intentos fallidos la cuenta se bloquea 15 minutos.",
        )
    token, vigencia = crear_token(estudiante["codigo"], config)
    return LoginSalida(token=token, expira_en=vigencia, estudiante=Estudiante(**estudiante))


@router.get("/sesion", response_model=Estudiante, responses={401: {"model": Error}})
def sesion(actual: Sesion = Depends(sesion_actual)):
    """Comprueba que el token guardado en la app sigue vigente y devuelve el perfil."""
    datos = consultas.perfil(actual.codigo)
    if not datos:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="La cuenta no está activa.")
    return Estudiante(**datos)
