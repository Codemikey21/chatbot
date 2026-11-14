-- =====================================================================
-- seeds/001_catalogo.sql
-- Catálogo académico: programa, pilares, cursos, pensum, requisitos,
-- reglas, afinidad, periodos y secciones (NRC).
--
-- Fuentes:
--   - Pensum de Ingeniería de Sistemas y ruta de competencias digitales:
--     información suministrada por el estudiante autor del proyecto.
--   - Códigos internos de curso, prerrequisitos, reglas, afinidades,
--     periodos, NRC, docentes y horarios: DATOS DEMO (no oficiales).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Programa
-- ---------------------------------------------------------------------
insert into programa (codigo, nombre, facultad, creditos_totales, semestres)
values ('ING-SIS', 'Ingeniería de Sistemas', 'Facultad de Ingeniería', 134, 8);

-- ---------------------------------------------------------------------
-- Pilares de competencias digitales
-- ---------------------------------------------------------------------
insert into pilar_competencia (codigo, nombre, descripcion, cursos_requeridos, orden_visual) values
('BASICAS',     'Competencias digitales básicas',
 'Pilar base de la ruta. Se aprueba con el curso Interacción Digital.', 1, 1),
('ANALITICA',   'Analítica y contenido digital',
 'Se aprueba con uno de sus tres cursos, a elección del estudiante.', 1, 2),
('TECNOLOGIAS', 'Tecnologías transformativas',
 'Se aprueba con uno de sus tres cursos, a elección del estudiante.', 1, 3);

-- ---------------------------------------------------------------------
-- Cursos de competencias digitales (descripciones DEMO)
-- ---------------------------------------------------------------------
insert into curso (codigo, nombre, tipo, creditos, pilar_id, descripcion)
select v.codigo, v.nombre, 'competencia_digital', 0, p.id, v.descripcion
from (values
    ('CCD-INT', 'Interacción Digital',              'BASICAS',
     'DEMO: uso de herramientas digitales para comunicarse, colaborar y gestionar información.'),
    ('CCD-ANA', 'Habilidades en Analítica Digital', 'ANALITICA',
     'DEMO: lectura, análisis y visualización de datos para la toma de decisiones.'),
    ('CCD-MAR', 'Marca Personal Digital',           'ANALITICA',
     'DEMO: construcción de una identidad profesional en línea y un portafolio digital.'),
    ('CCD-CON', 'Creación de Contenidos Digitales', 'ANALITICA',
     'DEMO: diseño y producción de contenidos multimedia para distintos canales.'),
    ('CCD-IAG', 'IA Generativa',                    'TECNOLOGIAS',
     'DEMO: uso responsable de herramientas de inteligencia artificial generativa.'),
    ('CCD-LEG', 'Marco Legal Digital',              'TECNOLOGIAS',
     'DEMO: protección de datos, propiedad intelectual y normativa del entorno digital.'),
    ('CCD-BIE', 'Cuidado y Bienestar Digital',      'TECNOLOGIAS',
     'DEMO: seguridad personal, privacidad y hábitos saludables en el entorno digital.')
) as v (codigo, nombre, pilar_codigo, descripcion)
join pilar_competencia p on p.codigo = v.pilar_codigo;

-- ---------------------------------------------------------------------
-- Asignaturas del pensum y plan de estudios
-- ---------------------------------------------------------------------
create temporary table tmp_pensum (
    codigo      varchar(20),
    nombre      varchar(150),
    creditos    smallint,
    semestre    smallint,
    componente  varchar(20),
    creditos_minimos_previos smallint
) on commit drop;

