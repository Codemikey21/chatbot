# Chatbot de apoyo académico — UNAB

Asistente conversacional que permite a los estudiantes de la Universidad Autónoma de Bucaramanga (UNAB) consultar cursos de competencias digitales, su historial académico, el calendario institucional y las novedades, y recibir recomendaciones personalizadas.

Proyecto final de la asignatura Ciencia de Datos — Ingeniería de Sistemas, UNAB.

> **Datos demostrativos.** Este proyecto no tiene acceso a Banner-Cosmos ni a bases de datos institucionales. Los estudiantes, calificaciones, cursos y documentos marcados como DEMO son ficticios y no representan información oficial de la UNAB.

## Arquitectura

| Componente | Tecnología | Carpeta |
|---|---|---|
| App móvil | Flutter + Dart | `mobile_app/` |
| API segura | FastAPI (Python) | `backend/` |
| Orquestación y agentes | n8n | `n8n/` |
| Herramientas académicas (MCP) | FastMCP (Python) | `mcp-server/` |
| Noticias y convocatorias | Scraper en Python | `scraper/` |
| RAG | n8n + OpenAI + pgvector | `rag/` |
| Base de datos | Supabase PostgreSQL + pgvector | `database/` |
| Calendario | Google Sheets API | — |
| Infraestructura | Docker Compose, Caddy y AWS EC2 | `infrastructure/` |

El diagrama y los contratos entre servicios están en `docs/arquitectura/`.

## Estructura del repositorio

```text
chatbot/
├── mobile_app/        # App Flutter
├── backend/           # API FastAPI
├── mcp-server/        # Servidor FastMCP
├── scraper/           # Scraper de noticias
├── n8n/workflows/     # Workflows exportados
├── rag/               # Corpus y evaluación del RAG
├── database/          # Migraciones SQL y datos sintéticos
├── infrastructure/    # Caddy y despliegue en AWS
├── tests/             # Pruebas de integración
├── docs/              # Documentación, mockups y evidencias
└── docker-compose.yml
```

## Estado del proyecto

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Entorno y conectividad | En curso |
| 1 | Arquitectura y contratos | Pendiente |
| 2 | Base de datos | Pendiente |
| 3 | Servidor MCP | Pendiente |
| 4 | RAG e ingesta | Pendiente |
| 5 | Workflows de n8n | Pendiente |
| 6 | Guardrails, intención, memoria y API | Pendiente |
| 7 | App móvil | Pendiente |
| 8 | Despliegue en AWS EC2 | Pendiente |
| 9 | Pruebas | Pendiente |
| 10 | Documentación y demo | Pendiente |

## Ejecución local

Se documentará al cerrar la Fase 0.

## Autor

Miguel Ángel Solano Díaz — Ingeniería de Sistemas, UNAB.
