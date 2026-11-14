import json

import httpx
import respx

from tests.conftest import auth

URL_N8N = "http://n8n-prueba:5678/webhook/chat-academico"
RESPUESTA = {
    "sesion_id": "8a6f0c2e-6c51-4f6a-9d2f-1c2b3d4e5f60", "sesion_nueva": True, "mensaje_id": "10",
    "respuesta": "Te recomiendo IA Generativa.", "intencion": "recomendacion",
    "intenciones": ["recomendacion"], "fuentes": [{"tipo": "historial"}],
    "herramientas": ["consultar_mis_datos"], "bloqueado": False,
}


@respx.mock
def test_chat_reenvia_a_n8n(cliente, config, token_laura):
    ruta = respx.post(URL_N8N).mock(return_value=httpx.Response(200, json=RESPUESTA))
    r = cliente.post("/api/v1/chat", json={"mensaje": "  ¿Qué me recomiendas?  "}, headers=auth(token_laura))
    assert r.status_code == 200 and r.json()["respuesta"] == RESPUESTA["respuesta"]
    enviado = ruta.calls.last.request
    cuerpo = json.loads(enviado.content)
    assert enviado.headers["X-Chat-Token"] == config.n8n_secreto
    assert cuerpo == {"token_sesion": token_laura, "sesion_id": None, "mensaje": "¿Qué me recomiendas?"}


@respx.mock
def test_chat_con_sesion(cliente, token_laura):
    ruta = respx.post(URL_N8N).mock(return_value=httpx.Response(200, json=RESPUESTA))
    sesion = "8a6f0c2e-6c51-4f6a-9d2f-1c2b3d4e5f60"
    cliente.post("/api/v1/chat", json={"mensaje": "¿y cuándo?", "sesion_id": sesion}, headers=auth(token_laura))
    assert json.loads(ruta.calls.last.request.content)["sesion_id"] == sesion


def test_chat_valida_el_mensaje(cliente, token_laura):
    assert cliente.post("/api/v1/chat", json={"mensaje": "   "}, headers=auth(token_laura)).status_code == 422
    assert cliente.post("/api/v1/chat", json={"mensaje": "x" * 1501}, headers=auth(token_laura)).status_code == 422
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola", "sesion_id": "no-uuid"},
                        headers=auth(token_laura)).status_code == 422


def test_chat_sin_sesion(cliente):
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}).status_code == 401


@respx.mock
def test_chat_n8n_tarda_demasiado(cliente, token_laura):
    respx.post(URL_N8N).mock(side_effect=httpx.ReadTimeout("lento"))
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code == 504


@respx.mock
def test_chat_n8n_caido(cliente, token_laura):
    respx.post(URL_N8N).mock(side_effect=httpx.ConnectError("caído"))
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code == 502


@respx.mock
def test_chat_n8n_error_y_formato_invalido(cliente, token_laura):
    respx.post(URL_N8N).mock(return_value=httpx.Response(500, json={"message": "error"}))
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code == 502
    respx.post(URL_N8N).mock(return_value=httpx.Response(200, json={"otra": "cosa"}))
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code == 502


@respx.mock
def test_chat_sesion_vencida_en_n8n(cliente, token_laura):
    respx.post(URL_N8N).mock(return_value=httpx.Response(401, json={"error": "Sesión no válida"}))
    assert cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code == 401


@respx.mock
def test_chat_limite_por_minuto(cliente, token_laura):
    respx.post(URL_N8N).mock(return_value=httpx.Response(200, json=RESPUESTA))
    codigos = [cliente.post("/api/v1/chat", json={"mensaje": "hola"}, headers=auth(token_laura)).status_code
               for _ in range(4)]
    assert codigos == [200, 200, 200, 429]


def test_sesiones_y_mensajes(cliente, token_laura, token_otro):
    from app.db import consultar
    from tests.conftest import LAURA

    sesion_id = consultar(
        "insert into sesion_chat (estudiante_codigo, titulo) values (%s, 'Prueba de la API') returning id",
        (LAURA,), estudiante=LAURA,
    )[0]["id"]

    lista = cliente.get("/api/v1/chat/sesiones", headers=auth(token_laura)).json()["sesiones"]
    assert any(s["id"] == sesion_id for s in lista)

    r = cliente.get(f"/api/v1/chat/sesiones/{sesion_id}/mensajes", headers=auth(token_laura))
    assert r.status_code == 200 and r.json()["mensajes"] == []

    # Otro estudiante no puede ver ni archivar esa conversación
    assert cliente.get(f"/api/v1/chat/sesiones/{sesion_id}/mensajes", headers=auth(token_otro)).status_code == 404
    assert cliente.delete(f"/api/v1/chat/sesiones/{sesion_id}", headers=auth(token_otro)).status_code == 404

    assert cliente.delete(f"/api/v1/chat/sesiones/{sesion_id}", headers=auth(token_laura)).status_code == 204
    lista = cliente.get("/api/v1/chat/sesiones", headers=auth(token_laura)).json()["sesiones"]
    assert all(s["id"] != sesion_id for s in lista)
