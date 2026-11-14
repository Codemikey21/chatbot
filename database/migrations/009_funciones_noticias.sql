-- =====================================================================
-- 009_funciones_noticias.sql
-- Configuración de las fuentes del scraper y guardado de noticias.
-- n8n (WF04) llama a fn_guardar_noticias con lo que devuelve el scraper.
-- =====================================================================

begin;

-- Selectores CSS, palabras clave y otras opciones de cada fuente
alter table fuente_noticia
    add column configuracion jsonb not null default '{}'::jsonb;

comment on column fuente_noticia.configuracion is
    'Opciones del scraper para esta fuente: palabras_clave, categoria, selectores CSS (HTML) y conservar_fragmento.';

-- ---------------------------------------------------------------------
-- Guarda las noticias de una fuente y registra la ejecución.
-- Inserta las nuevas, actualiza solo las que cambiaron (hash distinto)
-- y deja intactas las demás. Si robots.txt no lo permite o hubo un
-- error, solo registra la ejecución como fallida.
-- ---------------------------------------------------------------------
create function fn_guardar_noticias(
    p_fuente_id   smallint,
    p_noticias    jsonb,
    p_permitido   boolean,
    p_error       text default null,
    p_iniciado_en timestamptz default now()
)
returns table (ejecucion_id bigint, estado text, nuevas int, actualizadas int, sin_cambios int)
language plpgsql
set search_path = public
as $$
declare
    v_recibidas int := 0;
begin
    update fuente_noticia
       set permitido_robots   = p_permitido,
           revisado_robots_en = now()
     where id = p_fuente_id;

    if not found then
        raise exception 'La fuente % no existe', p_fuente_id;
    end if;

    nuevas := 0;
    actualizadas := 0;

    if p_error is not null or not p_permitido then
        estado := 'fallida';
    else
        with entrada as (
            select distinct on (n.url)
                   left(trim(n.titulo), 300)  as titulo,
                   nullif(trim(n.resumen), '') as resumen,
                   n.url,
                   case when n.categoria in ('curso', 'convocatoria', 'certificacion', 'noticia')
                        then n.categoria else 'noticia' end as categoria,
                   n.fecha_publicacion,
                   n.hash_contenido
              from jsonb_to_recordset(coalesce(p_noticias, '[]'::jsonb)) as n(
                       titulo text, resumen text, url text, categoria text,
                       fecha_publicacion date, hash_contenido text)
             where coalesce(trim(n.titulo), '') <> ''
               and n.url ~ '^https?://'
               and n.hash_contenido ~ '^[0-9a-f]{64}$'
        ),
        guardadas as (
            insert into noticia (fuente_id, titulo, resumen, url, categoria, fecha_publicacion, hash_contenido)
            select p_fuente_id, e.titulo, e.resumen, e.url, e.categoria, e.fecha_publicacion, e.hash_contenido
              from entrada e
            on conflict (url) do update
               set titulo            = excluded.titulo,
                   resumen           = excluded.resumen,
                   categoria         = excluded.categoria,
                   fecha_publicacion = coalesce(excluded.fecha_publicacion, noticia.fecha_publicacion),
                   hash_contenido    = excluded.hash_contenido,
                   actualizado_en    = now()
             where noticia.hash_contenido is distinct from excluded.hash_contenido
            returning (xmax = 0) as es_nueva
        )
        select count(*) filter (where es_nueva),
               count(*) filter (where not es_nueva),
               (select count(*) from entrada)
          into nuevas, actualizadas, v_recibidas
          from guardadas;

        estado := 'exitosa';
    end if;

    sin_cambios := greatest(v_recibidas - nuevas - actualizadas, 0);

    insert into ejecucion_scraper (fuente_id, iniciado_en, finalizado_en, estado,
                                   noticias_nuevas, noticias_actualizadas, mensaje_error)
    values (p_fuente_id, coalesce(p_iniciado_en, now()), now(), estado, nuevas, actualizadas,
            case when not p_permitido and p_error is null
                 then 'robots.txt no permite extraer esta fuente'
                 else left(p_error, 500) end)
    returning id into ejecucion_id;

    return next;
end
$$;

comment on function fn_guardar_noticias(smallint, jsonb, boolean, text, timestamptz) is
    'Guarda las noticias de una fuente sin duplicados (por URL), actualiza las que cambiaron y registra la ejecución del scraper.';

revoke all on function fn_guardar_noticias(smallint, jsonb, boolean, text, timestamptz) from public;
grant execute on function fn_guardar_noticias(smallint, jsonb, boolean, text, timestamptz) to chatbot_n8n;

commit;
