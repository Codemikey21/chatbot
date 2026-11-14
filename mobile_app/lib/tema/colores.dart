import 'package:flutter/material.dart';

/// Paleta de la app: morado institucional, naranja de acento y fondos claros.
class Colores {
  static const morado = Color(0xFF5B21B6);
  static const moradoOscuro = Color(0xFF3B0F80);
  static const moradoNoche = Color(0xFF2E0B6B);
  static const moradoMedio = Color(0xFF6D28D9);
  static const moradoVivo = Color(0xFF7C3AED);
  static const moradoClaro = Color(0xFF8B5CF6);
  static const lavanda = Color(0xFFF1EBFF);
  static const naranja = Color(0xFFF97316);
  static const naranjaClaro = Color(0xFFFFA94D);

  /// Naranja de los botones con texto blanco (más oscuro para que se lea bien).
  static const naranjaFuerte = Color(0xFFEA580C);
  static const fondo = Color(0xFFF7F5FC);
  static const texto = Color(0xFF1F1537);
  static const textoSuave = Color(0xFF6B6280);
  static const etiqueta = Color(0xFF3B2F63);
  static const borde = Color(0xFFE7E1F5);
  static const verde = Color(0xFF16A34A);
  static const verdeClaro = Color(0xFFDCFCE7);
  static const rojo = Color(0xFFDC2626);
  static const rojoClaro = Color(0xFFFEE2E2);
  static const azul = Color(0xFF2563EB);
  static const azulClaro = Color(0xFFDBEAFE);
  static const amarillo = Color(0xFFD97706);
  static const amarilloClaro = Color(0xFFFEF3C7);

  static const degradadoMorado = LinearGradient(
    colors: [Color(0xFF3B0F80), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const degradadoNaranja = LinearGradient(
    colors: [Color(0xFFFFA94D), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Degradado del botón principal (Ingresar).
  static const degradadoBoton = LinearGradient(
    colors: [moradoVivo, morado],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: const Color(0xFF3B0F80).withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}
