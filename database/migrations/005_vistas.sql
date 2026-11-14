-- =====================================================================
-- 005_vistas.sql
-- Vistas analíticas que consumen el servidor MCP, n8n y la app.
-- Las vistas con datos personales usan security_invoker = true para que
-- se aplique el RLS de quien consulta (migración 006).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Historial académico con el detalle del curso
-- ---------------------------------------------------------------------
create view v_historial_academico
with (security_invoker = true) as
select
    i.estudiante_codigo,
    i.periodo,
    s.nrc,
    c.id          as curso_id,
    c.codigo      as curso_codigo,
    c.nombre      as curso_nombre,
    c.tipo        as curso_tipo,
    c.creditos,
    c.pilar_id,
    p.nombre      as pilar,
    i.estado,
    i.nota_final,
    s.modalidad
from inscripcion i
join seccion s            on s.id = i.seccion_id
join curso c              on c.id = s.curso_id
left join pilar_competencia p on p.id = c.pilar_id;

comment on view v_historial_academico is
    'Una fila por NRC inscrito, con nombre del curso, tipo, pilar, estado y nota.';

-- ---------------------------------------------------------------------
-- Progreso por pilar de competencias digitales
-- ---------------------------------------------------------------------
create view v_progreso_competencias
with (security_invoker = true) as
select
    e.codigo  as estudiante_codigo,
    p.id      as pilar_id,
    p.codigo  as pilar_codigo,
    p.nombre  as pilar,
    p.cursos_requeridos,
    count(distinct h.curso_id) filter (where h.estado = 'aprobado')                        as cursos_aprobados,
    coalesce(string_agg(distinct h.curso_nombre, ', ') filter (where h.estado = 'aprobado'), '') as cursos_aprobados_nombres,
    count(distinct h.curso_id) filter (where h.estado = 'inscrito')                        as cursos_en_curso,
    count(distinct h.curso_id) filter (where h.estado = 'aprobado') >= p.cursos_requeridos as pilar_aprobado
from estudiante e
cross join pilar_competencia p
left join v_historial_academico h
       on h.estudiante_codigo = e.codigo
      and h.pilar_id = p.id
group by e.codigo, p.id, p.codigo, p.nombre, p.cursos_requeridos;

comment on view v_progreso_competencias is
    'Por estudiante y pilar: cursos aprobados, en curso y si el pilar está aprobado.';

-- ---------------------------------------------------------------------
-- Estado de la insignia de competencias digitales
-- ---------------------------------------------------------------------
create view v_estado_insignia
with (security_invoker = true) as
select
    estudiante_codigo,
    count(*) filter (where pilar_aprobado)                       as pilares_aprobados,
    count(*)                                                     as pilares_totales,
    bool_and(pilar_aprobado)                                     as insignia_obtenida,
    coalesce(array_agg(pilar order by pilar_id) filter (where not pilar_aprobado), '{}') as pilares_pendientes
from v_progreso_competencias
group by estudiante_codigo;

comment on view v_estado_insignia is
    'Resumen por estudiante: pilares aprobados, pendientes y si ya obtuvo la insignia.';

-- ---------------------------------------------------------------------
-- Avance en el plan de estudios
-- ---------------------------------------------------------------------
create view v_avance_plan
with (security_invoker = true) as
with aprobadas as (
    select distinct estudiante_codigo, curso_id
    from v_historial_academico
    where estado = 'aprobado' and curso_tipo = 'asignatura'
)
select
    e.codigo                                                          as estudiante_codigo,
    e.programa_id,
    e.semestre_actual,
    pr.creditos_totales,
    coalesce(sum(c.creditos) filter (where a.curso_id is not null), 0)::int as creditos_aprobados,
    count(*) filter (where a.curso_id is not null)::int               as asignaturas_aprobadas,
    count(*) filter (where a.curso_id is null)::int                   as asignaturas_pendientes,
    round(100.0 * coalesce(sum(c.creditos) filter (where a.curso_id is not null), 0)
          / pr.creditos_totales, 1)                                   as porcentaje_avance
