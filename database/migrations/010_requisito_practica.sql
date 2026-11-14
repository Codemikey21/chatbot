-- =====================================================================
-- 010_requisito_practica.sql
-- La Práctica Profesional exige, además de 110 créditos aprobados, la
-- insignia de Competencias Digitales completa (regla DEMO, configurable).
--
-- 1. Agrega la regla 'practica_requiere_insignia' (1 = sí, 0 = no).
-- 2. Recrea v_asignaturas_pendientes para que la columna "habilitada"
--    de la Práctica Profesional tenga en cuenta la insignia. Las demás
--    columnas no cambian, así que la API y el servidor MCP no se tocan.
-- =====================================================================

begin;

insert into regla_academica (programa_id, clave, valor, descripcion)
select id,
       'practica_requiere_insignia',
       1,
       'La Práctica Profesional exige la insignia de Competencias Digitales completa (1 = sí, 0 = no).'
from programa
on conflict (programa_id, clave) do update
    set valor = excluded.valor,
        descripcion = excluded.descripcion;

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
             or coalesce(ins.insignia_obtenida, false))) as habilitada
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
    'Asignaturas del pensum sin aprobar: prerrequisitos que faltan, si está en curso y si ya se puede matricular (habilitada). La Práctica Profesional también exige la insignia completa.';

commit;

-- Verificación: estudiantes con 110 créditos o más, su insignia y si la práctica queda habilitada
select ap.estudiante_codigo, ap.creditos_aprobados, ins.insignia_obtenida, ap.habilitada
from v_asignaturas_pendientes ap
join v_estado_insignia ins on ins.estudiante_codigo = ap.estudiante_codigo
where ap.componente = 'practica'
order by ap.creditos_aprobados desc
limit 10;