insert into tmp_pensum values
-- Primer semestre
('SIS-101', 'Electiva EHLE (Escucha, Habla y Lectura)',    4, 1, 'electiva',    0),
('SIS-102', 'Ideando la Ingeniería',                       2, 1, 'obligatorio', 0),
('SIS-103', 'Pensamiento Sistémico',                       2, 1, 'obligatorio', 0),
('SIS-104', 'Razonamiento Algorítmico',                    3, 1, 'obligatorio', 0),
('SIS-105', 'Tecnologías para el Entorno de Desarrollo',   2, 1, 'obligatorio', 0),
('SIS-106', 'Álgebra Lineal',                              3, 1, 'obligatorio', 0),
-- Segundo semestre
('SIS-201', 'Análisis de Algoritmos',                      3, 2, 'obligatorio', 0),
('SIS-202', 'Cálculo Diferencial',                         4, 2, 'obligatorio', 0),
('SIS-203', 'Dinámica de la Ingeniería',                   2, 2, 'obligatorio', 0),
('SIS-204', 'Electiva Autonomía en Contexto',              3, 2, 'electiva',    0),
('SIS-205', 'Matemáticas Computacionales',                 2, 2, 'obligatorio', 0),
('SIS-206', 'Programación Orientada a Objetos',            3, 2, 'obligatorio', 0),
-- Tercer semestre
('SIS-301', 'Cálculo Integral',                            3, 3, 'obligatorio', 0),
('SIS-302', 'Diseño y Desarrollo Multimedia',              3, 3, 'obligatorio', 0),
('SIS-303', 'Electiva Creatividad',                        3, 3, 'electiva',    0),
('SIS-304', 'Estructura de Datos',                         3, 3, 'obligatorio', 0),
('SIS-305', 'Ingeniería del Entorno',                      2, 3, 'obligatorio', 0),
('SIS-306', 'Laboratorio de Mecánica',                     0, 3, 'obligatorio', 0),
('SIS-307', 'Mecánica',                                    3, 3, 'obligatorio', 0),
-- Cuarto semestre
('SIS-401', 'Arquitectura de Software',                    3, 4, 'obligatorio', 0),
('SIS-402', 'Cálculo en Varias Variables',                 3, 4, 'obligatorio', 0),
('SIS-403', 'Desarrollo Frontend',                         2, 4, 'obligatorio', 0),
('SIS-404', 'Diseño de Bases de Datos',                    3, 4, 'obligatorio', 0),
('SIS-405', 'Electiva Ética, Ciudadanía y Cultura',        3, 4, 'electiva',    0),
('SIS-406', 'Electromagnetismo',                           3, 4, 'obligatorio', 0),
('SIS-407', 'Laboratorio de Electromagnetismo',            0, 4, 'obligatorio', 0),
-- Quinto semestre
('SIS-501', 'Cursos Menor - Ing. Sistemas I',              3, 5, 'menor',       0),
('SIS-502', 'Desarrollo Backend',                          3, 5, 'obligatorio', 0),
('SIS-503', 'Ecuaciones Diferenciales',                    3, 5, 'obligatorio', 0),
('SIS-504', 'Estadística Descriptiva',                     3, 5, 'obligatorio', 0),
('SIS-505', 'Gestión de Bases de Datos',                   2, 5, 'obligatorio', 0),
('SIS-506', 'Ingeniería de Software',                      3, 5, 'obligatorio', 0),
-- Sexto semestre
('SIS-601', 'Ciencia de Datos e Inteligencia Artificial',  3, 6, 'obligatorio', 0),
('SIS-602', 'Cursos Menor - Ing. Sistemas II',             3, 6, 'menor',       0),
('SIS-603', 'Desarrollo de Aplicaciones Móviles',          3, 6, 'obligatorio', 0),
('SIS-604', 'Estadística Inferencial y Muestreo',          3, 6, 'obligatorio', 0),
('SIS-605', 'Infraestructura Tecnológica',                 3, 6, 'obligatorio', 0),
('SIS-606', 'Ingeniería Basada en Evidencia',              2, 6, 'obligatorio', 0),
-- Séptimo semestre
('SIS-701', 'Calidad de Software',                         2, 7, 'obligatorio', 0),
('SIS-702', 'Ciberseguridad',                              3, 7, 'obligatorio', 0),
('SIS-703', 'Cursos Menor - Ing. Sistemas III',            3, 7, 'menor',       0),
('SIS-704', 'Dinámica de Sistemas',                        2, 7, 'obligatorio', 0),
('SIS-705', 'Servicios Cloud e IoT',                       3, 7, 'obligatorio', 0),
('SIS-706', 'Sistemas Inteligentes',                       3, 7, 'obligatorio', 0),
('SIS-707', 'Soluciones Innovadoras',                      2, 7, 'obligatorio', 0),
-- Octavo semestre
('SIS-801', 'Cursos Menor - Ing. Sistemas IV',             3, 8, 'menor',       0),
('SIS-802', 'Práctica Profesional',                       12, 8, 'practica',  110);

insert into curso (codigo, nombre, tipo, creditos)
select codigo, nombre, 'asignatura', creditos
from tmp_pensum;

insert into plan_estudio (programa_id, curso_id, semestre, componente, creditos_minimos_previos)
select pr.id, c.id, t.semestre, t.componente, t.creditos_minimos_previos
from tmp_pensum t
join curso c     on c.codigo = t.codigo
join programa pr on pr.codigo = 'ING-SIS';

