import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/l10n.dart';

class AppTheme {
  AppTheme._();

  // ── Couleurs ───────────────────────────────────────────────────
  static const Color primary         = Color(0xFF0B8FAC);
  static const Color secondary       = Color(0xFF00C9B1);
  static const Color bgColor         = Color(0xFFF5F7FA);
  static const Color cardBg          = Colors.white;
  static const Color danger          = Color(0xFFE53935);
  static const Color warning         = Color(0xFFFF9A3C);
  static const Color success         = Color(0xFF16A34A);

  static const Color breakfastColor  = Color(0xFFFF9A3C);
  static const Color lunchColor      = Color(0xFF0B8FAC);
  static const Color dinnerColor     = Color(0xFF7C3AED);
  static const Color snackColor      = Color(0xFF16A34A);

  // ── Helpers glycémie ───────────────────────────────────────────
  /// Retourne la couleur indicateur selon la valeur Mg/dl
  static Color glucoseColor(double value) {
    if (value < 0.7)  return const Color(0xFFE53935); // rouge — hypo
    if (value <= 1.6) return const Color(0xFF16A34A); // vert  — normal
    if (value <= 1.9) return const Color(0xFFFF9A3C); // orange — élevé
    return const Color(0xFFE53935);                   // rouge  — hyper
  }

  /// Alias court utilisé dans add_reading_sheet
  static String glucose(double value) => glucoseLabel(value);

  /// Retourne le label textuel selon la valeur Mg/dl
  static String glucoseLabel(double value) {
    if (value < 0.7)  return 'Hypoglycémie'.tr;
    if (value <= 1.6) return 'Normale'.tr;
    if (value <= 1.9) return 'Légèrement élevée'.tr;
    return 'Hyperglycémie'.tr;
  }

  // ── Système typographique Poppins ─────────────────────────────
  //
  //  displayLarge   → 28 SemiBold  — grands titres (logo, onboarding)
  //  headlineMedium → 22 SemiBold  — titres de page / section
  //  headlineSmall  → 18 SemiBold  — sous-titres de card
  //  titleLarge     → 16 Medium    — headers de carte (meal zone)
  //  titleMedium    → 15 Medium    — labels importants
  //  titleSmall     → 13 Medium    — chips, badges, petits titres
  //  bodyLarge      → 15 Regular   — corps de texte principal
  //  bodyMedium     → 14 Regular   — corps secondaire
  //  bodySmall      → 12 Regular   — descriptions, hints
  //  labelLarge     → 14 SemiBold  — boutons
  //  labelMedium    → 12 Medium    — labels de champ
  //  labelSmall     → 11 Medium    — unités, annotations

  static TextTheme get _textTheme => GoogleFonts.poppinsTextTheme().copyWith(
    displayLarge: GoogleFonts.poppins(
        fontSize: 28, fontWeight: FontWeight.w600,
        color: const Color(0xFF1A2E3B), height: 1.2, letterSpacing: -0.5),

    headlineMedium: GoogleFonts.poppins(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: const Color(0xFF1A2E3B), height: 1.3),

    headlineSmall: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: const Color(0xFF1A2E3B), height: 1.35),

    titleLarge: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w500,
        color: const Color(0xFF1A2E3B), height: 1.4),

    titleMedium: GoogleFonts.poppins(
        fontSize: 15, fontWeight: FontWeight.w500,
        color: const Color(0xFF1A2E3B), height: 1.4),

    titleSmall: GoogleFonts.poppins(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: const Color(0xFF4A6572), height: 1.4),

    bodyLarge: GoogleFonts.poppins(
        fontSize: 15, fontWeight: FontWeight.w400,
        color: const Color(0xFF2D3E4E), height: 1.6),

    bodyMedium: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: const Color(0xFF4A6572), height: 1.6),

    bodySmall: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: const Color(0xFF7A95A3), height: 1.5),

    labelLarge: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: Colors.white, letterSpacing: 0.3),

    labelMedium: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: const Color(0xFF4A6572), letterSpacing: 0.2),

    labelSmall: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: const Color(0xFF7A95A3), letterSpacing: 0.3),
  );

  // ── Thème complet ──────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    primaryColor: primary,
    scaffoldBackgroundColor: bgColor,
    textTheme: _textTheme,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary:   primary,
      secondary: secondary,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        letterSpacing: 0.2,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F4F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: const Color(0xFF7A95A3)),
      hintStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: const Color(0xFFB0C4CE)),
      errorStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w400,
          color: danger),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),

    // BottomNav
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: const Color(0xFFB0C4CE),
      elevation: 14,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w400),
    ),

    // TabBar
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w400),
    ),

    // Chip
    chipTheme: ChipThemeData(
      labelStyle: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A2E3B),
      contentTextStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: const Color(0xFF1A2E3B)),
      contentTextStyle: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: const Color(0xFF4A6572)),
    ),
  );
}

// ── Helpers d'accès rapide aux styles Poppins ─────────────────────────────────
// Utilisation : AppFonts.title(color: Colors.white)
class AppFonts {
  AppFonts._();

  static TextStyle display({Color? color, double? size}) =>
      GoogleFonts.poppins(fontSize: size ?? 28, fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF1A2E3B));

  static TextStyle title({Color? color, double? size}) =>
      GoogleFonts.poppins(fontSize: size ?? 16, fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF1A2E3B));

  static TextStyle body({Color? color, double? size}) =>
      GoogleFonts.poppins(fontSize: size ?? 14, fontWeight: FontWeight.w400,
          color: color ?? const Color(0xFF4A6572));

  static TextStyle label({Color? color, double? size}) =>
      GoogleFonts.poppins(fontSize: size ?? 12, fontWeight: FontWeight.w500,
          color: color ?? const Color(0xFF7A95A3));

  static TextStyle bold({Color? color, double? size}) =>
      GoogleFonts.poppins(fontSize: size ?? 14, fontWeight: FontWeight.w700,
          color: color ?? const Color(0xFF1A2E3B));

  static TextStyle button({Color? color}) =>
      GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600,
          color: color ?? Colors.white, letterSpacing: 0.3);

  static TextStyle unit({Color? color}) =>
      GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
          color: color ?? AppTheme.primary, letterSpacing: 0.5);
}

// ── Extensions pour les nouveaux écrans ───────────────────────────────────────

extension AppThemeGlucose on AppTheme {
  static const double hypoThreshold = 0.7;
  static const double normalMax     = 1.6;
  static const double elevMax       = 1.9;
}

extension AppThemeHelpers on AppTheme {}

// Helpers statiques globaux pour les nouveaux screens
Color glucoseColorOf(double value) {
  if (value < 0.7) return const Color(0xFFE53935);
  if (value <= 1.6) return const Color(0xFF16A34A);
  if (value <= 1.9) return const Color(0xFFFF9A3C);
  return const Color(0xFFE53935);
}

String glucoseLabelOf(double value) {
  if (value < 0.7) return 'Hypoglycémie'.tr;
  if (value <= 1.6) return 'Normale'.tr;
  if (value <= 1.9) return 'Légèrement élevée'.tr;
  return 'Hyperglycémie'.tr;
}