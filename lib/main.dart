import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_reporting_teknisi/screens/login_screen.dart';
import 'package:app_reporting_teknisi/screens/technician_dashboard.dart';
import 'package:app_reporting_teknisi/screens/supervisor_dashboard.dart';

/// Simple app entry: initialize Supabase (if keys provided) then runApp.
/// Provide keys with --dart-define, e.g.:
/// flutter run --dart-define=SUPABASE_URL="https://<project>.supabase.co" --dart-define=SUPABASE_ANON_KEY="<anon-key>"
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'https://zktnthewyxkqlwvvhknk.supabase.co',
    defaultValue: '',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprdG50aGV3eXhrcWx3dnZoa25rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMTMxOTEsImV4cCI6MjA3NzU4OTE5MX0.vhcl7lOQom625DBN-svGLQd7qS2Vixaki9OWO621N6Y',
    defaultValue: '',
  );

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('Supabase initialized');
    } catch (e, st) {
      debugPrint('Supabase.initialize failed: $e');
      debugPrint('$st');
    }
  } else {
    debugPrint(
      'SUPABASE_URL or SUPABASE_ANON_KEY not provided; running in demo mode.',
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
