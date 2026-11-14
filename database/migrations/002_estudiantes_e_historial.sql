-- =====================================================================
-- 002_estudiantes_e_historial.sql
-- Datos personales y académicos de los estudiantes.
-- Tablas: estudiante, credencial, matricula, inscripcion.
-- Estas tablas quedan protegidas con RLS en la migración 006.
-- =====================================================================

begin;

-- Permite que inscripcion exija que la sección sea del mismo periodo
-- que la matrícula (llave foránea compuesta).
alter table seccion add constraint seccion_id_periodo_uk unique (id, periodo);

-- ---------------------------------------------------------------------
-- Estudiantes
-- ---------------------------------------------------------------------
create table estudiante (
    codigo           varchar(9)   primary key check (codigo ~ '^U00[0-9]{6}$'),
    nombres          varchar(80)  not null,
    apellidos        varchar(80)  not null,
    correo           varchar(150) not null unique,
    programa_id      smallint     not null references programa (id),
    semestre_actual  smallint     not null check (semestre_actual between 1 and 14),
    periodo_ingreso  varchar(6)   not null references periodo_academico (codigo),
    estado           varchar(15)  not null default 'activo'
                     check (estado in ('activo', 'inactivo', 'graduado', 'retirado')),
    es_demo          boolean      not null default true,
    creado_en        timestamptz  not null default now()
);
create index estudiante_programa_idx on estudiante (programa_id);
comment on table estudiante is
    'Estudiantes. El código (U00 + 6 dígitos) es el identificador que viaja en el JWT. Datos DEMO.';

-- ---------------------------------------------------------------------
-- Credenciales (tabla aparte: solo la función de login las consulta)
-- ---------------------------------------------------------------------
create table credencial (
    estudiante_codigo  varchar(9)  primary key references estudiante (codigo) on delete cascade,
    hash_contrasena    text        not null,
    intentos_fallidos  smallint    not null default 0 check (intentos_fallidos >= 0),
    bloqueado_hasta    timestamptz,
    ultimo_acceso      timestamptz,
    actualizado_en     timestamptz not null default now()
);
comment on table credencial is
    'Hash bcrypt (pgcrypto) de la contraseña. Ningún rol de la aplicación la lee directamente; solo fn_autenticar.';

-- ---------------------------------------------------------------------
-- Matrícula por periodo
-- ---------------------------------------------------------------------
create table matricula (
    id                 integer generated always as identity primary key,
    estudiante_codigo  varchar(9)  not null references estudiante (codigo) on delete cascade,
    periodo            varchar(6)  not null references periodo_academico (codigo),
    fecha_matricula    date        not null,
    estado             varchar(15) not null default 'activa'
                       check (estado in ('activa', 'cancelada', 'finalizada')),
    constraint matricula_estudiante_periodo_uk unique (estudiante_codigo, periodo),
    constraint matricula_id_estudiante_periodo_uk unique (id, estudiante_codigo, periodo)
);
create index matricula_periodo_idx on matricula (periodo);
comment on table matricula is
    'Matrícula de un estudiante en un periodo. Una por estudiante y periodo.';

-- ---------------------------------------------------------------------
-- Inscripción de NRC (historial académico)
-- ---------------------------------------------------------------------
create table inscripcion (
    id                 integer generated always as identity primary key,
    matricula_id       integer      not null,
    estudiante_codigo  varchar(9)   not null,
    periodo            varchar(6)   not null,
    seccion_id         integer      not null,
    estado             varchar(15)  not null default 'inscrito'
                       check (estado in ('inscrito', 'aprobado', 'reprobado', 'retirado')),
    nota_final         numeric(3,1) check (nota_final between 0 and 5),
    registrado_en      timestamptz  not null default now(),
    constraint inscripcion_matricula_seccion_uk unique (matricula_id, seccion_id),
    constraint inscripcion_nota_coherente
        check ((estado in ('aprobado', 'reprobado')) = (nota_final is not null)),
    constraint inscripcion_matricula_fk foreign key (matricula_id, estudiante_codigo, periodo)
        references matricula (id, estudiante_codigo, periodo) on delete cascade,
    constraint inscripcion_seccion_fk foreign key (seccion_id, periodo)
        references seccion (id, periodo)
);
create index inscripcion_estudiante_idx on inscripcion (estudiante_codigo);
create index inscripcion_seccion_idx on inscripcion (seccion_id);
comment on table inscripcion is
    'Cada NRC inscrito por un estudiante, con su estado y nota (escala 0 a 5). Es el historial académico. estudiante_codigo y periodo se repiten para aplicar RLS y validar con llaves compuestas.';

commit;
