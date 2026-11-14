# API segura (FastAPI)

Única puerta de entrada de la app móvil. Autentica al estudiante, emite su token de sesión (JWT), lee sus datos en Supabase con RLS y reenvía el chat al orquestador n8n. n8n, el servidor MCP y el scraper no se exponen a la app.

```text
App Flutter ──HTTPS──► API (FastAPI) ──► Supabase (rol chatbot_api + RLS)
                          │
                          └──► n8n WF01 (webhook interno + X-Chat-Token) ──► agente, RAG, MCP, Sheets, noticias
```

- **Base:** `/api/v1`. Documentación interactiva (contratos) en `/docs`.
- **Salud:** `GET /health` → `{"estado": "ok", "base_de_datos": true, "n8n": true}`.
- **Puerto:** `8080`. En local queda en `127.0.0.1:8080`; el emulador de Android entra por `http://10.0.2.2:8080`. En EC2 la publica Caddy con HTTPS.

## Endpoints

| Método y ruta | Sesión | Qué devuelve |
|---|---|---|
| `POST /api/v1/auth/login` | No | Token JWT y perfil del estudiante |
| `GET /api/v1/auth/sesion` | Sí | Perfil, si el token guardado sigue vigente |
| `GET /api/v1/estudiante/resumen` | Sí | Insignia por pilares, avance del plan y semestres restantes |
| `GET /api/v1/estudiante/historial?tipo=` | Sí | Cursos por periodo (`todos`, `competencia_digital`, `asignatura`) |
| `GET /api/v1/estudiante/recomendaciones` | Sí | Curso recomendado por pilar pendiente, con razones y NRC |
| `GET /api/v1/cursos` | Sí | Pilares, cursos y secciones abiertas |
| `GET /api/v1/calendario?tipo=&solo_proximos=` | Sí | Eventos con su estado (próximo, en curso, finalizado) |
| `GET /api/v1/noticias?categoria=&limite=` | Sí | Noticias y convocatorias del scraper |
| `POST /api/v1/chat` | Sí | Respuesta del asistente con intención, fuentes y herramientas |
| `GET /api/v1/chat/sesiones` | Sí | Conversaciones anteriores |
| `GET /api/v1/chat/sesiones/{id}/mensajes` | Sí | Mensajes de una conversación propia |
| `DELETE /api/v1/chat/sesiones/{id}` | Sí | Archiva una conversación |

Ejemplo de login:

```json
POST /api/v1/auth/login
{ "codigo": "U00900100", "contrasena": "Demo2026*" }

200
{ "token": "eyJ…", "tipo": "Bearer", "expira_en": 7200,
  "estudiante": { "codigo": "U00900100", "nombres": "Laura Valentina", "apellidos": "Rojas Méndez",
                  "programa": "Ingeniería de Sistemas", "semestre_actual": 6 } }
```

## Seguridad

- **Login:** `fn_autenticar` compara la contraseña con bcrypt y bloquea la cuenta 15 minutos tras 5 intentos fallidos. La API responde el mismo mensaje si el código no existe, si la contraseña falla o si la cuenta está bloqueada, para no revelar qué códigos existen. Además limita los intentos por IP (10 cada 5 minutos).
- **Token de sesión:** JWT HS256 con emisor `chatbot-unab-api`, audiencia `chatbot-unab`, vencimiento (`JWT_EXPIRES_MINUTES`) e identificador único. Lo verifican la API, n8n (WF01 y WF03) y el servidor MCP.
- **Identidad:** el código del estudiante sale siempre del token, nunca de un parámetro. Cada consulta fija `app.estudiante_id` en la transacción y las políticas RLS solo devuelven sus filas: pedir la conversación de otro estudiante responde 404.
- **Mínimo privilegio:** el rol `chatbot_api` solo puede ejecutar el login, leer el catálogo y los datos propios, y crear o archivar sus sesiones de chat. No puede leer contraseñas ni escribir mensajes.
- **Chat:** máximo 12 mensajes por minuto por estudiante; mensajes de 1 a 1500 caracteres; tiempo máximo de espera de n8n de 90 s. Las respuestas de n8n se validan antes de entregarlas.
- **Errores:** si la base de datos o n8n fallan, la API responde 503, 502 o 504 con un mensaje claro y sin detalles internos.
- **Cabeceras:** `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` y `Cache-Control: no-store` en todas las respuestas de la API.

## Ejecución local

Requisitos: Python 3.11 y el `.env` en la raíz del repositorio (`SUPABASE_DB_*`, `DB_API_USER`, `DB_API_PASSWORD`, `JWT_*`, `N8N_WEBHOOK_SECRET`).

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest
```

Las pruebas usan Supabase con los estudiantes DEMO y simulan n8n, así que no consumen el modelo de lenguaje.

Con Docker se levanta junto con los demás servicios (`docker compose up -d`). Dentro de Docker la API llama a n8n en `http://n8n:5678/webhook/`.
