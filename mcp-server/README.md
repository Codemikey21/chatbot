# Servidor MCP

Servidor [Model Context Protocol](https://modelcontextprotocol.io) construido con **FastMCP** (Python). Expone herramientas de **solo lectura** para consultar la base académica en Supabase PostgreSQL. Lo usan los workflows de n8n y cualquier cliente MCP compatible.

- **Transporte:** HTTP streamable en el puerto `9000`, ruta `/mcp`.
- **Acceso:** token Bearer (`MCP_AUTH_TOKEN`).
- **Salud:** `GET /health` responde `{"estado": "ok", "base_de_datos": true}`.
- **Base de datos:** se conecta con el rol `chatbot_mcp`, de solo lectura, con un tiempo máximo de 5 s por consulta y sujeto a RLS.

## Herramientas

| Herramienta | Datos personales | Qué devuelve |
|---|---|---|
| `consultar_cursos_disponibles` | No | Cursos de competencias digitales abiertos (NRC, cupos, modalidad), los tres pilares y la regla de la insignia |
| `obtener_requisitos` | Opcional | Prerrequisitos, correquisitos y créditos mínimos de un curso; con token, si el estudiante ya puede matricularlo |
| `consultar_calendario` | No | Eventos del calendario académico (inscripciones, pruebas diagnósticas, inicio de cursos, insignias) |
| `consultar_noticias` | No | Noticias, convocatorias y cursos nuevos recopilados por el scraper |
| `consultar_historial` | Sí | Historial del estudiante: periodo, NRC, curso, estado y nota |
| `consultar_progreso` | Sí | Pilares e insignia, avance del pensum, semestres restantes estimados y materias que puede matricular |
| `obtener_recomendaciones` | Sí | Cursos digitales recomendados en los pilares pendientes, con la razón de cada uno |

## Seguridad de los datos personales

Las herramientas personales no reciben un código de estudiante: reciben `token_sesion`, el JWT que emite la API al iniciar sesión (HS256, emisor `chatbot-unab-api`, audiencia `chatbot-unab`, `sub` = código del estudiante).

1. El servidor verifica la firma, el emisor, la audiencia y la expiración del token. Un modelo de lenguaje no puede fabricar ni modificar ese token, así que no puede pedir datos de otro estudiante.
2. El código extraído se fija en la transacción con `set_config('app.estudiante_id', ...)`.
3. Las políticas RLS de PostgreSQL solo devuelven las filas de ese estudiante.
4. El rol `chatbot_mcp` no puede escribir ni leer contraseñas, y todas las consultas son parametrizadas.

## Ejecución local

Requisitos: Python 3.11 y el archivo `.env` en la raíz del repositorio con `SUPABASE_DB_*`, `DB_MCP_USER`, `DB_MCP_PASSWORD`, `MCP_AUTH_TOKEN` y `JWT_SECRET`.

```powershell
cd mcp-server
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt

# Pruebas (las de integración usan la base configurada en .env)
python -m pytest -v

# Servidor en http://localhost:9000/mcp
python -m app.servidor
```

## Ejecución con Docker

Desde la raíz del repositorio:

```powershell
docker compose up -d --build mcp-server
docker compose ps
curl.exe http://localhost:9000/health
```

## Conectar clientes MCP

En todos los casos se usa la URL del servidor y el token Bearer `MCP_AUTH_TOKEN`. Para probar las herramientas personales sin pasar por la API se puede generar un token de sesión DEMO:

```powershell
python scripts/generar_token.py U00900100
```

### n8n
Nodo **MCP Client Tool** (para agentes) o **MCP Client** (llamada directa):
- Endpoint: `http://mcp-server:9000/mcp` (dentro de la red de Docker)
- Server Transport: `HTTP Streamable`
- Authentication: `Bearer Auth` con el valor de `MCP_AUTH_TOKEN`

Las herramientas personales se llaman desde un nodo MCP Client con el `token_sesion` que llega en la petición de la API. El modelo nunca recibe ni elige el token.

### MCP Inspector
```powershell
npx @modelcontextprotocol/inspector
```
Transport `Streamable HTTP`, URL `http://localhost:9000/mcp`, y en Authentication el header `Authorization: Bearer <MCP_AUTH_TOKEN>`.

### Claude (API de Anthropic, conector MCP)
El servidor debe estar publicado con HTTPS (en AWS: `https://<dominio>:9000/mcp`).

```json
{
  "model": "claude-haiku-5-5",
  "max_tokens": 1024,
  "messages": [{"role": "user", "content": "¿Qué cursos de competencias digitales hay disponibles?"}],
  "mcp_servers": [
    {
      "type": "url",
      "url": "https://<dominio>:9000/mcp",
      "name": "chatbot-academico",
      "authorization_token": "<MCP_AUTH_TOKEN>"
    }
  ],
  "tools": [{"type": "mcp_toolset", "mcp_server_name": "chatbot-academico"}]
}
```
Encabezado requerido: `anthropic-beta: mcp-client-2025-11-20`.

### Claude Desktop
En `claude_desktop_config.json`, usando el puente `mcp-remote`:

```json
{
  "mcpServers": {
    "chatbot-academico": {
      "command": "npx",
      "args": ["mcp-remote", "https://<dominio>:9000/mcp",
               "--header", "Authorization: Bearer <MCP_AUTH_TOKEN>"]
    }
  }
}
```

### OpenAI (Responses API)
```json
{
  "model": "<modelo>",
  "input": "¿Cuándo son las pruebas diagnósticas?",
  "tools": [{
    "type": "mcp",
    "server_label": "chatbot-academico",
    "server_url": "https://<dominio>:9000/mcp",
    "headers": {"Authorization": "Bearer <MCP_AUTH_TOKEN>"},
    "require_approval": "never"
  }]
}
```

## Estructura

```
mcp-server/
├── app/
│   ├── config.py        Variables de entorno
│   ├── db.py            Pool de conexiones y contexto RLS
│   ├── seguridad.py     Token Bearer y verificación del JWT del estudiante
│   ├── herramientas.py  Consultas académicas (parametrizadas)
│   └── servidor.py      Servidor FastMCP, herramientas y /health
├── scripts/generar_token.py
├── tests/               Pruebas de seguridad, consultas y servidor
├── Dockerfile
└── requirements.txt
```
