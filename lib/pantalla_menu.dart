import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// 🔗 IMPORTACIÓN DE CADA PANTALLA
import 'registro_rotura_screen.dart';
import 'dashboard_rotura_screen.dart';
import 'eliminar_registros_screen.dart';
import 'descargas_screen.dart';
import 'cinco_s_screen.dart';
import 'cinco_why_screen.dart';
import 'login_screen.dart';

class PantallaMenu extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const PantallaMenu({super.key, required this.usuario});

  @override
  State<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends State<PantallaMenu> {
  String _mensajeMotivacional = "Hoy es un gran día para dar lo mejor de ti.\n¡Vamos con toda!";
  String? _fotoUrl;

  final List<String> _mensajes = [
    "¡El éxito es la suma de pequeños esfuerzos\nrepetidos día tras día!",
    "Tu dedicación y esfuerzo marcan\nla diferencia en nuestra operación hoy.",
    "La calidad de tu trabajo es el reflejo\nde tu excelencia.",
    "Hoy es un gran día para dar lo mejor de ti.\n¡Vamos con toda!",
    "Los grandes logros nacen de\npersonas comprometidas como tú.",
    "¡Mantén la actitud positiva y el éxito\nte seguirá en cada estiba!",
    "Tu seguridad y tu buen trabajo son\nel motor de esta operación."
  ];

  @override
  void initState() {
    super.initState();
    _mensajeMotivacional = _mensajes[Random().nextInt(_mensajes.length)];
    _fotoUrl = widget.usuario['foto'] ?? widget.usuario['Foto'];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_fotoUrl == null || _fotoUrl.toString().trim().isEmpty) {
        _sugerirConfigurarPerfil();
      }
    });
  }

  void _sugerirConfigurarPerfil() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_a_photo_rounded, color: Color(0xFF0D47A1)),
            SizedBox(width: 10),
            Text('¡Bienvenido!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Aún no has agregado una foto a tu perfil. Puedes tomarte una foto o seleccionar una de tu galería ahora.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _mostrarModalEditarPerfil();
            },
            child: const Text('Agregar Foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalEditarPerfil() {
    showDialog(
      context: context,
      builder: (context) => ModalEditarPerfil(
        usuario: widget.usuario,
        fotoActualUrl: _fotoUrl,
        onPerfilActualizado: (nuevoNombre, nuevaFoto) {
          setState(() {
            widget.usuario['nombre'] = nuevoNombre;
            widget.usuario['foto'] = nuevaFoto;
            _fotoUrl = nuevaFoto;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nombreEmpleado = (widget.usuario['nombre'] ?? widget.usuario['Nombre'] ?? 'OPERADOR').toString().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Panel Principal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      drawer: CustomDrawer(
        usuario: widget.usuario,
        fotoUrl: _fotoUrl,
        onEditarPerfil: _mostrarModalEditarPerfil,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D47A1), width: 3.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: _fotoUrl != null && _fotoUrl!.trim().isNotEmpty
                          ? ClipOval(child: Image.network(_fotoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, size: 100, color: Color(0xFF0D47A1))))
                          : const Icon(Icons.person_rounded, size: 100, color: Color(0xFF0D47A1)),
                    ),
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: InkWell(
                        onTap: _mostrarModalEditarPerfil,
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D47A1),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Text(
                    nombreEmpleado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 36),
                        const SizedBox(height: 12),
                        Text(
                          _mensajeMotivacional,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Color(0xFF37474F), fontWeight: FontWeight.w600, height: 1.5),
                        ),
                      ],
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

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final String? fotoUrl;
  final VoidCallback onEditarPerfil;

  const CustomDrawer({
    super.key,
    required this.usuario,
    this.fotoUrl,
    required this.onEditarPerfil,
  });

  void _mostrarDialogoEditarContrasena(BuildContext context) {
    final TextEditingController contrasenaCtrl = TextEditingController();
    final TextEditingController confirmarCtrl = TextEditingController();
    bool ocultarContrasena = true;
    bool cargando = false;

    final idUsuario = usuario['id'] ?? usuario['ID'] ?? usuario['Id'];
    const String baseUrl = 'https://plantatocancipa.site/api/v1/db_logistica/editar/roturas/usuarios';
    const String apiKey = 'PlantaLogistica2026*';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Color(0xFF0D47A1)),
                  SizedBox(width: 10),
                  Text('Editar Contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ingresa tu nueva contraseña. Se actualizará inmediatamente en el sistema.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: contrasenaCtrl,
                    obscureText: ocultarContrasena,
                    decoration: InputDecoration(
                      hintText: 'Nueva Contraseña',
                      prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF0D47A1)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          ocultarContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setModalState(() => ocultarContrasena = !ocultarContrasena);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmarCtrl,
                    obscureText: ocultarContrasena,
                    decoration: InputDecoration(
                      hintText: 'Confirmar Contraseña',
                      prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF0D47A1)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: cargando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: cargando
                      ? null
                      : () async {
                    final nuevaPass = contrasenaCtrl.text.trim();
                    final confirmarPass = confirmarCtrl.text.trim();

                    if (nuevaPass.isEmpty || confirmarPass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor completa ambos campos.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    if (nuevaPass != confirmarPass) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Las contraseñas no coinciden.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    if (idUsuario == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: No se encontró el ID del usuario.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setModalState(() => cargando = true);

                    try {
                      final response = await http.put(
                        Uri.parse('$baseUrl/$idUsuario'),
                        headers: {
                          'Content-Type': 'application/json',
                          'x-api-key': apiKey,
                        },
                        body: jsonEncode({
                          'contrasena': nuevaPass,
                        }),
                      ).timeout(const Duration(seconds: 10));

                      if (response.statusCode == 200) {
                        usuario['contrasena'] = nuevaPass;

                        if (!context.mounted) return;
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Contraseña actualizada correctamente.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error al actualizar (${response.statusCode})'), backgroundColor: Colors.red),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Error de conexión: $e'), backgroundColor: Colors.red),
                      );
                    } finally {
                      setModalState(() => cargando = false);
                    }
                  },
                  child: cargando
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nombreEmpleado = (usuario['nombre'] ?? usuario['Nombre'] ?? 'OPERADOR').toString().toUpperCase();

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 65, bottom: 35),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(50)),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 95,
                      height: 95,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: fotoUrl != null && fotoUrl!.trim().isNotEmpty
                          ? ClipOval(child: Image.network(fotoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, size: 60, color: Colors.white)))
                          : const Icon(Icons.person_rounded, size: 60, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onEditarPerfil();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Color(0xFF0D47A1), size: 16),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    nombreEmpleado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10),
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.broken_image_outlined, color: Color(0xFF0D47A1)),
                  title: const Text('ROTURA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 15)),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(context, 'Reporte de roturas', Icons.app_registration, RegistroRoturaScreen(usuario: usuario)),
                    _buildSubMenuItem(context, 'Dashboard de rotura', Icons.dashboard_outlined, const DashboardRoturaScreen()),
                    _buildSubMenuItem(context, 'Eliminar registros', Icons.delete_outline, const EliminarRegistrosScreen()),
                    _buildSubMenuItem(context, 'Descargas', Icons.file_download_outlined, const DescargasScreen()),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF0D47A1)),
                  title: const Text('GESTIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 15)),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: const Color(0xFF0D47A1),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    _buildSubMenuItem(context, '5S', Icons.fact_check_outlined, const CincoSScreen()),
                    _buildSubMenuItem(context, '5Why (5 Porqués)', Icons.psychology_outlined, CincoWhyScreen(usuario: usuario)),
                  ],
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0D47A1)),
                  title: const Text('Editar Contraseña', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoEditarContrasena(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 20, color: Colors.black12),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFE53935)),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 15)),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 25.0, top: 10.0),
            child: Text(
              'Desarrollado por: Gerardo Rodriguez',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(BuildContext context, String titulo, IconData icono, Widget pantallaDestino) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 45, right: 20),
      leading: Icon(icono, color: const Color(0xFF1565C0), size: 22),
      title: Text(titulo, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => pantallaDestino));
      },
    );
  }
}

