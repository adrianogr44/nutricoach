import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System — NutriCoach IA · Dark Premium.
///
/// Identidade centralizada. Toda tela deve consumir estes tokens e os
/// componentes compartilhados em `widgets/app_components.dart` em vez de
/// definir cores/tamanhos isolados.
///
/// Paleta oficial:
/// - Preto carvão  #101014  → fundo principal
/// - Grafite       #202027  → cards, painéis e superfícies
/// - Branco        #FFFFFF  → títulos e leitura principal
/// - Verde cítrico #C5FF5A  → ações principais, progresso e seleção
/// - Cinza         #8A8793  → informações secundárias
class AppTheme {
  AppTheme._();

  // ── Fundos ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF101014);
  static const Color backgroundSubtle = Color(0xFF0B0B0E);
  static const Color backgroundElevated = Color(0xFF17171C);

  // ── Superfícies (grafite) ─────────────────────────────────────────────
  static const Color surface = Color(0xFF202027);
  static const Color surfaceLight = Color(0xFF282830);
  static const Color surfaceHover = Color(0xFF30303A);
  static const Color surfacePressed = Color(0xFF383844);
  static const Color surfaceSunken = Color(0xFF16161B);

  // ── Bordas e divisores ────────────────────────────────────────────────
  static const Color border = Color(0xFF30303A);
  static const Color borderSubtle = Color(0x14FFFFFF); // 8% branco
  static const Color borderStrong = Color(0xFF3C3C48);
  static const Color divider = Color(0x0FFFFFFF); // 6% branco

  // ── Texto ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8793);
  static const Color textMuted = Color(0xFF77747F);
  static const Color textFaint = Color(0xFF55525C);
  static const Color textOnPrimary = Color(0xFF101014);

  // ── Destaque (verde cítrico) ──────────────────────────────────────────
  static const Color primary = Color(0xFFC5FF5A);
  static const Color primarySoft = Color(0xFFA9E63F);
  static const Color primaryMuted = Color(0xFF232B14);
  static const Color primarySubtle = Color(0x1FC5FF5A); // 12%

  // ── Semânticas ────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF8FA8FF); // azul suave (informação)
  static const Color accentSoft = Color(0xFF23263A);
  static const Color warning = Color(0xFFFFC857);
  static const Color warningSoft = Color(0xFF2E2612);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color dangerSoft = Color(0xFF2E1414);
  static const Color success = Color(0xFF7BE0A8);
  static const Color successSoft = Color(0xFF12281D);

  // ── Macros (cores discretas, nunca dominantes) ────────────────────────
  static const Color macroProtein = Color(0xFFC0A6FF); // lilás
  static const Color macroCarbs = Color(0xFFFFC857); // âmbar
  static const Color macroFat = Color(0xFF7FB0FF); // azul
  static const Color macroWater = Color(0xFF6FD9EA); // ciano

  // ── Raios ─────────────────────────────────────────────────────────────
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusFull = 999;

  // ── Espaçamento (escala 4/8) ──────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double space2xl = 40;

  /// Altura mínima de área de toque (acessibilidade).
  static const double minTouch = 48;

  // ── Sombras ───────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowSubtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Decoração padrão de card grafite.
  static BoxDecoration cardDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: borderColor ?? border, width: 0.8),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: textOnPrimary,
        secondary: accent,
        onSecondary: textOnPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceLight,
        onSurfaceVariant: textSecondary,
        error: danger,
        onError: textOnPrimary,
        outline: border,
        outlineVariant: borderStrong,
        surfaceTint: Colors.transparent,
      ),
      textTheme: inter.copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 52,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -1.6,
          height: 0.95,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -1.0,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.7,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          color: textSecondary,
          height: 1.45,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 0.3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.8,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSunken,
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: primarySubtle,
        side: const BorderSide(color: border, width: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          disabledBackgroundColor: surfaceHover,
          disabledForegroundColor: textFaint,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          disabledForegroundColor: textFaint,
          side: const BorderSide(color: borderStrong, width: 0.8),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 22),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border, width: 0.8),
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border, width: 0.8),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 14),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(textOnPrimary),
        side: const BorderSide(color: borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHover,
          borderRadius: BorderRadius.circular(radiusXs),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundElevated,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundElevated.withValues(alpha: 0.98),
        elevation: 0,
        indicatorColor: primarySubtle,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? primary : textSecondary,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: s.contains(WidgetState.selected) ? primary : textSecondary,
          ),
        ),
        height: 66,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceLight,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.30)
              : surfaceLight,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerColor: divider,
    );
  }

  /// Container central — max-width 1180, para desktop não esticar.
  static Widget centeredContainer({required Widget child, double maxWidth = 1180}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Fundo com profundidade sutil (nunca preto puro chapado).
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [backgroundSubtle, background],
        ),
      );
}
