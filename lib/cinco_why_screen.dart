import 'package:flutter/material.dart';

class CincoWhyScreen extends StatelessWidget {
  final Map<String, dynamic> usuario;

  const CincoWhyScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Análisis 5Why',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    size: 85,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  '¡Módulo en Construcción!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D47A1),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estamos trabajando en la integración del módulo de Análisis 5Why (5 Porqués) para la gestión de causa raíz.\n\n¡Estará disponible muy pronto!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 35),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'REGRESAR AL MENÚ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}