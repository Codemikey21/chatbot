"""Pruebas de integración de las consultas contra la base con datos DEMO."""

import pytest

from app import herramientas as h
from app.db import consultar

pytestmark = pytest.mark.usefixtures("base_de_datos")

DEMO = "U00900100"


def test_rls_sin_estudiante_no_devuelve_datos_personales():
    assert consultar("select count(*) as n from estudiante")[0]["n"] == 0
    assert consultar("select count(*) as n from inscripcion")[0]["n"] == 0


def test_rls_con_estudiante_solo_devuelve_sus_datos():
    filas = consultar("select distinct estudiante_codigo from inscripcion", estudiante=DEMO)
    assert [f["estudiante_codigo"] for f in filas] == [DEMO]


def test_rls_no_permite_ver_a_otro_estudiante():
    filas = consultar(
        "select count(*) as n from v_historial_academico where estudiante_codigo = %s",
        ("U00900105",),
        estudiante=DEMO,
    )
    assert filas[0]["n"] == 0


def test_rol_mcp_es_de_solo_lectura():
    with pytest.raises(Exception):
        consultar("insert into evento_seguridad (tipo) values ('fuera_de_alcance') returning id")


def test_cursos_disponibles_muestra_los_siete_cursos_digitales():
    datos = h.cursos_disponibles()
    assert len(datos["pilares"]) == 3
    assert len({c["curso_codigo"] for c in datos["oferta"]}) == 7
    assert all(c["curso_tipo"] == "competencia_digital" for c in datos["oferta"])


def test_cursos_disponibles_filtra_por_pilar():
    datos = h.cursos_disponibles("tecnologias")
    assert {c["curso_nombre"] for c in datos["oferta"]} == {
        "IA Generativa", "Marco Legal Digital", "Cuidado y Bienestar Digital",
    }


def test_requisitos_de_asignatura_sin_tildes():
    datos = h.requisitos_de_curso("calculo integral")
    assert datos["prerrequisitos"] == ["Cálculo Diferencial"]


def test_requisitos_de_practica_por_creditos_para_el_estudiante():
    datos = h.requisitos_de_curso("Práctica Profesional", DEMO)
    assert datos["creditos_minimos_previos"] == 110
    assert datos["estado_estudiante"]["puede_matricularla"] is False


def test_curso_digital_no_tiene_requisitos():
    datos = h.requisitos_de_curso("IA Generativa")
    assert datos["requisitos"] == []


def test_curso_inexistente_da_error_claro():
    with pytest.raises(ValueError, match="No encontré"):
        h.requisitos_de_curso("Astrofísica Cuántica")


def test_historial_de_competencias_digitales():
    datos = h.historial(DEMO, "competencia_digital")
    nombres = {c["curso_nombre"] for c in datos["cursos"] if c["estado"] == "aprobado"}
    assert nombres == {"Interacción Digital", "Marca Personal Digital"}


def test_progreso_del_usuario_demo():
    datos = h.progreso(DEMO)
    assert datos["competencias_digitales"]["pilares_aprobados"] == 2
    assert datos["competencias_digitales"]["pilares_pendientes"] == ["Tecnologías transformativas"]
    assert datos["plan_de_estudios"]["creditos_aprobados"] == 81
    assert datos["proyeccion"]["semestres_estimados"] == 3


def test_recomendacion_prioriza_ia_generativa():
    datos = h.recomendaciones(DEMO)
    primera = datos["recomendaciones"][0]
    assert primera["curso_nombre"] == "IA Generativa"
    assert primera["posicion"] == 1
    assert primera["razones"]


def test_estudiante_con_insignia_no_recibe_recomendaciones():
    datos = h.recomendaciones("U00900105")
    assert datos["recomendaciones"] == []
    assert "insignia" in datos["mensaje"]


def test_calendario_de_inscripciones():
    datos = h.calendario("inscripcion", solo_proximos=False)
    assert {e["id_evento"] for e in datos["eventos"]} == {"EV-003", "EV-007"}
