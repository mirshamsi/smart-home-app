import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: 'iransans',
    scaffoldBackgroundColor: Colors.grey[300],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.amber[800],
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'iransans',
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blueGrey,
    fontFamily: 'iransans',
    scaffoldBackgroundColor: Colors.grey[800],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.blueGrey[900],
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'iransans',
      ),
    ),
  );
}
