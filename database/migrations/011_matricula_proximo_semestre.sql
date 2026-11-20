-- =====================================================================
-- 011_matricula_proximo_semestre.sql
-- Matrícula del próximo semestre.
--
-- "habilitada" responde qué puede matricular el estudiante hoy, con lo
-- que ya aprobó. Para planear el próximo semestre hay que suponer que
-- aprueba lo que está cursando. Esta migración agrega dos columnas al
-- final de v_asignaturas_pendientes (las existentes no cambian, así que
-- la API y los permisos siguen igual):
--
--   habilitada_proximo_periodo  la podrá matricular si aprueba lo que
--                               cursa ahora (prerrequisitos y créditos)
--   depende_de_en_curso         prerrequisitos que hoy está cursando
-- =====================================================================

begin;

create or replace view v_asignaturas_pendientes
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
),
creditos_en_curso as (
    select ec.estudiante_codigo, coalesce(sum(c.creditos), 0) as creditos
    from en_curso ec
    join curso c on c.id = ec.curso_id
    join plan_estudio pe on pe.curso_id = c.id
    group by ec.estudiante_codigo
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
        and av.creditos_aprobados >= pe.creditos_minimos_previos
        -- La práctica también exige la insignia, si la regla está activa
        and (pe.componente <> 'practica'
             or coalesce(ra.valor, 0) = 0
             or coalesce(ins.insignia_obtenida, false))) as habilitada,
    -- Nuevas columnas (al final para no alterar las existentes)
    (coalesce(cardinality(f2.prerrequisitos_sin_cursar), 0) = 0
        and av.creditos_aprobados + coalesce(cc.creditos, 0) >= pe.creditos_minimos_previos
        and (pe.componente <> 'practica'
             or coalesce(ra.valor, 0) = 0
             or coalesce(ins.insignia_obtenida, false))) as habilitada_proximo_periodo,
    coalesce(f3.prerrequisitos_en_curso, '{}')         as depende_de_en_curso
from estudiante e
join plan_estudio pe on pe.programa_id = e.programa_id
join curso c         on c.id = pe.curso_id
join v_avance_plan av on av.estudiante_codigo = e.codigo
left join v_estado_insignia ins
       on ins.estudiante_codigo = e.codigo
left join regla_academica ra
       on ra.programa_id = e.programa_id
      and ra.clave = 'practica_requiere_insignia'
left join en_curso ec
       on ec.estudiante_codigo = e.codigo
      and ec.curso_id = c.id
left join creditos_en_curso cc
       on cc.estudiante_codigo = e.codigo
-- Prerrequisitos sin aprobar
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
-- Prerrequisitos que no ha aprobado ni está cursando
left join lateral (
    select array_agg(rc.nombre order by rc.nombre) as prerrequisitos_sin_cursar
    from requisito r
    join curso rc on rc.id = r.requiere_curso_id
    where r.curso_id = c.id
      and r.tipo = 'prerrequisito'
      and not exists (
          select 1 from aprobadas a3
          where a3.estudiante_codigo = e.codigo
            and a3.curso_id = r.requiere_curso_id
      )
      and not exists (
          select 1 from en_curso e3
          where e3.estudiante_codigo = e.codigo
            and e3.curso_id = r.requiere_curso_id
      )
) f2 on true
-- Prerrequisitos que está cursando ahora
left join lateral (
    select array_agg(rc.nombre order by rc.nombre) as prerrequisitos_en_curso
    from requisito r
    join curso rc on rc.id = r.requiere_curso_id
    join en_curso e4
      on e4.estudiante_codigo = e.codigo
     and e4.curso_id = r.requiere_curso_id
    where r.curso_id = c.id
      and r.tipo = 'prerrequisito'
) f3 on true
where not exists (
    select 1 from aprobadas a
    where a.estudiante_codigo = e.codigo
      and a.curso_id = c.id
);

comment on view v_asignaturas_pendientes is
    'Asignaturas del pensum sin aprobar: prerrequisitos que faltan, si está en curso, si ya se puede matricular (habilitada) y si se podrá matricular el próximo periodo suponiendo que aprueba lo que cursa (habilitada_proximo_periodo). La Práctica Profesional también exige la insignia completa.';

commit;

-- Verificación: lo que el estudiante DEMO podrá matricular el próximo semestre
select curso_codigo, curso_nombre, creditos, semestre, depende_de_en_curso
from v_asignaturas_pendientes
where estudiante_codigo = 'U00900100'
  and habilitada_proximo_periodo
  and not en_curso
order by semestre, curso_codigo;
