import 'package:flutter/material.dart';

/// Cores do app (claro e escuro), no estilo do mockup.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg, surface, surface2, surface3, text, text2, text3, line, ink, inkText, accent, star, danger, green, wood1, wood2;
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.text2,
    required this.text3,
    required this.line,
    required this.ink,
    required this.inkText,
    required this.accent,
    required this.star,
    required this.danger,
    required this.green,
    required this.wood1,
    required this.wood2,
  });

  static const light = Palette(
    bg: Color(0xFFF4F3F6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE9E8ED),
    surface3: Color(0xFFDDDCE2),
    text: Color(0xFF141217),
    text2: Color(0xFF5D5A64),
    text3: Color(0xFF8F8C96),
    line: Color(0x17141217),
    ink: Color(0xFF1A181D),
    inkText: Color(0xFFF6F5F8),
    accent: Color(0xFF2F6FE0),
    star: Color(0xFFF2A516),
    danger: Color(0xFFD23F3F),
    green: Color(0xFF2E9E62),
    wood1: Color(0xFFD7C3A5),
    wood2: Color(0xFFB89A74),
  );

  static const dark = Palette(
    bg: Color(0xFF121014),
    surface: Color(0xFF1D1B20),
    surface2: Color(0xFF26232A),
    surface3: Color(0xFF322F37),
    text: Color(0xFFF2F0F5),
    text2: Color(0xFFB4B0BB),
    text3: Color(0xFF7E7A86),
    line: Color(0x14FFFFFF),
    ink: Color(0xFFF2F0F5),
    inkText: Color(0xFF141217),
    accent: Color(0xFF6AA1FF),
    star: Color(0xFFF2A516),
    danger: Color(0xFFE5574F),
    green: Color(0xFF4CC285),
    wood1: Color(0xFF4A3B2C),
    wood2: Color(0xFF2F251B),
  );

  /// Cartão de estatísticas: escuro no tema claro, superfície no escuro.
  Color get statBg => this == dark ? surface2 : ink;
  Color get statText => this == dark ? text : inkText;

  static const chart = [Color(0xFF4C8FE8), Color(0xFF9AA8BF), Color(0xFFEC6A54), Color(0xFFF2B25C), Color(0xFF6CC2A1), Color(0xFFB28BE0)];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < .5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b, surface: p.bg, primary: p.ink, onPrimary: p.inkText),
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: p.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bg, surfaceTintColor: Colors.transparent, showDragHandle: true, dragHandleColor: p.surface3),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: p.inkText),
      actionTextColor: p == Palette.dark ? const Color(0xFF2F6FE0) : const Color(0xFF8FB6FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface2,
      hintStyle: TextStyle(color: p.text3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ink,
        foregroundColor: p.inkText,
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.text2, shape: const StadiumBorder())),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    datePickerTheme: DatePickerThemeData(backgroundColor: p.bg, surfaceTintColor: Colors.transparent),
  );
}

const serif = TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.w600);
