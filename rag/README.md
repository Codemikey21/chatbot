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
| `plan-estudios-ingenieria-sistemas-DEMO.md` | Demostrativo | Plan de estudios por semestre, prerrequisitos, reglas de avance y requisitos de la Práctica Profesional |

Los documentos demostrativos (DEMO) tienen contenido sintético y lo indican en su encabezado, porque no hay documentos públicos específicos de los Cursos de Competencias Digitales (CCD) ni un plan de estudios público con prerrequisitos. Son coherentes con los datos DEMO de la base (pilares, regla de la insignia, pensum, prerrequisitos y calendario): el plan de estudios se generó a partir de `database/seeds/001_catalogo.sql`, así que el RAG y el servidor MCP dicen lo mismo.

Con esto el RAG cubre los tres tipos de documento que necesita un estudiante para planear su carrera: **reglamento** (reglamento estudiantil), **plan de estudios** (plan DEMO y lineamientos curriculares) y **requisitos** (reglamento de la insignia, prerrequisitos y requisitos de la práctica).

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

## Parámetros y por qué

| Parámetro | Valor | Por qué |
|---|---|---|
| Tamaño del fragmento | ~1.200 caracteres (máximo 1.600) | Se eligió para que un artículo del reglamento o una sección de los documentos DEMO quepa en un fragmento: así cada fragmento trata una sola idea y su embedding no se diluye con temas distintos. Con 5 fragmentos el modelo recibe unos 6.000 caracteres de contexto, suficiente para responder y barato en tokens. El máximo de 1.600 evita partir un artículo largo a la mitad. |
| Solape (overlap) | 200 caracteres (~17 %) | Cuando una regla y su excepción quedan en fragmentos distintos, el solape repite el final del anterior para no perder el contexto. Un solape mayor haría que los 5 resultados repitieran casi el mismo texto. |
| Corte | Por párrafo, artículo o sección | Respetar los límites del documento evita fragmentos que empiezan o terminan a mitad de frase y permite guardar la sección y la página para citar la fuente. |
| Modelo de embeddings | Voyage AI `voyage-4`, 1024 dimensiones | Distingue `input_type` de documento y de consulta (búsqueda asimétrica: preguntas cortas contra párrafos largos), funciona con el corpus en español (100 % de acierto@5 en la evaluación) y su capa gratuita (200 millones de tokens) alcanza para el corpus. 1024 dimensiones funcionan con el índice HNSW de pgvector y ocupan la mitad que un modelo de 2048. |
| Búsqueda | Híbrida: vectorial + texto completo, unidas con RRF | La parte vectorial encuentra paráfrasis («¿cuánto vale?» ↔ «valor de la inscripción»); la de texto completo encuentra términos exactos como códigos de curso, NRC o números de artículo, que los embeddings representan mal. |
| Fragmentos devueltos (k) | 5 | En la evaluación el documento correcto quedó primero en casi todas las preguntas (MRR 0,95); 5 deja margen sin llenar el contexto de texto irrelevante. |
| Similitud mínima | 0,35 | En la evaluación la pregunta válida con menor similitud obtuvo 0,43 y las preguntas fuera de alcance no superaron el umbral. Con 0,35 se rechaza lo que no está en los documentos sin perder respuestas válidas. |

## Ejemplo de recuperación

Resultados reales de `rag/evaluacion/evaluar.py` (similitud del mejor fragmento y documentos recuperados, en orden):

| Pregunta | Similitud | Documentos recuperados |
|---|---:|---|
| ¿Cuántos cursos necesito aprobar para obtener la insignia? | 0,754 | reglamento de la insignia, catálogo de cursos, preguntas frecuentes |
| ¿Cuántas veces puedo cancelar un mismo curso? | 0,655 | reglamento estudiantil, reglamento de la insignia, preguntas frecuentes |
| ¿Cómo se organiza el plan de estudios según los lineamientos curriculares? | 0,681 | lineamientos curriculares, reglamento estudiantil |
| ¿Qué asignaturas se ven en sexto semestre de Ingeniería de Sistemas? | 0,652 | plan de estudios |
| ¿Cuál es el prerrequisito de Desarrollo de Aplicaciones Móviles? | 0,526 | plan de estudios, lineamientos curriculares |
| ¿La prueba diagnóstica es eliminatoria? | 0,431 | guía de la prueba diagnóstica, reglamento estudiantil |
| ¿Cuál es la receta del ajiaco santafereño? | — | ninguno: el chatbot responde que no encontró la información |

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
