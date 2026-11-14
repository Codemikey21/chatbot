import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/servicios.dart';
import '../tema/colores.dart';
import '../utilidades/navegacion.dart';
import '../widgets/emblema.dart';
import 'bienvenida.dart';
import 'principal.dart';

/// Pantalla inicial: muestra el emblema animado mientras recupera la sesión
/// guardada y luego abre la pantalla principal o la de bienvenida.
class PantallaArranque extends StatefulWidget {
  const PantallaArranque({super.key});

  @override
  State<PantallaArranque> createState() => _PantallaArranqueState();
}

class _PantallaArranqueState extends State<PantallaArranque> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    final resultados = await Future.wait([
      sesion.restaurar(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    if (!mounted) return;
    final activa = resultados.first as bool;
    Navigator.of(context).pushReplacement(
      ruta(activa ? const PantallaPrincipal() : const PantallaBienvenida()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Colores.degradadoMorado),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Emblema(tamano: 100, claro: true)
                  .animate()
                  .scale(begin: const Offset(0.4, 0.4), duration: 700.ms, curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 1000.ms, color: Colors.white54),
              const SizedBox(height: 20),
              const Text('Asistente Académico',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.4),
            ],
          ),
        ),
      ),
    );
  }
}
