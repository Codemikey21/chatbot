"""Pruebas del token de sesión del estudiante (no requieren base de datos)."""

import pytest
from fastmcp.exceptions import ToolError

from app.config import Configuracion
from app.seguridad import estudiante_desde_token
from tests.conftest import crear_token


def _verificar(token: str) -> str:
    c = Configuracion()
    return estudiante_desde_token(token, c.jwt_secreto, c.jwt_emisor, c.jwt_audiencia)


def test_token_valido_devuelve_el_codigo():
    assert _verificar(crear_token("U00900100")) == "U00900100"


def test_token_vencido_se_rechaza():
    with pytest.raises(ToolError, match="venció"):
        _verificar(crear_token("U00900100", minutos=-5))


def test_token_con_otra_firma_se_rechaza():
    with pytest.raises(ToolError, match="no es válido"):
        _verificar(crear_token("U00900100", secreto="otro-secreto"))


def test_token_de_otra_audiencia_se_rechaza():
    with pytest.raises(ToolError, match="no es válido"):
        _verificar(crear_token("U00900100", aud="otra-aplicacion"))


def test_token_con_codigo_invalido_se_rechaza():
    with pytest.raises(ToolError, match="estudiante válido"):
        _verificar(crear_token("ADMIN; drop table estudiante"))


def test_token_vacio_se_rechaza():
    with pytest.raises(ToolError, match="Se requiere"):
        _verificar("")