from estudiante e
join programa pr     on pr.id = e.programa_id
join plan_estudio pe on pe.programa_id = e.programa_id
join curso c         on c.id = pe.curso_id
left join aprobadas a
       on a.estudiante_codigo = e.codigo
      and a.curso_id = pe.curso_id
group by e.codigo, e.programa_id, e.semestre_actual, pr.creditos_totales;

comment on view v_avance_plan is
    'Créditos y asignaturas aprobadas frente al pensum, con el porcentaje de avance.';

-- ---------------------------------------------------------------------
-- Asignaturas pendientes y si ya se pueden matricular
-- ---------------------------------------------------------------------
create view v_asignaturas_pendientes
with (security_invoker = true) as
with aprobadas as (
    select distinct estudiante_codigo, curso_id
    from v_historial_academico
    where estado = 'aprobado'
),
en_curso as (
    select distinct estudiante_codigo, curso_id
    from v_historial_academico
    where estado = 'inscrito'
)
select
    e.codigo     as estudiante_codigo,
    c.id         as curso_id,
    c.codigo     as curso_codigo,
    c.nombre     as curso_nombre,
    c.creditos,
    pe.semestre,
    pe.componente,
    (ec.curso_id is not null)                         as en_curso,
    coalesce(f.prerrequisitos_faltantes, '{}')        as prerrequisitos_faltantes,
    pe.creditos_minimos_previos,
    av.creditos_aprobados,
    (coalesce(cardinality(f.prerrequisitos_faltantes), 0) = 0
        and av.creditos_aprobados >= pe.creditos_minimos_previos) as habilitada
from estudiante e
join plan_estudio pe on pe.programa_id = e.programa_id
join curso c         on c.id = pe.curso_id
join v_avance_plan av on av.estudiante_codigo = e.codigo
left join en_curso ec
       on ec.estudiante_codigo = e.codigo
      and ec.curso_id = c.id
left join lateral (
    select array_agg(rc.nombre order by rc.nombre) as prerrequisitos_faltantes
    from requisito r
    join curso rc on rc.id = r.requiere_curso_id
    where r.curso_id = c.id
      and r.tipo = 'prerrequisito'
      and not exists (
          select 1 from aprobadas a2
          where a2.estudiante_codigo = e.codigo
            and a2.curso_id = r.requiere_curso_id
      )
) f on true
where not exists (
    select 1 from aprobadas a
    where a.estudiante_codigo = e.codigo
      and a.curso_id = c.id
);

comment on view v_asignaturas_pendientes is
    'Asignaturas del pensum sin aprobar: prerrequisitos que faltan, si está en curso y si ya se puede matricular (habilitada).';

-- ---------------------------------------------------------------------
-- Proyección de semestres restantes
-- ---------------------------------------------------------------------
create view v_proyeccion_semestres
with (security_invoker = true) as
with recursive pendientes as (
    select estudiante_codigo, curso_id
    from v_asignaturas_pendientes
),
cadena as (
    -- Nivel 1: pendientes que no dependen de otra pendiente
    select p.estudiante_codigo, p.curso_id, 1 as nivel
    from pendientes p
    where not exists (
        select 1
        from requisito r
        join pendientes p2
          on p2.estudiante_codigo = p.estudiante_codigo
         and p2.curso_id = r.requiere_curso_id
        where r.curso_id = p.curso_id
          and r.tipo = 'prerrequisito'
    )
    union all
    -- Nivel n+1: pendientes cuyo prerrequisito está en el nivel n
    select p.estudiante_codigo, p.curso_id, c.nivel + 1
    from cadena c
    join requisito r
      on r.requiere_curso_id = c.curso_id
     and r.tipo = 'prerrequisito'
    join pendientes p
      on p.estudiante_codigo = c.estudiante_codigo
     and p.curso_id = r.curso_id
),
cadena_maxima as (
    select estudiante_codigo, max(nivel) as nivel_maximo
    from cadena
    group by estudiante_codigo
)
select
    av.estudiante_codigo,
    av.creditos_totales - av.creditos_aprobados                      as creditos_pendientes,
    ra.valor::int                                                    as max_creditos_semestre,
    coalesce(cm.nivel_maximo, 0)                                     as cadena_prerrequisitos,
    greatest(
        ceil((av.creditos_totales - av.creditos_aprobados) / ra.valor),
        coalesce(cm.nivel_maximo, 0)
    )::int                                                           as semestres_estimados
