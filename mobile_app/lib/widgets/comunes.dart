import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../datos/api.dart';
import '../tema/colores.dart';

/// Tarjeta blanca con bordes redondeados y sombra suave.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Colores.sombraSuave,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Píldora que recuerda que los datos son demostrativos.
class EtiquetaDemo extends StatelessWidget {
  const EtiquetaDemo({super.key, this.texto = 'Proyecto académico · datos demostrativos', this.clara = false});

  final String texto;
  final bool clara;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: clara ? Colors.white.withValues(alpha: 0.15) : Colores.amarilloClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 14, color: clara ? Colors.white : Colores.amarillo),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: clara ? Colors.white : Colores.amarillo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado morado con la curva naranja de los mockups.
class EncabezadoCurvo extends StatelessWidget {
  const EncabezadoCurvo({super.key, required this.child, this.altoExtra = 0});

  final Widget child;
  final double altoExtra;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        decoration: const BoxDecoration(gradient: Colores.degradadoMorado),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Colores.degradadoNaranja,
                  boxShadow: [BoxShadow(color: Colores.naranja.withValues(alpha: 0.4), blurRadius: 30)],
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -60,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + altoExtra),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior de las pantallas secundarias (morada con curva).
class BarraPantalla extends StatelessWidget {
  const BarraPantalla({super.key, required this.titulo, this.subtitulo, this.acciones = const []});

  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.of(context).canPop();
    return EncabezadoCurvo(
      child: Row(
        children: [
          if (puedeVolver)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                if (subtitulo != null)
                  Text(subtitulo!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
          ...acciones,
        ],
      ),
    );
  }
}

/// Mensaje de error con botón para reintentar.
class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: Colores.rojoClaro, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, color: Colores.rojo, size: 32),
            ),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colores.textoSuave, height: 1.4)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

/// Estado vacío con ícono y mensaje.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icono, size: 48, color: Colores.moradoClaro.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colores.textoSuave)),
        ],
      ),
    );
  }
}

/// Bloques grises con brillo mientras cargan los datos.
class Esqueleto extends StatelessWidget {
  const Esqueleto({super.key, this.bloques = 4, this.alto = 76});

  final int bloques;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        bloques,
        (i) => Container(
          height: alto,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        )
            .animate(onPlay: (control) => control.repeat())
            .shimmer(duration: 1200.ms, color: Colores.lavanda),
      ),
    );
  }
}

/// Carga datos de la API y muestra esqueleto, error con reintento o contenido.
class VistaAsincrona<T> extends StatefulWidget {
  const VistaAsincrona({super.key, required this.cargar, required this.construir, this.cargando});

  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos, Future<void> Function() recargar) construir;
  final Widget? cargando;

  @override
  State<VistaAsincrona<T>> createState() => _VistaAsincronaState<T>();
}

class _VistaAsincronaState<T> extends State<VistaAsincrona<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.cargar();
  }

  Future<void> _recargar() async {
    final nuevo = widget.cargar();
    setState(() => _futuro = nuevo);
    try {
      await nuevo;
    } catch (_) {
      // El error se muestra en la vista
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, estado) {
        if (estado.connectionState != ConnectionState.done) {
          return widget.cargando ??
              const Padding(padding: EdgeInsets.all(20), child: Esqueleto());
        }
        if (estado.hasError) {
          final error = estado.error;
          return EstadoError(
            mensaje: error is ApiError ? error.mensaje : 'No se pudo cargar la información.',
            alReintentar: _recargar,
          );
        }
        return widget.construir(context, estado.data as T, _recargar);
      },
    );
  }
}

/// Ícono dentro de un círculo de color suave.
class IconoCirculo extends StatelessWidget {
  const IconoCirculo({super.key, required this.icono, this.color = Colores.morado, this.fondo, this.tamano = 44});

  final IconData icono;
  final Color color;
  final Color? fondo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: fondo ?? color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Icon(icono, color: color, size: tamano * 0.52),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
