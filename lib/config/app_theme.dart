import 'package:flutter/material.dart';

// class AppTheme {
//   static final ThemeData lightTheme = ThemeData(
//     brightness: Brightness.light,
//     primarySwatch: Colors.blue,
//     fontFamily: 'iransans',
//     scaffoldBackgroundColor: Colors.grey[300],
//     appBarTheme: AppBarTheme(
//       backgroundColor: Colors.amber[800],
//       titleTextStyle: const TextStyle(
//         color: Colors.white,
//         fontSize: 20,
//         fontWeight: FontWeight.bold,
//         fontFamily: 'iransans',
//       ),
//     ),
//   );

//   static final ThemeData darkTheme = ThemeData(
//     brightness: Brightness.dark,
//     primarySwatch: Colors.blueGrey,
//     fontFamily: 'iransans',
//     scaffoldBackgroundColor: Colors.grey[800],
//     appBarTheme: AppBarTheme(
//       backgroundColor: Colors.blueGrey[900],
//       titleTextStyle: const TextStyle(
//         color: Colors.white,
//         fontSize: 20,
//         fontWeight: FontWeight.bold,
//         fontFamily: 'iransans',
//       ),
//     ),
//   );
// }

class AppTheme {
  static const Color _seed = Color(0xFFFDC410);

  static const Color _brandBlack = Color(0xFF050505);
  static const Color _brandGold = Color(0xFFFDC410);
  static const Color _deepGold = Color(0xFFE2A501);
  static const Color _warmWhite = Color(0xFFF8F7F2);
  static const Color _darkSurface = Color(0xFF111111);
  static const Color _darkCard = Color(0xFF1A1A1A);
  static const Color _metalGray = Color(0xFF7D7D7C);
  static const Color _softSilver = Color(0xFFA9A9A8);

  static ThemeData _theme(Brightness brightness) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    final colorScheme = baseColorScheme.copyWith(
      primary: _brandGold,
      onPrimary: _brandBlack,
      secondary: isDark ? _softSilver : _brandBlack,
      tertiary: _deepGold,
      surface: isDark ? _darkSurface : Colors.white,
      onSurface: isDark ? Colors.white : _brandBlack,
      surfaceContainerHighest: isDark
          ? const Color(0xFF282828)
          : const Color(0xFFECEBE6),
      onSurfaceVariant: isDark ? _softSilver : _metalGray,
      outline: isDark ? _metalGray : _softSilver,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'iransans',
      colorScheme: colorScheme,

      scaffoldBackgroundColor: isDark ? _brandBlack : _warmWhite,

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'iransans',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: isDark ? _darkCard : Colors.white,
        indicatorColor: _brandGold.withOpacity(isDark ? 0.22 : 0.30),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'iransans',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _brandGold);
          }

          return IconThemeData(color: isDark ? _softSilver : _metalGray);
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? _darkCard : Colors.white,
        indicatorColor: _brandGold.withOpacity(isDark ? 0.22 : 0.30),
        selectedIconTheme: const IconThemeData(color: _brandGold),
        unselectedIconTheme: IconThemeData(
          color: isDark ? _softSilver : _metalGray,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontFamily: 'iransans',
          color: _brandGold,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'iransans',
          color: isDark ? _softSilver : _metalGray,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brandGold;
          }

          return isDark ? _softSilver : _metalGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brandGold.withOpacity(0.35);
          }

          return isDark
              ? Colors.white.withOpacity(0.16)
              : Colors.black.withOpacity(0.12);
        }),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _brandGold,
        foregroundColor: _brandBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static final ThemeData lightTheme = _theme(Brightness.light);
  static final ThemeData darkTheme = _theme(Brightness.dark);
}