class ModalEditarPerfil extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String? fotoActualUrl;
  final Function(String nuevoNombre, String? nuevaFotoUrl) onPerfilActualizado;

  const ModalEditarPerfil({
    super.key,
    required this.usuario,
    required this.fotoActualUrl,
    required this.onPerfilActualizado,
  });

  @override
  State<ModalEditarPerfil> createState() => _ModalEditarPerfilState();
}

class _ModalEditarPerfilState extends State<ModalEditarPerfil> {
  late TextEditingController _nombreCtrl;
  XFile? _nuevaFotoXFile;
  Uint8List? _nuevaFotoBytes;
  String? _fotoUrlActual;
  bool _eliminarFotoExistente = false;
  bool _guardando = false;

  final ImagePicker _picker = ImagePicker();
  static const String _apiKey = 'PlantaLogistica2026*';

  @override
  void initState() {
    super.initState();
    final nombreOriginal = widget.usuario['nombre'] ?? widget.usuario['Nombre'] ?? '';
    _nombreCtrl = TextEditingController(text: nombreOriginal.toString());
    _fotoUrlActual = widget.fotoActualUrl;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    final XFile? pick = await _picker.pickImage(source: origen, imageQuality: 50, maxWidth: 800);
    if (pick != null) {
      final bytes = await pick.readAsBytes();
      setState(() {
        _nuevaFotoXFile = pick;
        _nuevaFotoBytes = bytes;
        _eliminarFotoExistente = false;
      });
    }
  }

