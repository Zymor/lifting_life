import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'core/auth/auth_diagnostics.dart';
import 'core/configuration/supabase_config.dart';
import 'main_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase must be initialized before any Auth call (signUp, verifyOTP,
  // session restore). When credentials are absent the app still starts and
  // registration reports that it is unavailable instead of faking success.
  try {
    await SupabaseConfig.initializeIfConfigured().timeout(
      const Duration(seconds: 8),
    );
  } catch (error) {
    // Never block startup on the network/config layer.
    AuthDiagnostics.record(
      operation: 'initialize',
      category: 'initialization_failed',
    );
  }
  runApp(const LiftingLifeApp());
}

class LiftingLifeApp extends StatelessWidget {
  const LiftingLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lifting Life — Train. Progress. Compete. Inspire.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainLayout(),
    );
  }
}
