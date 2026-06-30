import 'package:flutter/material.dart';

import 'dashboard_screen.dart';

void main() {
  runApp(const ShadowTempMailApp());
}

class ShadowTempMailApp extends StatelessWidget {
  const ShadowTempMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShadowTempMail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF020617),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
