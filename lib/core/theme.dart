import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF00897B);
  static const Color primaryDark = Color(0xFF005B4F);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color success = Color(0xFF43A047);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBg = Colors.white;

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        scaffoldBackgroundColor: background,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
        ),
        cardTheme: const CardThemeData(
          color: cardBg,
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
}
