"""Acceso a PostgreSQL con un pool de conexiones y el contexto del estudiante para RLS."""

import logging
from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

log = logging.getLogger(__name__)

_pool: ConnectionPool | None = None


class BaseDeDatosNoDisponible(Exception):
    """La base de datos no respondió (red, credenciales o tiempo de espera)."""


def iniciar_pool(conninfo: str) -> None:
    global _pool
    if _pool is None:
        try:
            with psycopg.connect(conninfo) as prueba:
                prueba.execute("select 1")
        except psycopg.OperationalError as error:
            # "from None" evita que el traceback muestre la cadena de conexión.
            raise RuntimeError(f"No se pudo conectar a la base de datos: {error}") from None
        _pool = ConnectionPool(conninfo, min_size=1, max_size=8, timeout=15, open=True)
        log.info("Pool de conexiones listo")


def cerrar_pool() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


def _a_json(valor: Any) -> Any:
    """Convierte tipos de PostgreSQL a valores serializables en JSON."""
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, (date, datetime)):
        return valor.isoformat()
    if isinstance(valor, UUID):
        return str(valor)
    if isinstance(valor, list):
        return [_a_json(v) for v in valor]
    if isinstance(valor, dict):
        return {k: _a_json(v) for k, v in valor.items()}
    return valor


def consultar(sql: str, parametros: tuple | dict | None = None,
              estudiante: str | None = None) -> list[dict[str, Any]]:
    """Ejecuta una consulta parametrizada dentro de una transacción.

    Si se indica un estudiante, se fija app.estudiante_id solo para esta
    transacción: las políticas RLS limitan los datos personales a ese
    estudiante y el valor desaparece al terminar.
    """
    if _pool is None:
        raise BaseDeDatosNoDisponible("El pool de conexiones no está iniciado")
    try:
        with _pool.connection() as conexion:
            with conexion.transaction():
                with conexion.cursor(row_factory=dict_row) as cursor:
                    if estudiante:
                        cursor.execute("select set_config('app.estudiante_id', %s, true)", (estudiante,))
                    cursor.execute(sql, parametros)
                    filas = cursor.fetchall() if cursor.description else []
    except (psycopg.OperationalError, psycopg.errors.QueryCanceled) as error:
        log.error("Error de conexión con la base de datos: %s", type(error).__name__)
        raise BaseDeDatosNoDisponible(str(error)) from None
    return [_a_json(fila) for fila in filas]


def verificar_conexion() -> bool:
    try:
        return consultar("select 1 as ok")[0]["ok"] == 1
    except Exception:  # noqa: BLE001
        log.exception("La base de datos no responde")
        return False
