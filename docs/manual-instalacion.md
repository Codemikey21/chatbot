# Manual de instalación

Guía para levantar el asistente académico desde cero en un equipo con Windows (los comandos de Docker y Python son iguales en Linux y macOS). Al final está la parte de AWS EC2.

> Los datos académicos son **demostrativos** (DEMO): estudiantes, notas, NRC, prerrequisitos y calendario son ficticios. Ver `docs/decisiones.md`.

## 1. Requisitos

| Herramienta | Versión usada |
|---|---|
| Git | cualquiera reciente |
| Docker Desktop | con Docker Compose v2 |
| Python | 3.11 (para pruebas y scripts) |
| Flutter | 3.44 (Dart 3.12) con Android SDK 36 |
| Android Studio | emulador o celular Android con depuración USB |

Cuentas y llaves necesarias:

| Servicio | Para qué | Dónde se obtiene |
|---|---|---|
| Supabase | Base de datos PostgreSQL con pgvector | supabase.com (proyecto en us-west-2) |
| Claude (Anthropic) | Modelo de lenguaje del chat | Consola de Claude, API key |
| Voyage AI | Embeddings del RAG | Panel de Voyage AI, API key |
| Google Cloud | Leer el calendario de Google Sheets | Cuenta de servicio con la Google Sheets API activada |

## 2. Clonar y configurar variables

```powershell
git clone https://github.com/Codemikey21/chatbot.git
cd chatbot
Copy-Item .env.example .env
```

Abre `.env` y completa cada valor. Para los secretos (`N8N_ENCRYPTION_KEY`, `N8N_WEBHOOK_SECRET`, `JWT_SECRET`, `MCP_AUTH_TOKEN`, `SCRAPER_TOKEN` y las contraseñas de los roles) genera cadenas aleatorias así:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

`.env` y la carpeta `secrets/` están en `.gitignore` y nunca se suben al repositorio.

## 3. Base de datos en Supabase

1. Crea el proyecto en la región **us-west-2 (Oregon)**. En *Settings* desactiva la Data API (ningún componente la usa).
2. En **SQL Editor** ejecuta, en este orden, cada archivo de `database/migrations/`:

   `001_extensiones_y_catalogo.sql` → `002_estudiantes_e_historial.sql` → `003_calendario_rag_noticias.sql` → `004_chat_y_seguridad.sql` → `005_vistas.sql` → `006_roles_seguridad_y_rls.sql` → `007_funciones_rag.sql` → `008_funciones_chat.sql` → `009_funciones_noticias.sql`

3. Luego los datos de `database/seeds/`, también en orden: `001_catalogo.sql` → `002_estudiantes_demo.sql` → `003_calendario_demo.sql` → `004_fuentes_noticias.sql`.
4. Activa los roles de la aplicación con las contraseñas que pusiste en `.env` (este script no se guarda en el repositorio):

   ```sql
   alter role chatbot_api with login password '<DB_API_PASSWORD>';
   alter role chatbot_mcp with login password '<DB_MCP_PASSWORD>';
   alter role chatbot_n8n with login password '<DB_N8N_PASSWORD>';
   ```

5. En **Connect → Session pooler** copia el host al `.env` (`SUPABASE_DB_HOST`). Los usuarios llevan el sufijo del proyecto, por ejemplo `chatbot_api.<project-ref>`.

## 4. Calendario en Google Sheets

1. Crea una hoja de cálculo con una pestaña llamada `calendario`.
2. Importa `database/seeds/calendario_demo.csv` en esa pestaña **sin convertir el texto a fechas** (las fechas van como texto `AAAA-MM-DD`).
3. Comparte la hoja con el correo de la cuenta de servicio, con permiso de **Lector**.
4. Guarda la llave JSON de la cuenta de servicio en `secrets/google-service-account.json`.
5. Si usas una hoja distinta a la del proyecto, cambia su ID en el nodo de Google Sheets de `WF02 - Consulta de calendario`.

## 5. Levantar los servicios

```powershell
docker compose up -d --build
docker compose ps
```

Los cuatro contenedores (`chatbot-n8n`, `chatbot-api`, `chatbot-mcp`, `chatbot-scraper`) deben quedar en estado `running`. Comprueba la salud:

```powershell
curl.exe http://localhost:5678/healthz
curl.exe http://localhost:9000/health
curl.exe http://localhost:8080/health
```

La API responde `{"estado":"ok","base_de_datos":true,"n8n":true}` cuando llega a Supabase y a n8n. El scraper no publica puertos: se revisa con `docker compose logs scraper`.

## 6. Configurar n8n

1. Abre `http://localhost:5678` y crea la cuenta de administrador.
2. Crea las 9 credenciales con los **nombres exactos** de la tabla de `n8n/README.md` (Supabase, Voyage, Claude, Google Sheets, JWT, MCP, Chat, Scraper e Ingesta). La importación las enlaza por nombre.
3. Importa los workflows con sus IDs fijos:

   ```powershell
   docker compose exec n8n n8n import:workflow --separate --input=/data/workflows
   ```

