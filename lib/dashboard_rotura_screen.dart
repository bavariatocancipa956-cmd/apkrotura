import 'package:flutter/material.dart';
import 'api_service.dart';

class DashboardRoturaScreen extends StatefulWidget {
  const DashboardRoturaScreen({super.key});

  @override
  State<DashboardRoturaScreen> createState() => _DashboardRoturaScreenState();
}

class _DashboardRoturaScreenState extends State<DashboardRoturaScreen> {
  bool _cargando = true;
  List<dynamic> _registrosTotales = [];
  List<dynamic> _registrosFiltrados = [];

  // Filtros
  String _anioFiltro = 'Todos';
  String _mesFiltro = 'Todos';
  String _turnoFiltro = 'Todos';
  String _areaFiltro = 'Todos';

  List<String> _aniosDisponibles = ['Todos'];
  List<String> _mesesDisponibles = ['Todos'];
  List<String> _turnosDisponibles = ['Todos'];
  List<String> _areasDisponibles = ['Todos'];

  // Agrupaciones y Métricas
  int _totalReportes = 0;
  double _totalMermas = 0;
  double _totalHl = 0; // 🍺 Métrica acumulada para HL Total
  Map<String, int> _causales = {};
  Map<String, int> _sectores = {};
  Map<String, Map<String, dynamic>> _opms = {};
  List<dynamic> _historico = [];

  // Nombres de meses para el filtro
  final Map<String, String> _nombresMeses = {
    '01': 'Enero', '02': 'Febrero', '03': 'Marzo', '04': 'Abril',
    '05': 'Mayo', '06': 'Junio', '07': 'Julio', '08': 'Agosto',
    '09': 'Septiembre', '10': 'Octubre', '11': 'Noviembre', '12': 'Diciembre'
  };

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final datos = await ApiService.consultar('roturas', 'reportes_rotura');
      _registrosTotales = datos;
      _extraerOpcionesFiltros();
      _aplicarFiltros();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _extraerOpcionesFiltros() {
    Set<String> anios = {};
    Set<String> meses = {};
    Set<String> turnos = {};
    Set<String> areas = {};

    for (var reg in _registrosTotales) {
      final fecha = reg['fecha_evento']?.toString() ?? '';
      if (fecha.length >= 10) {
        anios.add(fecha.substring(0, 4));
        meses.add(fecha.substring(5, 7));
      }

      final turno = reg['turno']?.toString().trim();
      if (turno != null && turno.isNotEmpty && turno.toUpperCase() != 'NULL') {
        turnos.add(turno);
      }

      final area = reg['ubicacion']?.toString().trim();
      if (area != null && area.isNotEmpty && area.toUpperCase() != 'NULL') {
        areas.add(area);
      }
    }

    _aniosDisponibles = ['Todos', ...anios.toList()..sort()];
    _mesesDisponibles = ['Todos', ...meses.toList()..sort()];
    _turnosDisponibles = ['Todos', ...turnos.toList()..sort()];
    _areasDisponibles = ['Todos', ...areas.toList()..sort()];
  }

  void _aplicarFiltros() {
    _registrosFiltrados = _registrosTotales.where((reg) {
      final fecha = reg['fecha_evento']?.toString() ?? '';
      final anioReg = fecha.length >= 4 ? fecha.substring(0, 4) : '';
      final mesReg = fecha.length >= 7 ? fecha.substring(5, 7) : '';
      final turnoReg = reg['turno']?.toString().trim() ?? '';
      final areaReg = reg['ubicacion']?.toString().trim() ?? '';

      if (_anioFiltro != 'Todos' && anioReg != _anioFiltro) return false;
      if (_mesFiltro != 'Todos' && mesReg != _mesFiltro) return false;
      if (_turnoFiltro != 'Todos' && turnoReg != _turnoFiltro) return false;
      if (_areaFiltro != 'Todos' && areaReg != _areaFiltro) return false;

      return true;
    }).toList();

    _calcularMetricas();
  }

