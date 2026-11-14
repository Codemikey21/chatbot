"""Pruebas del servidor MCP con un cliente en memoria."""

import pytest
from fastmcp import Client
from fastmcp.exceptions import ToolError

from app.servidor import mcp
from tests.conftest import crear_token

pytestmark = pytest.mark.usefixtures("base_de_datos")

HERRAMIENTAS = {
    "consultar_cursos_disponibles",
    "obtener_requisitos",
    "consultar_calendario",
    "consultar_noticias",
    "consultar_historial",
    "consultar_progreso",
    "obtener_recomendaciones",
}


async def test_expone_las_siete_herramientas_de_solo_lectura():
    async with Client(mcp) as cliente:
        herramientas = await cliente.list_tools()
    assert {t.name for t in herramientas} == HERRAMIENTAS
    assert all(t.annotations.read_only_hint for t in herramientas)


async def test_progreso_con_token_valido():
    async with Client(mcp) as cliente:
        resultado = await cliente.call_tool("consultar_progreso", {"token_sesion": crear_token("U00900100")})
    assert resultado.data["estudiante"]["codigo"] == "U00900100"


async def test_herramienta_personal_rechaza_token_falso():
    async with Client(mcp) as cliente:
        with pytest.raises(ToolError, match="no es válido"):
            await cliente.call_tool(
                "consultar_historial",
                {"token_sesion": crear_token("U00900105", secreto="token-inventado")},
            )


async def test_pilar_desconocido_da_mensaje_util():
    async with Client(mcp) as cliente:
        with pytest.raises(ToolError, match="Pilar no reconocido"):
            await cliente.call_tool("consultar_cursos_disponibles", {"pilar": "astronomia"})
