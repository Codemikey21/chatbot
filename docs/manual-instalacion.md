# Manual de instalación

Guía para levantar el asistente académico desde cero en un equipo con Windows (los comandos de Docker y Python son iguales en Linux y macOS). La sección 12 explica el despliegue en AWS EC2.

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

   `001_extensiones_y_catalogo.sql` → `002_estudiantes_e_historial.sql` → `003_calendario_rag_noticias.sql` → `004_chat_y_seguridad.sql` → `005_vistas.sql` → `006_roles_seguridad_y_rls.sql` → `007_funciones_rag.sql` → `008_funciones_chat.sql` → `009_funciones_noticias.sql` → `010_requisito_practica.sql`

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

**APK para instalar** (usa la API publicada en AWS, sección 12):

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

Verificado el 2026-11-14: la API, el chat y el servidor MCP responden por HTTPS desde internet (ver `docs/pruebas.md`), y la versión web de la app queda publicada en la raíz del dominio.

```text
Internet ──► Caddy (80, 443, 9000, HTTPS) ──► api:8080        /api/v1 y /health
                                          ├─► /srv/web        versión web de la app
                                          └─► mcp-server:9000 :9000/mcp
            n8n (5678) y scraper (8000): solo red interna; n8n se administra por túnel SSH
```

### 12.1 Instancia (consola de AWS Academy)

1. Learner Lab → **Start Lab** → **AWS**. Región **us-west-2 (Oregón)**, la misma de Supabase.
2. **EC2 → Lanzar instancia:** nombre `chatbot-unab`, **Ubuntu Server 24.04 LTS** (64 bits x86), tipo `t3.medium`, un par de claves RSA en formato `.pem` y **30 GiB** gp3.
3. **Grupo de seguridad** `chatbot-sg`:

| Puerto | Origen | Uso |
|---|---|---|
| 22 (SSH) | Solo la IPv4 del desarrollador (`x.x.x.x/32`) | Administración y túnel a n8n |
| 80 (HTTP) | Cualquier lugar | Certificado de Let's Encrypt y redirección a HTTPS |
| 443 (HTTPS) | Cualquier lugar | API y versión web |
| 9000 (TCP) | Cualquier lugar | Servidor MCP con HTTPS |

   "Mi IP" de la consola puede tomar la IPv6 del equipo; la instancia solo tiene IPv4, así que se usa la IPv4 (`curl.exe -4 ifconfig.me`).
4. **Direcciones IP elásticas → Asignar** y **Asociar** a la instancia, para que la IP no cambie al reiniciar el laboratorio.
5. En **duckdns.org**, el dominio `chatbot-unab-demo` apunta a la IP elástica.
6. La llave `.pem` se guarda en `C:\Users\<usuario>\.ssh\` y se deja solo para el usuario:

   ```powershell
   icacls $HOME\.ssh\chatbot-key.pem /inheritance:r /grant:r "$($env:USERNAME):R"
   ssh -i $HOME\.ssh\chatbot-key.pem ubuntu@<IP-elastica>
   ```

### 12.2 Desde el PC

```powershell
git push

# Respaldo de n8n (credenciales y workflows publicados). Queda en secrets/, que no se sube a GitHub
docker compose stop n8n
docker run --rm -v chatbot_n8n_data:/datos -v "${PWD}\secrets:/respaldo" alpine tar czf /respaldo/n8n_data.tgz -C /datos .

# Versión web apuntando al dominio
cd mobile_app
flutter build web --release --dart-define=API_URL=https://chatbot-unab-demo.duckdns.org/api/v1
cd ..

