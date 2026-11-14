-- =====================================================================
-- seeds/002_estudiantes_demo.sql
-- Estudiantes, credenciales, matrículas e historial académico DEMO.
--
-- TODOS LOS DATOS DE ESTE ARCHIVO SON FICTICIOS. Los códigos usan el
-- rango U009xxxxx y los correos el dominio @demo.local.
-- Contraseña de todos los usuarios de prueba: Demo2026*
-- Usuario recomendado para la demostración: U00900100
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Estudiantes
-- ---------------------------------------------------------------------
insert into estudiante (codigo, nombres, apellidos, correo, programa_id, semestre_actual, periodo_ingreso)
select v.codigo, v.nombres, v.apellidos, v.correo, pr.id, v.semestre, v.ingreso
from (values
    ('U00900100', 'Laura Valentina', 'Rojas Méndez',     'laura.rojas@demo.local',      6, '2024-1'),
    ('U00900101', 'Santiago',        'Pérez Gómez',      'santiago.perez@demo.local',   1, '2026-2'),
    ('U00900102', 'Camila',          'Torres Ruiz',      'camila.torres@demo.local',    2, '2026-1'),
    ('U00900103', 'Andrés Felipe',   'Martínez Díaz',    'andres.martinez@demo.local',  3, '2025-2'),
    ('U00900104', 'Daniela',         'Castro Vargas',    'daniela.castro@demo.local',   4, '2025-1'),
    ('U00900105', 'Juan David',      'Herrera López',    'juan.herrera@demo.local',     5, '2024-2'),
    ('U00900106', 'María José',      'Ramírez Ortiz',    'maria.ramirez@demo.local',    5, '2024-2'),
    ('U00900107', 'Sebastián',       'Moreno Silva',     'sebastian.moreno@demo.local', 6, '2024-1'),
    ('U00900108', 'Natalia',         'Jiménez Cárdenas', 'natalia.jimenez@demo.local',  7, '2023-2'),
    ('U00900109', 'Felipe',          'Suárez Rincón',    'felipe.suarez@demo.local',    7, '2023-2'),
    ('U00900110', 'Isabella',        'Navarro Quintero', 'isabella.navarro@demo.local', 8, '2023-1'),
    ('U00900111', 'Diego Alejandro', 'Rueda Parra',      'diego.rueda@demo.local',      8, '2023-1')
) as v (codigo, nombres, apellidos, correo, semestre, ingreso)
join programa pr on pr.codigo = 'ING-SIS';

-- ---------------------------------------------------------------------
-- Credenciales (bcrypt). Contraseña DEMO: Demo2026*
-- ---------------------------------------------------------------------
insert into credencial (estudiante_codigo, hash_contrasena)
select codigo, crypt('Demo2026*', gen_salt('bf', 10))
from estudiante;

-- ---------------------------------------------------------------------
-- Periodos numerados (para ubicar cada semestre del estudiante)
-- ---------------------------------------------------------------------
create temporary table tmp_periodo on commit drop as
select codigo, fecha_inicio, row_number() over (order by codigo) as idx
from periodo_academico
where codigo <= '2026-2';

-- ---------------------------------------------------------------------
-- Matrículas: desde el periodo de ingreso hasta el actual (2026-2)
-- ---------------------------------------------------------------------
insert into matricula (estudiante_codigo, periodo, fecha_matricula, estado)
select e.codigo,
       tp.codigo,
       tp.fecha_inicio - 10,
       case when tp.codigo = '2026-2' then 'activa' else 'finalizada' end
from estudiante e
join tmp_periodo ti on ti.codigo = e.periodo_ingreso
join tmp_periodo tp on tp.idx >= ti.idx;

-- ---------------------------------------------------------------------
-- Historial del pensum: cada semestre ya cursado queda aprobado y el
-- semestre actual queda inscrito. Notas DEMO entre 3.0 y 4.9.
-- ---------------------------------------------------------------------
insert into inscripcion (matricula_id, estudiante_codigo, periodo, seccion_id, estado, nota_final)
select m.id,
       e.codigo,
       tp.codigo,
       s.id,
       case when tp.codigo = '2026-2' then 'inscrito' else 'aprobado' end,
       case when tp.codigo = '2026-2' then null
            else 3.0 + (abs(hashtext(e.codigo || c.codigo)) % 20) / 10.0 end
from estudiante e
join tmp_periodo ti   on ti.codigo = e.periodo_ingreso
join plan_estudio pe  on pe.programa_id = e.programa_id
                     and pe.semestre <= e.semestre_actual
join curso c          on c.id = pe.curso_id
join tmp_periodo tp   on tp.idx = ti.idx + pe.semestre - 1
join matricula m      on m.estudiante_codigo = e.codigo
                     and m.periodo = tp.codigo
join seccion s        on s.curso_id = c.id
                     and s.periodo = tp.codigo
                     and s.grupo = 'A';

-- ---------------------------------------------------------------------
-- Asignaturas reprobadas y repetidas en el periodo siguiente
-- ---------------------------------------------------------------------
create temporary table tmp_reprobada (
    codigo        varchar(9),
    curso_codigo  varchar(20),
    nota          numeric(3,1)
) on commit drop;

