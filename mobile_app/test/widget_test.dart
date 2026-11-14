import 'package:chatbot_unab/datos/modelos.dart';
import 'package:chatbot_unab/utilidades/fechas.dart';
import 'package:chatbot_unab/widgets/anillo_progreso.dart';
import 'package:chatbot_unab/widgets/comunes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fechas en español', () {
    test('formatos largos y cortos', () {
      final fecha = DateTime(2026, 11, 23);
      expect(fechaLarga(fecha), '23 de noviembre de 2026');
      expect(fechaCorta(fecha), '23 nov');
      expect(mesAnio(fecha), 'Noviembre 2026');
    });

    test('rangos de fechas', () {
      expect(rangoFechas(DateTime(2026, 11, 23), DateTime(2026, 12, 4)), 'Del 23 nov al 4 dic de 2026');
      expect(rangoFechas(DateTime(2026, 12, 7), DateTime(2026, 12, 9)), 'Del 7 al 9 de diciembre');
      expect(rangoFechas(DateTime(2026, 11, 27), DateTime(2026, 11, 27)), '27 de noviembre de 2026');
    });

    test('tiempo relativo', () {
      final hoy = DateTime(2026, 11, 14, 10);
      expect(haceCuanto(DateTime(2026, 11, 14, 8), ahora: hoy), 'hoy');
      expect(haceCuanto(DateTime(2026, 11, 13), ahora: hoy), 'ayer');
      expect(haceCuanto(DateTime(2026, 11, 10), ahora: hoy), 'hace 4 días');
      expect(cuandoEmpieza(9), 'En 9 días');
      expect(cuandoEmpieza(1), 'Mañana');
    });
  });

  group('Modelos de la API', () {
    test('resumen del estudiante', () {
      final resumen = Resumen.desdeJson({
        'estudiante': {
          'codigo': 'U00900100',
          'nombres': 'Laura Valentina',
          'apellidos': 'Rojas Méndez',
          'programa': 'Ingeniería de Sistemas',
          'semestre_actual': 6,
        },
        'insignia': {
          'pilares_aprobados': 2,
          'pilares_totales': 3,
          'insignia_obtenida': false,
          'pilares': [
            {'codigo': 'BASICAS', 'nombre': 'Básicas', 'aprobado': true, 'curso_aprobado': 'Interacción Digital', 'en_curso': false},
            {'codigo': 'TECNOLOGIAS', 'nombre': 'Tecnologías', 'aprobado': false, 'curso_aprobado': null, 'en_curso': false},
          ],
        },
        'plan_de_estudios': {'creditos_totales': 134, 'creditos_aprobados': 81, 'porcentaje_avance': 60.4},
        'proyeccion': {'semestres_estimados': 3, 'creditos_pendientes': 53, 'max_creditos_semestre': 20},
        'aviso': 'DEMO',
      });
      expect(resumen.estudiante.primerNombre, 'Laura');
      expect(resumen.estudiante.iniciales, 'LR');
      expect(resumen.pilares.first.cursoAprobado, 'Interacción Digital');
      expect(resumen.pilares.last.cursoAprobado, isNull);
      expect(resumen.porcentajeAvance, 60.4);
      expect(resumen.semestresEstimados, 3);
    });

    test('respuesta del chat con fuentes', () {
      final respuesta = RespuestaChat.desdeJson({
        'sesion_id': 'abc',
        'respuesta': '**Hola**',
        'intencion': 'documental',
        'intenciones': ['documental'],
        'fuentes': [
          {'tipo': 'documento', 'titulo': 'Reglamento estudiantil', 'pagina': 12, 'origen': 'publico'},
          {'tipo': 'historial', 'titulo': 'Historial', 'origen': 'demostrativo'},
        ],
        'herramientas': ['buscar_documentos'],
        'bloqueado': false,
      });
      expect(respuesta.fuentes, hasLength(2));
      expect(respuesta.fuentes.first.pagina, 12);
      expect(respuesta.fuentes.last.demostrativa, isTrue);
    });

    test('evento que dura varios días', () {
      final evento = Evento.desdeJson({
        'id_evento': 'EV-003',
        'titulo': 'Inscripciones',
        'tipo_evento': 'inscripcion',
        'fecha_inicio': '2026-11-23',
        'fecha_fin': '2026-12-04',
        'estado': 'proximo',
        'dias_para_inicio': 9,
      });
      expect(evento.ocurreEl(DateTime(2026, 11, 30)), isTrue);
      expect(evento.ocurreEl(DateTime(2026, 12, 5)), isFalse);
    });

    test('recomendación con razones', () {
      final r = Recomendacion.desdeJson({
        'pilar': 'Tecnologías transformativas',
        'curso_codigo': 'CCD-IAG',
        'curso_nombre': 'IA Generativa',
        'posicion': 1,
        'puntaje': 9,
        'razones': [
          {'razon': 'Se relaciona con Ciencia de Datos e IA'},
        ],
        'nrc_disponibles': [91646],
      });
      expect(r.razones.single, contains('Ciencia de Datos'));
      expect(r.nrcDisponibles, [91646]);
    });
  });

  group('Componentes', () {
    testWidgets('el anillo muestra el porcentaje de avance', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AnilloProgreso(porcentaje: 60.4))));
      await tester.pumpAndSettle();
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('el estado de error permite reintentar', (tester) async {
      var reintentos = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EstadoError(mensaje: 'Sin conexión', alReintentar: () => reintentos++)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });
  });
}
