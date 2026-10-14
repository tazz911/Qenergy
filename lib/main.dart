import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart' as app;
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const EnergyIQApp());
}

class EnergyIQApp extends StatelessWidget {
  const EnergyIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app.AuthProvider()),
      ],
      child: MaterialApp(
        title: 'EnergyIQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AppRouter(),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app.AuthProvider>();
    return switch (auth.status) {
      app.AuthStatus.initial => const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
      app.AuthStatus.authenticated => const MainShell(),
      _ => const LoginScreen(),
    };
  }
}