-- ---------------------------------------------------------------------
-- Prerrequisitos y correquisitos (DEMO)
-- ---------------------------------------------------------------------
insert into requisito (curso_id, requiere_curso_id, tipo)
select c.id, r.id, v.tipo
from (values
    ('SIS-206', 'SIS-104', 'prerrequisito'),  -- POO ← Razonamiento Algorítmico
    ('SIS-201', 'SIS-104', 'prerrequisito'),  -- Análisis de Algoritmos ← Razonamiento Algorítmico
    ('SIS-304', 'SIS-206', 'prerrequisito'),  -- Estructura de Datos ← POO
    ('SIS-301', 'SIS-202', 'prerrequisito'),  -- Cálculo Integral ← Cálculo Diferencial
    ('SIS-402', 'SIS-301', 'prerrequisito'),  -- Varias Variables ← Cálculo Integral
    ('SIS-503', 'SIS-301', 'prerrequisito'),  -- Ecuaciones Diferenciales ← Cálculo Integral
    ('SIS-307', 'SIS-202', 'prerrequisito'),  -- Mecánica ← Cálculo Diferencial
    ('SIS-406', 'SIS-307', 'prerrequisito'),  -- Electromagnetismo ← Mecánica
    ('SIS-406', 'SIS-301', 'prerrequisito'),  -- Electromagnetismo ← Cálculo Integral
    ('SIS-306', 'SIS-307', 'correquisito'),   -- Lab. Mecánica ↔ Mecánica
    ('SIS-407', 'SIS-406', 'correquisito'),   -- Lab. Electromagnetismo ↔ Electromagnetismo
    ('SIS-203', 'SIS-102', 'prerrequisito'),  -- Dinámica de la Ingeniería ← Ideando la Ingeniería
    ('SIS-305', 'SIS-203', 'prerrequisito'),  -- Ingeniería del Entorno ← Dinámica de la Ingeniería
    ('SIS-704', 'SIS-103', 'prerrequisito'),  -- Dinámica de Sistemas ← Pensamiento Sistémico
    ('SIS-401', 'SIS-304', 'prerrequisito'),  -- Arquitectura de Software ← Estructura de Datos
    ('SIS-506', 'SIS-401', 'prerrequisito'),  -- Ingeniería de Software ← Arquitectura de Software
    ('SIS-701', 'SIS-506', 'prerrequisito'),  -- Calidad de Software ← Ingeniería de Software
    ('SIS-404', 'SIS-304', 'prerrequisito'),  -- Diseño de BD ← Estructura de Datos
    ('SIS-505', 'SIS-404', 'prerrequisito'),  -- Gestión de BD ← Diseño de BD
    ('SIS-403', 'SIS-206', 'prerrequisito'),  -- Frontend ← POO
    ('SIS-502', 'SIS-403', 'prerrequisito'),  -- Backend ← Frontend
    ('SIS-502', 'SIS-404', 'prerrequisito'),  -- Backend ← Diseño de BD
    ('SIS-603', 'SIS-502', 'prerrequisito'),  -- Móviles ← Backend
    ('SIS-604', 'SIS-504', 'prerrequisito'),  -- Estadística Inferencial ← Descriptiva
    ('SIS-601', 'SIS-504', 'prerrequisito'),  -- Ciencia de Datos e IA ← Estadística Descriptiva
    ('SIS-706', 'SIS-601', 'prerrequisito'),  -- Sistemas Inteligentes ← Ciencia de Datos e IA
    ('SIS-606', 'SIS-504', 'prerrequisito'),  -- Ingeniería Basada en Evidencia ← Estadística Descriptiva
    ('SIS-707', 'SIS-606', 'prerrequisito'),  -- Soluciones Innovadoras ← Ingeniería Basada en Evidencia
    ('SIS-705', 'SIS-605', 'prerrequisito'),  -- Cloud e IoT ← Infraestructura Tecnológica
    ('SIS-702', 'SIS-605', 'prerrequisito'),  -- Ciberseguridad ← Infraestructura Tecnológica
    ('SIS-602', 'SIS-501', 'prerrequisito'),  -- Menor II ← Menor I
    ('SIS-703', 'SIS-602', 'prerrequisito'),  -- Menor III ← Menor II
    ('SIS-801', 'SIS-703', 'prerrequisito')   -- Menor IV ← Menor III
) as v (curso, requiere, tipo)
join curso c on c.codigo = v.curso
join curso r on r.codigo = v.requiere;

-- ---------------------------------------------------------------------
-- Reglas académicas (DEMO)
-- ---------------------------------------------------------------------
insert into regla_academica (programa_id, clave, valor, descripcion)
select pr.id, v.clave, v.valor, v.descripcion
from (values
    ('max_creditos_semestre',  20.0, 'Máximo de créditos que un estudiante puede cursar en un semestre.'),
    ('nota_minima_aprobacion',  3.0, 'Nota mínima (escala 0 a 5) para aprobar un curso.')
) as v (clave, valor, descripcion)
join programa pr on pr.codigo = 'ING-SIS';

