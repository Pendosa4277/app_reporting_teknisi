import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import file LoginScreen dari folder screens
import 'package:app_reporting_teknisi/screens/login_screen.dart';
import 'package:app_reporting_teknisi/screens/technician_dashboard.dart';
import 'package:app_reporting_teknisi/screens/supervisor_dashboard.dart';

/// Supabase expects you to provide the URL and ANON KEY at runtime.
/// For security don't commit real keys. Provide them when running the app:
/// flutter run --dart-define=SUPABASE_URL="https://..." --dart-define=SUPABASE_ANON_KEY="ey..."
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'https://scggbgdtpqysqjwmjbzo.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjZ2diZ2R0cHF5c3Fqd21qYnpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMDU2MzQsImV4cCI6MjA3NzU4MTYzNH0.GG2E_JsVDp_f2_iy_RAFxcU_v6-P_0viOEJl_Yxl9jU',
  );

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      // Optionally set debug to true while developing
      debug: false,
    );
  } else {
    // If keys are not provided we continue but Supabase calls will fail.
    // This allows the app to run in offline/demo mode.
    debugPrint(
      'Warning: SUPABASE_URL or SUPABASE_ANON_KEY not set. Provide via --dart-define.',
    );
  }

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/technician': (context) => const TechnicianDashboard(),
        '/supervisor': (context) => const SupervisorDashboard(),
      },
    );
  }
}
