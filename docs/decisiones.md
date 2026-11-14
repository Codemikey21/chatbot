# Registro de decisiones

Cada entrada indica la fecha, qué se decidió y por qué.

## 2026-11-13 — App móvil con Flutter y Dart
- **Decisión:** la app Android se desarrolla con Flutter y Dart.
- **Motivo:** lograr una interfaz moderna con animaciones fluidas y microinteracciones, en morado, naranja y blanco, a partir de los mockups de referencia.
- **Pendiente:** confirmar con el profesor, porque la especificación menciona Kotlin y Jetpack Compose.

## 2026-11-13 — Datos sintéticos
- **Decisión:** la información académica (estudiantes, cursos, matrículas, calificaciones, requisitos y competencias digitales) se simula en Supabase PostgreSQL.
- **Motivo:** no hay acceso a Banner-Cosmos ni a otras bases privadas de la UNAB. Todo dato de ejemplo se marca como DEMO.

## 2026-11-13 — Modelo de lenguaje: OpenAI
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

## Pendientes
- Modelo de chat, modelo de embeddings y dimensión de los vectores (paso 6 de la Fase 0).
- Región definitiva del Learner Lab y de Supabase.