-- ---------------------------------------------------------------------
-- Afinidad cursos digitales ↔ asignaturas (DEMO, base de recomendaciones)
-- ---------------------------------------------------------------------
insert into curso_afinidad (curso_digital_id, asignatura_id, afinidad, razon)
select d.id, a.id, v.afinidad, v.razon
from (values
    ('CCD-ANA', 'SIS-504', 3, 'Refuerza el análisis y la visualización de datos que se trabajan en Estadística Descriptiva.'),
    ('CCD-ANA', 'SIS-604', 3, 'Complementa la interpretación de resultados de Estadística Inferencial y Muestreo.'),
    ('CCD-ANA', 'SIS-601', 3, 'Prepara la lectura y el análisis de datos que exige Ciencia de Datos e Inteligencia Artificial.'),
    ('CCD-ANA', 'SIS-505', 3, 'Aplica la consulta y el análisis de información almacenada en bases de datos.'),
    ('CCD-CON', 'SIS-302', 2, 'Amplía la producción multimedia vista en Diseño y Desarrollo Multimedia.'),
    ('CCD-CON', 'SIS-403', 2, 'Aporta criterios de diseño de contenido para interfaces web en Desarrollo Frontend.'),
    ('CCD-MAR', 'SIS-802', 2, 'Ayuda a preparar el perfil profesional y el portafolio antes de la Práctica Profesional.'),
    ('CCD-MAR', 'SIS-707', 2, 'Facilita comunicar y mostrar los proyectos desarrollados en Soluciones Innovadoras.'),
    ('CCD-IAG', 'SIS-601', 3, 'Profundiza en el uso de modelos de IA, tema central de Ciencia de Datos e Inteligencia Artificial.'),
    ('CCD-IAG', 'SIS-706', 3, 'Aporta experiencia práctica con IA generativa para Sistemas Inteligentes.'),
    ('CCD-LEG', 'SIS-702', 2, 'Complementa Ciberseguridad con la normativa de protección de datos.'),
    ('CCD-LEG', 'SIS-405', 2, 'Relaciona la ética y la ciudadanía con las leyes del entorno digital.'),
    ('CCD-BIE', 'SIS-702', 1, 'Refuerza hábitos de seguridad y privacidad personal relacionados con Ciberseguridad.')
) as v (curso_digital, asignatura, afinidad, razon)
join curso d on d.codigo = v.curso_digital
join curso a on a.codigo = v.asignatura;

-- ---------------------------------------------------------------------
-- Periodos académicos (fechas DEMO)
-- ---------------------------------------------------------------------
insert into periodo_academico (codigo, fecha_inicio, fecha_fin, es_actual) values
('2023-1', '2023-01-23', '2023-06-02', false),
('2023-2', '2023-07-24', '2023-12-01', false),
('2024-1', '2024-01-22', '2024-05-31', false),
('2024-2', '2024-07-22', '2024-11-29', false),
('2025-1', '2025-01-27', '2025-06-06', false),
('2025-2', '2025-07-28', '2025-12-05', false),
('2026-1', '2026-01-26', '2026-06-05', false),
('2026-2', '2026-07-27', '2026-12-04', true),
('2027-1', '2027-01-25', '2027-06-04', false),
('2027-2', '2027-07-26', '2027-12-03', false);

-- ---------------------------------------------------------------------
-- Secciones (NRC DEMO): un grupo por curso y periodo, de 2023-1 a 2027-1
-- El NRC se calcula para que sea único dentro de cada periodo.
-- ---------------------------------------------------------------------
insert into seccion (nrc, curso_id, periodo, grupo, docente, modalidad, horario, cupo, estado)
select
    10000 + ((pa.idx * 8999 + c.id * 131) % 89999)                                   as nrc,
    c.id,
    pa.codigo,
    'A',
    'Docente DEMO ' || lpad(((c.id * 7 + pa.idx) % 25 + 1)::text, 2, '0')            as docente,
    case when c.tipo = 'competencia_digital' then 'virtual' else 'presencial' end    as modalidad,
    case when c.tipo = 'competencia_digital'
         then 'Virtual, a ritmo propio (DEMO)'
         else (array['Lun y Mié 7:00-9:00', 'Mar y Jue 9:00-11:00', 'Lun y Mié 14:00-16:00',
                     'Mar y Jue 16:00-18:00', 'Vie 7:00-10:00'])[(c.id % 5) + 1] || ' (DEMO)'
    end                                                                              as horario,
    case when c.tipo = 'competencia_digital' then 40 else 30 end                     as cupo,
    case
        when pa.codigo < '2026-2' then 'finalizada'
        when pa.codigo = '2026-2' then 'en_curso'
        else 'abierta'
    end                                                                              as estado
from curso c
cross join (
    select codigo, row_number() over (order by codigo) as idx
    from periodo_academico
    where codigo <= '2027-1'
) pa;

commit;
