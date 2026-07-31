import 'package:flutter/material.dart';
import 'api_service.dart';

class EliminarRegistrosScreen extends StatefulWidget {
  const EliminarRegistrosScreen({super.key});

  @override
  State<EliminarRegistrosScreen> createState() => _EliminarRegistrosScreenState();
}

class _EliminarRegistrosScreenState extends State<EliminarRegistrosScreen> {
  bool _cargando = true;
  List<dynamic> _registrosTotales = [];
  List<dynamic> _registrosFiltrados = [];

  // Variables para los filtros
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

  // 🕒 EVALUAR SI PASARON MÁS DE 3 DÍAS
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

  Future<void> _eliminarRegistroConfirmado(dynamic registro) async {
    final dynamic idRegistro = registro['id'];
    final dynamic fechaEvento = registro['fecha_evento'];

    // 🔒 1. VALIDACIÓN DE 3 DÍAS
    if (_esMayorA3Dias(fechaEvento)) {
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
          content: const Text(
            'No es posible eliminar este registro porque han transcurrido más de 3 días desde la fecha del evento.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Diálogo de confirmación
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
                'Esta acción borrará el registro de la base de datos y destruirá '
                'las fotografías y firmas asociadas en el servidor de forma irreversible.',
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

    // 3. Ejecutar la eliminación
    setState(() => _cargando = true);
    try {
      await ApiService.eliminar('roturas', 'reportes_rotura', 'id', idRegistro);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registro y evidencias eliminados correctamente.')),
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
          // 🔎 ZONA DE FILTROS
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

          // 📋 LISTA DE REGISTROS
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

                  // Evaluar la regla de los 3 días
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
                      trailing: IconButton(
                        icon: Icon(
                          esExpirado ? Icons.lock_outline_rounded : Icons.delete_outline_rounded,
                          color: esExpirado ? Colors.grey : Colors.red,
                          size: 26,
                        ),
                        tooltip: esExpirado ? 'Bloqueado (> 3 días)' : 'Eliminar Registro',
                        onPressed: () => _eliminarRegistroConfirmado(registro),
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