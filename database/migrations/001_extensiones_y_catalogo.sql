-- =====================================================================
-- 001_extensiones_y_catalogo.sql
-- Extensiones y catálogo académico del chatbot de apoyo académico.
-- Tablas: programa, pilar_competencia, curso, plan_estudio, requisito,
--         regla_academica, curso_afinidad, periodo_academico, seccion.
-- Ejecutar una sola vez, en orden, desde el SQL Editor de Supabase.
-- =====================================================================

begin;

-- pgvector: embeddings del RAG. pgcrypto: hash de contraseñas.
create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Programas académicos
-- ---------------------------------------------------------------------
create table programa (
    id                smallint generated always as identity primary key,
    codigo            varchar(20)  not null unique,
    nombre            varchar(150) not null,
    facultad          varchar(150),
    creditos_totales  smallint     not null check (creditos_totales > 0),
    semestres         smallint     not null check (semestres between 1 and 14),
    creado_en         timestamptz  not null default now()
);
comment on table programa is
    'Programas académicos. El proyecto modela solo Ingeniería de Sistemas.';

-- ---------------------------------------------------------------------
-- Pilares de la ruta de competencias digitales
-- ---------------------------------------------------------------------
create table pilar_competencia (
    id                 smallint generated always as identity primary key,
    codigo             varchar(20)  not null unique,
    nombre             varchar(120) not null unique,
    descripcion        text,
    cursos_requeridos  smallint     not null default 1 check (cursos_requeridos >= 1),
    orden_visual       smallint     not null default 1
);
comment on table pilar_competencia is
    'Pilares de competencias digitales. Cada pilar se aprueba con cursos_requeridos cursos; no hay orden entre pilares.';

-- ---------------------------------------------------------------------
-- Cursos: asignaturas del pensum y cursos de competencias digitales
-- ---------------------------------------------------------------------
create table curso (
    id           integer generated always as identity primary key,
    codigo       varchar(20)  not null unique,
    nombre       varchar(150) not null,
    tipo         varchar(25)  not null check (tipo in ('asignatura', 'competencia_digital')),
    creditos     smallint     not null default 0 check (creditos >= 0),
    pilar_id     smallint     references pilar_competencia (id),
    descripcion  text,
    activo       boolean      not null default true,
    constraint curso_id_tipo_uk unique (id, tipo),
    constraint curso_pilar_coherente check ((tipo = 'competencia_digital') = (pilar_id is not null))
);
create index curso_pilar_idx on curso (pilar_id) where pilar_id is not null;
comment on table curso is
    'Asignaturas del pensum y cursos de competencias digitales. Solo los cursos digitales pertenecen a un pilar.';
comment on constraint curso_id_tipo_uk on curso is
    'Permite que otras tablas exijan un tipo de curso mediante llaves foráneas compuestas.';

-- ---------------------------------------------------------------------
-- Plan de estudios (pensum)
-- ---------------------------------------------------------------------
create table plan_estudio (
    programa_id               smallint    not null references programa (id) on delete cascade,
    curso_id                  integer     not null,
    tipo_curso                varchar(25) not null default 'asignatura' check (tipo_curso = 'asignatura'),
    semestre                  smallint    not null check (semestre between 1 and 14),
    componente                varchar(20) not null default 'obligatorio'
                              check (componente in ('obligatorio', 'electiva', 'menor', 'practica')),
    creditos_minimos_previos  smallint    not null default 0 check (creditos_minimos_previos >= 0),
    primary key (programa_id, curso_id),
    foreign key (curso_id, tipo_curso) references curso (id, tipo)
);
create index plan_estudio_semestre_idx on plan_estudio (programa_id, semestre);
comment on table plan_estudio is
    'Pensum: semestre sugerido de cada asignatura. creditos_minimos_previos expresa requisitos por créditos aprobados (ej. práctica profesional).';

