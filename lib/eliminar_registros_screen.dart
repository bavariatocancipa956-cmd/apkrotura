import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

// ============================================================================
// 1️⃣ PANTALLA PRINCIPAL DE GESTIÓN (LISTADO, ELIMINACIÓN Y EDICIÓN)
// ============================================================================
class EliminarRegistrosScreen extends StatefulWidget {
  const EliminarRegistrosScreen({super.key});

  @override
  State<EliminarRegistrosScreen> createState() => _EliminarRegistrosScreenState();
}

class _EliminarRegistrosScreenState extends State<EliminarRegistrosScreen> {
  bool _cargando = true;
  List<dynamic> _registrosTotales = [];
  List<dynamic> _registrosFiltrados = [];

  DateTime? _fechaFiltro;
  final TextEditingController _reportanteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
    _reportanteCtrl.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _reportanteCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarRegistros() async {
    setState(() => _cargando = true);
    try {
      final datos = await ApiService.consultar('roturas', 'reportes_rotura');

      setState(() {
        _registrosTotales = datos;
        _aplicarFiltros();
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al cargar registros: $e'), backgroundColor: Colors.red),
        );
        setState(() => _cargando = false);
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _registrosFiltrados = _registrosTotales.where((reg) {
        bool coincideFecha = true;
        bool coincideReportante = true;

        if (_fechaFiltro != null) {
          final fechaReg = reg['fecha_evento']?.toString().split('T')[0] ?? '';
          final fechaFiltroStr = _fechaFiltro!.toIso8601String().split('T')[0];
          coincideFecha = fechaReg == fechaFiltroStr;
        }

        if (_reportanteCtrl.text.isNotEmpty) {
          final reportanteReg = reg['reportante']?.toString().toLowerCase() ?? '';
          coincideReportante = reportanteReg.contains(_reportanteCtrl.text.toLowerCase());
        }

        return coincideFecha && coincideReportante;
      }).toList();

      _registrosFiltrados.sort((a, b) {
        final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        return idB.compareTo(idA);
      });
    });
  }

  bool _esMayorA3Dias(dynamic fechaRaw) {
    if (fechaRaw == null) return false;
    try {
      final String fechaStr = fechaRaw.toString().split('T')[0];
      final DateTime fechaEvento = DateTime.parse(fechaStr);
      final DateTime hoy = DateTime.now();

      final DateTime fechaHoySolo = DateTime(hoy.year, hoy.month, hoy.day);
      final DateTime fechaEventoSolo = DateTime(fechaEvento.year, fechaEvento.month, fechaEvento.day);

      final int diferenciaDias = fechaHoySolo.difference(fechaEventoSolo).inDays;
      return diferenciaDias > 3;
    } catch (e) {
      return false;
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null && seleccion != _fechaFiltro) {
      setState(() {
        _fechaFiltro = seleccion;
        _aplicarFiltros();
      });
    }
  }

