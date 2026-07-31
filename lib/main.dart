import 'package:flutter/material.dart';
import 'login_screen.dart'; // 🔐 Importamos la pantalla de Login

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // ⚡ Inicializa los plugins nativos (Biometría / SharedPreferences)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planta Logística',
      debugShowCheckedModeBanner: false, // Quita la cinta de "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)), // Azul corporativo
        useMaterial3: true,
      ),
      // 🚀 Arranca la app OBLIGATORIAMENTE en el LoginScreen
      home: const LoginScreen(),
    );
  }
}