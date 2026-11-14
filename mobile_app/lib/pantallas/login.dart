import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/api.dart';
import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades/navegacion.dart';
import '../widgets/logo_unab.dart';
import 'principal.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  static const _codigoDemo = 'U00900100';
  static const _contrasenaDemo = 'Demo2026*';

  final _formulario = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _oculta = true;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (sesion.vencio) _error = 'Tu sesión venció. Inicia sesión de nuevo.';
  }

  @override
  void dispose() {
    _codigo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await sesion.iniciar(_codigo.text, _contrasena.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(ruta(const PantallaPrincipal()), (_) => false);
    } on ApiError catch (error) {
      setState(() => _error = error.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Llena el formulario con el estudiante de prueba de la base demostrativa.
  void _usarCuentaDePrueba() {
    _codigo.text = _codigoDemo;
    _contrasena.text = _contrasenaDemo;
    setState(() => _error = null);
  }

  void _olvideContrasena() {
    showModalBottomSheet<void>(
      context: context,
      builder: (contextoHoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                'Esta versión del asistente no restablece contraseñas. '
                'Para la demostración puedes entrar con la cuenta de prueba.',
                style: TextStyle(color: Colores.textoSuave, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(contextoHoja).pop();
                  _usarCuentaDePrueba();
                },
                child: const Text('Usar cuenta de prueba'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Positioned(
              left: -90,
              top: -90,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colores.lavanda),
              ).animate().fadeIn(duration: 700.ms),
            ),
            if (!tecladoAbierto)
              Positioned(
                right: 0,
                bottom: 0,
                child: const CustomPaint(size: Size(230, 200), painter: _EsquinaInferior())
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slide(begin: const Offset(0.3, 0.3), duration: 800.ms, curve: Curves.easeOutCubic),
              ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formulario,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: LogoUnab(ancho: 190)),
                            const SizedBox(height: 44),
                            Semantics(
                              header: true,
                              child: const Text(
                                'Inicia sesión',
                                style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Accede a tu asistente académico personalizado',
                              style: TextStyle(color: Colores.textoSuave, fontSize: 15, height: 1.5),
                            ),
                            const SizedBox(height: 30),
                            const _Etiqueta('Código estudiantil'),
                            const SizedBox(height: 8),
                            Semantics(
                              label: 'Código estudiantil',
                              child: TextFormField(
                                controller: _codigo,
                                textCapitalization: TextCapitalization.characters,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                style: const TextStyle(fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'U00XXXXXX',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                validator: (valor) => RegExp(r'^[Uu]00\d{6}$').hasMatch((valor ?? '').trim())
                                    ? null
                                    : 'El código tiene la forma U00 seguido de 6 números',
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _Etiqueta('Contraseña'),
                            const SizedBox(height: 8),
                            Semantics(
                              label: 'Contraseña',
                              child: TextFormField(
                                controller: _contrasena,
                                obscureText: _oculta,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _ingresar(),
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Tu contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    onPressed: () => setState(() => _oculta = !_oculta),
                                    icon: Icon(_oculta ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                  ),
                                ),
                                validator: (valor) => (valor ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _error == null
                                  ? const SizedBox(height: 22)
                                  : Container(
                                      margin: const EdgeInsets.only(top: 14, bottom: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colores.rojoClaro,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Colores.rojo),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(_error!, style: const TextStyle(color: Colores.rojo, height: 1.3)),
                                          ),
                                        ],
                                      ),
                                    ).animate(key: ValueKey(_error)).shake(hz: 4, duration: 400.ms),
                            ),
                            const SizedBox(height: 12),
                            _BotonIngresar(cargando: _cargando, onPressed: _cargando ? null : _ingresar),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: _cargando ? null : _olvideContrasena,
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            Center(
                              child: TextButton.icon(
                                onPressed: _cargando ? null : _usarCuentaDePrueba,
                                style: TextButton.styleFrom(foregroundColor: Colores.textoSuave),
                                icon: const Icon(Icons.person_pin_outlined, size: 20),
                                label: const Text('Usar cuenta de prueba'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user_outlined, size: 18, color: Colores.textoSuave),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Sesión protegida · tus datos solo los ves tú',
                                    style: TextStyle(color: Colores.textoSuave, fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ].animate(interval: 60.ms).fadeIn(duration: 400.ms).slideY(begin: 0.12, curve: Curves.easeOutCubic),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto pequeño sobre cada campo del formulario.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colores.etiqueta),
      ),
    );
  }
}

/// Botón morado con degradado y sombra.
class _BotonIngresar extends StatelessWidget {
  const _BotonIngresar({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: Colores.degradadoBoton,
        boxShadow: [
          BoxShadow(
            color: Colores.morado.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(58),
          textStyle: const TextStyle(fontFamily: fuenteApp, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        child: cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
              )
            : const Text('Ingresar'),
      ),
    );
  }
}

/// Esquina naranja de la parte inferior derecha (como en el mockup).
class _EsquinaInferior extends CustomPainter {
  const _EsquinaInferior();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 230;
    final sy = size.height / 200;
    final grande = Path()
      ..moveTo(230 * sx, 30 * sy)
      ..lineTo(230 * sx, 200 * sy)
      ..lineTo(30 * sx, 200 * sy)
      ..cubicTo(112 * sx, 182 * sy, 200 * sx, 124 * sy, 230 * sx, 30 * sy)
      ..close();
    final pequena = Path()
      ..moveTo(230 * sx, 104 * sy)
      ..lineTo(230 * sx, 200 * sy)
      ..lineTo(112 * sx, 200 * sy)
      ..cubicTo(168 * sx, 184 * sy, 214 * sx, 152 * sy, 230 * sx, 104 * sy)
      ..close();
    canvas.drawPath(grande, Paint()..color = Colores.naranja);
    canvas.drawPath(pequena, Paint()..color = Colores.naranjaClaro);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
