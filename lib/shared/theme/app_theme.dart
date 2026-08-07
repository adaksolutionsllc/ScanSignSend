import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF1A73E8);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );

  // Status colours
  static const statusDraft = Color(0xFFFFB300);
  static const statusPressed = Color(0xFF2E7D32);
  static const statusTemplate = Color(0xFF1565C0);
  static const statusFillable = Color(0xFF00897B); // teal — live fillable form
}
