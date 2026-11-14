import httpx
import respx


@respx.mock
def test_salud(cliente):
    respx.get("http://n8n-prueba:5678/healthz").mock(return_value=httpx.Response(200))
    r = cliente.get("/health")
    assert r.status_code == 200
    assert r.json() == {"servicio": "api", "estado": "ok", "base_de_datos": True, "n8n": True}


@respx.mock
def test_salud_con_n8n_caido(cliente):
    respx.get("http://n8n-prueba:5678/healthz").mock(side_effect=httpx.ConnectError("caído"))
    datos = cliente.get("/health").json()
    assert datos["estado"] == "degradado" and datos["n8n"] is False


def test_cabeceras_de_seguridad(cliente):
    r = cliente.get("/api/v1/auth/sesion")
    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["X-Frame-Options"] == "DENY"
    assert r.headers["Cache-Control"] == "no-store"
