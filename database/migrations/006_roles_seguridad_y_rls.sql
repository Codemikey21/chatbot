-- =====================================================================
-- 006_roles_seguridad_y_rls.sql
-- Roles por servicio, permisos mínimos, Row Level Security y funciones
-- de seguridad (login y estudiante actual).
--
-- Los roles se crean SIN login. La contraseña de cada uno se asigna
-- después, a mano, desde el SQL Editor (nunca se guarda en el repo).
--
-- Cómo funciona el RLS: antes de consultar datos personales, FastAPI,
-- n8n o el servidor MCP ejecutan
--     select set_config('app.estudiante_id', '<codigo del JWT>', true);
-- y las políticas solo dejan ver las filas de ese estudiante.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_roles where rolname = 'chatbot_api') then
        create role chatbot_api nologin;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'chatbot_mcp') then
        create role chatbot_mcp nologin;
    end if;
    if not exists (select 1 from pg_roles where rolname = 'chatbot_n8n') then
        create role chatbot_n8n nologin;
    end if;
end
$$;

comment on role chatbot_api is 'FastAPI: login, perfil del estudiante y lectura de su información.';
comment on role chatbot_mcp is 'Servidor MCP: solo lectura, con tiempo máximo por consulta.';
comment on role chatbot_n8n is 'n8n: ingesta del RAG, noticias, calendario y memoria del chat.';

-- Configuración de cada rol al conectarse
alter role chatbot_api set search_path = public, extensions;
alter role chatbot_mcp set search_path = public, extensions;
alter role chatbot_n8n set search_path = public, extensions;

alter role chatbot_mcp set default_transaction_read_only = on;
alter role chatbot_mcp set statement_timeout = '5s';
alter role chatbot_api set statement_timeout = '10s';
alter role chatbot_n8n set statement_timeout = '60s';

-- ---------------------------------------------------------------------
-- Quitar los permisos por defecto de los roles de la API de Supabase
-- (la Data API está desactivada; esto es una segunda barrera)
-- ---------------------------------------------------------------------
do $$
declare
    r text;
begin
    foreach r in array array['anon', 'authenticated'] loop
        if exists (select 1 from pg_roles where rolname = r) then
            execute format('revoke all on all tables in schema public from %I', r);
            execute format('revoke all on all sequences in schema public from %I', r);
            execute format('revoke all on all functions in schema public from %I', r);
        end if;
    end loop;
end
$$;

-- ---------------------------------------------------------------------
-- Funciones de seguridad
-- ---------------------------------------------------------------------

-- Código del estudiante autenticado en la transacción actual
create function app_estudiante_actual()
returns varchar
language sql
stable
as $$
    select nullif(current_setting('app.estudiante_id', true), '')::varchar
$$;

comment on function app_estudiante_actual() is
    'Devuelve el código del estudiante fijado con set_config(''app.estudiante_id'', ...). NULL si no hay ninguno.';

-- Login: valida la contraseña con bcrypt y bloquea tras 5 intentos fallidos
create function fn_autenticar(p_codigo varchar, p_contrasena text)
returns table (codigo varchar, nombres varchar, apellidos varchar, programa varchar, semestre_actual smallint)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_cred credencial%rowtype;
begin
    select * into v_cred
    from credencial
    where estudiante_codigo = upper(p_codigo)
    for update;

    if not found then
        return;
    end if;

    if v_cred.bloqueado_hasta is not null and v_cred.bloqueado_hasta > now() then
        return;
    end if;

    if v_cred.hash_contrasena = crypt(p_contrasena, v_cred.hash_contrasena) then
        update credencial
           set intentos_fallidos = 0,
               bloqueado_hasta   = null,
               ultimo_acceso     = now()
         where estudiante_codigo = v_cred.estudiante_codigo;

        return query
        select e.codigo, e.nombres, e.apellidos, pr.nombre, e.semestre_actual
        from estudiante e
        join programa pr on pr.id = e.programa_id
        where e.codigo = v_cred.estudiante_codigo
          and e.estado = 'activo';
    else
        update credencial
           set intentos_fallidos = intentos_fallidos + 1,
               bloqueado_hasta   = case when intentos_fallidos + 1 >= 5
                                        then now() + interval '15 minutes' end
         where estudiante_codigo = v_cred.estudiante_codigo;

        insert into evento_seguridad (estudiante_codigo, tipo, detalle)
        values (v_cred.estudiante_codigo, 'login_fallido',
                jsonb_build_object('intentos', v_cred.intentos_fallidos + 1));
    end if;
end
$$;

comment on function fn_autenticar(varchar, text) is
    'Valida código y contraseña. Devuelve los datos básicos del estudiante o ninguna fila. Bloquea 15 minutos tras 5 intentos fallidos.';

revoke all on function fn_autenticar(varchar, text) from public;

-- Actualiza la vista materializada de estadísticas
create function fn_refrescar_estadisticas()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if exists (select 1 from mv_estadisticas_cursos limit 1) then
        refresh materialized view concurrently mv_estadisticas_cursos;
    else
        refresh materialized view mv_estadisticas_cursos;
    end if;
exception
    when object_not_in_prerequisite_state then
        refresh materialized view mv_estadisticas_cursos;
end
$$;

comment on function fn_refrescar_estadisticas() is
    'Recalcula mv_estadisticas_cursos. La ejecuta n8n de forma programada.';

revoke all on function fn_refrescar_estadisticas() from public;

-- ---------------------------------------------------------------------
-- Permisos (mínimos por rol)
-- ---------------------------------------------------------------------
grant usage on schema public to chatbot_api, chatbot_mcp, chatbot_n8n;
grant usage on schema extensions to chatbot_api, chatbot_mcp, chatbot_n8n;

