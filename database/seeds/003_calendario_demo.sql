-- =====================================================================
-- seeds/003_calendario_demo.sql
-- Carga inicial del calendario académico DEMO (mismos 15 eventos de
-- calendario_demo.csv y de la hoja de Google Sheets). Después, n8n
-- mantiene la tabla sincronizada con la hoja.
-- =====================================================================

begin;

insert into calendario_evento
    (id_evento, titulo, tipo_evento, fecha_inicio, fecha_fin, periodo, dirigido_a, descripcion)
values
    ('EV-001', 'Inicio de cursos de competencias digitales 2026-2', 'inicio_curso', '2026-08-10', '2026-08-10', '2026-2', 'Estudiantes inscritos en 2026-2', 'Primer día de clases de los cursos de competencias digitales del periodo 2026-2.'),
    ('EV-002', 'Cierre de cursos de competencias digitales 2026-2', 'fin_curso', '2026-11-20', '2026-11-20', '2026-2', 'Estudiantes inscritos en 2026-2', 'Último día de actividades y registro de notas finales de los cursos 2026-2.'),
    ('EV-003', 'Inscripciones a cursos de competencias digitales 2027-1', 'inscripcion', '2026-11-23', '2026-12-04', '2027-1', 'Estudiantes de pregrado', 'Periodo ordinario de inscripción a los cursos de competencias digitales.'),
    ('EV-004', 'Entrega de insignias de competencias digitales 2026-2', 'certificacion', '2026-11-27', '2026-11-27', '2026-2', 'Estudiantes que aprobaron cursos en 2026-2', 'Publicación de las insignias digitales de los estudiantes que aprobaron sus cursos.'),
    ('EV-005', 'Prueba diagnóstica de competencias digitales', 'prueba_diagnostica', '2026-12-07', '2026-12-09', '2027-1', 'Estudiantes inscritos en 2027-1', 'Prueba virtual que define el nivel inicial y los cursos recomendados para cada estudiante.'),
    ('EV-006', 'Publicación de resultados de la prueba diagnóstica', 'resultados', '2026-12-11', '2026-12-11', '2027-1', 'Estudiantes que presentaron la prueba', 'Consulta de resultados y de la ruta de cursos sugerida.'),
    ('EV-007', 'Inscripciones extemporáneas', 'inscripcion', '2026-12-14', '2026-12-16', '2027-1', 'Estudiantes de pregrado', 'Último plazo para inscribirse a los cursos de competencias digitales 2027-1.'),
    ('EV-008', 'Receso de fin de año', 'receso', '2026-12-19', '2027-01-11', '2027-1', 'Toda la comunidad', 'Periodo sin actividades académicas.'),
    ('EV-009', 'Matrícula académica 2027-1', 'matricula', '2027-01-12', '2027-01-22', '2027-1', 'Estudiantes de pregrado', 'Periodo de matrícula de asignaturas del semestre 2027-1.'),
    ('EV-010', 'Inicio de clases 2027-1', 'inicio_clases', '2027-01-25', '2027-01-25', '2027-1', 'Estudiantes de pregrado', 'Inicio del semestre académico 2027-1.'),
    ('EV-011', 'Inicio de cursos de competencias digitales 2027-1', 'inicio_curso', '2027-02-01', '2027-02-01', '2027-1', 'Estudiantes inscritos en 2027-1', 'Primer día de clases de los cursos de competencias digitales 2027-1.'),
    ('EV-012', 'Fecha límite de retiro de cursos', 'retiro', '2027-02-26', '2027-02-26', '2027-1', 'Estudiantes inscritos en 2027-1', 'Último día para retirar un curso de competencias digitales sin afectar el historial.'),
    ('EV-013', 'Evaluación final de cursos de competencias digitales', 'evaluacion', '2027-04-19', '2027-04-23', '2027-1', 'Estudiantes inscritos en 2027-1', 'Semana de evaluaciones finales de los cursos.'),
    ('EV-014', 'Cierre de cursos de competencias digitales 2027-1', 'fin_curso', '2027-04-30', '2027-04-30', '2027-1', 'Estudiantes inscritos en 2027-1', 'Último día de actividades y registro de notas finales.'),
    ('EV-015', 'Entrega de insignias de competencias digitales 2027-1', 'certificacion', '2027-05-07', '2027-05-07', '2027-1', 'Estudiantes que aprobaron cursos en 2027-1', 'Publicación de las insignias digitales del periodo 2027-1.');

commit;
