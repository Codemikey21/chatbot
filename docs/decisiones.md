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

## Pendientes
- Confirmar con el profesor el uso de Flutter en lugar de Kotlin y Jetpack Compose.
- Reemplazar los prerrequisitos DEMO por los oficiales si se consiguen.
