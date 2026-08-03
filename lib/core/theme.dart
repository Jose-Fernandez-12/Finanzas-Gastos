import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores y tema principal de la app (Gradient Design System — Finanzas)
class AppTheme {
  // ──────────────────────────────────────────────────────────────
  // ACENTO PRINCIPAL  (purpura #7C3AED — unico acento de la app)
  // ──────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF7C3AED); // Purpura principal
  static const Color primaryDark = Color(0xFF6D28D9); // Purpura profundo
  static const Color primaryMid  = Color(0xFF990FFA); // Purpura medio (gradiente)
  static const Color primaryLight= Color(0xFFA855F7); // Purpura claro (gradiente)

  /// Alias para compatibilidad con codigo existente que usaba `accent`
  static const Color accent      = primary;
  static const Color secondary   = Color(0xFF0D9488); // Teal (uso puntual)

  // ──────────────────────────────────────────────────────────────
  // COLORES SEMANTICOS FINANCIEROS
  // ──────────────────────────────────────────────────────────────
  static const Color colorIngresos    = Color(0xFF10B981); // Green
  static const Color colorGastos      = Color(0xFFEF4444); // Red
  static const Color colorDeudas      = Color(0xFFF59E0B); // Amber
  static const Color colorAhorros     = Color(0xFF3B82F6); // Blue
  static const Color colorMora        = Color(0xFFEF4444);
  static const Color colorAlDia       = Color(0xFF10B981);
  static const Color colorCancelado   = Color(0xFF6B7280);

  // Semaforo rapido
  static const Color success = Color(0xFF10B981);
  static const Color warn    = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFEF4444);

  // ──────────────────────────────────────────────────────────────
  // ESCALA DE RIESGO CREDITICIO
  // ──────────────────────────────────────────────────────────────
  static const Color riesgoBajo     = Color(0xFF10B981);
  static const Color riesgoModerado = Color(0xFFF59E0B);
  static const Color riesgoAlto     = Color(0xFFEF4444);
  static const Color riesgoCritico  = Color(0xFFDC2626);

  // ──────────────────────────────────────────────────────────────
  // FONDOS Y SUPERFICIES  (tinte lila suave)
  // ──────────────────────────────────────────────────────────────
  static const Color bgCanvas    = Color(0xFFF7F3FF); // Fondo general — lila suave
  static const Color bgCard      = Color(0xFFFFFFFF); // Superficie blanca
  static const Color bgCardWarm  = Color(0xFFEFE7FF); // Superficie lila calida
  static const Color bgCardLight = Color(0xFFEFE7FF); // Alias de bgCardWarm
  static const Color surfaceColor= Color(0xFFEFE7FF); // Inputs y hover

  // Alias de compatibilidad
  static const Color bgDark = bgCanvas;

  // ──────────────────────────────────────────────────────────────
  // BORDES
  // ──────────────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFDDD2F2); // Borde general
  static const Color borderSoft  = Color(0xFFEEE6FB); // Borde suave (cards)

  // ──────────────────────────────────────────────────────────────
  // TEXTO
  // ──────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF191225); // fg principal
  static const Color textSecondary = Color(0xFF443856); // fg secundario
  static const Color textMuted     = Color(0xFF746985); // texto muted

  // Color de marca especial
  static const Color brandWhatsapp = Color(0xFF25D366);

  // ──────────────────────────────────────────────────────────────
  // GRADIENTES
  // ──────────────────────────────────────────────────────────────

  /// Gradiente hero de la app (health card, hero cards)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C3AED),
      Color(0xFF990FFA),
      Color(0xFFA855F7),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradiente para tarjeta RappiCard (oscuro azul marino)
  static const LinearGradient cardRappiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
      Color(0xFF0F3460),
    ],
  );

  /// Gradiente para tarjeta NuBank (purpura)
  static const LinearGradient cardNuGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C3AED),
      Color(0xFF990FFA),
      Color(0xFFC084FC),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  // ──────────────────────────────────────────────────────────────
  // SOMBRAS
  // ──────────────────────────────────────────────────────────────

  /// Sombra del FAB central
  static List<BoxShadow> get fabShadow => [
    BoxShadow(
      color: primary.withAlpha(89), // ~35% opacidad
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ──────────────────────────────────────────────────────────────
  // TEMA MATERIAL
  // ──────────────────────────────────────────────────────────────

  /// Tema claro principal (Gradient Design System)
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSoft, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       bgCardWarm,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: borderSoft),
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
        backgroundColor: bgCard,
        indicatorColor: Color(0x197C3AED), // ~10% opacidad del primary
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
        color: borderSoft,
        thickness: 1,
      ),
    );
  }

  /// Compatibilidad: darkTheme apunta a lightTheme en esta version
  static ThemeData get darkTheme => lightTheme;

  // ──────────────────────────────────────────────────────────────
  // UTILIDADES
  // ──────────────────────────────────────────────────────────────

  /// Estilo tipografico JetBrains Mono para cifras y montos monetarios
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

  /// Gradiente para las tarjetas de credito basado en color hex
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

  /// Color segun nivel de riesgo
  static Color colorPorRiesgo(String nivel) {
    switch (nivel) {
      case 'MODERADO': return riesgoModerado;
      case 'ALTO':     return riesgoAlto;
      case 'CRITICO':  return riesgoCritico;
      default:         return riesgoBajo;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // RADIOS DE BORDE ESTANDAR
  // ──────────────────────────────────────────────────────────────
  static const double radiusSm  = 12.0;
  static const double radiusMd  = 20.0;
  static const double radiusLg  = 32.0;
  static const double radiusPill = 999.0;
}
