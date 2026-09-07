import 'package:flutter/material.dart';

class AppTheme {
  static const Color seed = Color(0xFF2D341A);

  /// Cabeceras.
  static const Color headerDark = Color(0xFF1A1D11);
  static const Color header = Color(0xFF2D341A);

  /// Fondos.
  static const Color background = Color(0xFFF2EBD3);
  static const Color cardBackground = Color(0xFFFFFBF0);
  static const Color chipBackground = Color(0xFFE7DABC);

  /// Botones.
  static const Color button = Color(0xFFC86B32);
  static const Color buttonDark = Color(0xFFA95526);

  /// Texto.
  static const Color ink = Color(0xFF1A1D11);
  static const Color inkSoft = Color(0xFF4A4A3A);

  static const Color ok = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);

  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: header,
      brightness: Brightness.light,
    );

    final scheme = baseScheme.copyWith(
      primary: header,
      onPrimary: Colors.white,
      primaryContainer: header,
      onPrimaryContainer: Colors.white,
      secondary: button,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF0D9BE),
      onSecondaryContainer: ink,
      tertiary: headerDark,
      onTertiary: Colors.white,
      tertiaryContainer: chipBackground,
      onTertiaryContainer: ink,
      surface: background,
      onSurface: ink,
      error: danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: ink,
            displayColor: ink,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: header,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: header,
        indicatorColor: button,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => const IconThemeData(color: Colors.white),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: button,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: button,
          foregroundColor: Colors.white,
          disabledBackgroundColor: button.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: button,
          foregroundColor: Colors.white,
          disabledBackgroundColor: button.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: header,
          side: const BorderSide(color: header),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: header,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: button,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: button,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? button
              : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? button.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.4),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? button
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: header),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? button
              : header,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBackground,
        selectedColor: header,
        labelStyle: const TextStyle(color: ink),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: header.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: header.withValues(alpha: 0.2),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: header,
        titleTextStyle: TextStyle(color: ink, fontSize: 16),
        subtitleTextStyle: TextStyle(color: inkSoft, fontSize: 13),
      ),
      iconTheme: const IconThemeData(color: header),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: inkSoft),
        hintStyle: TextStyle(color: inkSoft.withValues(alpha: 0.7)),
        prefixIconColor: header,
        suffixIconColor: header,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: header.withValues(alpha: 0.4)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: button, width: 1.5),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardBackground,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: ink, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBackground,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: headerDark,
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white,
      ),
    );
  }
}