from v_avance_plan av
join regla_academica ra
  on ra.programa_id = av.programa_id
 and ra.clave = 'max_creditos_semestre'
left join cadena_maxima cm on cm.estudiante_codigo = av.estudiante_codigo;

comment on view v_proyeccion_semestres is
    'Semestres restantes estimados: el mayor entre (créditos pendientes / máximo por semestre) y la cadena de prerrequisitos pendientes más larga. Incluye las asignaturas en curso.';

-- ---------------------------------------------------------------------
-- Recomendación de cursos digitales por pilar pendiente
-- ---------------------------------------------------------------------
create view v_recomendacion_cursos
with (security_invoker = true) as
with pilares_pendientes as (
    select estudiante_codigo, pilar_id
    from v_progreso_competencias
    where not pilar_aprobado
),
estado_asignatura as (
    select
        e.codigo as estudiante_codigo,
        pe.curso_id,
        pe.semestre,
        case
            when exists (select 1 from v_historial_academico h
                         where h.estudiante_codigo = e.codigo and h.curso_id = pe.curso_id
                           and h.estado = 'aprobado') then 'aprobada'
            when exists (select 1 from v_historial_academico h
                         where h.estudiante_codigo = e.codigo and h.curso_id = pe.curso_id
                           and h.estado = 'inscrito') then 'en_curso'
            else 'pendiente'
        end as estado
    from estudiante e
    join plan_estudio pe on pe.programa_id = e.programa_id
),
puntajes as (
    select
        pp.estudiante_codigo,
        p.id     as pilar_id,
        p.nombre as pilar,
        c.id     as curso_id,
        c.codigo as curso_codigo,
        c.nombre as curso_nombre,
        coalesce(max(ca.afinidad), 0) as afinidad_maxima,
        coalesce(sum(ca.afinidad * case ea.estado when 'aprobada' then 3
                                                  when 'en_curso' then 2
                                                  else 1 end), 0)::int as puntaje,
        coalesce(
            jsonb_agg(
                jsonb_build_object(
                    'asignatura', a.nombre,
                    'estado',     ea.estado,
                    'semestre',   ea.semestre,
                    'afinidad',   ca.afinidad,
                    'razon',      ca.razon
                ) order by ca.afinidad desc, a.nombre
            ) filter (where ca.asignatura_id is not null),
            '[]'::jsonb
        ) as razones
    from pilares_pendientes pp
    join pilar_competencia p on p.id = pp.pilar_id
    join curso c             on c.pilar_id = pp.pilar_id and c.activo
    left join curso_afinidad ca on ca.curso_digital_id = c.id
    left join curso a           on a.id = ca.asignatura_id
    left join estado_asignatura ea
           on ea.estudiante_codigo = pp.estudiante_codigo
          and ea.curso_id = ca.asignatura_id
    where not exists (
        select 1 from v_historial_academico h
        where h.estudiante_codigo = pp.estudiante_codigo
          and h.curso_id = c.id
          and h.estado in ('inscrito', 'aprobado')
    )
    group by pp.estudiante_codigo, p.id, p.nombre, c.id, c.codigo, c.nombre
)
select
    puntajes.*,
    rank() over (partition by estudiante_codigo, pilar_id order by puntaje desc, afinidad_maxima desc) as posicion
from puntajes;

