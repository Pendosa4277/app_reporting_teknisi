import 'package:flutter/material.dart';
// Import file LoginScreen dari folder screens
import 'package:app_reporting_teknisi/screens/login_screen.dart';
// Ganti 'flutter_app_name' dengan nama proyek Anda (biasanya nama folder utama)

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Operasional',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Atur home ke LoginScreen yang diimpor dari folder screens
      home: const LoginScreen(),
    );
  }
}
