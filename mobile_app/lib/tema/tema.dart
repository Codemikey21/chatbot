import 'package:flutter/material.dart';

import 'colores.dart';

/// Tipografía de la app. Es la misma del manual de marca de la universidad y
/// va empaquetada en assets/fuentes (no se descarga en tiempo de ejecución).
const fuenteApp = 'Poppins';

ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Colores.morado,
    primary: Colores.morado,
    secondary: Colores.naranja,
    surface: Colors.white,
  );

  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: ancho),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fuenteApp,
    colorScheme: esquema,
    scaffoldBackgroundColor: Colores.fondo,
    textTheme: Typography.blackMountainView.apply(
      fontFamily: fuenteApp,
      bodyColor: Colores.texto,
      displayColor: Colores.texto,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: borde(Colores.borde, 1.5),
      enabledBorder: borde(Colores.borde, 1.5),
      focusedBorder: borde(Colores.moradoVivo, 2),
      errorBorder: borde(Colores.rojo, 1.5),
      focusedErrorBorder: borde(Colores.rojo, 2),
      prefixIconColor: WidgetStateColor.resolveWith(
        (estados) => estados.contains(WidgetState.focused) ? Colores.moradoMedio : Colores.textoSuave,
      ),
      suffixIconColor: Colores.textoSuave,
      hintStyle: const TextStyle(fontFamily: fuenteApp, color: Colores.textoSuave),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colores.morado,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: fuenteApp, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colores.morado,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontFamily: fuenteApp, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Colores.morado,
      side: const BorderSide(color: Colores.borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(fontFamily: fuenteApp, fontWeight: FontWeight.w600, color: Colores.texto),
      secondaryLabelStyle: const TextStyle(fontFamily: fuenteApp, fontWeight: FontWeight.w600, color: Colors.white),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colores.lavanda,
      elevation: 0,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontFamily: fuenteApp,
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: estados.contains(WidgetState.selected) ? Colores.morado : Colores.textoSuave,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected) ? Colores.morado : Colores.textoSuave,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colores.texto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: const DividerThemeData(color: Colores.borde, thickness: 1, space: 1),
  );
}
