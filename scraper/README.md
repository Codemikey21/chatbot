# Scraper de noticias y convocatorias

Servicio en Python (FastAPI) que extrae novedades académicas de fuentes públicas: nuevos cursos, convocatorias, certificaciones y noticias. Lo ejecuta n8n de forma programada (**WF04**). El scraper **no escribe en la base de datos**: devuelve las noticias limpias y n8n las guarda en PostgreSQL con `fn_guardar_noticias`, que evita duplicados y registra cada ejecución.

```text
n8n (cada 6 h) ─► lee fuente_noticia ─► POST /extraer (por fuente) ─► limpia y deduplica ─► fn_guardar_noticias
                                            │
                                            ├─ revisa robots.txt
                                            ├─ descarga RSS o HTML
                                            └─ limpia, clasifica y calcula la huella
```

## API

| Método y ruta | Acceso | Qué hace |
|---|---|---|
| `POST /extraer` | Bearer `SCRAPER_TOKEN` | Extrae una fuente y devuelve sus noticias |
| `GET /health` | Libre | Estado del servicio |
| `GET /demo/boletin-ccd.html` | Libre | Boletín **DEMO** del CCD para demostrar la extracción HTML |
| `GET /robots.txt` | Libre | Permite solo `/demo/` |

Entrada de `/extraer` (la arma n8n con una fila de `fuente_noticia`):

```json
{
  "fuente_id": 1,
  "nombre": "UNAB - Noticias",
  "url": "https://unab.edu.co/feed/",
  "tipo": "rss",
  "configuracion": { "palabras_clave": ["estudiantes", "curso", "convocatoria"] }
}
```

Salida:

```json
{
  "fuente_id": 1, "fuente": "UNAB - Noticias", "permitido_robots": true,
  "revisado_en": "2026-11-14T21:00:00+00:00", "total": 2, "error": null,
  "noticias": [
    { "titulo": "…", "url": "https://unab.edu.co/…", "resumen": "…", "categoria": "convocatoria",
      "fecha_publicacion": "2026-11-11", "hash_contenido": "<sha256>" }
  ]
}
```

## Configuración de cada fuente (`fuente_noticia.configuracion`)

| Clave | Tipo de fuente | Uso |
|---|---|---|
| `palabras_clave` | RSS y HTML | Solo se guardan las entradas que contienen alguna (filtro de relevancia académica) |
| `categorias_excluidas` | RSS | Descarta entradas con esas categorías del sitio (por ejemplo, avisos internos o empleos) |
| `categoria` | RSS y HTML | Fija la categoría en lugar de clasificar por palabras |
| `selector_item`, `selector_titulo`, `selector_enlace`, `selector_resumen`, `selector_fecha` | HTML | Selectores CSS de cada entrada |
| `conservar_fragmento` | HTML | Conserva `#ancla` en la URL (lo usa el boletín DEMO, que es una sola página) |

## Uso responsable

- **robots.txt:** antes de descargar se revisa el `robots.txt` del sitio (en caché por 6 horas). Si no lo permite, o si el sitio no responde, no se extrae nada y la ejecución queda registrada como fallida.
- **Lista blanca de dominios:** solo se descargan páginas de `SCRAPER_DOMINIOS_PERMITIDOS` (por defecto `unab.edu.co` y el propio servicio). Esto también evita que el endpoint se use para llegar a otros servidores.
- **Carga mínima:** una petición por fuente en cada ejecución (cada 6 horas), tiempo máximo de 20 s, 5 MB como máximo y un `User-Agent` que identifica el proyecto.
- **Solo información pública:** titular, enlace, resumen corto y fecha. El texto completo se lee en la fuente original.

## Limpieza y clasificación

- Se quitan etiquetas HTML, espacios sobrantes y el cierre `[…]` de los extractos de WordPress; el resumen se recorta a 500 caracteres.
- La fecha se toma en hora de Bogotá (UTC−5).
- Las URL se vuelven absolutas y se quitan parámetros de rastreo (`utm_*`, `fbclid`, `gclid`), para no guardar la misma noticia dos veces.
- Fechas aceptadas: `AAAA-MM-DD`, `DD/MM/AAAA` y `14 de noviembre de 2026`.
- Categoría por palabras clave, en este orden: **convocatoria** (convocatoria, becas, postúlate), **certificación** (certificación, insignia), **curso** (curso, diplomado, taller, seminario) y, si nada coincide, **noticia**.
- `hash_contenido` (SHA-256 de título, resumen y fecha) permite saber si una noticia ya guardada cambió.

## Ejecución local

```powershell
cd scraper
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
python -m pytest
```

Con Docker, el servicio se levanta junto con los demás (`docker compose up -d`) y solo es accesible dentro de la red `chatbot-net`, en `http://scraper:8000`.
