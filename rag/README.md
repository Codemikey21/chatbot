# RAG institucional

Sistema de Retrieval-Augmented Generation que permite al chatbot responder con información de documentos institucionales y citar la fuente.

## Corpus (`rag/corpus/`)

| Documento | Origen | Uso |
|---|---|---|
| `reglamento-estudiantil-pregrado.pdf` | Público, UNAB ([enlace](https://unab.edu.co/NewFolder/Reglamento-estudiantil-pregraod.pdf)) | Normas académicas: matrícula, cancelaciones, evaluación, grados, deberes |
| `lineamientos-curriculares-pregrado.pdf` | Público, UNAB ([enlace](https://unab.edu.co/NewFolder/Lineamientos-curriculares-pregrado.pdf)) | Créditos académicos, estructura curricular |
| `ccd-reglamento-insignia-DEMO.md` | Demostrativo | Regla de la insignia de competencias digitales |
| `ccd-catalogo-cursos-DEMO.md` | Demostrativo | Descripción de los 7 cursos de los 3 pilares |
| `ccd-guia-prueba-diagnostica-DEMO.md` | Demostrativo | Prueba diagnóstica |
| `ccd-preguntas-frecuentes-DEMO.md` | Demostrativo | Preguntas frecuentes de los CCD |

Los documentos demostrativos (DEMO) tienen contenido sintético y lo indican en su encabezado, porque no hay documentos públicos específicos de los Cursos de Competencias Digitales (CCD). Son coherentes con los datos DEMO de la base (pilares, regla de la insignia y calendario).

## Ingesta (workflow de n8n `AUX - Ingesta de documentos (RAG)`)

```
Carpeta rag/corpus  ─┐
(manual o diario)    ├─► Identificar archivo ─► Extraer texto (PDF / texto) ─► Hash SHA-256
Webhook (subir PDF) ─┘                                                            │
                                                         ¿nuevo o cambió? ◄───────┘
                                                               │ sí
              Limpiar y fragmentar ─► Lotes ─► Embeddings Voyage ─► Unir ─► fn_guardar_documento
```

1. **Recepción:** lee `rag/corpus` (montada en n8n como `/data/corpus`, solo lectura) o recibe un archivo por el webhook `POST /webhook/ingesta-documentos` (header de autorización).
2. **Extracción:** PDF página por página (conserva el número de página); MD y TXT como texto. Los `.md` traen título y origen en un encabezado `---`.
3. **Detección de cambios:** el hash SHA-256 del texto se compara con el guardado (`fn_estado_documento`). Si no cambió, no se generan embeddings.
4. **Limpieza:** une palabras cortadas por guion, quita índices, números de página y espacios repetidos, y une las líneas partidas de los PDF.
5. **Fragmentación (chunking):** fragmentos de ~1.200 caracteres (máximo 1.600) que respetan párrafos y artículos, con 200 caracteres de solape. Cada fragmento guarda su sección (título, capítulo o artículo) y su página.
6. **Embeddings:** Voyage AI `voyage-4` (1024 dimensiones, `input_type=document`). El texto enviado incluye el título del documento y la sección, para dar contexto. Se envían lotes de 24 fragmentos con 21 s de pausa para respetar el límite de la cuenta gratuita.
7. **Almacenamiento:** `fn_guardar_documento` crea o actualiza el documento y reemplaza sus fragmentos en una sola transacción (sube la versión si cambió).

## Búsqueda (`fn_buscar_fragmentos`)

Búsqueda **híbrida**:
- **Semántica:** similitud coseno con pgvector (índice HNSW) sobre el embedding de la pregunta (`input_type=query`).
- **Léxica:** búsqueda de texto completo en español (`websearch_to_tsquery`, índice GIN).
- Las dos listas se combinan con **Reciprocal Rank Fusion**.
- Solo se devuelven fragmentos con **similitud mínima** (0,35 por defecto). Si ninguno la alcanza, el resultado es vacío y el chatbot responde que **no encontró la información**, en lugar de inventarla.

Cada resultado trae el título del documento, su URL (si es público), la sección, la página y la similitud, para citar la fuente en la respuesta.

## Evaluación (`rag/evaluacion/`)

`preguntas.csv` contiene preguntas de prueba con el documento que debería responderlas, más preguntas fuera de alcance que no deben recuperar nada.

```powershell
mcp-server\.venv\Scripts\python.exe rag\evaluacion\evaluar.py
```

Muestra `acierto@5`, `MRR` y el porcentaje de rechazo de preguntas fuera de alcance, y guarda el detalle en `resultados.csv`. Con `--umbral` se puede probar otra similitud mínima.
