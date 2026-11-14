-- =====================================================================
-- 003_calendario_rag_noticias.sql
-- Calendario académico, documentos del RAG y noticias.
-- Tablas: calendario_evento, documento, fragmento, fuente_noticia,
--         noticia, ejecucion_scraper.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Calendario (copia sincronizada de la hoja de Google Sheets)
-- ---------------------------------------------------------------------
create table calendario_evento (
    id_evento        varchar(20)  primary key,
    titulo           varchar(200) not null,
    tipo_evento      varchar(30)  not null,
    fecha_inicio     date         not null,
    fecha_fin        date         not null,
    periodo          varchar(6)   references periodo_academico (codigo),
    dirigido_a       varchar(150),
    descripcion      text,
    es_demo          boolean      not null default true,
    fuente           varchar(30)  not null default 'google_sheets',
    sincronizado_en  timestamptz  not null default now(),
    constraint calendario_fechas_validas check (fecha_fin >= fecha_inicio)
);
create index calendario_fecha_idx on calendario_evento (fecha_inicio);
create index calendario_tipo_idx on calendario_evento (tipo_evento);
comment on table calendario_evento is
    'Eventos del calendario académico. Fuente principal: Google Sheets; esta tabla es la copia sincronizada que consultan MCP y la app.';

-- ---------------------------------------------------------------------
-- Documentos del RAG
-- ---------------------------------------------------------------------
create table documento (
    id                integer generated always as identity primary key,
    titulo            varchar(250) not null,
    descripcion       text,
    nombre_archivo    varchar(250) not null unique,
    tipo_archivo      varchar(10)  not null check (tipo_archivo in ('pdf', 'txt', 'md', 'html', 'docx')),
    origen            varchar(15)  not null check (origen in ('publico', 'demostrativo')),
    url_origen        text,
    hash_contenido    char(64)     not null,
    version           integer      not null default 1 check (version >= 1),
    total_fragmentos  integer      not null default 0 check (total_fragmentos >= 0),
    estado            varchar(15)  not null default 'pendiente'
                      check (estado in ('pendiente', 'procesado', 'error')),
    creado_en         timestamptz  not null default now(),
    actualizado_en    timestamptz  not null default now(),
    constraint documento_publico_con_url check (origen <> 'publico' or url_origen is not null)
);
comment on table documento is
    'Documentos fuente del RAG. hash_contenido (SHA-256) detecta cambios: si cambia, se regeneran los fragmentos y sube la versión.';

-- ---------------------------------------------------------------------
-- Fragmentos con embeddings (pgvector)
-- ---------------------------------------------------------------------
create table fragmento (
    id             bigint generated always as identity primary key,
    documento_id   integer      not null references documento (id) on delete cascade,
    indice         integer      not null check (indice >= 0),
    contenido      text         not null,
    pagina         integer,
    seccion        varchar(250),
    tokens         integer,
    embedding      vector(1024) not null,
    contenido_tsv  tsvector     generated always as (to_tsvector('spanish', contenido)) stored,
    creado_en      timestamptz  not null default now(),
    constraint fragmento_documento_indice_uk unique (documento_id, indice)
);
create index fragmento_embedding_hnsw_idx on fragmento using hnsw (embedding vector_cosine_ops);
create index fragmento_tsv_idx on fragmento using gin (contenido_tsv);
comment on table fragmento is
    'Fragmentos (chunks) de cada documento con su embedding voyage-4 de 1024 dimensiones. Índice HNSW para similitud coseno y GIN para búsqueda por palabras.';

-- ---------------------------------------------------------------------
-- Fuentes de noticias
-- ---------------------------------------------------------------------
create table fuente_noticia (
    id                  smallint generated always as identity primary key,
    nombre              varchar(120) not null unique,
    url_base            text         not null unique,
    tipo                varchar(10)  not null default 'html' check (tipo in ('html', 'rss')),
    permitido_robots    boolean      not null default false,
    revisado_robots_en  timestamptz,
    activa              boolean      not null default true
);
comment on table fuente_noticia is
    'Sitios consultados por el scraper. Solo se recorren si permitido_robots es verdadero según su robots.txt.';

-- ---------------------------------------------------------------------
-- Noticias y convocatorias
-- ---------------------------------------------------------------------
create table noticia (
    id                 bigint generated always as identity primary key,
    fuente_id          smallint     not null references fuente_noticia (id),
    titulo             varchar(300) not null,
    resumen            text,
    url                text         not null unique,
    categoria          varchar(20)  not null default 'noticia'
                       check (categoria in ('curso', 'convocatoria', 'certificacion', 'noticia')),
    fecha_publicacion  date,
    hash_contenido     char(64)     not null,
    recopilado_en      timestamptz  not null default now(),
    actualizado_en     timestamptz  not null default now()
);
create index noticia_fecha_idx on noticia (fecha_publicacion desc nulls last);
create index noticia_categoria_idx on noticia (categoria);
create index noticia_fuente_idx on noticia (fuente_id);
comment on table noticia is
    'Noticias recopiladas. La URL única evita duplicados; hash_contenido indica si una noticia existente cambió.';

-- ---------------------------------------------------------------------
-- Registro de ejecuciones del scraper
-- ---------------------------------------------------------------------
create table ejecucion_scraper (
    id                     bigint generated always as identity primary key,
    fuente_id              smallint    references fuente_noticia (id),
    iniciado_en            timestamptz not null default now(),
    finalizado_en          timestamptz,
    estado                 varchar(15) not null default 'en_curso'
                           check (estado in ('en_curso', 'exitosa', 'parcial', 'fallida')),
    noticias_nuevas        integer     not null default 0,
    noticias_actualizadas  integer     not null default 0,
    mensaje_error          text
);
create index ejecucion_scraper_fecha_idx on ejecucion_scraper (iniciado_en desc);
comment on table ejecucion_scraper is
    'Bitácora de cada corrida del scraper, para diagnosticar fallos.';

commit;
