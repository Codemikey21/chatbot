-- =====================================================================
-- 004_chat_y_seguridad.sql
-- Memoria conversacional y registro de eventos de seguridad.
-- Tablas: sesion_chat, mensaje_chat, evento_seguridad.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Sesiones de chat
-- ---------------------------------------------------------------------
create table sesion_chat (
    id                 uuid         primary key default gen_random_uuid(),
    estudiante_codigo  varchar(9)   not null references estudiante (codigo) on delete cascade,
    titulo             varchar(150),
    creada_en          timestamptz  not null default now(),
    ultima_actividad   timestamptz  not null default now(),
    activa             boolean      not null default true,
    constraint sesion_chat_id_estudiante_uk unique (id, estudiante_codigo)
);
create index sesion_chat_estudiante_idx on sesion_chat (estudiante_codigo, ultima_actividad desc);
comment on table sesion_chat is
    'Conversaciones de cada estudiante. Permite recuperar conversaciones anteriores.';

-- ---------------------------------------------------------------------
-- Mensajes (memoria persistente)
-- ---------------------------------------------------------------------
create table mensaje_chat (
    id                 bigint generated always as identity primary key,
    sesion_id          uuid         not null,
    estudiante_codigo  varchar(9)   not null,
    rol                varchar(10)  not null check (rol in ('usuario', 'asistente')),
    contenido          text         not null,
    intencion          varchar(30)
                       check (intencion in ('academica_general', 'documental', 'calendario', 'historial',
                                            'noticias', 'recomendacion', 'fuera_de_alcance')),
    fuentes            jsonb        not null default '[]'::jsonb,
    herramientas       jsonb        not null default '[]'::jsonb,
    bloqueado          boolean      not null default false,
    latencia_ms        integer      check (latencia_ms >= 0),
    creado_en          timestamptz  not null default now(),
    constraint mensaje_chat_sesion_fk foreign key (sesion_id, estudiante_codigo)
        references sesion_chat (id, estudiante_codigo) on delete cascade
);
create index mensaje_chat_sesion_idx on mensaje_chat (sesion_id, creado_en);
create index mensaje_chat_estudiante_idx on mensaje_chat (estudiante_codigo);
comment on table mensaje_chat is
    'Mensajes de cada sesión: intención detectada, fuentes citadas y herramientas usadas. La llave compuesta impide guardar un mensaje en la sesión de otro estudiante.';

-- ---------------------------------------------------------------------
-- Eventos de seguridad (guardrails)
-- ---------------------------------------------------------------------
create table evento_seguridad (
    id                 bigint generated always as identity primary key,
    estudiante_codigo  varchar(9)   references estudiante (codigo) on delete set null,
    sesion_id          uuid,
    tipo               varchar(30)  not null
                       check (tipo in ('fuera_de_alcance', 'prompt_injection', 'datos_personales',
                                       'acceso_no_autorizado', 'login_fallido', 'respuesta_no_validada')),
    detalle            jsonb        not null default '{}'::jsonb,
    creado_en          timestamptz  not null default now()
);
create index evento_seguridad_fecha_idx on evento_seguridad (creado_en desc);
create index evento_seguridad_tipo_idx on evento_seguridad (tipo);
comment on table evento_seguridad is
    'Bitácora de bloqueos de guardrails, intentos de acceso indebido y logins fallidos.';

commit;