  void _calcularMetricas() {
    _totalReportes = _registrosFiltrados.length;
    _totalMermas = 0;
    _totalHl = 0;
    _causales.clear();
    _sectores.clear();
    _opms.clear();

    // Ordenar por ID descendente
    _registrosFiltrados.sort((a, b) {
      final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
      final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      return idB.compareTo(idA);
    });

    _historico = _registrosFiltrados.take(15).toList();

    for (var reg in _registrosFiltrados) {
      // 1. Acumulado de Mermas (Unidades)
      final cant = double.tryParse(reg['cantidad']?.toString() ?? '0') ?? 0;
      _totalMermas += cant;

      // 2. Acumulado de HL Total (Soporta coma ',' o punto '.' decimal)
      final String hlStr = reg['hl_total']?.toString().replaceAll(',', '.') ?? '0';
      final cantHl = double.tryParse(hlStr) ?? 0;
      _totalHl += cantHl;

      // 3. Causales
      final causal = reg['causal']?.toString().trim() ?? 'Sin clasificar';
      _causales[causal] = (_causales[causal] ?? 0) + 1;

      // 4. Ubicación / Sector
      final sector = reg['ubicacion']?.toString().trim() ?? 'Sin ubicación';
      _sectores[sector] = (_sectores[sector] ?? 0) + 1;

      // 5. Personal / OPM
      String opm = reg['personal']?.toString().trim().toUpperCase() ?? '';
      if (opm.isEmpty || opm == 'NULL') opm = 'SIN ASIGNAR';

      if (!_opms.containsKey(opm)) {
        _opms[opm] = {'reportes': 0, 'roturas': 0.0};
      }
      _opms[opm]!['reportes'] += 1;
      _opms[opm]!['roturas'] += cant;
    }

    // Ordenar mapas
    _causales = Map.fromEntries(_causales.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));
    _sectores = Map.fromEntries(_sectores.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));
    _opms = Map.fromEntries(_opms.entries.toList()..sort((e1, e2) => (e2.value['roturas'] as double).compareTo(e1.value['roturas'] as double)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Dashboard de Roturas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : RefreshIndicator(
        onRefresh: _cargarDatos,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTarjetasKPI(),
            const SizedBox(height: 15),
            _buildFiltros(),
            const SizedBox(height: 15),
            _buildCausales(),
            const SizedBox(height: 15),
            _buildSectores(),
            const SizedBox(height: 15),
            _buildDesgloseOPM(),
            const SizedBox(height: 15),
            _buildHistorico(),
            const SizedBox(height: 20),
            const Center(child: Text('Desarrollado por: Gerardo Rodriguez', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================
  // COMPONENTES DE LA UI
  // ============================

  Widget _buildTarjetasKPI() {
    return Row(
      children: [
        Expanded(
          child: _buildCardKPI(
            titulo: 'TOTAL REPORTES',
            valor: '$_totalReportes',
            icono: Icons.assignment_outlined,
            colorIcono: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCardKPI(
            titulo: 'MERMAS (UND)',
            valor: _totalMermas.toStringAsFixed(0),
            icono: Icons.show_chart_rounded,
            colorIcono: Colors.orange.shade800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCardKPI(
            titulo: 'HL TOTAL',
            valor: _totalHl.toStringAsFixed(2),
            icono: Icons.opacity_rounded,
            colorIcono: Colors.teal.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildCardKPI({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color colorIcono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icono, color: colorIcono, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 8),
              const Text('Filtros de Control Logístico', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildDropdown('Año', _anioFiltro, _aniosDisponibles, (v) => setState(() { _anioFiltro = v!; _aplicarFiltros(); }))),
              const SizedBox(width: 15),
              Expanded(child: _buildDropdown('Mes', _mesFiltro, _mesesDisponibles, (v) => setState(() { _mesFiltro = v!; _aplicarFiltros(); }), isMes: true)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildDropdown('Turno', _turnoFiltro, _turnosDisponibles, (v) => setState(() { _turnoFiltro = v!; _aplicarFiltros(); }))),
              const SizedBox(width: 15),
              Expanded(child: _buildDropdown('Área / Ubicación', _areaFiltro, _areasDisponibles, (v) => setState(() { _areaFiltro = v!; _aplicarFiltros(); }))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String valor, List<String> opciones, Function(String?) onChanged, {bool isMes = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: valor,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
              items: opciones.map((String opt) {
                String display = opt;
                if (isMes && opt != 'Todos') {
                  display = _nombresMeses[opt] ?? opt;
                }
                return DropdownMenuItem<String>(value: opt, child: Text(display));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCausales() {
    int maxValor = _causales.isEmpty ? 1 : _causales.values.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ANÁLISIS DE CAUSALES DE ROTURA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
          const SizedBox(height: 15),
          if (_causales.isEmpty)
            const Text('No hay datos', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ..._causales.entries.map((e) {
            double proporcion = e.value / maxValor;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))),
                      Text('${e.value} rep.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: proporcion,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectores() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AFECTACIÓN POR SECTOR / LÍNEA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(6)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ÁREA DE TRABAJO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('INCIDENCIAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_sectores.isEmpty)
            const Text('No hay datos', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ..._sectores.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Text('${e.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDesgloseOPM() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DESGLOSE DE REPORTES POR OPM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(6)),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('COLABORADOR (OPM)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 1, child: Text('REPORTES', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 1, child: Text('ROTURAS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_opms.isEmpty)
            const Text('No hay datos', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ..._opms.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(e.key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('${e.value['reportes']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('${(e.value['roturas'] as double).toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistorico() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HISTÓRICO RECIENTE DE MERMAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
          const SizedBox(height: 15),
          if (_historico.isEmpty)
            const Text('No hay datos recientes', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ..._historico.map((reg) {
            final area = reg['ubicacion']?.toString().toUpperCase() ?? 'N/A';
            final causal = reg['causal']?.toString() ?? 'Sin causal';

            String opm = reg['personal']?.toString().toUpperCase() ?? '';
            if (opm.isEmpty || opm == 'NULL') opm = 'SIN ASIGNAR';

            final cant = double.tryParse(reg['cantidad']?.toString() ?? '0') ?? 0;

            final String hlStr = reg['hl_total']?.toString().replaceAll(',', '.') ?? '0';
            final cantHl = double.tryParse(hlStr) ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(area, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Causal: $causal • OPM: $opm', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('-${cant.toStringAsFixed(0)} Und', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      ),
                      const SizedBox(height: 2),
                      Text('${cantHl.toStringAsFixed(3)} HL', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}