import 'package:flutter/material.dart';

class AppTheme {
  static const Color seed = Color(0xFFD71920);
  static const Color ok = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: const CardThemeData(
          elevation: 1.5,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );
}
