"""Chat: reenvía las preguntas a n8n (WF01) y expone las conversaciones guardadas."""

import logging
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import ValidationError

from .. import consultas
from ..config import Configuracion
from ..esquemas import ChatEntrada, ChatSalida, Error
from ..seguridad import Sesion, demasiadas_peticiones, obtener_config, sesion_actual

log = logging.getLogger("api.chat")
router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post("", response_model=ChatSalida,
             responses={401: {"model": Error}, 429: {"model": Error}, 502: {"model": Error}, 504: {"model": Error}})
async def enviar(
    entrada: ChatEntrada,
    request: Request,
    actual: Sesion = Depends(sesion_actual),
    config: Configuracion = Depends(obtener_config),
):
    """Envía la pregunta al orquestador. La identidad viaja en el token, no en el mensaje."""
    espera = request.app.state.limite_chat.registrar(actual.codigo)
    if espera:
        raise demasiadas_peticiones(espera, "Estás enviando mensajes muy rápido. Espera un momento.")

    cliente: httpx.AsyncClient = request.app.state.http
    try:
        respuesta = await cliente.post(
            config.url_chat,
            json={
                "token_sesion": actual.token,
                "sesion_id": str(entrada.sesion_id) if entrada.sesion_id else None,
                "mensaje": entrada.mensaje,
            },
            headers={"X-Chat-Token": config.n8n_secreto},
            timeout=config.n8n_timeout,
        )
    except httpx.TimeoutException:
        raise HTTPException(status.HTTP_504_GATEWAY_TIMEOUT,
                            "El asistente tardó demasiado en responder. Intenta de nuevo.") from None
    except httpx.HTTPError as error:
        log.error("n8n no responde: %s", type(error).__name__)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY,
                            "El asistente no está disponible en este momento.") from None

    if respuesta.status_code == status.HTTP_401_UNAUTHORIZED:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Tu sesión venció. Inicia sesión de nuevo.")
    if respuesta.status_code != status.HTTP_200_OK:
        log.error("n8n respondió %s", respuesta.status_code)
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "El asistente no pudo procesar el mensaje.")
    try:
        return ChatSalida.model_validate(respuesta.json())
    except (ValueError, ValidationError):
        log.error("Respuesta de n8n con formato inesperado")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "El asistente devolvió una respuesta no válida.") from None


@router.get("/sesiones")
def sesiones(limite: int = Query(default=30, ge=1, le=100), actual: Sesion = Depends(sesion_actual)):
    """Conversaciones anteriores del estudiante, de la más reciente a la más antigua."""
    return {"sesiones": consultas.sesiones(actual.codigo, limite)}


@router.get("/sesiones/{sesion_id}/mensajes", responses={404: {"model": Error}})
def mensajes(sesion_id: UUID, actual: Sesion = Depends(sesion_actual)):
    """Mensajes de una conversación propia. Las de otros estudiantes responden 404."""
    filas = consultas.mensajes(actual.codigo, str(sesion_id))
    if filas is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversación no encontrada.")
    return {"sesion_id": str(sesion_id), "mensajes": filas}


@router.delete("/sesiones/{sesion_id}", status_code=status.HTTP_204_NO_CONTENT,
               responses={404: {"model": Error}})
def archivar(sesion_id: UUID, actual: Sesion = Depends(sesion_actual)):
    """Archiva una conversación: deja de aparecer en la lista y en la memoria del chat."""
    if not consultas.archivar_sesion(actual.codigo, str(sesion_id)):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversación no encontrada.")
