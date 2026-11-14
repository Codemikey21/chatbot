-- =====================================================================
-- 008_funciones_chat.sql
-- Memoria conversacional para el workflow de chat de n8n.
-- Funciones: fn_iniciar_turno, fn_guardar_turno.
--
-- Las dos funciones se ejecutan con los permisos de quien las llama
-- (security invoker): fijan el estudiante de la transacción y dejan
-- que las políticas RLS de sesion_chat y mensaje_chat hagan el control.
-- Así n8n nunca puede leer ni escribir la conversación de otro estudiante.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Inicio de turno: valida al estudiante, abre o recupera la sesión y
-- devuelve la memoria reciente con el perfil mínimo para el modelo.
-- ---------------------------------------------------------------------
create function fn_iniciar_turno(
    p_codigo    varchar,
    p_sesion_id uuid,
    p_pregunta  text,
    p_limite    int default 10
)
returns table (sesion_id uuid, sesion_nueva boolean, memoria jsonb, perfil jsonb)
language plpgsql
set search_path = public
as $$
declare
    v_sesion uuid;
    v_nueva  boolean := false;
begin
    if p_codigo is null or p_codigo !~ '^U00[0-9]{6}$' then
        raise exception 'Código de estudiante no válido';
    end if;

    -- Desde aquí RLS solo deja ver las filas de este estudiante
    perform set_config('app.estudiante_id', p_codigo, true);

    select jsonb_build_object(
               'nombre',   split_part(e.nombres, ' ', 1),
               'programa', pr.nombre,
               'semestre', e.semestre_actual)
      into perfil
      from estudiante e
      join programa pr on pr.id = e.programa_id
     where e.codigo = p_codigo
       and e.estado = 'activo';

    if perfil is null then
        raise exception 'Estudiante no encontrado o inactivo';
    end if;

    -- La sesión solo se encuentra si pertenece al estudiante (RLS)
    if p_sesion_id is not null then
        select s.id into v_sesion
          from sesion_chat s
         where s.id = p_sesion_id;

        if v_sesion is null then
            insert into evento_seguridad (estudiante_codigo, sesion_id, tipo, detalle)
            values (p_codigo, p_sesion_id, 'acceso_no_autorizado',
                    jsonb_build_object('motivo', 'sesión inexistente o de otro estudiante'));
        end if;
    end if;

    if v_sesion is null then
        insert into sesion_chat (estudiante_codigo, titulo)
        values (p_codigo, left(regexp_replace(coalesce(p_pregunta, 'Nueva conversación'), '\s+', ' ', 'g'), 80))
        returning id into v_sesion;
        v_nueva := true;
    end if;

    -- Últimos mensajes en orden cronológico. Los bloqueados por los
    -- guardrails no vuelven a entrar al contexto del modelo.
    select coalesce(jsonb_agg(jsonb_build_object('rol', m.rol, 'contenido', m.contenido)
                              order by m.creado_en, m.id), '[]'::jsonb)
      into memoria
      from (select mc.rol, left(mc.contenido, 2000) as contenido, mc.creado_en, mc.id
              from mensaje_chat mc
             where mc.sesion_id = v_sesion
               and not mc.bloqueado
             order by mc.creado_en desc, mc.id desc
             limit greatest(p_limite, 0)) m;

    sesion_id    := v_sesion;
    sesion_nueva := v_nueva;
    return next;
end
$$;

comment on function fn_iniciar_turno(varchar, uuid, text, int) is
    'Fija el estudiante de la transacción, abre o recupera su sesión y devuelve la memoria reciente y un perfil mínimo (nombre, programa, semestre).';

-- ---------------------------------------------------------------------
-- Cierre de turno: guarda la pregunta y la respuesta en la sesión.
-- ---------------------------------------------------------------------
create function fn_guardar_turno(
    p_codigo       varchar,
    p_sesion_id    uuid,
    p_pregunta     text,
    p_respuesta    text,
    p_intencion    varchar,
    p_fuentes      jsonb   default '[]'::jsonb,
    p_herramientas jsonb   default '[]'::jsonb,
    p_bloqueado    boolean default false,
    p_latencia_ms  int     default null
)
returns table (mensaje_usuario_id bigint, mensaje_asistente_id bigint)
language plpgsql
set search_path = public
as $$
begin
    if p_codigo is null or p_codigo !~ '^U00[0-9]{6}$' then
        raise exception 'Código de estudiante no válido';
    end if;

    perform set_config('app.estudiante_id', p_codigo, true);

    -- La llave compuesta (sesion_id, estudiante_codigo) y RLS impiden
    -- escribir en la sesión de otro estudiante.
    insert into mensaje_chat (sesion_id, estudiante_codigo, rol, contenido, intencion, bloqueado)
    values (p_sesion_id, p_codigo, 'usuario', p_pregunta, p_intencion, p_bloqueado)
    returning id into mensaje_usuario_id;

    insert into mensaje_chat (sesion_id, estudiante_codigo, rol, contenido, intencion,
                              fuentes, herramientas, bloqueado, latencia_ms)
    values (p_sesion_id, p_codigo, 'asistente', p_respuesta, p_intencion,
            coalesce(p_fuentes, '[]'::jsonb), coalesce(p_herramientas, '[]'::jsonb),
            p_bloqueado, p_latencia_ms)
    returning id into mensaje_asistente_id;

    update sesion_chat
       set ultima_actividad = now()
     where id = p_sesion_id;

    return next;
end
$$;

comment on function fn_guardar_turno(varchar, uuid, text, text, varchar, jsonb, jsonb, boolean, int) is
    'Guarda la pregunta del estudiante y la respuesta del asistente con intención, fuentes y herramientas usadas.';

-- ---------------------------------------------------------------------
-- Permisos: solo n8n ejecuta el turno de chat
-- ---------------------------------------------------------------------
revoke all on function fn_iniciar_turno(varchar, uuid, text, int) from public;
revoke all on function fn_guardar_turno(varchar, uuid, text, text, varchar, jsonb, jsonb, boolean, int) from public;

grant execute on function fn_iniciar_turno(varchar, uuid, text, int) to chatbot_n8n;
grant execute on function fn_guardar_turno(varchar, uuid, text, text, varchar, jsonb, jsonb, boolean, int) to chatbot_n8n;

commit;