-- Catálogo y contenido público: lectura para los tres roles
grant select on
    programa, pilar_competencia, curso, plan_estudio, requisito, regla_academica,
    curso_afinidad, periodo_academico, seccion,
    calendario_evento, documento, fragmento, fuente_noticia, noticia
to chatbot_api, chatbot_mcp, chatbot_n8n;

-- Datos personales: lectura (filtrada por RLS)
grant select on estudiante, matricula, inscripcion to chatbot_api, chatbot_mcp, chatbot_n8n;

-- Vistas
grant select on
    v_historial_academico, v_progreso_competencias, v_estado_insignia, v_avance_plan,
    v_asignaturas_pendientes, v_proyeccion_semestres, v_recomendacion_cursos,
    v_oferta_disponible, v_proximos_eventos, v_noticias_recientes, mv_estadisticas_cursos
to chatbot_api, chatbot_mcp, chatbot_n8n;

-- FastAPI: login, sesiones de chat y eventos de seguridad
grant execute on function fn_autenticar(varchar, text) to chatbot_api;
grant select, insert, update on sesion_chat to chatbot_api;
grant select on mensaje_chat to chatbot_api;
grant insert on evento_seguridad to chatbot_api;

-- n8n: ingesta del RAG, noticias, calendario, memoria y seguridad
grant insert, update, delete on documento, fragmento to chatbot_n8n;
grant insert, update on noticia, ejecucion_scraper to chatbot_n8n;
grant select on ejecucion_scraper to chatbot_n8n;
grant update (permitido_robots, revisado_robots_en) on fuente_noticia to chatbot_n8n;
grant insert, update, delete on calendario_evento to chatbot_n8n;
grant select, insert, update on sesion_chat to chatbot_n8n;
grant select, insert on mensaje_chat to chatbot_n8n;
grant insert on evento_seguridad to chatbot_n8n;
grant execute on function fn_refrescar_estadisticas() to chatbot_n8n;

grant usage on all sequences in schema public to chatbot_api, chatbot_n8n;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table programa           enable row level security;
alter table pilar_competencia  enable row level security;
alter table curso              enable row level security;
alter table plan_estudio       enable row level security;
alter table requisito          enable row level security;
alter table regla_academica    enable row level security;
alter table curso_afinidad     enable row level security;
alter table periodo_academico  enable row level security;
alter table seccion            enable row level security;
alter table estudiante         enable row level security;
alter table credencial         enable row level security;
alter table matricula          enable row level security;
alter table inscripcion        enable row level security;
alter table calendario_evento  enable row level security;
alter table documento          enable row level security;
alter table fragmento          enable row level security;
alter table fuente_noticia     enable row level security;
alter table noticia            enable row level security;
alter table ejecucion_scraper  enable row level security;
alter table sesion_chat        enable row level security;
alter table mensaje_chat       enable row level security;
alter table evento_seguridad   enable row level security;

-- Catálogo y contenido público: cualquiera de los roles puede leerlo
create policy lectura_catalogo on programa          for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on pilar_competencia for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on curso             for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on plan_estudio      for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on requisito         for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on regla_academica   for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on curso_afinidad    for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on periodo_academico for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_catalogo on seccion           for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_publica  on calendario_evento for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_publica  on documento         for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_publica  on fragmento         for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_publica  on fuente_noticia    for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);
create policy lectura_publica  on noticia           for select to chatbot_api, chatbot_mcp, chatbot_n8n using (true);

-- Escritura de contenido: solo n8n
create policy escritura_n8n on calendario_evento for all    to chatbot_n8n using (true) with check (true);
create policy escritura_n8n on documento         for all    to chatbot_n8n using (true) with check (true);
create policy escritura_n8n on fragmento         for all    to chatbot_n8n using (true) with check (true);
create policy escritura_n8n on fuente_noticia    for update to chatbot_n8n using (true) with check (true);
create policy escritura_n8n on noticia           for all    to chatbot_n8n using (true) with check (true);
create policy escritura_n8n on ejecucion_scraper for all    to chatbot_n8n using (true) with check (true);

-- Datos personales: cada estudiante solo ve lo suyo
create policy propio_estudiante on estudiante for select
    to chatbot_api, chatbot_mcp, chatbot_n8n
    using (codigo = app_estudiante_actual());

create policy propio_estudiante on matricula for select
    to chatbot_api, chatbot_mcp, chatbot_n8n
    using (estudiante_codigo = app_estudiante_actual());

create policy propio_estudiante on inscripcion for select
    to chatbot_api, chatbot_mcp, chatbot_n8n
    using (estudiante_codigo = app_estudiante_actual());

create policy propio_estudiante on sesion_chat for all
    to chatbot_api, chatbot_n8n
    using (estudiante_codigo = app_estudiante_actual())
    with check (estudiante_codigo = app_estudiante_actual());

create policy propio_estudiante on mensaje_chat for select
    to chatbot_api, chatbot_n8n
    using (estudiante_codigo = app_estudiante_actual());

create policy propio_estudiante_insercion on mensaje_chat for insert
    to chatbot_n8n
    with check (estudiante_codigo = app_estudiante_actual());

-- Eventos de seguridad: se pueden registrar, nunca leer desde la app
create policy registro_eventos on evento_seguridad for insert
    to chatbot_api, chatbot_n8n
    with check (true);

-- credencial: RLS activo y sin políticas. Solo fn_autenticar (security
-- definer) accede a ella.

commit;
