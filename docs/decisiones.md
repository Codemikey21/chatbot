# Registro de decisiones

Cada entrada indica la fecha, qué se decidió y por qué.

## 2026-11-13 — App móvil con Flutter y Dart
- **Decisión:** la app Android se desarrolla con Flutter y Dart.
- **Motivo:** lograr una interfaz moderna con animaciones fluidas y microinteracciones, en morado, naranja y blanco, a partir de los mockups de referencia.
- **Pendiente:** confirmar con el profesor, porque la especificación menciona Kotlin y Jetpack Compose.

## 2026-11-13 — Datos sintéticos
- **Decisión:** la información académica (estudiantes, cursos, matrículas, calificaciones, requisitos y competencias digitales) se simula en Supabase PostgreSQL.
- **Motivo:** no hay acceso a Banner-Cosmos ni a otras bases privadas de la UNAB. Todo dato de ejemplo se marca como DEMO.

## 2026-11-13 — Modelo de lenguaje: OpenAI (reemplazada el 2026-11-14)
- **Decisión:** se usa OpenAI para el chat y los embeddings, con crédito prepago y la recarga automática desactivada.
- **Motivo:** cumple el requisito (OpenAI o Claude). Azure for Students suele bloquear Azure OpenAI, y no hay evidencia de acceso a Bedrock en AWS Academy.

## 2026-11-13 — Infraestructura: AWS Academy Learner Lab
- **Decisión:** el despliegue se hace en EC2 dentro del Learner Lab, con Elastic IP, dominio DuckDNS y HTTPS con Caddy.
- **Motivo:** es la cuenta de AWS disponible. Las sesiones duran 4 horas y las instancias se detienen al terminar, por eso la IP debe ser fija y los contenedores deben reiniciarse solos.

## 2026-11-13 — API segura con FastAPI
- **Decisión:** la app solo se comunica con FastAPI. FastAPI hace el login con JWT y llama a n8n por un webhook interno.
- **Motivo:** el identificador del estudiante sale de un token verificado y nunca del texto del mensaje ni del modelo, y n8n no queda expuesto a internet.

## 2026-11-13 — Corpus del RAG
- **Decisión:** se usan documentos públicos de la UNAB, citando su URL, más documentos del CCD redactados como DOCUMENTO DEMOSTRATIVO.
- **Motivo:** no hay documentos públicos específicos del CCD.

## 2026-11-13 — Región: us-west-2 (Oregon)
- **Decisión:** Supabase y la instancia EC2 del Learner Lab se ubican en us-west-2 (Oregon).
- **Motivo:** al crear el proyecto, Supabase solo ofrecía la opción "Americas" y lo ubicó en Oregon. El Learner Lab permite esa región, así que la base de datos y el servidor quedan en la misma región.
- **Configuración de seguridad de Supabase:** Data API desactivada (ningún componente usa la API REST) y RLS automático activado.

## 2026-11-14 — Modelo de lenguaje: Claude, y embeddings con Voyage AI
- **Decisión:** el chatbot usa Claude (API de Anthropic) para responder, clasificar intenciones y aplicar guardrails. Los embeddings del RAG se generan con Voyage AI.
- **Motivo:** cumple el requisito (OpenAI o Claude) con créditos de la API de Claude disponibles para el proyecto, sin costo adicional. Anthropic no ofrece un modelo de embeddings propio; Voyage AI incluye 200 millones de tokens gratis por cuenta.
- **Reemplaza:** la decisión del 2026-11-13 de usar OpenAI.

## 2026-11-14 — Modelos y dimensión de los vectores
- **Decisión:** el chat usa `claude-haiku-5-5` y los embeddings usan `voyage-4` con 1024 dimensiones.
- **Motivo:** Haiku es el modelo más económico de Claude y basta para clasificar y responder con contexto. Si la calidad no alcanza, se cambia a `claude-sonnet-5-5` desde la variable `ANTHROPIC_CHAT_MODEL`, sin tocar código. 1024 es la dimensión por defecto de `voyage-4` y es compatible con los índices de pgvector.
- **Verificación:** un workflow auxiliar de n8n confirmó la respuesta del modelo y un embedding de 1024 valores.

## 2026-11-14 — Conexión de n8n a Supabase
- **Decisión:** n8n se conecta por el session pooler (puerto 5432) con SSL obligatorio y la opción "Ignore SSL Issues" activada.
- **Motivo:** con la verificación del certificado activa, la conexión al pooler fallaba. El tráfico sigue cifrado; solo se omite la validación del certificado.
- **Mejora posible:** cargar el certificado raíz de Supabase para validar la conexión.

