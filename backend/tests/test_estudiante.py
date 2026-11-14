from tests.conftest import LAURA, OTRO, auth


def test_resumen(cliente, token_laura):
    r = cliente.get("/api/v1/estudiante/resumen", headers=auth(token_laura))
    assert r.status_code == 200
    datos = r.json()
    assert datos["estudiante"]["codigo"] == LAURA
    insignia = datos["insignia"]
    assert insignia["pilares_totales"] == 3 and len(insignia["pilares"]) == 3
    assert insignia["pilares_aprobados"] == sum(p["aprobado"] for p in insignia["pilares"])
    assert 0 <= datos["plan_de_estudios"]["porcentaje_avance"] <= 100
    assert datos["proyeccion"]["semestres_estimados"] >= 1
    assert "DEMO" in datos["aviso"]


def test_resumen_es_del_estudiante_del_token(cliente, token_otro):
    datos = cliente.get("/api/v1/estudiante/resumen", headers=auth(token_otro)).json()
    assert datos["estudiante"]["codigo"] == OTRO


def test_resumen_sin_sesion(cliente):
    assert cliente.get("/api/v1/estudiante/resumen").status_code == 401


def test_historial_filtrado(cliente, token_laura):
    digitales = cliente.get("/api/v1/estudiante/historial?tipo=competencia_digital", headers=auth(token_laura)).json()
    assert digitales["cursos"] and all(c["curso_tipo"] == "competencia_digital" for c in digitales["cursos"])
    todos = cliente.get("/api/v1/estudiante/historial", headers=auth(token_laura)).json()
    assert len(todos["cursos"]) > len(digitales["cursos"])
    assert sum(todos["resumen"].values()) == len(todos["cursos"])


def test_historial_tipo_invalido(cliente, token_laura):
    r = cliente.get("/api/v1/estudiante/historial?tipo=otro", headers=auth(token_laura))
    assert r.status_code == 422


def test_recomendaciones(cliente, token_laura):
    datos = cliente.get("/api/v1/estudiante/recomendaciones", headers=auth(token_laura)).json()
    recomendaciones = datos["recomendaciones"]
    assert recomendaciones
    primera = recomendaciones[0]
    assert primera["posicion"] == 1 and primera["razones"]
    assert isinstance(primera["nrc_disponibles"], list)


def test_cursos(cliente, token_laura):
    datos = cliente.get("/api/v1/cursos", headers=auth(token_laura)).json()
    assert len(datos["pilares"]) == 3
    assert all(p["cursos"] for p in datos["pilares"])
    assert "cualquier orden" in datos["regla_insignia"]


def test_calendario(cliente, token_laura):
    proximos = cliente.get("/api/v1/calendario", headers=auth(token_laura)).json()["eventos"]
    assert proximos and all(e["estado"] != "finalizado" for e in proximos)
    inscripciones = cliente.get("/api/v1/calendario?tipo=inscripcion&solo_proximos=false",
                                headers=auth(token_laura)).json()["eventos"]
    assert inscripciones and all(e["tipo_evento"] == "inscripcion" for e in inscripciones)


def test_noticias(cliente, token_laura):
    r = cliente.get("/api/v1/noticias?limite=5", headers=auth(token_laura))
    assert r.status_code == 200
    noticias = r.json()["noticias"]
    assert len(noticias) <= 5
    for n in noticias:
        assert {"titulo", "categoria", "fuente", "enlace", "demostrativa"} <= n.keys()
        if n["demostrativa"]:
            assert n["enlace"] is None
