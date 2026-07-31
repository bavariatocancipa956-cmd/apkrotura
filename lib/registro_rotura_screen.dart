import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'api_service.dart';
import 'api_whatsapp.dart';

class ProductoAfectado {
  TextEditingController skuCtrl = TextEditingController();
  TextEditingController cantCtrl = TextEditingController();
}

class RegistroRoturaScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const RegistroRoturaScreen({super.key, required this.usuario});

  @override
  State<RegistroRoturaScreen> createState() => _RegistroRoturaScreenState();
}

class _RegistroRoturaScreenState extends State<RegistroRoturaScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _estaCargando = true;
  bool _guardando = false;

  // 👤 NOMBRE AUTOMÁTICO DEL REPORTANTE
  String get _nombreReportante {
    final nombre = widget.usuario['nombre'] ?? widget.usuario['Nombre'] ?? widget.usuario['NOMBRE'];
    if (nombre != null && nombre.toString().trim().isNotEmpty) {
      return nombre.toString().trim().toUpperCase();
    }
    return 'OPERADOR';
  }

  // 📅 FECHA DE REGISTRO
  DateTime _fechaEvento = DateTime.now();
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

  List<String> _listaUbicaciones = [];
  List<String> _listaZonas = [];
  List<String> _listaEscenarios = [];
  List<String> _listaCausales = [];
  List<String> _listaSupervisores = [];
  List<String> _listaPersonal = [];
  List<String> _listaConciliadores = [];
  List<String> _listaSkus = [];

  List<String> _listaOrigenes = [];
  Map<String, String> _mapaCorreosOrigen = {};

  final List<ProductoAfectado> _productos = [ProductoAfectado()];

  File? _evidenciaEvento;
  File? _evidenciaCausante;

  File? _archivoFirmaProcesado;

  // 🚚 CONDICIÓN DE VEHÍCULO
  bool get _mostrarDatosVehiculo {
    final causalLimpia = _causalCtrl.text.trim().toLowerCase();
    return causalLimpia == 'vehiculo t1 condiciones no optimas' ||
        causalLimpia == 'vehiculo t2 condiciones no optimas';
  }

  // 🧹 LIMPIEZA VISUAL DE CÉDULAS / GUIONES
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
    _cargarListasDesdeBD();
  }

  Future<void> _cargarListasDesdeBD() async {
    setState(() => _estaCargando = true);
    try {
      final datosLista = await ApiService.consultar('roturas', 'rotura_lista');
      final datosOrigen = await ApiService.consultar('roturas', 'rotura_origen');
      final datosSku = await ApiService.consultar('roturas', 'rotura_sku_maestro');

      final Set<String> ubiSet = {};
      final Set<String> zonaSet = {};
      final Set<String> escSet = {};
      final Set<String> causalSet = {};
      final Set<String> supSet = {};
      final Set<String> perSet = {};
      final Set<String> conSet = {};
      final Set<String> skuSet = {};

      final Set<String> origenSet = {};
      final Map<String, String> mapaOrigen = {};

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
          String? correo = filaMap['emails']?.toString();

          if (origen != null && origen.trim().isNotEmpty) {
            origenSet.add(origen.trim());
            if (correo != null && correo.trim().isNotEmpty) {
              mapaOrigen[origen.trim()] = correo.trim();
            }
          }
        }
      }

      for (var fila in datosSku) {
        if (fila is Map) {
          final Map<String, dynamic> filaMap = {};
          fila.forEach((key, value) {
            filaMap[key.toString().toLowerCase()] = value;
          });

          String? sku = filaMap['sku_indentificacion']?.toString();
          if (sku != null && sku.trim().isNotEmpty) {
            skuSet.add(sku.trim());
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
          _listaSkus = skuSet.toList()..sort();

          _listaOrigenes = origenSet.toList()..sort();
          _mapaCorreosOrigen = mapaOrigen;

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

  // 🗜️ FUNCIÓN AUXILIAR PARA GARANTIZAR COMPRESIÓN DE FOTO <= 30 KB
  Future<File> _comprimirFoto(File fotoOriginal, {int maxKB = 30}) async {
    int maxBytes = maxKB * 1024;
    if (await fotoOriginal.length() <= maxBytes) {
      return fotoOriginal;
    }

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

  // 📷 TOMAR FOTO (Paso inicial ajustado + Compresión dinámica <= 30KB)
  Future<void> _tomarFoto(bool esEvento) async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 15, // Ajustado a 15 para menor peso base
      maxWidth: 500,    // Reducido de 800 a 500
      maxHeight: 500,
    );

    if (foto != null) {
      File fotoComprimida = await _comprimirFoto(File(foto.path), maxKB: 30);

      setState(() {
        if (esEvento) {
          _evidenciaEvento = fotoComprimida;
        } else {
          _evidenciaCausante = fotoComprimida;
        }
      });
    }
  }

  void _abrirModalFirma() {
    final GlobalKey modalFirmaKey = GlobalKey();
    List<Offset?> puntosModal = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.draw_rounded, color: Color(0xFF0D47A1)),
                      SizedBox(width: 8),
                      Text('Firma Conciliador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Dibuja la firma en el recuadro inferior:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: modalFirmaKey,
                    child: Container(
                      height: 180,
                      width: double.maxFinite,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Listener(
                        onPointerDown: (event) {
                          setModalState(() => puntosModal.add(event.localPosition));
                        },
                        onPointerMove: (event) {
                          setModalState(() => puntosModal.add(event.localPosition));
                        },
                        onPointerUp: (event) {
                          setModalState(() => puntosModal.add(null));
                        },
                        child: CustomPaint(
                          painter: _FirmaPainter(puntosModal),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setModalState(() => puntosModal.clear());
                      },
                      icon: const Icon(Icons.cleaning_services_rounded, color: Colors.red, size: 16),
                      label: const Text('Limpiar Trazo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (puntosModal.where((p) => p != null).isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Por favor realiza la firma antes de guardar.')),
                      );
                      return;
                    }

                    // ✍️ COMPRESIÓN DE FIRMA <= 10 KB
                    try {
                      RenderRepaintBoundary boundary = modalFirmaKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

                      double pixelRatio = 1.0; // Ratio óptimo para bajo peso
                      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
                      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                      Uint8List pngBytes = byteData!.buffer.asUint8List();

                      // Bucle dinámico para asegurar <= 10 KB (10240 Bytes)
                      while (pngBytes.lengthInBytes > 10 * 1024 && pixelRatio > 0.2) {
                        pixelRatio -= 0.15;
                        image = await boundary.toImage(pixelRatio: pixelRatio);
                        byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        if (byteData != null) {
                          pngBytes = byteData.buffer.asUint8List();
                        }
                      }

                      final tempDir = Directory.systemTemp;
                      final file = File('${tempDir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png');
                      await file.writeAsBytes(pngBytes, flush: true);

                      setState(() {
                        _archivoFirmaProcesado = file;
                      });
                    } catch (e) {
                      debugPrint("Error al procesar firma: $e");
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar Firma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _generarPdfBase64EnMemoria(File archivoFirma) async {
    final pdf = pw.Document();

    final imgFirma = pw.MemoryImage(archivoFirma.readAsBytesSync());
    pw.MemoryImage? imgEvento;
    pw.MemoryImage? imgCausante;

    if (_evidenciaEvento != null) imgEvento = pw.MemoryImage(_evidenciaEvento!.readAsBytesSync());
    if (_evidenciaCausante != null) imgCausante = pw.MemoryImage(_evidenciaCausante!.readAsBytesSync());

    final String placaPdf = _mostrarDatosVehiculo && _placaVehiculoCtrl.text.trim().isNotEmpty
        ? _placaVehiculoCtrl.text.trim()
        : 'NO APLICA';

    final String origenPdf = _mostrarDatosVehiculo && _origenVehiculoCtrl.text.trim().isNotEmpty
        ? _origenVehiculoCtrl.text.trim()
        : 'NO APLICA';

    pdf.addPage(
        pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(35),
            build: (pw.Context context) {
              return [
                pw.Header(
                    level: 0,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('INFORME OFICIAL DE ROTURA LOGISTICA',
                              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text('Sistema de Control de Calidad e Inventario',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ]
                    )
                ),
                pw.SizedBox(height: 10),

                pw.Text('1. DATOS GENERALES DEL INCIDENTE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Divider(color: PdfColors.blue900),
                pw.TableHelper.fromTextArray(
                  context: context,
                  cellPadding: const pw.EdgeInsets.all(4),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  data: <List<String>>[
                    ['Operador Reportante', _nombreReportante],
                    ['Fecha del Registro', _fechaEvento.toIso8601String().split('T')[0]],
                    ['Turno / Area', '$_turno / $_area'],
                    ['Ubicacion / Zona', '${_ubicacionCtrl.text} / ${_zonaCtrl.text}'],
                    ['Escenario', _escenarioCtrl.text],
                    ['Causal Especifica', _causalCtrl.text],
                    ['Placa Vehiculo', placaPdf],
                    ['Origen Vehiculo', origenPdf],
                    ['Supervisor / Conciliador', '${_supervisorCtrl.text} / ${_conciliadorCtrl.text}'],
                    ['Personal Involucrado', _personalCtrl.text],
                  ],
                ),
                pw.SizedBox(height: 10),

                pw.Text('Observaciones / Descripcion:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Container(
                    margin: const pw.EdgeInsets.only(top: 4),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), color: PdfColors.amber50),
                    child: pw.Text(_descripcionCtrl.text.isEmpty ? 'Ninguna observacion registrada.' : _descripcionCtrl.text, style: const pw.TextStyle(fontSize: 10))
                ),
                pw.SizedBox(height: 12),

                pw.Text('2. PRODUCTOS AFECTADOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Divider(color: PdfColors.blue900),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headers: ['SKU', 'Cantidad Afectada'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  data: _productos.map((p) => [p.skuCtrl.text, p.cantCtrl.text]).toList(),
                ),
                pw.SizedBox(height: 15),

                pw.Text('3. EVIDENCIAS Y CONFORMIDAD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Divider(color: PdfColors.blue900),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imgEvento != null)
                        pw.Column(children: [
                          pw.Text('EVIDENCIA DEL EVENTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.SizedBox(height: 4),
                          pw.Image(imgEvento, width: 180, height: 180, fit: pw.BoxFit.contain),
                        ]),
                      if (imgCausante != null)
                        pw.Column(children: [
                          pw.Text('EVIDENCIA DEL CAUSANTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.SizedBox(height: 4),
                          pw.Image(imgCausante, width: 180, height: 180, fit: pw.BoxFit.contain),
                        ]),
                    ]
                ),
                pw.SizedBox(height: 20),

                pw.Center(
                    child: pw.Column(
                        children: [
                          pw.Text('FIRMA CONCILIADOR / AUTORIZACION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                          pw.SizedBox(height: 4),
                          pw.Image(imgFirma, height: 65),
                          pw.SizedBox(width: 180, child: pw.Divider()),
                        ]
                    )
                ),
              ];
            }
        )
    );

    final Uint8List pdfBytes = await pdf.save();
    return base64Encode(pdfBytes);
  }

  // 🔒 GUARDAR Y VALIDAR TODO COMO OBLIGATORIO
  Future<void> _guardarReporte() async {
    if (_turno == null) {
      _mostrarAlertaValidacion('Falta seleccionar el Turno.');
      return;
    }
    if (_ubicacionCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar la Ubicación.');
      return;
    }
    if (_zonaCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar la Zona.');
      return;
    }
    if (_escenarioCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar el Escenario.');
      return;
    }
    if (_causalCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar la Causal Específica.');
      return;
    }
    if (_mostrarDatosVehiculo) {
      if (_placaVehiculoCtrl.text.trim().isEmpty) {
        _mostrarAlertaValidacion('Falta ingresar la Placa del Vehículo.');
        return;
      }
      if (_origenVehiculoCtrl.text.trim().isEmpty) {
        _mostrarAlertaValidacion('Falta seleccionar el Origen del Vehículo.');
        return;
      }
    }
    if (_descripcionCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta ingresar la Descripción / Observaciones.');
      return;
    }
    if (_supervisorCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar el Supervisor Encargado.');
      return;
    }
    if (_personalCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar el Personal Involucrado.');
      return;
    }

    final bool faltanProductos = _productos.any((p) => p.skuCtrl.text.trim().isEmpty || p.cantCtrl.text.trim().isEmpty);
    if (faltanProductos) {
      _mostrarAlertaValidacion('Por favor completa el SKU y Cantidad de todos los productos.');
      return;
    }

    if (_evidenciaEvento == null) {
      _mostrarAlertaValidacion('Falta tomar la Fotografía de Evidencia del Evento.');
      return;
    }
    if (_evidenciaCausante == null) {
      _mostrarAlertaValidacion('Falta tomar la Fotografía de Evidencia del Causante.');
      return;
    }
    if (_conciliadorCtrl.text.trim().isEmpty) {
      _mostrarAlertaValidacion('Falta seleccionar el Conciliador.');
      return;
    }
    if (_archivoFirmaProcesado == null) {
      _mostrarAlertaValidacion('Falta capturar la Firma del Conciliador.');
      return;
    }

    final String placaFinal = _mostrarDatosVehiculo && _placaVehiculoCtrl.text.trim().isNotEmpty
        ? _placaVehiculoCtrl.text.trim()
        : 'NO APLICA';

    final String origenFinal = _mostrarDatosVehiculo && _origenVehiculoCtrl.text.trim().isNotEmpty
        ? _origenVehiculoCtrl.text.trim()
        : 'NO APLICA';

    setState(() => _guardando = true);

    try {
      String? urlFotoEvento;
      String? urlFotoCausante;
      String? urlFotoFirma;
      String? pdfBase64;

      if (_evidenciaEvento != null) urlFotoEvento = await ApiService.subirFoto('evidencia_evento', _evidenciaEvento!);
      if (_evidenciaCausante != null) urlFotoCausante = await ApiService.subirFoto('evidencia_causante', _evidenciaCausante!);

      urlFotoFirma = await ApiService.subirFoto('firma_conciliador', _archivoFirmaProcesado!);

      final String valorFirmaBD = (urlFotoFirma != null && urlFotoFirma.startsWith('http'))
          ? urlFotoFirma
          : 'Firma_Registrada';

      pdfBase64 = await _generarPdfBase64EnMemoria(_archivoFirmaProcesado!);

      for (var producto in _productos) {
        Map<String, dynamic> datosDeRotura = {
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
          'reportante': _nombreReportante,
          'firma_conciliador': valorFirmaBD,
          'evidencia_evento': urlFotoEvento,
          'evidencia_causante': urlFotoCausante,
          'sku': producto.skuCtrl.text.trim(),
          'cantidad': double.tryParse(producto.cantCtrl.text.trim()) ?? 0,
        };

        await ApiService.insertar('roturas', 'reportes_rotura', datosDeRotura);
      }

      // 📱 NOTIFICACIÓN DE WHATSAPP
      try {
        final String listaProdTxt = _productos
            .map((p) => '  • *SKU:* ${p.skuCtrl.text.trim()} - *Cant:* ${p.cantCtrl.text.trim()}')
            .join('\n');

        final String mensajeWhatsapp = '''
🚨 *ALERTA: NUEVO REPORTE DE ROTURA*

👤 *Reportante:* $_nombreReportante
📅 *Fecha:* ${_fechaEvento.toIso8601String().split('T')[0]}
📍 *Ubicación / Zona:* ${_ubicacionCtrl.text.trim()} - ${_zonaCtrl.text.trim()}
🎬 *Escenario:* ${_escenarioCtrl.text.trim()}
⚠️ *Causal:* ${_causalCtrl.text.trim()}
👮 *Supervisor:* ${_supervisorCtrl.text.trim()}
👷 *Personal Involucrado:* ${_personalCtrl.text.trim()}
${_mostrarDatosVehiculo ? '🚛 *Placa / Origen:* $placaFinal - $origenFinal\n' : ''}
📦 *PRODUCTOS AFECTADOS:*
$listaProdTxt

📝 *Observaciones:* ${_descripcionCtrl.text.trim()}
''';

        await ApiWhatsapp.notificarRotura(
          mensaje: mensajeWhatsapp,
          urlImagen: urlFotoEvento,
        );
      } catch (e) {
        debugPrint("Error notificando por WhatsApp: $e");
      }

      // 📧 DISPARO DE CORREOS
      try {
        final String origenSeleccionado = origenFinal;
        List<String> listaCorreosEnviar = [];

        if (origenSeleccionado != 'NO APLICA' && _mapaCorreosOrigen.containsKey(origenSeleccionado)) {
          listaCorreosEnviar.add(_mapaCorreosOrigen[origenSeleccionado]!);
        }

        final listaCorreosBD = await ApiService.consultar('roturas', 'rotura_email');
        for (var fila in listaCorreosBD) {
          if (fila is Map) {
            final Map<String, dynamic> filaMap = {};
            fila.forEach((key, value) {
              filaMap[key.toString().toLowerCase()] = value;
            });

            String? est = filaMap['estado']?.toString().toUpperCase();
            String? mail = filaMap['correo_electronico']?.toString() ?? filaMap['email']?.toString();

            if (est == 'ACTIVO' && mail != null && mail.trim().isNotEmpty) {
              listaCorreosEnviar.add(mail.trim());
            }
          }
        }

        final correosDestino = listaCorreosEnviar.toSet().join(', ');

        final String listaProductosHtml = _productos.map((p) => '''
          <tr style="border-bottom: 1px solid #eee;">
            <td style="padding: 10px; font-weight: bold; color: #333;">${p.skuCtrl.text}</td>
            <td style="padding: 10px; text-align: center; font-weight: bold; color: #d32f2f;">${p.cantCtrl.text}</td>
          </tr>
        ''').join('');

        final String fotoEventoHtml = urlFotoEvento != null ? '''
          <td style="width: 50%; padding: 10px; text-align: center; vertical-align: top;">
            <p style="margin: 0 0 8px 0; font-weight: bold; font-size: 11px; color: #555;">EVIDENCIA DEL EVENTO</p>
            <img src="$urlFotoEvento" style="width: 100%; max-height: 200px; object-fit: contain; border-radius: 6px; border: 1px solid #ccc;">
          </td>
        ''' : '';

        final String fotoCausanteHtml = urlFotoCausante != null ? '''
          <td style="width: 50%; padding: 10px; text-align: center; vertical-align: top;">
            <p style="margin: 0 0 8px 0; font-weight: bold; font-size: 11px; color: #555;">EVIDENCIA DEL CAUSANTE</p>
            <img src="$urlFotoCausante" style="width: 100%; max-height: 200px; object-fit: contain; border-radius: 6px; border: 1px solid #ccc;">
          </td>
        ''' : '';

        final String fotoFirmaHtml = (urlFotoFirma != null && urlFotoFirma.startsWith('http')) ? '''
          <div style="margin-top: 20px; text-align: center;">
            <p style="margin: 0 0 5px 0; font-weight: bold; font-size: 11px; color: #555;">FIRMA CONCILIADOR / AUTORIZACIÓN</p>
            <img src="$urlFotoFirma" style="height: 70px; border-bottom: 1px solid #333; padding-bottom: 2px;">
          </div>
        ''' : '';

        final String datosVehiculoHtml = '''
          <tr><td style="padding: 8px; font-weight: bold;">Placa Vehículo:</td><td style="padding: 8px;">$placaFinal</td></tr>
          <tr style="background-color: #f9f9f9;"><td style="padding: 8px; font-weight: bold;">Origen Vehículo:</td><td style="padding: 8px;">$origenFinal</td></tr>
        ''';

        if (correosDestino.isNotEmpty) {
          await ApiService.enviarCorreo(
            esquemaCredenciales: 'administrador_principal',
            tablaCredenciales: 'smtp',
            para: correosDestino,
            asunto: '🚨 REPORTE OFICIAL DE ROTURA LOGÍSTICA',
            html: '''
              <div style="font-family: Arial, sans-serif; color: #333; max-width: 650px; margin: auto; background-color: #ffffff; border: 1px solid #dcdcdc; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
                
                <div style="background-color: #0B4398; color: #ffffff; padding: 20px; text-align: center;">
                  <h2 style="margin: 0; font-size: 20px; letter-spacing: 1px; text-transform: uppercase;">INFORME OFICIAL DE ROTURA LOGÍSTICA</h2>
                  <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.9;">Sistema de Control de Calidad e Inventario</p>
                </div>

                <div style="padding: 25px;">
                  
                  <h3 style="margin-top: 0; color: #0B4398; font-size: 14px; text-transform: uppercase; border-bottom: 2px solid #0B4398; padding-bottom: 5px;">1. DATOS GENERALES DEL INCIDENTE</h3>
                  <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
                    <tr style="background-color: #f9f9f9;"><td style="padding: 8px; font-weight: bold; width: 40%;">Operador Reportante:</td><td style="padding: 8px;">$_nombreReportante</td></tr>
                    <tr><td style="padding: 8px; font-weight: bold;">Fecha del Registro:</td><td style="padding: 8px;">${_fechaEvento.toIso8601String().split('T')[0]}</td></tr>
                    <tr style="background-color: #f9f9f9;"><td style="padding: 8px; font-weight: bold;">Turno / Área:</td><td style="padding: 8px;">$_turno / $_area</td></tr>
                    <tr><td style="padding: 8px; font-weight: bold;">Ubicación / Zona:</td><td style="padding: 8px;">${_ubicacionCtrl.text} - ${_zonaCtrl.text}</td></tr>
                    <tr style="background-color: #f9f9f9;"><td style="padding: 8px; font-weight: bold;">Escenario:</td><td style="padding: 8px;">${_escenarioCtrl.text}</td></tr>
                    <tr><td style="padding: 8px; font-weight: bold; color: #d32f2f;">Causal Específica:</td><td style="padding: 8px; font-weight: bold; color: #d32f2f;">${_causalCtrl.text}</td></tr>
                    $datosVehiculoHtml
                    <tr><td style="padding: 8px; font-weight: bold;">Supervisor / Conciliador:</td><td style="padding: 8px;">${_supervisorCtrl.text} / ${_conciliadorCtrl.text}</td></tr>
                    <tr style="background-color: #f9f9f9;"><td style="padding: 8px; font-weight: bold;">Personal Involucrado:</td><td style="padding: 8px;">${_personalCtrl.text}</td></tr>
                  </table>

                  <div style="margin-top: 15px; background-color: #FFFDE7; border: 1px solid #FFE082; padding: 12px; border-radius: 6px;">
                    <strong style="color: #8D6E63; font-size: 13px;">Observaciones / Descripción:</strong>
                    <p style="margin: 5px 0 0 0; color: #333; font-size: 13px;">${_descripcionCtrl.text.trim()}</p>
                  </div>

                  <br>

                  <h3 style="color: #0B4398; font-size: 14px; text-transform: uppercase; border-bottom: 2px solid #0B4398; padding-bottom: 5px;">2. PRODUCTOS AFECTADOS</h3>
                  <table style="width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 10px;">
                    <thead>
                      <tr style="background-color: #E3F2FD; color: #0B4398;">
                        <th style="padding: 10px; text-align: left;">SKU</th>
                        <th style="padding: 10px; text-align: center; width: 35%;">Cantidad Afectada</th>
                      </tr>
                    </thead>
                    <tbody>
                      $listaProductosHtml
                    </tbody>
                  </table>

                  <br>

                  <h3 style="color: #0B4398; font-size: 14px; text-transform: uppercase; border-bottom: 2px solid #0B4398; padding-bottom: 5px;">3. EVIDENCIAS Y CONFORMIDAD</h3>
                  <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
                    <tr>
                      $fotoEventoHtml
                      $fotoCausanteHtml
                    </tr>
                  </table>

                  $fotoFirmaHtml

                </div>

                <div style="background-color: #F4F6F9; padding: 15px; text-align: center; border-top: 1px solid #E0E0E0; font-size: 11px; color: #777;">
                  Documento generado automáticamente por la aplicación de control de roturas.<br>
                  Desarrollado por: Gerardo Rodriguez
                </div>

              </div>
            ''',
            adjuntoBase64: pdfBase64,
          );
        } else {
          debugPrint("⚠️ No se encontraron correos destinatarios activos en BD.");
        }
      } catch (e) {
        debugPrint("Error al enviar correo: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Reporte registrado, enviando notificaciones...')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _mostrarAlertaValidacion(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ $mensaje'), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 4)),
    );
  }

  void _abrirModalBuscador({
    required String titulo,
    required List<String> Function() getOpciones,
    required TextEditingController controller,
  }) async {
    if (getOpciones().isEmpty) {
      await _cargarListasDesdeBD();
    }

    if (!mounted) return;

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
                        Expanded(
                          child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)), overflow: TextOverflow.ellipsis),
                        ),
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
                      onChanged: (val) {
                        setModalState(() => filtro = val);
                      },
                    ),
                    const SizedBox(height: 15),
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
                      child: opcionesFiltradas.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No se encontraron coincidencias.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _cargarListasDesdeBD();
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Recargar BD'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                              )
                            ],
                          ),
                        ),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: opcionesFiltradas.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final opcion = opcionesFiltradas[index];
                          return ListTile(
                            title: Text(opcion, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            trailing: controller.text == opcion ? const Icon(Icons.check_circle, color: Color(0xFF0D47A1)) : null,
                            onTap: () {
                              setState(() {
                                controller.text = opcion;
                              });
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
        title: const Text('Módulo de Roturas', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
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
              Text(_estaCargando ? 'Cargando catálogos de BD...' : 'Enviando Reporte y Notificaciones...', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔷 TARJETA DEL REPORTANTE AUTOMÁTICO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 25, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.person, color: Color(0xFF0D47A1), size: 30)),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OPERADOR REPORTANTE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 3),
                        Text(_nombreReportante, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                  _buildTextField(controlador: _descripcionCtrl, hint: 'Añada comentarios o detalles adicionales obligatorios...', maxLines: 3),
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

              // 4️⃣ PRODUCTOS AFECTADOS
              _buildSeccionCard(
                titulo: 'Productos Afectados',
                hijos: [
                  ..._productos.asMap().entries.map((entry) {
                    int index = entry.key;
                    ProductoAfectado prod = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index == 0) _buildLabel('SKU *'),
                                InkWell(
                                  onTap: () => _abrirModalBuscador(
                                    titulo: 'Seleccionar SKU',
                                    getOpciones: () => _listaSkus,
                                    controller: prod.skuCtrl,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
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
                                            prod.skuCtrl.text.isEmpty ? 'Buscar SKU...' : prod.skuCtrl.text,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: prod.skuCtrl.text.isEmpty ? Colors.black38 : Colors.black87,
                                              fontWeight: prod.skuCtrl.text.isEmpty ? FontWeight.normal : FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.search_rounded, color: Color(0xFF0D47A1), size: 18),
                                      ],
                                    ),
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
                                if (index == 0) _buildLabel('Cant *'),
                                _buildTextField(controlador: prod.cantCtrl, hint: '#', esNumerico: true)
                              ],
                            ),
                          ),
                          if (index > 0) ...[
                            const SizedBox(width: 5),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _productos.removeAt(index)),
                            )
                          ]
                        ],
                      ),
                    );
                  }),

                  OutlinedButton.icon(
                    onPressed: () => setState(() => _productos.add(ProductoAfectado())),
                    icon: const Icon(Icons.add, color: Color(0xFF0D47A1)),
                    label: const Text('+ Agregar Otro Producto', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15),

              // 5️⃣ FOTOGRAFÍAS OBLIGATORIAS
              _buildSeccionCard(
                titulo: 'Fotografías Obligatorias *',
                hijos: [
                  Row(
                    children: [
                      Expanded(child: _buildFotoCaja('EVIDENCIA EVENTO *', _evidenciaEvento, () => _tomarFoto(true))),
                      const SizedBox(width: 15),
                      Expanded(child: _buildFotoCaja('EVIDENCIA CAUSANTE *', _evidenciaCausante, () => _tomarFoto(false))),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),

              // 6️⃣ FIRMA CONCILIADOR
              _buildSeccionCard(
                titulo: 'Firma Conciliador',
                hijos: [
                  _buildCampoBuscadorModal(
                    label: 'Seleccionar Conciliador *',
                    hint: 'Seleccionar Conciliador...',
                    controller: _conciliadorCtrl,
                    getOpciones: () => _listaConciliadores,
                  ),
                  const SizedBox(height: 15),

                  if (_archivoFirmaProcesado == null) ...[
                    OutlinedButton.icon(
                      onPressed: _abrirModalFirma,
                      icon: const Icon(Icons.draw_rounded, color: Color(0xFF0D47A1)),
                      label: const Text('Capturar Firma en Pantalla *', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('FIRMA REGISTRADA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Image.file(_archivoFirmaProcesado!, height: 90, fit: BoxFit.contain),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _abrirModalFirma,
                                icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0D47A1)),
                                label: const Text('Cambiar', style: TextStyle(color: Color(0xFF0D47A1))),
                              ),
                              const SizedBox(width: 15),
                              TextButton.icon(
                                onPressed: () => setState(() => _archivoFirmaProcesado = null),
                                icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                                label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 25),

              SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _guardarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text('REGISTRAR ROTURA EN SISTEMA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 15),
              const Center(child: Text('Desarrollado por: Gerardo Rodriguez', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
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
    bool esNumerico = false,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controlador,
      keyboardType: esNumerico ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: Colors.black38, fontSize: 14)),
      value: valor,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFotoCaja(String titulo, File? archivoFoto, VoidCallback onTap) {
    return Container(
      height: 140,
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid, width: 1.5), borderRadius: BorderRadius.circular(12)),
      child: archivoFoto != null
          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(archivoFoto, fit: BoxFit.cover, width: double.infinity))
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.black87),
            label: const Text('Cargar', style: TextStyle(color: Colors.black87)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300))),
          ),
          const SizedBox(height: 10),
          const Text('Sin archivo', style: TextStyle(fontSize: 10, color: Colors.black38)),
        ],
      ),
    );
  }
}

class _FirmaPainter extends CustomPainter {
  final List<Offset?> puntos;
  _FirmaPainter(this.puntos);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < puntos.length - 1; i++) {
      if (puntos[i] != null && puntos[i + 1] != null) {
        canvas.drawLine(puntos[i]!, puntos[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FirmaPainter oldDelegate) => true;
}