# Copiar a la instancia
scp -i $HOME\.ssh\chatbot-key.pem .env secrets\n8n_data.tgz ubuntu@<IP-elastica>:/home/ubuntu/
scp -i $HOME\.ssh\chatbot-key.pem -r mobile_app\build\web ubuntu@<IP-elastica>:/home/ubuntu/web
```

Como el `.env` lleva la misma `N8N_ENCRYPTION_KEY`, las credenciales de n8n se pueden leer en la instancia sin volver a crearlas.

### 12.3 En la instancia

```bash
git clone https://github.com/Codemikey21/chatbot.git
cd chatbot
bash infrastructure/aws/instalar.sh     # Docker, Compose, 2 GB de swap y hora de Bogotá
exit                                     # volver a entrar para usar docker sin sudo
```

```bash
cd ~/chatbot
mv ~/.env .env && chmod 600 .env
sed -i 's/\r$//' .env
sed -i 's/^APP_ENV=.*/APP_ENV=aws/; s/^CORS_ORIGINS=.*/CORS_ORIGINS=/' .env
grep -q '^DOMINIO=' .env || echo 'DOMINIO=chatbot-unab-demo.duckdns.org' >> .env

mkdir -p mobile_app/build && mv ~/web mobile_app/build/web
docker volume create chatbot_n8n_data
docker run --rm -v chatbot_n8n_data:/datos -v ~/:/respaldo alpine tar xzf /respaldo/n8n_data.tgz -C /datos

echo "alias dc='docker compose -f docker-compose.yml -f docker-compose.aws.yml'" >> ~/.bashrc && source ~/.bashrc
getent hosts chatbot-unab-demo.duckdns.org   # debe mostrar la IP elástica
dc up -d --build
dc ps
```

`CORS_ORIGINS` queda vacío porque la versión web y la API se sirven desde el mismo dominio.

### 12.4 Verificación

```bash
curl -s https://chatbot-unab-demo.duckdns.org/health        # {"estado":"ok","base_de_datos":true,"n8n":true}
curl -s https://chatbot-unab-demo.duckdns.org:9000/health   # {"estado":"ok","base_de_datos":true}
```

Desde el PC, la prueba de la API contra AWS:

```powershell
$env:API_URL="https://chatbot-unab-demo.duckdns.org/api/v1"
mcp-server\.venv\Scripts\python.exe tests\integracion\probar_api.py
Remove-Item Env:API_URL
```

### 12.5 Uso diario

| Tarea | Cómo |
|---|---|
| Encender | Learner Lab → **Start Lab**. La instancia vuelve a encender y los contenedores arrancan solos (`restart: unless-stopped`). Esperar unos 5 minutos y abrir `/health`. |
| Antes de la demostración | Iniciar el laboratorio unos 40 minutos antes. La sesión dura 4 horas; **Start Lab** otra vez la renueva. |
| Entrar a n8n | `ssh -i $HOME\.ssh\chatbot-key.pem -L 5678:localhost:5678 ubuntu@<IP-elastica>` y abrir `http://localhost:5678` en el PC |
| Ver registros | `dc logs -f api` (o `caddy`, `n8n`, `mcp-server`, `scraper`) |
| Actualizar el código | `cd ~/chatbot && git pull && dc up -d --build` |
| Actualizar la versión web | Compilarla en el PC y copiarla de nuevo a `~/chatbot/mobile_app/build/web` |
| APK para Android | `flutter build apk --release --dart-define=API_URL=https://chatbot-unab-demo.duckdns.org/api/v1` (con `--split-per-abi` sale un archivo más liviano por tipo de procesador) |
| iPhone | Abrir `https://chatbot-unab-demo.duckdns.org` en Safari → Compartir → **Agregar a pantalla de inicio** |

### 12.6 Problemas comunes en AWS

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Permission denied (publickey)` | Ruta o permisos de la llave `.pem` | Revisar la ruta y aplicar el `icacls` del paso 12.1 |
| SSH no conecta (tiempo agotado) | Cambió la IP de la casa | Editar la regla 22 del grupo de seguridad con la IPv4 nueva |
| HTTPS no funciona o el navegador avisa del certificado | El dominio no apunta a la IP elástica | `getent hosts chatbot-unab-demo.duckdns.org`, corregir en DuckDNS y `dc restart caddy` |
| `/health` con `"n8n": false` | n8n sigue arrancando | Esperar un minuto y revisar `dc logs n8n` |
| El chat responde "no está disponible" | Workflows sin publicar en la instancia | Entrar a n8n por túnel y publicarlos |
