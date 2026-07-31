import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_service.dart';

class DescargasScreen extends StatefulWidget {
  const DescargasScreen({super.key});

  @override
  State<DescargasScreen> createState() => _DescargasScreenState();
}

class _DescargasScreenState extends State<DescargasScreen> {
  bool _cargando = true;
  List<dynamic> _registrosTotales = [];
  List<dynamic> _registrosFiltrados = [];

  final TextEditingController _buscadorCtrl = TextEditingController();
  DateTime? _fechaFiltro;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
    _buscadorCtrl.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
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
        bool coincideBusqueda = true;
        bool coincideFecha = true;

        if (_buscadorCtrl.text.isNotEmpty) {
          final query = _buscadorCtrl.text.toLowerCase();
          final sku = reg['sku']?.toString().toLowerCase() ?? '';
          final reportante = reg['reportante']?.toString().toLowerCase() ?? '';
          final id = reg['id']?.toString() ?? '';

          coincideBusqueda = sku.contains(query) || reportante.contains(query) || id.contains(query);
        }

        if (_fechaFiltro != null) {
          final fechaReg = reg['fecha_evento']?.toString().split('T')[0] ?? '';
          final fechaFiltroStr = _fechaFiltro!.toIso8601String().split('T')[0];
          coincideFecha = fechaReg == fechaFiltroStr;
        }

