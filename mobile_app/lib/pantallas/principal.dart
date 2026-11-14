import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utilidades/navegacion.dart';
import 'chat.dart';
import 'cursos.dart';
import 'inicio.dart';
import 'mas.dart';
import 'progreso.dart';

/// Contenedor con la barra de navegación inferior.
class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  static const _pantallas = [
    PantallaInicio(),
    PantallaChat(),
    PantallaCursos(),
    PantallaProgreso(),
    PantallaMas(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ValueListenableBuilder<int>(
        valueListenable: pestanaActual,
        builder: (context, indice, _) => PopScope(
          canPop: indice == Pestanas.inicio,
          onPopInvokedWithResult: (salio, _) {
            if (!salio) pestanaActual.value = Pestanas.inicio;
          },
          child: Scaffold(
            body: IndexedStack(index: indice, children: _pantallas),
            bottomNavigationBar: NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: (i) => pestanaActual.value = i,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
                NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
                NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers_rounded), label: 'Cursos'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Progreso'),
                NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Más'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
