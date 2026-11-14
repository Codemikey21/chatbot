import jwt

from tests.conftest import CONTRASENA_DEMO, LAURA, auth, firmar

MENSAJE_401 = "Código o contraseña incorrectos"


def test_login_correcto(cliente, config):
    r = cliente.post("/api/v1/auth/login", json={"codigo": LAURA.lower(), "contrasena": CONTRASENA_DEMO})
    assert r.status_code == 200
    datos = r.json()
    assert datos["tipo"] == "Bearer" and datos["expira_en"] == config.jwt_minutos * 60
    assert datos["estudiante"]["codigo"] == LAURA
    assert datos["estudiante"]["nombres"].startswith("Laura")
    claims = jwt.decode(datos["token"], config.jwt_secreto, algorithms=["HS256"],
                        issuer=config.jwt_emisor, audience=config.jwt_audiencia)
    assert claims["sub"] == LAURA and claims["rol"] == "estudiante"


def test_login_contrasena_incorrecta_y_luego_correcta(cliente):
    r = cliente.post("/api/v1/auth/login", json={"codigo": LAURA, "contrasena": "otra"})
    assert r.status_code == 401 and MENSAJE_401 in r.json()["detail"]
    # El login correcto reinicia el contador de intentos fallidos
    r = cliente.post("/api/v1/auth/login", json={"codigo": LAURA, "contrasena": CONTRASENA_DEMO})
    assert r.status_code == 200


def test_login_codigo_inexistente_mismo_mensaje(cliente):
    r = cliente.post("/api/v1/auth/login", json={"codigo": "U00999999", "contrasena": "x"})
    assert r.status_code == 401 and MENSAJE_401 in r.json()["detail"]


def test_login_codigo_con_formato_invalido(cliente):
    r = cliente.post("/api/v1/auth/login", json={"codigo": "' or 1=1 --", "contrasena": "x"})
    assert r.status_code == 422


def test_limite_de_intentos_por_ip(cliente):
    codigos = [cliente.post("/api/v1/auth/login", json={"codigo": "U00999999", "contrasena": "x"}).status_code
               for _ in range(9)]
    assert codigos[:8] == [401] * 8
    assert codigos[8] == 429


def test_limite_devuelve_retry_after(cliente):
    for _ in range(8):
        cliente.post("/api/v1/auth/login", json={"codigo": "U00999999", "contrasena": "x"})
    r = cliente.post("/api/v1/auth/login", json={"codigo": "U00999999", "contrasena": "x"})
    assert r.status_code == 429 and int(r.headers["Retry-After"]) > 0


def test_sesion_valida(cliente, token_laura):
    r = cliente.get("/api/v1/auth/sesion", headers=auth(token_laura))
    assert r.status_code == 200 and r.json()["codigo"] == LAURA


def test_sesion_sin_token(cliente):
    assert cliente.get("/api/v1/auth/sesion").status_code == 401


def test_sesion_token_vencido(cliente, config):
    r = cliente.get("/api/v1/auth/sesion", headers=auth(firmar(LAURA, config, minutos=-1)))
    assert r.status_code == 401 and "venció" in r.json()["detail"]


def test_sesion_token_mal_firmado(cliente, config):
    r = cliente.get("/api/v1/auth/sesion", headers=auth(firmar(LAURA, config, secreto="otro-secreto")))
    assert r.status_code == 401


def test_sesion_token_de_otro_emisor(cliente, config):
    r = cliente.get("/api/v1/auth/sesion", headers=auth(firmar(LAURA, config, iss="otra-api")))
    assert r.status_code == 401


def test_sesion_codigo_no_valido_en_token(cliente, config):
    r = cliente.get("/api/v1/auth/sesion", headers=auth(firmar("admin", config)))
    assert r.status_code == 401
