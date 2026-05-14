import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart' as app;
import 'features/auth/login_screen.dart';
import 'features/home/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCt1p4mXxx6k7ZS8yAOkKkKALqpIxjm7sI",
      authDomain: "btech-91fce.firebaseapp.com",
      projectId: "btech-91fce",
      storageBucket: "btech-91fce.firebasestorage.app",
      messagingSenderId: "679005043282",
      appId: "1:679005043282:web:5819b9a286d154bc387d8b",
      measurementId: "G-D1J30MRMMW",
    ),
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