  Future<void> _eliminarFotoFisicaServidor(String url) async {
    try {
      await http.delete(
        Uri.parse('https://plantatocancipa.site/api/v1/archivos/borrar'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({'urlArchivo': url}),
      );
    } catch (e) {
      debugPrint("Error borrando foto previa del servidor: $e");
    }
  }

  Future<String?> _subirFotoPerfil(XFile foto) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://plantatocancipa.site/api/v1/archivos/subir'),
      );
      request.headers['x-api-key'] = _apiKey;

      final bytes = await foto.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'fotos_perfil',
        bytes,
        filename: 'perfil_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exito'] == true && data['urls'] != null) {
          return data['urls']['fotos_perfil'];
        }
      }
    } catch (e) {
      debugPrint("Error subiendo foto de perfil: $e");
    }
    return null;
  }

  Future<void> _guardarCambiosPerfil() async {
    final nuevoNombre = _nombreCtrl.text.trim();
    if (nuevoNombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre válido.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      String? urlFotoFinal = _fotoUrlActual;

      if (_nuevaFotoXFile != null) {
        if (_fotoUrlActual != null && _fotoUrlActual!.startsWith('http')) {
          await _eliminarFotoFisicaServidor(_fotoUrlActual!);
        }
        urlFotoFinal = await _subirFotoPerfil(_nuevaFotoXFile!);
      } else if (_eliminarFotoExistente) {
        if (_fotoUrlActual != null && _fotoUrlActual!.startsWith('http')) {
          await _eliminarFotoFisicaServidor(_fotoUrlActual!);
        }
        urlFotoFinal = null;
      }

      final idUsuario = widget.usuario['id'] ?? widget.usuario['ID'] ?? widget.usuario['Id'];

      final response = await http.put(
        Uri.parse('https://plantatocancipa.site/api/v1/db_logistica/editar/roturas/usuarios/$idUsuario'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'nombre': nuevoNombre,
          'foto': urlFotoFinal,
        }),
      );

      if (response.statusCode == 200) {
        widget.onPerfilActualizado(nuevoNombre, urlFotoFinal);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Perfil actualizado exitosamente.'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error del servidor: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al actualizar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imagenMostrar;
    if (_nuevaFotoBytes != null) {
      imagenMostrar = MemoryImage(_nuevaFotoBytes!);
    } else if (!_eliminarFotoExistente && _fotoUrlActual != null && _fotoUrlActual!.trim().isNotEmpty) {
      imagenMostrar = NetworkImage(_fotoUrlActual!);
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_pin_rounded, color: Color(0xFF0D47A1)),
          SizedBox(width: 8),
          Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE3F2FD),
                    backgroundImage: imagenMostrar,
                    child: imagenMostrar == null ? const Icon(Icons.person, size: 55, color: Color(0xFF0D47A1)) : null,
                  ),
                  if (imagenMostrar != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _nuevaFotoXFile = null;
                            _nuevaFotoBytes = null;
                            _eliminarFotoExistente = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _seleccionarImagen(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF0D47A1)),
                  label: const Text('Cámara', style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1))),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _seleccionarImagen(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 16, color: Color(0xFF0D47A1)),
                  label: const Text('Galería', style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1))),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF0D47A1)),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _guardando ? null : _guardarCambiosPerfil,
          child: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}