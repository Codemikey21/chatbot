# App móvil (Flutter)

App Android del asistente académico. Consume **solo** la API segura (`backend/`); toda la información viene del backend real: Supabase, n8n, el servidor MCP, Google Sheets y el scraper.

## Pantallas

| Pantalla | Qué muestra | Datos |
|---|---|---|
| Arranque | Emblema animado mientras recupera la sesión guardada | `GET /auth/sesion` |
| Bienvenida | Foto del campus, logo de la universidad, accesos principales y botón *Comenzar*, con animación de entrada | — |
| Inicio de sesión | Logo, código y contraseña, enlace *Usar cuenta de prueba*, errores claros | `POST /auth/login` |
| Inicio | Saludo, insignia por pilares, avance del plan, accesos y próximo evento | `/estudiante/resumen`, `/calendario` |
| Chat | Conversación con el agente, respuestas en Markdown, fuentes, indicador de escritura, reintento | `POST /chat` |
| Conversaciones | Conversaciones anteriores; abrir o archivar | `/chat/sesiones` |
| Cursos | Pilares de la insignia, cursos y secciones (NRC, horario, cupos) | `/cursos`, `/estudiante/resumen` |
| Progreso | Plan de estudios (avance, créditos, semestres restantes) e historial por periodo | `/estudiante/resumen`, `/estudiante/historial` |
| Recomendaciones | Curso recomendado por pilar con sus razones y NRC | `/estudiante/recomendaciones` |
| Calendario | Mes con los eventos marcados y lista de próximos eventos | `/calendario` |
| Noticias | Convocatorias, cursos, certificaciones y noticias, con enlace a la fuente | `/noticias` |
| Más | Perfil, accesos, acerca del proyecto y cerrar sesión | — |

Desde las pantallas de cursos, recomendaciones, progreso y calendario hay botones que abren el chat con una pregunta ya escrita.

## Estructura

```text
lib/
├── main.dart            # Tema, navegador y regreso al login si la sesión termina
├── config.dart          # URL de la API (--dart-define=API_URL=...)
├── datos/               # Cliente de la API, modelos y sesión (token en almacenamiento seguro)
├── pantallas/           # Una pantalla por archivo
├── widgets/             # Logo de la UNAB, emblema, anillo de progreso, indicador de escritura y componentes comunes
├── tema/                # Colores (morado, naranja, blanco), tipografía Poppins y tema Material 3
└── utilidades/          # Fechas en español y navegación
```

## Seguridad

- El token de sesión (JWT) se guarda cifrado con `flutter_secure_storage` (Android Keystore) y se envía como `Authorization: Bearer`.
- Si la API responde 401 (sesión vencida), la app borra el token y vuelve al inicio de sesión con un aviso.
- Android solo permite HTTP sin cifrar hacia `10.0.2.2` y `localhost` (la API local vista desde el emulador). Cualquier otro servidor debe usar HTTPS (`android/app/src/main/res/xml/network_security_config.xml`).
- La app no guarda contraseñas ni datos académicos en el teléfono.

## Ejecución

Requisitos: Flutter estable, el emulador de Android y los servicios de Docker levantados (`docker compose up -d`).

```powershell
cd mobile_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Por defecto la app usa `http://10.0.2.2:8080/api/v1`, la API local vista desde el emulador. Para usar el servidor desplegado:

```powershell
flutter run --dart-define=API_URL=https://chatbot-unab-demo.duckdns.org/api/v1
```

En un celular Android conectado por USB (con la API local):

```powershell
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_URL=http://localhost:8080/api/v1
```

Usuario de prueba: `U00900100` / `Demo2026*` (estudiante DEMO). En el login, *Usar cuenta de prueba* llena los campos.

## Recursos gráficos

| Archivo | Origen |
|---|---|
| `assets/imagenes/logo_unab_color.png` y `logo_unab_blanco.png` | Logo horizontal extraído del Manual de Identidad de Marca de la UNAB (versión a color para fondo blanco y versión blanca para fondos de color, como indica el manual) |
| `assets/imagenes/campus.jpg` | Foto del campus usada en la bienvenida |
| `assets/fuentes/Poppins-*.ttf` | Tipografía Poppins (la del manual de marca), licencia SIL Open Font License en `assets/fuentes/OFL.txt` |
