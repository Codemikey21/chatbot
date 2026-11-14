import 'package:flutter/material.dart';

import 'api.dart';
import 'sesion.dart';

/// Instancias compartidas por toda la app.
final api = ApiCliente();
final sesion = SesionApp(api);
final navegador = GlobalKey<NavigatorState>();