4. Abre cada workflow y pulsa **Publish**, también los sub-workflows (WF02, WF03, WF04 y AUX). Si un sub-workflow no está publicado, el agente responde `Workflow is not active and cannot be executed`.

## 7. Cargar los documentos del RAG

1. En n8n abre `AUX - Ingesta de documentos (RAG)` y ejecuta el disparador **Ejecutar manualmente**. Lee `rag/corpus/`, fragmenta los documentos, genera los embeddings con Voyage y los guarda en pgvector. Con la cuenta gratuita de Voyage tarda unos minutos por las pausas entre lotes.
2. Evalúa la recuperación (usa el entorno de Python del servidor MCP, ver el paso 9):

   ```powershell
   mcp-server\.venv\Scripts\python.exe rag\evaluacion\evaluar.py
   ```

## 8. Cargar las noticias

En n8n abre `WF04 - Noticias y nuevos cursos` y ejecuta el disparador **Cada 6 horas** con el botón *Execute*. El nodo **Resumen** muestra cuántas noticias nuevas, actualizadas y sin cambios hubo por fuente. Después corre solo cada 6 horas.

## 9. Probar el backend de punta a punta

Crea una vez el entorno de Python que usan los scripts de prueba:

```powershell
cd mcp-server
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
cd ..
```

Luego, desde la raíz del repositorio:

```powershell
# Chat completo en n8n: RAG, calendario, MCP, noticias, guardrails y memoria
mcp-server\.venv\Scripts\python.exe tests\integracion\probar_chat.py

# API: login, datos del estudiante, chat y memoria
mcp-server\.venv\Scripts\python.exe tests\integracion\probar_api.py
```

Cada prueba imprime `OK` o `XX` (falla) con el detalle, y al final el total aprobado. Las pruebas unitarias de cada servicio están en su README y en `docs/pruebas.md`.

## 10. App móvil

```powershell
cd mobile_app
flutter pub get
flutter analyze
flutter test
```

**En el emulador de Android** (la app usa `http://10.0.2.2:8080/api/v1` por defecto):

```powershell
flutter run
```

**En un celular Android por cable:** activa *Opciones de desarrollador → Depuración USB*, conecta el celular y ejecuta:

```powershell
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_URL=http://localhost:8080/api/v1
```

**APK para instalar** (cuando la API esté publicada con HTTPS):

```powershell
flutter build apk --release --dart-define=API_URL=https://chatbot-unab-demo.duckdns.org/api/v1
```

El archivo queda en `mobile_app\build\app\outputs\flutter-apk\app-release.apk`.

**Usuario de prueba:** código `U00900100`, contraseña `Demo2026*` (todos los estudiantes DEMO usan la misma contraseña). En la pantalla de inicio de sesión, *Usar cuenta de prueba* llena los campos.

## 11. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `/health` de la API dice `"n8n": false` | n8n no ha terminado de arrancar o está detenido | `docker compose ps` y `docker compose logs n8n` |
| La app dice que no hay conexión | La API no está corriendo o la URL no corresponde al dispositivo | Emulador: `10.0.2.2`; celular por USB: `adb reverse` + `localhost` |
| El chat responde "no pude consultar mis fuentes" | Falló Claude (llave, cuota o red) | Revisar la credencial `Claude - Anthropic` y la ejecución en n8n |
| `Workflow is not active and cannot be executed` | Un sub-workflow no está publicado | Publicarlo en n8n |
| HTTP 401 en el chat | Token vencido o `JWT_SECRET` distinto entre servicios | Iniciar sesión de nuevo y revisar `JWT_*` en `.env` |
| Error de conexión a Supabase | Host, usuario o contraseña del pooler | Revisar `SUPABASE_DB_*` y que el rol tenga `login` |
| El RAG no encuentra nada | No se ejecutó la ingesta | Paso 7 |

Más casos en `n8n/README.md` y en el README de cada servicio.

## 12. Despliegue en AWS EC2

> **Pendiente (fase 8).** Esta sección se completa con los archivos de despliegue (`infrastructure/`) cuando se monte y se verifique la instancia. Hasta entonces el sistema solo está probado en local.

Plan:

1. Instancia Ubuntu en el Learner Lab de AWS Academy, región us-west-2, con Elastic IP.
2. Security Group: 22 solo desde la IP del desarrollador, 80 y 443 para Caddy, 9000 para el servidor MCP con HTTPS.
3. Docker y Docker Compose en la instancia, el repositorio clonado y el `.env` copiado por SSH.
4. Caddy como proxy con HTTPS para `chatbot-unab-demo.duckdns.org` (API en `/api/v1` y MCP en el puerto 9000). n8n queda sin publicar y se administra por túnel SSH.
5. Como las sesiones del laboratorio duran 4 horas, hay que iniciar el laboratorio unos 40 minutos antes de la demostración.
