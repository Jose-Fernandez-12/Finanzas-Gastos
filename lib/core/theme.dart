import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores y tema principal de la app (Light Vibrant Theme — Finanzas)
class AppTheme {
  // Colores primarios y acentos
  static const Color primary     = Color(0xFF6C63FF);  // Indigo / Violeta vibrante
  static const Color primaryDark = Color(0xFF4F46E5);  // Indigo profundo
  static const Color secondary   = Color(0xFF0D9488);  // Teal
  static const Color accent      = Color(0xFFE11D48);  // Rose

  // Colores semánticos financieros (Finanzas HTML)
  static const Color colorIngresos    = Color(0xFF10B981); // Green
  static const Color colorGastos      = Color(0xFFEF4444); // Red
  static const Color colorDeudas      = Color(0xFFF59E0B); // Amber
  static const Color colorAhorros     = Color(0xFF3B82F6); // Blue
  static const Color colorMora        = Color(0xFFEF4444);
  static const Color colorAlDia       = Color(0xFF10B981);
  static const Color colorCancelado   = Color(0xFF6B7280);

  // Escala de riesgo crediticio
  static const Color riesgoBajo     = Color(0xFF10B981);
  static const Color riesgoModerado = Color(0xFFF59E0B);
  static const Color riesgoAlto     = Color(0xFFEF4444);
  static const Color riesgoCritico  = Color(0xFFDC2626);

  // Fondos y superficies (Light Vibrant)
  static const Color bgCanvas    = Color(0xFFF9FAFB);  // Fondo general claro
  static const Color bgCard      = Color(0xFFFFFFFF);  // Superficie blanca
  static const Color bgCardLight = Color(0xFFF3F4F6);  // Superficie gris suave
  static const Color surfaceColor= Color(0xFFF3F4F6);  // Inputs y hover
  static const Color borderLight = Color(0xFFE5E7EB);  // Bordes limpios

  // Alias de compatibilidad (para transición suave de código existente)
  static const Color bgDark      = bgCanvas;

  // Texto (Light Theme)
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted     = Color(0xFF9CA3AF);

  // Color de marca especial
  static const Color brandWhatsapp = Color(0xFF25D366);

  /// Tema claro principal (Light Vibrant Theme)
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgCanvas,
      colorScheme: const ColorScheme.light(
        primary:   primary,
        secondary: secondary,
        surface:   bgCard,
        error:     colorGastos,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor:    textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgCanvas,
        elevation:       0,
        centerTitle:     false,
        iconTheme:       const IconThemeData(color: textPrimary),
        titleTextStyle:  GoogleFonts.inter(
          color:      textPrimary,
          fontSize:   20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color:        bgCard,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: primary, width: 2),
        ),
        labelStyle:   const TextStyle(color: textSecondary),
        hintStyle:    const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      bgCard,
        selectedItemColor:    primary,
        unselectedItemColor:  textMuted,
        type:                 BottomNavigationBarType.fixed,
        elevation:            0,
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
      ),
    );
  }

  /// Compatibilidad: darkTheme apunta a lightTheme en esta versión enfocada al diseño claro
  static ThemeData get darkTheme => lightTheme;

  /// Estilo tipográfico JetBrains Mono para cifras y montos monetarios
  static TextStyle monoStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      color:         color ?? textPrimary,
      fontSize:      fontSize ?? 16,
      fontWeight:    fontWeight ?? FontWeight.w600,
      letterSpacing: letterSpacing ?? -0.5,
    );
  }

  /// Gradiente para las tarjetas de crédito
  static LinearGradient cardGradient(String hex) {
    final color = _hexToColor(hex);
    return LinearGradient(
      begin: Alignment.topLeft,
      end:   Alignment.bottomRight,
      colors: [color, color.withAlpha(200)],
    );
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  /// Color según nivel de riesgo
  static Color colorPorRiesgo(String nivel) {
    switch (nivel) {
      case 'MODERADO': return riesgoModerado;
      case 'ALTO':     return riesgoAlto;
      case 'CRITICO':  return riesgoCritico;
      default:         return riesgoBajo;
    }
  }
}