## 2026-11-14 — Llamadas a Voyage AI con HTTP Request
- **Decisión:** n8n llama a la API de Voyage con el nodo HTTP Request y una credencial de tipo Header Auth.
- **Motivo:** n8n no tiene un nodo oficial de Voyage. Evitar nodos de la comunidad reduce dependencias y permite guardar los vectores en las tablas propias del proyecto.

## 2026-11-14 — Calendario académico en Google Sheets
- **Decisión:** el calendario DEMO está en una hoja de Google Sheets (pestaña `calendario`), cargada desde `database/seeds/calendario_demo.csv`, con las fechas como texto en formato AAAA-MM-DD. n8n la lee con una cuenta de servicio que solo tiene permiso de lectura sobre esa hoja.
- **Motivo:** el requisito pide Google Sheets como fuente del calendario. Las columnas coinciden con la tabla del calendario en PostgreSQL para poder sincronizarlas.

## 2026-11-14 — Alcance de los datos académicos
- **Decisión:** solo se modela el programa de Ingeniería de Sistemas, con su pensum (47 asignaturas, 134 créditos). Los NRC, los prerrequisitos, los estudiantes y las notas son sintéticos y se marcan como DEMO.
- **Motivo:** el foco del chatbot son los cursos de competencias digitales (tres pilares; cada uno se aprueba con un curso y se pueden cursar en cualquier orden). La información de la carrera se usa como respaldo para las preguntas de avance y semestres restantes.

## 2026-11-14 — Chat con un agente que combina herramientas
- **Decisión:** WF01 clasifica la intención con Claude (salida JSON) y luego un agente de n8n con Claude responde usando cuatro herramientas: `buscar_documentos` (RAG), `consultar_calendario` (Google Sheets), `consultar_mis_datos` (MCP) y `consultar_noticias`. Cada herramienta es un sub-workflow.
- **Motivo:** una pregunta puede necesitar varios módulos ("¿cuándo son las inscripciones y qué curso me recomiendas?"). Con un agente se combinan sin escribir una rama por cada combinación. El clasificador se conserva para bloquear lo que está fuera de alcance, guardar la intención y orientar al agente.

## 2026-11-14 — El modelo nunca recibe el token de sesión
- **Decisión:** el token JWT del estudiante pasa a WF03 como entrada fija del sub-workflow. El modelo solo elige el tipo de consulta de una lista blanca.
- **Motivo:** si el modelo recibiera el token o el código, una inyección de instrucciones podría intentar consultar datos de otro estudiante. Así la identidad la decide el token verificado (en WF01, WF03 y el servidor MCP) y no el texto del chat.

## 2026-11-14 — Memoria propia en PostgreSQL
- **Decisión:** la memoria del chat usa las tablas `sesion_chat` y `mensaje_chat` con las funciones `fn_iniciar_turno` y `fn_guardar_turno`, en lugar del nodo de memoria de n8n.
- **Motivo:** las funciones fijan el estudiante y RLS impide leer o escribir sesiones ajenas; además se guardan la intención, las fuentes, las herramientas y la latencia de cada respuesta, y los mensajes bloqueados no vuelven al contexto del modelo.

## 2026-11-14 — Importación de workflows con IDs fijos
- **Decisión:** los workflows se importan con `n8n import:workflow` desde la carpeta montada `/data/workflows`, con IDs fijos en cada JSON. Las credenciales se enlazan por nombre.
- **Motivo:** las herramientas del agente llaman a sus sub-workflows por ID. Con IDs fijos la importación es reproducible en local y en EC2 sin volver a enlazar nada a mano.

## 2026-11-14 — Scraper sin acceso a la base de datos
- **Decisión:** el scraper (FastAPI) solo descarga, limpia y clasifica las noticias. n8n (WF04) las guarda con `fn_guardar_noticias`. El servicio no publica puertos y exige un token Bearer.
- **Motivo:** el único servicio que se conecta a sitios externos no tiene credenciales de la base de datos. La deduplicación por URL, la detección de cambios por hash y el registro de cada ejecución quedan en una sola función transaccional.

## 2026-11-14 — Fuentes de noticias
- **Decisión:** se usan el feed RSS público de la UNAB (`/feed/`), filtrado por palabras académicas y sin las categorías internas (Gestión Humana, Trabaja con nosotros), y un boletín DEMO del CCD que sirve el propio scraper.
- **Motivo:** no hay una fuente pública específica de los cursos de competencias digitales. El boletín DEMO demuestra la extracción de páginas HTML y garantiza datos para la demo aunque el sitio externo no responda. El `robots.txt` de la UNAB permite `/feed/`; el scraper lo revisa en cada ejecución y solo consulta dominios de una lista blanca.

## Pendientes
- Confirmar con el profesor el uso de Flutter en lugar de Kotlin y Jetpack Compose.
- Reemplazar los prerrequisitos DEMO por los oficiales si se consiguen.
