-- =====================================================================
-- 007_funciones_rag.sql
-- Funciones del RAG: estado de un documento, guardado atómico de un
-- documento con sus fragmentos y búsqueda híbrida (vectores + texto).
-- Las ejecuta n8n con el rol chatbot_n8n; la búsqueda también la pueden
-- usar la API y el servidor MCP.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- ¿El documento es nuevo, cambió o sigue igual?
-- ---------------------------------------------------------------------
create function fn_estado_documento(p_nombre_archivo varchar, p_hash char(64))
returns table (estado text, documento_id integer, version integer)
language sql
stable
as $$
    select
        case
            when d.id is null then 'nuevo'
            when d.hash_contenido = p_hash and d.estado = 'procesado' then 'sin_cambios'
            else 'modificado'
        end,
        d.id,
        d.version
    from (select 1) as uno
    left join documento d on d.nombre_archivo = p_nombre_archivo
$$;

comment on function fn_estado_documento(varchar, char) is
    'Compara el hash SHA-256 del contenido con el guardado: nuevo, modificado o sin_cambios. Evita generar embeddings de documentos que no cambiaron.';

-- ---------------------------------------------------------------------
-- Guarda un documento y reemplaza sus fragmentos en una sola transacción
--   p_documento:  {"nombre_archivo", "titulo", "descripcion", "tipo_archivo",
--                  "origen", "url_origen", "hash_contenido"}
--   p_fragmentos: [{"indice", "contenido", "pagina", "seccion", "tokens",
--                   "embedding": [1024 números]}]
-- ---------------------------------------------------------------------
create function fn_guardar_documento(p_documento jsonb, p_fragmentos jsonb)
returns table (documento_id integer, version integer, total_fragmentos integer, accion text)
language plpgsql
as $$
declare
    v_id       integer;
    v_version  integer;
    v_total    integer;
    v_accion   text;
begin
    if jsonb_typeof(p_fragmentos) is distinct from 'array' or jsonb_array_length(p_fragmentos) = 0 then
        raise exception 'El documento % no tiene fragmentos', p_documento->>'nombre_archivo';
    end if;

    select d.id into v_id
    from documento d
    where d.nombre_archivo = p_documento->>'nombre_archivo'
    for update;

    if v_id is null then
        insert into documento (titulo, descripcion, nombre_archivo, tipo_archivo, origen,
                               url_origen, hash_contenido, estado)
        values (p_documento->>'titulo',
                p_documento->>'descripcion',
                p_documento->>'nombre_archivo',
                p_documento->>'tipo_archivo',
                p_documento->>'origen',
                nullif(p_documento->>'url_origen', ''),
                p_documento->>'hash_contenido',
                'pendiente')
        returning documento.id, documento.version into v_id, v_version;
        v_accion := 'creado';
    else
        delete from fragmento f where f.documento_id = v_id;

        update documento d
           set titulo         = p_documento->>'titulo',
               descripcion    = p_documento->>'descripcion',
               tipo_archivo   = p_documento->>'tipo_archivo',
               origen         = p_documento->>'origen',
               url_origen     = nullif(p_documento->>'url_origen', ''),
               hash_contenido = p_documento->>'hash_contenido',
               version        = d.version + 1,
               estado         = 'pendiente',
               actualizado_en = now()
         where d.id = v_id
        returning d.version into v_version;
        v_accion := 'actualizado';
    end if;

    insert into fragmento (documento_id, indice, contenido, pagina, seccion, tokens, embedding)
    select v_id,
           (f->>'indice')::integer,
           f->>'contenido',
           nullif(f->>'pagina', '')::integer,
           nullif(f->>'seccion', ''),
           nullif(f->>'tokens', '')::integer,
           (f->'embedding')::text::vector
    from jsonb_array_elements(p_fragmentos) as f;

    get diagnostics v_total = row_count;

    update documento d
       set total_fragmentos = v_total,
           estado = 'procesado'
     where d.id = v_id;

    return query select v_id, v_version, v_total, v_accion;
end
$$;

comment on function fn_guardar_documento(jsonb, jsonb) is
    'Crea o actualiza un documento y reemplaza todos sus fragmentos con embeddings. Si algo falla no queda nada a medias.';

-- ---------------------------------------------------------------------
-- Búsqueda híbrida: similitud de vectores + búsqueda de texto en español,
-- combinadas con Reciprocal Rank Fusion (RRF). Solo devuelve fragmentos
-- con similitud mínima, para poder responder "no encontrado".
-- ---------------------------------------------------------------------
create function fn_buscar_fragmentos(
    p_embedding         vector,
    p_consulta          text,
    p_limite            integer default 5,
    p_similitud_minima  double precision default 0.35
)
returns table (
    fragmento_id    bigint,
    titulo          varchar,
    nombre_archivo  varchar,
    origen          varchar,
    url_origen      text,
    indice          integer,
    pagina          integer,
    seccion         varchar,
    contenido       text,
    similitud       numeric,
    puntaje         numeric
)
language sql
stable
as $$
    with semantica as (
        select f.id,
               row_number() over (order by f.embedding <=> p_embedding) as posicion
        from fragmento f
        order by f.embedding <=> p_embedding
        limit 20
    ),
    lexica as (
        select f.id,
               row_number() over (order by ts_rank_cd(f.contenido_tsv, q) desc) as posicion
        from fragmento f,
             websearch_to_tsquery('spanish', coalesce(p_consulta, '')) as q
        where f.contenido_tsv @@ q
        order by ts_rank_cd(f.contenido_tsv, q) desc
        limit 20
    ),
    combinada as (
        select coalesce(s.id, l.id) as id,
               coalesce(1.0 / (60 + s.posicion), 0) + coalesce(1.0 / (60 + l.posicion), 0) as rrf
        from semantica s
        full join lexica l on l.id = s.id
    )
    select f.id,
           d.titulo,
           d.nombre_archivo,
           d.origen,
           d.url_origen,
           f.indice,
           f.pagina,
           f.seccion,
           f.contenido,
           round((1 - (f.embedding <=> p_embedding))::numeric, 4),
           round(c.rrf::numeric, 5)
    from combinada c
    join fragmento f on f.id = c.id
    join documento d on d.id = f.documento_id
    where 1 - (f.embedding <=> p_embedding) >= p_similitud_minima
    order by c.rrf desc
    limit greatest(1, least(p_limite, 10))
$$;

comment on function fn_buscar_fragmentos(vector, text, integer, double precision) is
    'Búsqueda híbrida para el RAG. Devuelve hasta p_limite fragmentos con su documento, URL y similitud; vacío si ninguno supera p_similitud_minima.';

-- ---------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------
revoke all on function fn_estado_documento(varchar, char) from public;
revoke all on function fn_guardar_documento(jsonb, jsonb) from public;
revoke all on function fn_buscar_fragmentos(vector, text, integer, double precision) from public;

grant execute on function fn_estado_documento(varchar, char) to chatbot_n8n;
grant execute on function fn_guardar_documento(jsonb, jsonb) to chatbot_n8n;
grant execute on function fn_buscar_fragmentos(vector, text, integer, double precision)
    to chatbot_n8n, chatbot_mcp, chatbot_api;

commit;
