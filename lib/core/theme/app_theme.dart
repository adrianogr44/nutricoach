import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System — NutriCoach Premium Dark (2026 vibecoded)
/// Risco estético: números como marca (Space Grotesk 800 tabular, -1.4 tracking) + timeline vertical orgânica.
/// Minimal, elegante, fluido. Inspirado em Linear/Raycast/Vercel com toque health — mas com voz própria.
class AppTheme {
  AppTheme._();

  // ── Background — preto levemente azulado/esverdeado, não #000 puro ──
  static const Color background = Color(0xFF070A0F);
  static const Color backgroundSubtle = Color(0xFF0A0F14);
  static const Color backgroundElevated = Color(0xFF0F141B);

  // Surfaces — tons discretamente mais claros, com profundidade sutil
  static const Color surface = Color(0xFF121821);
  static const Color surfaceLight = Color(0xFF1A2330);
  static const Color surfaceHover = Color(0xFF1E2A3A);
  static const Color surfacePressed = Color(0xFF243247);

  // Borders — extremamente sutis, usa-se contraste de surface antes de borda
  static const Color border = Color(0xFF1E2A38);
  static const Color borderSubtle = Color(0x141E2A38); // 8% — fallback será rgba
  static const Color borderStrong = Color(0xFF243247);
  static const Color divider = Color(0x0F1E2A38);

  // Text — branco suave, não branco puro em tudo
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF8DA0B8);
  static const Color textMuted = Color(0xFF5F7288);
  static const Color textFaint = Color(0xFF3D4E62);
  static const Color textOnPrimary = Color(0xFF06251A);

  // Accent — verde só para progresso/ações positivas
  static const Color primary = Color(0xFF00E6A0);
  static const Color primarySoft = Color(0xFF00B87A);
  static const Color primaryMuted = Color(0xFF0A2E22);
  static const Color primarySubtle = Color(0x1412E6A0);

  // Semantic — uso moderado
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentSoft = Color(0xFF1E3A5F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFF2A1F0A);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFF2A0F0F);
  static const Color success = Color(0xFF00E6A0);
  static const Color successSoft = Color(0xFF0A2E22);

  // Macros — cores discretas, predominantemente neutro
  static const Color macroProtein = Color(0xFFA78BFA); // roxo suave
  static const Color macroCarbs = Color(0xFFFBBF24); // âmbar
  static const Color macroFat = Color(0xFF60A5FA); // azul
  static const Color macroWater = Color(0xFF22D3EE); // ciano

  // Radius — escala coerente
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  // Spacing
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Shadows — suaves, ambient
  static List<BoxShadow> get shadowSoft => [
        BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 20, offset: const Offset(0, 8)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1)),
      ];
  static List<BoxShadow> get shadowSubtle => [
        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
      ];

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
        onPrimary: textOnPrimary,
        onSurface: textPrimary,
        outline: border,
      ),
      textTheme: inter.copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(fontSize: 52, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.6, height: 0.9, fontFeatures: const [FontFeature.tabularFigures()]),
        displayMedium: GoogleFonts.spaceGrotesk(fontSize: 34, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.0, height: 1.0, fontFeatures: const [FontFeature.tabularFigures()]),
        headlineLarge: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.6),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.4),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
        titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: textPrimary, height: 1.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textMuted, height: 1.4),
        labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 0.1),
        labelSmall: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 0.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg), side: BorderSide(color: border, width: 0.8)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 0.8, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: border, width: 0.8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: border, width: 0.8)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: primary, width: 1.4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: primary.withValues(alpha: 0.14),
        side: const BorderSide(color: border, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.1),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 0.8),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        titleTextStyle: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        subtitleTextStyle: const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : textMuted, size: 22)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: s.contains(WidgetState.selected) ? primary : textMuted)),
        height: 64,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary, linearTrackColor: surfaceLight),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.30) : surfaceLight),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerColor: border,
    );
  }

  /// Container central — max-width 1180, para desktop não esticar
  static Widget centeredContainer({required Widget child, double maxWidth = 1180}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Background sutil com profundidade (não blocos #000/#111)
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [backgroundSubtle, background],
        ),
      );
}