comment on view v_recomendacion_cursos is
    'Cursos digitales recomendados en los pilares que el estudiante aún no aprueba, ordenados por afinidad con su pensum. razones explica cada relación (asignatura, estado, semestre y motivo).';

-- ---------------------------------------------------------------------
-- Oferta disponible (NRC abiertos)
-- Sin security_invoker: solo expone conteos agregados de cupos, no datos
-- personales, y necesita contar inscripciones de todos los estudiantes.
-- ---------------------------------------------------------------------
create view v_oferta_disponible as
select
    s.nrc,
    s.periodo,
    c.codigo  as curso_codigo,
    c.nombre  as curso_nombre,
    c.tipo    as curso_tipo,
    p.nombre  as pilar,
    c.creditos,
    s.grupo,
    s.docente,
    s.modalidad,
    s.horario,
    s.cupo,
    (s.cupo - count(i.id) filter (where i.estado = 'inscrito'))::int as cupos_disponibles
from seccion s
join curso c                  on c.id = s.curso_id
left join pilar_competencia p on p.id = c.pilar_id
left join inscripcion i       on i.seccion_id = s.id
where s.estado = 'abierta'
group by s.id, s.nrc, s.periodo, c.codigo, c.nombre, c.tipo, p.nombre, c.creditos,
         s.grupo, s.docente, s.modalidad, s.horario, s.cupo;

comment on view v_oferta_disponible is
    'Secciones abiertas a inscripción con cupos disponibles. No expone datos personales.';

-- ---------------------------------------------------------------------
-- Próximos eventos del calendario (hora de Colombia)
-- ---------------------------------------------------------------------
create view v_proximos_eventos
with (security_invoker = true) as
select
    ce.*,
    (ce.fecha_inicio - (now() at time zone 'America/Bogota')::date) as dias_para_inicio
from calendario_evento ce
where ce.fecha_fin >= (now() at time zone 'America/Bogota')::date;

comment on view v_proximos_eventos is
    'Eventos que no han terminado, con los días que faltan para su inicio (negativo si ya empezó).';

-- ---------------------------------------------------------------------
-- Noticias recientes con su fuente
-- ---------------------------------------------------------------------
create view v_noticias_recientes
with (security_invoker = true) as
select
    n.id,
    n.titulo,
    n.resumen,
    n.url,
    n.categoria,
    n.fecha_publicacion,
    n.recopilado_en,
    f.nombre as fuente
from noticia n
join fuente_noticia f on f.id = n.fuente_id;

comment on view v_noticias_recientes is
    'Noticias con el nombre de su fuente. Ordenar por fecha_publicacion al consultar.';

-- ---------------------------------------------------------------------
-- Estadísticas por curso (vista materializada, sin datos personales)
-- ---------------------------------------------------------------------
create materialized view mv_estadisticas_cursos as
select
    c.id      as curso_id,
    c.codigo  as curso_codigo,
    c.nombre  as curso_nombre,
    c.tipo    as curso_tipo,
    p.nombre  as pilar,
    count(i.id)                                                   as inscripciones,
    count(i.id) filter (where i.estado = 'aprobado')              as aprobados,
    count(i.id) filter (where i.estado = 'reprobado')             as reprobados,
    round(100.0 * count(i.id) filter (where i.estado = 'aprobado')
          / nullif(count(i.id) filter (where i.estado in ('aprobado', 'reprobado')), 0), 1) as tasa_aprobacion,
    round(avg(i.nota_final), 2)                                   as nota_promedio
from curso c
left join pilar_competencia p on p.id = c.pilar_id
left join seccion s           on s.curso_id = c.id
left join inscripcion i       on i.seccion_id = s.id
group by c.id, c.codigo, c.nombre, c.tipo, p.nombre
with no data;

create unique index mv_estadisticas_cursos_uk on mv_estadisticas_cursos (curso_id);

comment on materialized view mv_estadisticas_cursos is
    'Inscripciones, aprobación y nota promedio por curso. Se actualiza con fn_refrescar_estadisticas().';

commit;