insert into tmp_reprobada values
    ('U00900100', 'SIS-503', 2.6),  -- Ecuaciones Diferenciales: la repite en 2026-2
    ('U00900106', 'SIS-302', 2.8),  -- Diseño y Desarrollo Multimedia: aprobada al repetir
    ('U00900108', 'SIS-402', 2.3);  -- Cálculo en Varias Variables: aprobada al repetir

update inscripcion i
   set estado = 'reprobado',
       nota_final = r.nota
  from tmp_reprobada r
  join curso c on c.codigo = r.curso_codigo
  join seccion s on s.curso_id = c.id
 where i.estudiante_codigo = r.codigo
   and i.seccion_id = s.id;

insert into inscripcion (matricula_id, estudiante_codigo, periodo, seccion_id, estado, nota_final)
select m.id,
       r.codigo,
       tsig.codigo,
       s2.id,
       case when tsig.codigo = '2026-2' then 'inscrito' else 'aprobado' end,
       case when tsig.codigo = '2026-2' then null else 3.6 end
from tmp_reprobada r
join curso c         on c.codigo = r.curso_codigo
join inscripcion i   on i.estudiante_codigo = r.codigo and i.estado = 'reprobado'
join seccion s       on s.id = i.seccion_id and s.curso_id = c.id
join tmp_periodo tp  on tp.codigo = i.periodo
join tmp_periodo tsig on tsig.idx = tp.idx + 1
join matricula m     on m.estudiante_codigo = r.codigo and m.periodo = tsig.codigo
join seccion s2      on s2.curso_id = c.id and s2.periodo = tsig.codigo and s2.grupo = 'A';

-- ---------------------------------------------------------------------
-- Cursos de competencias digitales (los pilares se cursan en cualquier orden)
-- ---------------------------------------------------------------------
insert into inscripcion (matricula_id, estudiante_codigo, periodo, seccion_id, estado, nota_final)
select m.id, v.codigo, v.periodo, s.id, v.estado, v.nota
from (values
    -- Usuario de prueba: Básicas y Analítica aprobadas; le falta Tecnologías
    ('U00900100', 'CCD-INT', '2024-2', 'aprobado',  4.5),
    ('U00900100', 'CCD-MAR', '2025-2', 'aprobado',  4.2),
    -- Primer semestre: cursando Interacción Digital
    ('U00900101', 'CCD-INT', '2026-2', 'inscrito',  null),
    -- Tercer semestre: solo Básicas
    ('U00900103', 'CCD-INT', '2026-1', 'aprobado',  4.0),
    -- Cuarto semestre: Básicas y Analítica; cursando IA Generativa
    ('U00900104', 'CCD-INT', '2025-2', 'aprobado',  4.3),
    ('U00900104', 'CCD-ANA', '2026-1', 'aprobado',  4.6),
    ('U00900104', 'CCD-IAG', '2026-2', 'inscrito',  null),
    -- Quinto semestre: insignia completa
    ('U00900105', 'CCD-INT', '2025-1', 'aprobado',  4.1),
    ('U00900105', 'CCD-CON', '2025-2', 'aprobado',  4.4),
    ('U00900105', 'CCD-BIE', '2026-1', 'aprobado',  4.7),
    -- Quinto semestre: reprobó Interacción Digital y la aprobó después
    ('U00900106', 'CCD-INT', '2025-1', 'reprobado', 2.5),
    ('U00900106', 'CCD-INT', '2025-2', 'aprobado',  3.8),
    -- Sexto semestre: insignia completa
    ('U00900107', 'CCD-INT', '2024-2', 'aprobado',  4.0),
    ('U00900107', 'CCD-ANA', '2025-1', 'aprobado',  4.2),
    ('U00900107', 'CCD-IAG', '2026-1', 'aprobado',  4.8),
    -- Séptimo semestre: solo Básicas
    ('U00900108', 'CCD-INT', '2024-1', 'aprobado',  3.9),
    -- Séptimo semestre: insignia completa empezando por los pilares avanzados
    ('U00900109', 'CCD-MAR', '2024-1', 'aprobado',  4.0),
    ('U00900109', 'CCD-LEG', '2024-2', 'aprobado',  4.1),
    ('U00900109', 'CCD-INT', '2025-1', 'aprobado',  4.4),
    -- Octavo semestre: insignia completa
    ('U00900110', 'CCD-INT', '2023-2', 'aprobado',  4.2),
    ('U00900110', 'CCD-CON', '2024-1', 'aprobado',  3.7),
    ('U00900110', 'CCD-LEG', '2025-2', 'aprobado',  4.0)
    -- U00900102 y U00900111 no han tomado cursos de competencias digitales
) as v (codigo, curso_codigo, periodo, estado, nota)
join curso c     on c.codigo = v.curso_codigo
join seccion s   on s.curso_id = c.id and s.periodo = v.periodo and s.grupo = 'A'
join matricula m on m.estudiante_codigo = v.codigo and m.periodo = v.periodo;

-- Estadísticas iniciales
refresh materialized view mv_estadisticas_cursos;

commit;
