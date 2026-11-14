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

## Pendientes
- Modelo de Claude, modelo de Voyage y dimensión de los vectores (paso 6 de la Fase 0).