-- ---------------------------------------------------------------------
-- Prerrequisitos y correquisitos
-- ---------------------------------------------------------------------
create table requisito (
    curso_id           integer     not null references curso (id) on delete cascade,
    requiere_curso_id  integer     not null references curso (id),
    tipo               varchar(15) not null default 'prerrequisito'
                       check (tipo in ('prerrequisito', 'correquisito')),
    es_demo            boolean     not null default true,
    primary key (curso_id, requiere_curso_id),
    constraint requisito_no_reflexivo check (curso_id <> requiere_curso_id)
);
create index requisito_requiere_idx on requisito (requiere_curso_id);
comment on table requisito is
    'Prerrequisitos (aprobar antes) y correquisitos (cursar en el mismo periodo). Valores DEMO.';

-- ---------------------------------------------------------------------
-- Reglas académicas configurables
-- ---------------------------------------------------------------------
create table regla_academica (
    programa_id  smallint     not null references programa (id) on delete cascade,
    clave        varchar(50)  not null,
    valor        numeric(6,2) not null,
    descripcion  text         not null,
    es_demo      boolean      not null default true,
    primary key (programa_id, clave)
);
comment on table regla_academica is
    'Reglas configurables (ej. máximo de créditos por semestre, nota mínima de aprobación). Se usan en la proyección de semestres.';

-- ---------------------------------------------------------------------
-- Afinidad entre cursos digitales y asignaturas (recomendaciones)
-- ---------------------------------------------------------------------
create table curso_afinidad (
    curso_digital_id  integer     not null,
    tipo_digital      varchar(25) not null default 'competencia_digital'
                      check (tipo_digital = 'competencia_digital'),
    asignatura_id     integer     not null,
    tipo_asignatura   varchar(25) not null default 'asignatura'
                      check (tipo_asignatura = 'asignatura'),
    afinidad          smallint    not null check (afinidad between 1 and 3),
    razon             text        not null,
    es_demo           boolean     not null default true,
    primary key (curso_digital_id, asignatura_id),
    foreign key (curso_digital_id, tipo_digital) references curso (id, tipo) on delete cascade,
    foreign key (asignatura_id, tipo_asignatura) references curso (id, tipo) on delete cascade
);
create index curso_afinidad_asignatura_idx on curso_afinidad (asignatura_id);
comment on table curso_afinidad is
    'Relación entre cada curso digital y las asignaturas del pensum con las que se conecta. afinidad: 1 baja, 2 media, 3 alta. Base de las recomendaciones.';

-- ---------------------------------------------------------------------
-- Periodos académicos
-- ---------------------------------------------------------------------
create table periodo_academico (
    codigo        varchar(6) primary key check (codigo ~ '^[0-9]{4}-[12]$'),
    fecha_inicio  date    not null,
    fecha_fin     date    not null,
    es_actual     boolean not null default false,
    constraint periodo_fechas_validas check (fecha_fin > fecha_inicio)
);
create unique index periodo_un_solo_actual_uk on periodo_academico (es_actual) where es_actual;
comment on table periodo_academico is
    'Periodos académicos (AAAA-1 y AAAA-2). Solo uno puede estar marcado como actual.';

-- ---------------------------------------------------------------------
-- Secciones (oferta por periodo, identificada por NRC)
-- ---------------------------------------------------------------------
create table seccion (
    id         integer generated always as identity primary key,
    nrc        integer     not null check (nrc between 10000 and 99999),
    curso_id   integer     not null references curso (id),
    periodo    varchar(6)  not null references periodo_academico (codigo),
    grupo      varchar(5)  not null default 'A',
    docente    varchar(120),
    modalidad  varchar(15) not null default 'presencial'
               check (modalidad in ('presencial', 'virtual', 'hibrida')),
    horario    varchar(120),
    cupo       smallint    not null check (cupo > 0),
    estado     varchar(15) not null default 'abierta'
               check (estado in ('abierta', 'en_curso', 'finalizada', 'cancelada')),
    es_demo    boolean     not null default true,
    constraint seccion_nrc_periodo_uk unique (periodo, nrc),
    constraint seccion_curso_grupo_uk unique (curso_id, periodo, grupo)
);
create index seccion_curso_idx on seccion (curso_id);
create index seccion_estado_idx on seccion (periodo, estado);
comment on table seccion is
    'Oferta de cursos por periodo. El NRC (5 dígitos) es único dentro de cada periodo, como en Banner. Valores DEMO.';

commit;