  void _abrirEdicion(Map<String, dynamic> registro) async {
    if (_esMayorA3Dias(registro['fecha_evento'])) {
      _mostrarAlertaBloqueo('No es posible editar este registro porque han transcurrido más de 3 días desde la fecha del evento.');
      return;
    }

    final editado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditarRegistroScreen(registro: registro),
      ),
    );

    if (editado == true) {
      _cargarRegistros();
    }
  }

  Future<void> _eliminarRegistroConfirmado(dynamic registro) async {
    final dynamic idRegistro = registro['id'];
    final dynamic fechaEvento = registro['fecha_evento'];

    if (_esMayorA3Dias(fechaEvento)) {
      _mostrarAlertaBloqueo('No es posible eliminar este registro porque han transcurrido más de 3 días desde la fecha del evento.');
      return;
    }

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Confirmar Eliminación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este reporte?\n\n'
                'Esta acción borrará el registro de la base de datos de forma irreversible.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sí, Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    setState(() => _cargando = true);
    try {
      await ApiService.eliminar('roturas', 'reportes_rotura', 'id', idRegistro);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registro eliminado correctamente.')),
        );
        _cargarRegistros();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al eliminar: $e'), backgroundColor: Colors.red),
        );
        setState(() => _cargando = false);
      }
    }
  }

  void _mostrarAlertaBloqueo(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Acción Bloqueada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje, style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Gestión de Registros', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _reportanteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nombre de reportante...',
                    prefixIcon: const Icon(Icons.person_search, color: Color(0xFF0D47A1)),
                    suffixIcon: _reportanteCtrl.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _reportanteCtrl.clear();
                        FocusScope.of(context).unfocus();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D47A1))),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _seleccionarFecha(context),
                        icon: const Icon(Icons.calendar_month, color: Color(0xFF0D47A1), size: 20),
                        label: Text(
                          _fechaFiltro == null
                              ? 'Filtrar por Fecha Evento'
                              : 'Fecha: ${_fechaFiltro!.toIso8601String().split('T')[0]}',
                          style: TextStyle(
                            color: _fechaFiltro == null ? Colors.grey.shade700 : const Color(0xFF0D47A1),
                            fontWeight: _fechaFiltro == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: _fechaFiltro == null ? Colors.grey.shade300 : const Color(0xFF0D47A1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    if (_fechaFiltro != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _fechaFiltro = null;
                            _aplicarFiltros();
                          });
                        },
                        icon: const Icon(Icons.event_busy, color: Colors.red),
                        tooltip: 'Limpiar Fecha',
                      )
                    ]
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _registrosFiltrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  Text('No se encontraron registros', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _cargarRegistros,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _registrosFiltrados.length,
                itemBuilder: (context, index) {
                  final registro = _registrosFiltrados[index];

                  final id = registro['id']?.toString() ?? 'N/A';
                  final sku = registro['sku']?.toString() ?? 'Sin SKU';
                  final cantidad = registro['cantidad']?.toString() ?? '0';
                  final fecha = registro['fecha_evento']?.toString().split('T')[0] ?? 'Sin Fecha';
                  final reportante = registro['reportante']?.toString() ?? 'Desconocido';

                  final bool esExpirado = _esMayorA3Dias(registro['fecha_evento']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D47A1)),
                      ),
                      title: Text(
                        'Reporte #$id - SKU: $sku',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 12, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text('Fecha: $fecha', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 12, color: Color(0xFF0D47A1)),
                                const SizedBox(width: 4),
                                Text('Rep: $reportante', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.numbers_rounded, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text('Cant: $cantidad', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              esExpirado ? Icons.lock_outline_rounded : Icons.edit_outlined,
                              color: esExpirado ? Colors.grey : const Color(0xFF0D47A1),
                              size: 24,
                            ),
                            tooltip: esExpirado ? 'Bloqueado (> 3 días)' : 'Editar Registro',
                            onPressed: () => _abrirEdicion(registro),
                          ),
                          IconButton(
                            icon: Icon(
                              esExpirado ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                              color: esExpirado ? Colors.grey : Colors.red,
                              size: 24,
                            ),
                            tooltip: esExpirado ? 'Bloqueado (> 3 días)' : 'Eliminar Registro',
                            onPressed: () => _eliminarRegistroConfirmado(registro),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2️⃣ PANTALLA DE EDICIÓN CON CAMPOS DE SKU, CANTIDAD Y FIRMA BLOQUEADOS
// ============================================================================
class EditarRegistroScreen extends StatefulWidget {
  final Map<String, dynamic> registro;

  const EditarRegistroScreen({super.key, required this.registro});

  @override
  State<EditarRegistroScreen> createState() => _EditarRegistroScreenState();
}

class _EditarRegistroScreenState extends State<EditarRegistroScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _estaCargando = true;
  bool _guardando = false;

  late DateTime _fechaEvento;
  String? _turno;
  final String _area = 'LOGISTICA';

  final TextEditingController _ubicacionCtrl = TextEditingController();
  final TextEditingController _zonaCtrl = TextEditingController();
  final TextEditingController _escenarioCtrl = TextEditingController();
  final TextEditingController _causalCtrl = TextEditingController();
  final TextEditingController _supervisorCtrl = TextEditingController();
  final TextEditingController _personalCtrl = TextEditingController();
  final TextEditingController _conciliadorCtrl = TextEditingController();

  final TextEditingController _placaVehiculoCtrl = TextEditingController();
  final TextEditingController _origenVehiculoCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();

  // Valores bloqueados (Solo lectura)
  late String _skuBloqueado;
  late String _cantidadBloqueada;
  late String _firmaBloqueada;

  List<String> _listaUbicaciones = [];
  List<String> _listaZonas = [];
  List<String> _listaEscenarios = [];
  List<String> _listaCausales = [];
  List<String> _listaSupervisores = [];
  List<String> _listaPersonal = [];
  List<String> _listaConciliadores = [];
  List<String> _listaOrigenes = [];

  File? _nuevaEvidenciaEvento;
  File? _nuevaEvidenciaCausante;
  String? _urlFotoEventoActual;
  String? _urlFotoCausanteActual;

  bool get _mostrarDatosVehiculo {
    final causalLimpia = _causalCtrl.text.trim().toLowerCase();
    return causalLimpia == 'vehiculo t1 condiciones no optimas' ||
        causalLimpia == 'vehiculo t2 condiciones no optimas';
  }

  String _limpiarTextoPersona(String? texto) {
    if (texto == null || texto.trim().isEmpty) return '';
    return texto
        .replaceAll(RegExp(r'[-0-9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _inicializarDatosValores();
    _cargarListasDesdeBD();
  }

  void _inicializarDatosValores() {
    final r = widget.registro;

    try {
      _fechaEvento = DateTime.tryParse(r['fecha_evento']?.toString() ?? '') ?? DateTime.now();
    } catch (_) {
      _fechaEvento = DateTime.now();
    }

    _turno = r['turno']?.toString();
    _ubicacionCtrl.text = r['ubicacion']?.toString() ?? '';
    _zonaCtrl.text = r['zona']?.toString() ?? '';
    _escenarioCtrl.text = r['escenario']?.toString() ?? '';
    _causalCtrl.text = r['causal']?.toString() ?? '';
    _supervisorCtrl.text = r['supervisor']?.toString() ?? '';
    _personalCtrl.text = r['personal']?.toString() ?? '';
    _conciliadorCtrl.text = r['conciliador']?.toString() ?? '';
    _placaVehiculoCtrl.text = r['placa_vehiculo']?.toString() == 'NO APLICA' ? '' : (r['placa_vehiculo']?.toString() ?? '');
    _origenVehiculoCtrl.text = r['origen_vehiculo']?.toString() == 'NO APLICA' ? '' : (r['origen_vehiculo']?.toString() ?? '');
    _descripcionCtrl.text = r['descripcion']?.toString() ?? '';

    // BLOQUEADOS DE SOLO LECTURA
    _skuBloqueado = r['sku']?.toString() ?? 'Sin SKU';
    _cantidadBloqueada = r['cantidad']?.toString() ?? '0';
    _firmaBloqueada = r['firma_conciliador']?.toString() ?? 'Sin Firma';

    // Evidencias Fotográficas
    _urlFotoEventoActual = r['evidencia_evento']?.toString();
    _urlFotoCausanteActual = r['evidencia_causante']?.toString();
  }

  Future<void> _cargarListasDesdeBD() async {
    setState(() => _estaCargando = true);
    try {
      final datosLista = await ApiService.consultar('roturas', 'rotura_lista');
      final datosOrigen = await ApiService.consultar('roturas', 'rotura_origen');

      final Set<String> ubiSet = {};
      final Set<String> zonaSet = {};
      final Set<String> escSet = {};
      final Set<String> causalSet = {};
      final Set<String> supSet = {};
      final Set<String> perSet = {};
      final Set<String> conSet = {};
      final Set<String> origenSet = {};

      for (var fila in datosLista) {
        if (fila is Map) {
          final Map<String, dynamic> filaMap = {};
          fila.forEach((key, value) {
            filaMap[key.toString().toLowerCase()] = value;
          });

          String? ubi = filaMap['ubicacion']?.toString();
          String? zona = filaMap['zona']?.toString();
          String? esc = filaMap['escenario']?.toString() ?? filaMap['escenarios']?.toString();
          String? causal = filaMap['causal']?.toString();

          String? sup = _limpiarTextoPersona(filaMap['supervisor']?.toString());
          String? per = _limpiarTextoPersona(filaMap['personal']?.toString());
          String? con = _limpiarTextoPersona(filaMap['conciliador']?.toString());

          if (ubi != null && ubi.trim().isNotEmpty) ubiSet.add(ubi.trim());
          if (zona != null && zona.trim().isNotEmpty) zonaSet.add(zona.trim());
          if (esc != null && esc.trim().isNotEmpty) escSet.add(esc.trim());
          if (causal != null && causal.trim().isNotEmpty) causalSet.add(causal.trim());
          if (sup.isNotEmpty) supSet.add(sup);
          if (per.isNotEmpty) perSet.add(per);
          if (con.isNotEmpty) conSet.add(con);
        }
      }

      for (var fila in datosOrigen) {
        if (fila is Map) {
          final Map<String, dynamic> filaMap = {};
          fila.forEach((key, value) {
            filaMap[key.toString().toLowerCase()] = value;
          });

          String? origen = filaMap['origen']?.toString();
          if (origen != null && origen.trim().isNotEmpty) {
            origenSet.add(origen.trim());
          }
        }
      }

      if (mounted) {
        setState(() {
          _listaUbicaciones = ubiSet.toList()..sort();
          _listaZonas = zonaSet.toList()..sort();
          _listaEscenarios = escSet.toList()..sort();
          _listaCausales = causalSet.toList()..sort();
          _listaSupervisores = supSet.toList()..sort();
          _listaPersonal = perSet.toList()..sort();
          _listaConciliadores = conSet.toList()..sort();
          _listaOrigenes = origenSet.toList()..sort();
          _estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al cargar BD: $e'), backgroundColor: Colors.red),
        );
        setState(() => _estaCargando = false);
      }
    }
  }

  Future<void> _seleccionarFechaEvento(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaEvento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null && seleccion != _fechaEvento) {
      setState(() {
        _fechaEvento = seleccion;
      });
    }
  }

  Future<File> _comprimirFoto(File fotoOriginal, {int maxKB = 30}) async {
    int maxBytes = maxKB * 1024;
    if (await fotoOriginal.length() <= maxBytes) return fotoOriginal;

    Uint8List bytes = await fotoOriginal.readAsBytes();
    int targetWidth = 450;

    while (bytes.lengthInBytes > maxBytes && targetWidth >= 100) {
      ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
      ui.FrameInfo frame = await codec.getNextFrame();
      ui.Image image = frame.image;
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        Uint8List newBytes = byteData.buffer.asUint8List();
        if (newBytes.lengthInBytes <= maxBytes || targetWidth <= 100) {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/foto_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(newBytes, flush: true);
          return file;
        }
      }
      targetWidth -= 50;
    }

    return fotoOriginal;
  }

  void _mostrarOpcionesOrigenImagen(bool esEvento) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cambiar Imagen de Evidencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D47A1)),
                  title: const Text('Tomar Foto con Cámara'),
                  onTap: () {
                    Navigator.pop(context);
                    _tomarFoto(esEvento, ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0D47A1)),
                  title: const Text('Elegir de la Galería'),
                  onTap: () {
                    Navigator.pop(context);
                    _tomarFoto(esEvento, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _tomarFoto(bool esEvento, ImageSource origen) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: origen,
        imageQuality: 15,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (foto != null) {
        File fotoComprimida = await _comprimirFoto(File(foto.path), maxKB: 30);
        setState(() {
          if (esEvento) {
            _nuevaEvidenciaEvento = fotoComprimida;
          } else {
            _nuevaEvidenciaCausante = fotoComprimida;
          }
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar foto: $e");
    }
  }

  Future<void> _guardarCambios() async {
    if (_turno == null) return _mostrarAlertaValidacion('Falta seleccionar el Turno.');
    if (_ubicacionCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar la Ubicación.');
    if (_zonaCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar la Zona.');
    if (_escenarioCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar el Escenario.');
    if (_causalCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar la Causal Específica.');

    if (_mostrarDatosVehiculo) {
      if (_placaVehiculoCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta ingresar la Placa del Vehículo.');
      if (_origenVehiculoCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar el Origen del Vehículo.');
    }

    if (_descripcionCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta ingresar la Descripción / Observaciones.');
    if (_supervisorCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar el Supervisor Encargado.');
    if (_personalCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar el Personal Involucrado.');
    if (_conciliadorCtrl.text.trim().isEmpty) return _mostrarAlertaValidacion('Falta seleccionar el Conciliador.');

    final String placaFinal = _mostrarDatosVehiculo && _placaVehiculoCtrl.text.trim().isNotEmpty
        ? _placaVehiculoCtrl.text.trim()
        : 'NO APLICA';

    final String origenFinal = _mostrarDatosVehiculo && _origenVehiculoCtrl.text.trim().isNotEmpty
        ? _origenVehiculoCtrl.text.trim()
        : 'NO APLICA';

    setState(() => _guardando = true);

    try {
      String? urlFotoEvento = _urlFotoEventoActual;
      String? urlFotoCausante = _urlFotoCausanteActual;

      if (_nuevaEvidenciaEvento != null) {
        urlFotoEvento = await ApiService.subirFoto('evidencia_evento', _nuevaEvidenciaEvento!);
      }
      if (_nuevaEvidenciaCausante != null) {
        urlFotoCausante = await ApiService.subirFoto('evidencia_causante', _nuevaEvidenciaCausante!);
      }

      Map<String, dynamic> datosActualizados = {
        'fecha_evento': _fechaEvento.toIso8601String().split('T')[0],
        'turno': _turno,
        'area': _area,
        'ubicacion': _ubicacionCtrl.text.trim(),
        'zona': _zonaCtrl.text.trim(),
        'escenario': _escenarioCtrl.text.trim(),
        'causal': _causalCtrl.text.trim(),
        'supervisor': _supervisorCtrl.text.trim(),
        'personal': _personalCtrl.text.trim(),
        'conciliador': _conciliadorCtrl.text.trim(),
        'placa_vehiculo': placaFinal,
        'origen_vehiculo': origenFinal,
        'descripcion': _descripcionCtrl.text.trim(),
        'evidencia_evento': urlFotoEvento,
        'evidencia_causante': urlFotoCausante,
      };

      final dynamic idRegistro = widget.registro['id'];
      await ApiService.actualizar('roturas', 'reportes_rotura', datosActualizados, 'id', idRegistro);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro actualizado correctamente.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al actualizar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _mostrarAlertaValidacion(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ $mensaje'), backgroundColor: Colors.orange.shade800),
    );
  }

  void _abrirModalBuscador({
    required String titulo,
    required List<String> Function() getOpciones,
    required TextEditingController controller,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String filtro = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final opcionesActuales = getOpciones();
            final opcionesFiltradas = opcionesActuales.where((op) => op.toLowerCase().contains(filtro.toLowerCase())).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)), overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Escribe para buscar...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      onChanged: (val) => setModalState(() => filtro = val),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
                      child: opcionesFiltradas.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('No se encontraron coincidencias.', style: TextStyle(color: Colors.grey))),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        itemCount: opcionesFiltradas.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final opcion = opcionesFiltradas[index];
                          return ListTile(
                            title: Text(opcion, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            trailing: controller.text == opcion ? const Icon(Icons.check_circle, color: Color(0xFF0D47A1)) : null,
                            onTap: () {
                              setState(() => controller.text = opcion);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text('Editar Reporte #${widget.registro['id']}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _estaCargando || _guardando
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0D47A1)),
              const SizedBox(height: 15),
              Text(_estaCargando ? 'Cargando datos...' : 'Guardando Cambios...', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔒 PRODUCTO AFECTADO (TOTALMENTE CONGELADO / SOLO LECTURA)
              _buildSeccionCard(
                titulo: 'Producto Afectado (Solo Lectura - No Editable)',
                hijos: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('SKU (Bloqueado) 🔒'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                _skuBloqueado,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Cant 🔒'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                _cantidadBloqueada,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 1️⃣ DETALLES DEL EVENTO
              _buildSeccionCard(
                titulo: 'Detalles del Evento',
                hijos: [
                  _buildLabel('Fecha de Registro * (Toca para cambiar)'),
                  InkWell(
                    onTap: () => _seleccionarFechaEvento(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fechaEvento.toIso8601String().split('T')[0], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D47A1), size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Turno *'), _buildDropdownSimple(valor: _turno, hint: 'T1, T2, T3...', items: ['T1', 'T2', 'T3'], onChanged: (v) => setState(() => _turno = v))])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildLabel('Área *'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Text(_area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        )
                      ])),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildCampoBuscadorModal(label: 'Ubicación *', hint: 'Seleccionar Ubicación...', controller: _ubicacionCtrl, getOpciones: () => _listaUbicaciones),
                  const SizedBox(height: 15),
                  _buildCampoBuscadorModal(label: 'Zona *', hint: 'Seleccionar Zona...', controller: _zonaCtrl, getOpciones: () => _listaZonas),
                  const SizedBox(height: 15),
                  _buildCampoBuscadorModal(label: 'Escenario *', hint: 'Seleccionar Escenario...', controller: _escenarioCtrl, getOpciones: () => _listaEscenarios),
                ],
              ),
              const SizedBox(height: 15),

              // 2️⃣ CAUSAL Y DATOS DE VEHÍCULO
              _buildSeccionCard(
                titulo: 'Causal y Clasificación',
                hijos: [
                  _buildCampoBuscadorModal(label: 'Causal Específica *', hint: 'Seleccionar Causal...', controller: _causalCtrl, getOpciones: () => _listaCausales),
                  if (_mostrarDatosVehiculo) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DATOS DEL VEHÍCULO *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Placa *'),
                                    _buildTextField(
                                      controlador: _placaVehiculoCtrl,
                                      hint: 'Ej. ABC123',
                                      inputFormatters: [
                                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                        TextInputFormatter.withFunction((oldValue, newValue) {
                                          return TextEditingValue(
                                            text: newValue.text.toUpperCase(),
                                            selection: newValue.selection,
                                          );
                                        }),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCampoBuscadorModal(label: 'Origen Vehículo *', hint: 'Empresa / Origen', controller: _origenVehiculoCtrl, getOpciones: () => _listaOrigenes),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  _buildLabel('Descripción / Observaciones Detalladas *'),
                  _buildTextField(controlador: _descripcionCtrl, hint: 'Añada comentarios o detalles adicionales...', maxLines: 3),
                ],
              ),
              const SizedBox(height: 15),

              // 3️⃣ PERSONAL Y ASIGNACIÓN
              _buildSeccionCard(
                titulo: 'Personal y Asignación',
                hijos: [
                  _buildCampoBuscadorModal(label: 'Supervisor Encargado *', hint: 'Seleccionar Supervisor...', controller: _supervisorCtrl, getOpciones: () => _listaSupervisores),
                  const SizedBox(height: 15),
                  _buildCampoBuscadorModal(label: 'Personal Involucrado *', hint: 'Seleccionar Personal...', controller: _personalCtrl, getOpciones: () => _listaPersonal),
                ],
              ),
              const SizedBox(height: 15),

              // 4️⃣ EVIDENCIAS FOTOGRÁFICAS
              _buildSeccionCard(
                titulo: 'Fotografías de Evidencia',
                hijos: [
                  Row(
                    children: [
                      Expanded(child: _buildFotoCajaEdicion('EVIDENCIA EVENTO', _nuevaEvidenciaEvento, _urlFotoEventoActual, () => _mostrarOpcionesOrigenImagen(true))),
                      const SizedBox(width: 15),
                      Expanded(child: _buildFotoCajaEdicion('EVIDENCIA CAUSANTE', _nuevaEvidenciaCausante, _urlFotoCausanteActual, () => _mostrarOpcionesOrigenImagen(false))),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),

              // 5️⃣ FIRMA CONCILIADOR (SOLO LECTURA)
              _buildSeccionCard(
                titulo: 'Conciliador y Firma 🔒',
                hijos: [
                  _buildCampoBuscadorModal(
                    label: 'Seleccionar Conciliador *',
                    hint: 'Seleccionar Conciliador...',
                    controller: _conciliadorCtrl,
                    getOpciones: () => _listaConciliadores,
                  ),
                  const SizedBox(height: 15),
                  _buildLabel('Firma del Conciliador Guardada (Solo Lectura)'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (_firmaBloqueada.startsWith('http'))
                          Image.network(_firmaBloqueada, height: 90, fit: BoxFit.contain)
                        else
                          Container(
                            height: 70,
                            alignment: Alignment.center,
                            child: Text(_firmaBloqueada, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                          ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text('La firma registrada no se puede alterar', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // 💾 BOTÓN DE GUARDAR CAMBIOS
              ElevatedButton.icon(
                onPressed: _guardarCambios,
                icon: const Icon(Icons.save_rounded),
                label: const Text('GUARDAR CAMBIOS EN REPORTE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampoBuscadorModal({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> Function() getOpciones,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        InkWell(
          onTap: () => _abrirModalBuscador(titulo: label, getOpciones: getOpciones, controller: controller),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: controller.text.isEmpty ? Colors.black38 : Colors.black87,
                      fontWeight: controller.text.isEmpty ? FontWeight.normal : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded, color: Color(0xFF0D47A1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCard({required String titulo, required List<Widget> hijos}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: Color(0xFFEEEEEE), thickness: 1.5)),
          ...hijos,
        ],
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controlador,
    required String hint,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controlador,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5)),
      ),
    );
  }

  Widget _buildDropdownSimple({required String? valor, required String hint, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: Colors.black38, fontSize: 14)),
      value: valor,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFotoCajaEdicion(String titulo, File? nuevaFoto, String? urlFotoActual, VoidCallback onTap) {
    Widget contenidoImagen;

    if (nuevaFoto != null) {
      contenidoImagen = Image.file(nuevaFoto, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (urlFotoActual != null && urlFotoActual.startsWith('http')) {
      contenidoImagen = Image.network(urlFotoActual, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      contenidoImagen = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Icon(Icons.add_a_photo_outlined, color: Colors.black54),
          const SizedBox(height: 6),
          const Text('Sin foto guardada', style: TextStyle(fontSize: 10, color: Colors.black38)),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: contenidoImagen),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}