-- =====================================================================
-- 012_textos_sin_etiqueta_demo.sql
-- Quita la etiqueta "DEMO" de los textos que ve el estudiante (descripción
-- de cursos, docentes, horarios y nombre del boletín). Los datos siguen
-- siendo sintéticos: la aclaración queda una sola vez en la app
-- (Más → Acerca del proyecto) y en el README.
-- =====================================================================

begin;

update curso
set descripcion = regexp_replace(descripcion, '^DEMO:\s*', '')
where descripcion like 'DEMO:%';

update seccion
set docente = replace(docente, 'Docente DEMO ', 'Docente '),
    horario = replace(horario, ' (DEMO)', '')
where docente like '%DEMO%' or horario like '%(DEMO)%';

update fuente_noticia
set nombre = 'Boletín de Competencias Digitales'
where nombre = 'Boletín de Competencias Digitales (DEMO)';

commit;

-- Verificación: no deben quedar textos con DEMO
select 'curso' as tabla, count(*) from curso where descripcion like '%DEMO%'
union all
select 'seccion', count(*) from seccion where docente like '%DEMO%' or horario like '%DEMO%'
union all
select 'fuente_noticia', count(*) from fuente_noticia where nombre like '%DEMO%';
