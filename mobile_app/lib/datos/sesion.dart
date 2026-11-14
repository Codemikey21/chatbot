import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'modelos.dart';

/// Estado de la sesión del estudiante. El token se guarda cifrado en el
/// almacenamiento seguro del dispositivo (Android Keystore).
class SesionApp extends ChangeNotifier {
  SesionApp(this.api) {
    api.alVencerSesion = _alVencer;
  }

  static const _claveToken = 'token_sesion';

  final ApiCliente api;
  final FlutterSecureStorage _almacen = const FlutterSecureStorage();

  Estudiante? estudiante;

  /// true cuando la sesión terminó por vencimiento (para avisar en el login).
  bool vencio = false;

  bool get activa => estudiante != null && api.token != null;

  /// Recupera la sesión guardada. Devuelve true si el token sigue vigente.
  Future<bool> restaurar() async {
    try {
      final token = await _almacen.read(key: _claveToken);
      if (token == null) return false;
      api.token = token;
      estudiante = await api.sesion();
      notifyListeners();
      return true;
    } on ApiError catch (error) {
      if (error.sesionVencida) await _borrar();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> iniciar(String codigo, String contrasena) async {
    final resultado = await api.login(codigo, contrasena);
    api.token = resultado.token;
    estudiante = resultado.estudiante;
    vencio = false;
    await _almacen.write(key: _claveToken, value: resultado.token);
    notifyListeners();
  }

  Future<void> cerrar() async {
    await _borrar();
    notifyListeners();
  }

  Future<void> _borrar() async {
    api.token = null;
    estudiante = null;
    try {
      await _almacen.delete(key: _claveToken);
    } catch (_) {
      // Si el almacenamiento falla, la sesión igual queda cerrada en memoria
    }
  }

  void _alVencer() {
    if (!activa) return;
    vencio = true;
    cerrar();
  }
}
