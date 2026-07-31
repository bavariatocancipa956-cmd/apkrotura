import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'pantalla_menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  bool _cargando = false;
  bool _ocultarContrasena = true;

  final String _apiUrl = 'https://plantatocancipa.site/api/v1/db_logistica/roturas/usuarios/login';
  final String _apiKey = 'PlantaLogistica2026*';

  @override
  void initState() {
    super.initState();
    _cargarUsuarioGuardado();
  }

  Future<void> _cargarUsuarioGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioGuardado = prefs.getString('ultimo_usuario');
    final passGuardada = prefs.getString('ultimo_pass');

    if (usuarioGuardado != null && mounted) {
      setState(() {
        _usuarioController.text = usuarioGuardado;
        if (passGuardada != null) {
          _contrasenaController.text = passGuardada;
        }
      });
    }
  }

  Future<void> _validarLogin() async {
    final usuario = _usuarioController.text.trim();
    final contrasena = _contrasenaController.text.trim();

    if (usuario.isEmpty || contrasena.isEmpty) {
      _mostrarErrorDialog('Por favor ingresa tu usuario y contraseña.');
      return;
    }

    setState(() => _cargando = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'usuario': usuario,
          'contrasena': contrasena,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['exito'] == true && data['usuario'] != null) {
          final Map<String, dynamic> usuarioMap = Map<String, dynamic>.from(data['usuario']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ultimo_usuario', usuario);
          await prefs.setString('ultimo_pass', contrasena);

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaMenu(usuario: usuarioMap),
            ),
          );
          return;
        }
      } else if (response.statusCode == 401) {
        _mostrarErrorDialog('Usuario o contraseña incorrectos.');
        return;
      }

      _mostrarErrorDialog('Error de comunicación con el servidor (${response.statusCode}).');
    } catch (e) {
      _mostrarErrorDialog('No se pudo conectar con el servidor. Verifica tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarErrorDialog(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Atención'),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 45, bottom: 35),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A3161), Color(0xFF0D47A1), Color(0xFF1565C0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.liquor_rounded,
                            size: 42,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'CONTROL DE ROTURAS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.liquor_outlined, color: Colors.amber.shade300, size: 15),
                            const SizedBox(width: 6),
                            const Text(
                              'Gestión de Envases & Líneas de Llenado',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D47A1).withOpacity(0.08),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFF0D47A1), size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF212121),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _usuarioController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF0D47A1)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _contrasenaController,
                            obscureText: _ocultarContrasena,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0D47A1)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(() => _ocultarContrasena = !_ocultarContrasena),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _cargando ? null : _validarLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _cargando
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                  : const Text(
                                'INGRESAR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Desarrollado por: Gerardo Rodriguez',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}