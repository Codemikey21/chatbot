/// Formato de fechas en español sin depender de paquetes de localización.
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const diasSemanaCortos = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

DateTime? leerFecha(Object? valor) {
  if (valor is! String || valor.isEmpty) return null;
  final fecha = DateTime.tryParse(valor);
  if (fecha == null) return null;
  // Las fechas sin hora (AAAA-MM-DD) se dejan tal cual; las demás se pasan a hora local
  return valor.length <= 10 ? fecha : fecha.toLocal();
}

String nombreMes(int mes) => _meses[mes - 1];

String mesAnio(DateTime fecha) {
  final mes = nombreMes(fecha.month);
  return '${mes[0].toUpperCase()}${mes.substring(1)} ${fecha.year}';
}

String fechaLarga(DateTime fecha) => '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

String fechaCorta(DateTime fecha) => '${fecha.day} ${_mesesCortos[fecha.month - 1]}';

String mesCorto(DateTime fecha) => _mesesCortos[fecha.month - 1];

String rangoFechas(DateTime inicio, DateTime fin) {
  if (inicio.year == fin.year && inicio.month == fin.month && inicio.day == fin.day) {
    return fechaLarga(inicio);
  }
  if (inicio.year == fin.year && inicio.month == fin.month) {
    return 'Del ${inicio.day} al ${fin.day} de ${_meses[fin.month - 1]}';
  }
  return 'Del ${fechaCorta(inicio)} al ${fechaCorta(fin)} de ${fin.year}';
}

String hora(DateTime fecha) {
  final h = fecha.hour.toString().padLeft(2, '0');
  final m = fecha.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "hoy", "ayer", "hace 3 días" o la fecha corta.
String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final dias = DateTime(hoy.year, hoy.month, hoy.day)
      .difference(DateTime(fecha.year, fecha.month, fecha.day))
      .inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';
  return fechaCorta(fecha);
}

/// "Hoy", "Mañana", "En 9 días" o "Hace 3 días" a partir de los días que faltan.
String cuandoEmpieza(int dias) {
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Mañana';
  if (dias > 1) return 'En $dias días';
  if (dias == -1) return 'Ayer';
  return 'Hace ${-dias} días';
}