        return coincideBusqueda && coincideFecha;
      }).toList();

      _registrosFiltrados.sort((a, b) {
        final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        return idB.compareTo(idA);
      });
    });
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF0D47A1), onPrimary: Colors.white, onSurface: Colors.black87),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Descargas y Visualización', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Column(
              children: [
                TextField(
                  controller: _buscadorCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por SKU, ID o Reportante...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                    suffixIcon: _buscadorCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _buscadorCtrl.clear(); FocusScope.of(context).unfocus(); })
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
                          _fechaFiltro == null ? 'Filtrar por Fecha Evento' : 'Fecha: ${_fechaFiltro!.toIso8601String().split('T')[0]}',
                          style: TextStyle(color: _fechaFiltro == null ? Colors.grey.shade700 : const Color(0xFF0D47A1), fontWeight: _fechaFiltro == null ? FontWeight.normal : FontWeight.bold),
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
                      IconButton(onPressed: () { setState(() { _fechaFiltro = null; _aplicarFiltros(); }); }, icon: const Icon(Icons.event_busy, color: Colors.red), tooltip: 'Limpiar Fecha')
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
                  Icon(Icons.picture_as_pdf_outlined, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  Text('No hay reportes para mostrar', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
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
                  final fecha = registro['fecha_evento']?.toString().split('T')[0] ?? 'Sin Fecha';
                  final reportante = registro['reportante']?.toString() ?? 'Desconocido';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0D47A1))),
                      title: Text('Reporte #$id - SKU: $sku', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Fecha: $fecha', style: const TextStyle(fontSize: 12)), Text('Rep: $reportante', style: const TextStyle(fontSize: 12))]),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => VisorPdfScreen(registro: registro)));
                        },
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text('Ver PDF', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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

// =========================================================================
// 📄 VISOR NATIVO DE PDF (Solo Firma de Conciliador)
// =========================================================================
class VisorPdfScreen extends StatelessWidget {
  final Map<String, dynamic> registro;

  const VisorPdfScreen({super.key, required this.registro});

  String _limpiarTexto(dynamic texto) {
    if (texto == null) return '';
    String str = texto.toString().trim();
    if (str.toLowerCase() == 'null' || str.isEmpty) return '';
    return str.replaceAll(RegExp(r'[^a-zA-Z0-9\s.,:;/@#\-_()ñÑáéíóúÁÉÍÓÚ]'), '');
  }

  Future<Uint8List> _generarDocumentoPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    Future<pw.ImageProvider?> obtenerImagenSegura(String? data) async {
      if (data == null || data.trim().isEmpty || data.toLowerCase() == 'null') return null;
      if (data.toLowerCase().contains('firma_registrada')) return null;

      try {
        if (data.startsWith('http')) {
          return await networkImage(data);
        } else {
          String cleanB64 = data;
          if (cleanB64.contains(',')) cleanB64 = cleanB64.split(',').last;
          cleanB64 = cleanB64.replaceAll(RegExp(r'\s+'), '');

          int padding = cleanB64.length % 4;
          if (padding > 0) cleanB64 += '=' * (4 - padding);

          final bytes = base64Decode(cleanB64);
          if (bytes.isNotEmpty) return pw.MemoryImage(bytes);
        }
      } catch (e) {
        debugPrint('⚠️ Ignorando imagen defectuosa: $e');
      }
      return null;
    }

    final imgEvento = await obtenerImagenSegura(registro['evidencia_evento']?.toString());
    final imgCausante = await obtenerImagenSegura(registro['evidencia_causante']?.toString());

    // Extracción segura de la firma
    final String firmaDB = registro['firma_conciliador']?.toString().trim() ?? '';
    final pw.ImageProvider? imgFirma = await obtenerImagenSegura(firmaDB);
    final bool esFirmaTexto = firmaDB.toLowerCase().contains('firma_registrada');

    final primaryColor = PdfColor.fromHex('#0D47A1');
    final secondaryColor = PdfColor.fromHex('#F4F6F9');

    List<List<String>> datosTabla = [];
    void agregarFila(String titulo, dynamic valor) {
      final String valLimpio = _limpiarTexto(valor);
      if (valLimpio.isNotEmpty && valLimpio.toLowerCase() != 'n/a') {
        datosTabla.add([titulo, valLimpio]);
      }
    }

    agregarFila('ID Reporte', registro['id']);
    agregarFila('Operador Reportante', registro['reportante']);
    agregarFila('Fecha del Registro', registro['fecha_evento']?.toString().split('T')[0]);

    String turno = _limpiarTexto(registro['turno']);
    String area = _limpiarTexto(registro['area']);
    if (turno.isNotEmpty || area.isNotEmpty) agregarFila('Turno / Área', '$turno / $area'.trim());

    String ubi = _limpiarTexto(registro['ubicacion']);
    String zona = _limpiarTexto(registro['zona']);
    if (ubi.isNotEmpty || zona.isNotEmpty) agregarFila('Ubicación / Zona', '$ubi / $zona'.trim());

    agregarFila('Causal Específica', registro['causal']);
    agregarFila('Placa Vehículo', registro['placa_vehiculo']);
    agregarFila('Origen Vehículo', registro['origen_vehiculo']);
    agregarFila('Supervisor Encargado', registro['supervisor']);
    agregarFila('Conciliador Autorizado', registro['conciliador']);
    agregarFila('Personal Involucrado (OPM)', registro['personal']);

    if (datosTabla.isEmpty) {
      datosTabla.add(['Información', 'Sin registros adicionales']);
    }

    final String descripcion = _limpiarTexto(registro['descripcion']);
    final String nombreConciliador = _limpiarTexto(registro['conciliador']);

    pdf.addPage(
        pw.MultiPage(
            pageFormat: format,
            // Redujimos los márgenes para que todo quepa en una sola hoja
            margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 25),
            footer: (context) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sistema Oficial de Control de Calidad e Inventarios', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ),
            build: (pw.Context context) {
              return [
                // 🏢 BANNER SUPERIOR INSTITUCIONAL
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('INFORME TÉCNICO DE ROTURA LOGÍSTICA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.SizedBox(height: 2),
                            pw.Text('Gestión de Calidad y Control de Mermas', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey200)),
                          ]
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('REPORTE #${registro['id'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      )
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // 1. SECCIÓN DE DATOS GENERALES
                pw.Row(
                    children: [
                      pw.Container(width: 4, height: 12, color: primaryColor),
                      pw.SizedBox(width: 6),
                      pw.Text('1. DATOS GENERALES DEL INCIDENTE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ]
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  context: context,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  headerDecoration: pw.BoxDecoration(color: secondaryColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey50),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  data: datosTabla,
                ),
                pw.SizedBox(height: 8),

                // OBSERVACIONES
                if (descripcion.isNotEmpty) ...[
                  pw.Text('Observaciones Técnicas / Descripción del Evento:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800)),
                  pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      padding: const pw.EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        color: PdfColors.amber50,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(descripcion, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900))
                  ),
                  pw.SizedBox(height: 10),
                ],

                // 2. PRODUCTO AFECTADO
                pw.Row(
                    children: [
                      pw.Container(width: 4, height: 12, color: primaryColor),
                      pw.SizedBox(width: 6),
                      pw.Text('2. RESUMEN DE PRODUCTO AFECTADO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ]
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headers: ['SKU / Código Producto', 'Cantidad Afectada'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: primaryColor),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  data: [
                    [_limpiarTexto(registro['sku']), _limpiarTexto(registro['cantidad'])]
                  ],
                ),
                pw.SizedBox(height: 12),

                // 3. EVIDENCIAS FOTOGRÁFICAS (Fotos más compactas para ahorrar espacio)
                if (imgEvento != null || imgCausante != null) ...[
                  pw.Row(
                      children: [
                        pw.Container(width: 4, height: 12, color: primaryColor),
                        pw.SizedBox(width: 6),
                        pw.Text('3. REGISTRO FOTOGRÁFICO DE EVIDENCIAS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ]
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (imgEvento != null)
                          pw.Container(
                            width: 200,
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Column(children: [
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                color: secondaryColor,
                                child: pw.Text('EVIDENCIA DEL EVENTO', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor)),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Image(imgEvento, height: 110, fit: pw.BoxFit.contain), // Altura reducida
                            ]),
                          ),
                        if (imgCausante != null)
                          pw.Container(
                            width: 200,
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Column(children: [
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                color: secondaryColor,
                                child: pw.Text('EVIDENCIA CAUSANTE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor)),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Image(imgCausante, height: 110, fit: pw.BoxFit.contain), // Altura reducida
                            ]),
                          ),
                      ]
                  ),
                  pw.SizedBox(height: 15),
                ],

                // ✍️ 4. FIRMA DEL CONCILIADOR (SOLA Y CENTRADA)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.white,
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('VALIDACIÓN Y AUTORIZACIÓN OFICIAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 10),
                      pw.Center(
                        child: pw.Column(
                          children: [
                            // Si hay foto real de la firma
                            if (imgFirma != null)
                              pw.Image(imgFirma, height: 35, fit: pw.BoxFit.contain)
                            // Si la BD dice "Firma_Registrada"
                            else if (esFirmaTexto)
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                                child: pw.Text('✔ FIRMADO DIGITALMENTE EN SISTEMA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2E7D32'))),
                              )
                            // Si la BD está NULL (vacía)
                            else
                              pw.SizedBox(height: 35),

                            pw.Container(width: 180, child: pw.Divider(color: PdfColors.grey500, thickness: 0.8)),
                            pw.SizedBox(height: 4),
                            pw.Text(nombreConciliador.isNotEmpty ? nombreConciliador : 'Nombre del Conciliador', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            pw.Text('CONCILIADOR AUTORIZADO', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            }
        )
    );

    return await pdf.save();
  }

  void _descargarPdfManualmente(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ Preparando archivo PDF...')));
    try {
      final bytes = await _generarDocumentoPdf(PdfPageFormat.a4);
      final nombreArchivo = 'Reporte_Rotura_${registro['id'] ?? 'Doc'}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al exportar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte #${registro['id'] ?? ''}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF0D47A1), size: 26),
            tooltip: 'Exportar / Compartir PDF',
            onPressed: () => _descargarPdfManualmente(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generarDocumentoPdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'Reporte_Rotura_${registro['id'] ?? 'Doc'}.pdf',
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
                  const SizedBox(height: 15),
                  const Text('Vista Previa No Disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  const Text('Tu dispositivo no soporta la previsualización nativa.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: () => _descargarPdfManualmente(context),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar / Compartir PDF Directamente', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )
                ],
              ),
            ),
          );
        },
        loadingWidget: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF0D47A1)),
                SizedBox(height: 15),
                Text('Generando informe corporativo...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
              ],
            )
        ),
      ),
    );
  }
}