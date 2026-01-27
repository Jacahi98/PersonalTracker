import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MiAppFinanciera());
}

class MiAppFinanciera extends StatelessWidget {
  const MiAppFinanciera({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Gastos',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5), // Indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}

// --- GESTOR DE BASE DE DATOS (SQLITE) ---
class DB {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = p.join(await getDatabasesPath(), 'gastos_pro.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE gastos(
            id TEXT PRIMARY KEY,
            titulo TEXT,
            monto REAL,
            fecha TEXT,
            categoria TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insert(Gasto gasto) async {
    final db = await database;
    return await db.insert('gastos', gasto.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Gasto>> getAll() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('gastos', orderBy: "fecha DESC");
    return List.generate(maps.length, (i) => Gasto.fromMap(maps[i]));
  }

  static Future<int> update(Gasto gasto) async {
    final db = await database;
    return await db.update('gastos', gasto.toMap(), where: 'id = ?', whereArgs: [gasto.id]);
  }

  static Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }
}

// --- MODELO ---
class Gasto {
  String id;
  String titulo;
  double monto;
  DateTime fecha;
  String categoria;

  Gasto({
    required this.id,
    required this.titulo,
    required this.monto,
    required this.fecha,
    required this.categoria,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'categoria': categoria,
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'],
      titulo: map['titulo'],
      monto: map['monto'],
      fecha: DateTime.parse(map['fecha']),
      categoria: map['categoria'] ?? 'Otros',
    );
  }
}

class CategoriaInfo {
  final IconData icono;
  final Color color;
  final String nombre;
  CategoriaInfo(this.icono, this.color, this.nombre);
}

final Map<String, CategoriaInfo> categoriasMap = {
  'Comida': CategoriaInfo(Icons.restaurant, Colors.orange, 'Comida'),
  'Transporte': CategoriaInfo(Icons.directions_car, Colors.blue, 'Transporte'),
  'Casa': CategoriaInfo(Icons.home, Colors.purple, 'Casa'),
  'Ocio': CategoriaInfo(Icons.movie, Colors.pink, 'Ocio'),
  'Salud': CategoriaInfo(Icons.local_hospital, Colors.red, 'Salud'),
  'Otros': CategoriaInfo(Icons.category, Colors.grey, 'Otros'),
};

// --- PANTALLA PRINCIPAL ---
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  List<Gasto> _misGastos = [];
  String _vistaGrafica = 'Semana';
  DateTimeRange? _rangoPersonalizado;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarGastos();
  }

  Future<void> _cargarGastos() async {
    final lista = await DB.getAll();
    setState(() {
      _misGastos = lista;
      _cargando = false;
    });
  }

  void _agregarOEditarGasto({Gasto? gastoExistente}) {
    final isEditing = gastoExistente != null;
    final tituloController = TextEditingController(text: isEditing ? gastoExistente.titulo : '');
    final montoController = TextEditingController(text: isEditing ? gastoExistente.monto.toString() : '');
    DateTime fechaSeleccionada = isEditing ? gastoExistente.fecha : DateTime.now();
    String categoriaSeleccionada = isEditing ? gastoExistente.categoria : 'Otros';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  top: 25, left: 20, right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text(isEditing ? 'Editar Gasto' : 'Nuevo Gasto', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 20),

                    TextField(
                      controller: tituloController,
                      decoration: InputDecoration(labelText: 'Concepto', prefixIcon: const Icon(Icons.edit), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: true,
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: montoController,
                      decoration: InputDecoration(labelText: 'Monto (€)', prefixIcon: const Icon(Icons.euro), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: fechaSeleccionada,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                locale: const Locale('es', 'ES'),
                              );
                              if (picked != null) setModalState(() => fechaSeleccionada = picked);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(labelText: 'Fecha', prefixIcon: const Icon(Icons.calendar_today), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              child: Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: categoriaSeleccionada,
                            decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            items: categoriasMap.keys.map((String key) {
                              return DropdownMenuItem<String>(
                                value: key,
                                child: Row(
                                  children: [
                                    Icon(categoriasMap[key]!.icono, size: 18, color: categoriasMap[key]!.color),
                                    const SizedBox(width: 8),
                                    Text(key, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) setModalState(() => categoriaSeleccionada = newValue);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final titulo = tituloController.text;
                          final monto = double.tryParse(montoController.text.replaceAll(',', '.'));
                          if (titulo.isEmpty || monto == null || monto <= 0) return;

                          final nuevoGasto = Gasto(
                            id: isEditing ? gastoExistente.id : DateTime.now().toString(),
                            titulo: titulo,
                            monto: monto,
                            fecha: fechaSeleccionada,
                            categoria: categoriaSeleccionada,
                          );

                          if (isEditing) {
                            await DB.update(nuevoGasto);
                          } else {
                            await DB.insert(nuevoGasto);
                          }

                          _cargarGastos();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('GUARDAR GASTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  void _borrarGasto(String id) async {
    await DB.delete(id);
    _cargarGastos();
  }

  // --- FUNCIÓN CORREGIDA PARA IOS ---
 Future<void> _exportarExcel() async {
    try {
      // 1. Crear datos
      List<List<dynamic>> rows = [];
      rows.add(["Fecha", "Categoría", "Concepto", "Monto"]);
      for (var gasto in _misGastos) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(gasto.fecha),
          gasto.categoria,
          gasto.titulo,
          gasto.monto
        ]);
      }
      String csvData = const ListToCsvConverter().convert(rows);

      // 2. Guardar archivo
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Gastos_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);
      
      // Espera de seguridad
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Comprobamos que el archivo existe antes de compartir
      if (!await file.exists()) {
         throw "El archivo no se pudo guardar";
      }

      // 3. COMPARTIR CON ORIGEN (El truco para iOS)
      final box = context.findRenderObject() as RenderBox?;
      
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Mis Gastos Exportados',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size, // <--- ESTO ES VITAL EN IOS
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _seleccionarRangoPersonalizado() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      saveText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _rangoPersonalizado = picked;
        _vistaGrafica = 'Personalizado';
      });
    } else {
      if (_vistaGrafica == 'Personalizado' && _rangoPersonalizado == null) {
        setState(() => _vistaGrafica = 'Semana');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Finanzas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.download), onPressed: _exportarExcel, tooltip: "Descargar Excel")],
      ),
      body: _indiceActual == 0 ? _buildListaGastos() : _buildGraficas(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (index) => setState(() => _indiceActual = index),
        elevation: 10,
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt_rounded), label: 'Mis Gastos'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Estadísticas'),
        ],
      ),
      floatingActionButton: _indiceActual == 0
          ? FloatingActionButton.extended(
        onPressed: () => _agregarOEditarGasto(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Añadir"),
      )
          : null,
    );
  }

  Widget _buildListaGastos() {
    if (_misGastos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text('¡Todo limpio!', style: TextStyle(fontSize: 20, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const Text('Añade tu primer gasto para empezar.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    double totalMes = 0;
    DateTime now = DateTime.now();
    for (var g in _misGastos) {
      if (g.fecha.month == now.month && g.fecha.year == now.year) totalMes += g.monto;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Gastado este mes", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 5),
              Text("${totalMes.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _misGastos.length,
            itemBuilder: (ctx, index) {
              final gasto = _misGastos[index];
              final catInfo = categoriasMap[gasto.categoria] ?? categoriasMap['Otros']!;

              return Dismissible(
                key: ValueKey(gasto.id),
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _borrarGasto(gasto.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: catInfo.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(catInfo.icono, color: catInfo.color),
                    ),
                    title: Text(gasto.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Row(
                      children: [
                        Text(gasto.categoria, style: TextStyle(color: catInfo.color, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Text(" • ", style: TextStyle(color: Colors.grey)),
                        Text(DateFormat('dd MMM yyyy', 'es').format(gasto.fecha), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: Text('-${gasto.monto.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    onTap: () => _agregarOEditarGasto(gastoExistente: gasto),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGraficas() {
    DateTime hoy = DateTime.now();
    DateTime inicioPeriodo;
    DateTime finPeriodo;

    if (_vistaGrafica == 'Semana') {
      inicioPeriodo = hoy.subtract(Duration(days: hoy.weekday - 1));
      inicioPeriodo = DateTime(inicioPeriodo.year, inicioPeriodo.month, inicioPeriodo.day);
      finPeriodo = inicioPeriodo.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else if (_vistaGrafica == 'Mes') {
      inicioPeriodo = DateTime(hoy.year, hoy.month, 1);
      finPeriodo = DateTime(hoy.year, hoy.month + 1, 0, 23, 59);
    } else if (_vistaGrafica == 'Año') {
      inicioPeriodo = DateTime(hoy.year, 1, 1);
      finPeriodo = DateTime(hoy.year, 12, 31, 23, 59);
    } else {
      if (_rangoPersonalizado == null) {
        inicioPeriodo = hoy;
        finPeriodo = hoy;
      } else {
        inicioPeriodo = _rangoPersonalizado!.start;
        finPeriodo = _rangoPersonalizado!.end.add(const Duration(hours: 23, minutes: 59));
      }
    }

    Map<int, double> datosGrafica = {};
    int cantidadBarras = 0;

    if (_vistaGrafica == 'Año') {
      cantidadBarras = 12;
      for (int i = 0; i < 12; i++) datosGrafica[i] = 0.0;
      for (var gasto in _misGastos) {
        if (gasto.fecha.isAfter(inicioPeriodo.subtract(const Duration(seconds: 1))) &&
            gasto.fecha.isBefore(finPeriodo)) {
          datosGrafica[gasto.fecha.month - 1] = (datosGrafica[gasto.fecha.month - 1] ?? 0) + gasto.monto;
        }
      }
    } else {
      int diasTotales = finPeriodo.difference(inicioPeriodo).inDays + 1;
      cantidadBarras = diasTotales;
      if (cantidadBarras > 365) cantidadBarras = 365;

      for (int i = 0; i < cantidadBarras; i++) datosGrafica[i] = 0.0;
      for (var gasto in _misGastos) {
        if (gasto.fecha.isAfter(inicioPeriodo.subtract(const Duration(seconds: 1))) &&
            gasto.fecha.isBefore(finPeriodo)) {
          int index = DateTime(gasto.fecha.year, gasto.fecha.month, gasto.fecha.day)
              .difference(DateTime(inicioPeriodo.year, inicioPeriodo.month, inicioPeriodo.day))
              .inDays;
          if (index >= 0 && index < cantidadBarras) {
            datosGrafica[index] = (datosGrafica[index] ?? 0) + gasto.monto;
          }
        }
      }
    }

    double total = datosGrafica.values.fold(0, (sum, x) => sum + x);
    String textoRango = "";
    if (_vistaGrafica == 'Semana') textoRango = "Esta Semana";
    else if (_vistaGrafica == 'Mes') textoRango = DateFormat('MMMM', 'es').format(hoy).toUpperCase();
    else if (_vistaGrafica == 'Año') textoRango = "Año ${hoy.year}";
    else textoRango = "${DateFormat('dd/MM/yyyy').format(inicioPeriodo)} - ${DateFormat('dd/MM/yyyy').format(finPeriodo)}";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBotonFiltro('Semana'),
                const SizedBox(width: 8),
                _buildBotonFiltro('Mes'),
                const SizedBox(width: 8),
                _buildBotonFiltro('Año'),
                const SizedBox(width: 8),
                _buildBotonFiltro('Personalizado'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(textoRango, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("${total.toStringAsFixed(2)} €", style: TextStyle(fontSize: 30, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 30),

          Expanded(
            child: Container(
              padding: const EdgeInsets.only(right: 16, left: 0, top: 10, bottom: 0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)]),
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem('${rod.toY.toStringAsFixed(2)} €', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: cantidadBarras > 15 ? 5 : 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= cantidadBarras) return const Text('');
                          String texto = '';
                          if (_vistaGrafica == 'Año') {
                            texto = DateFormat('MMM', 'es').format(DateTime(hoy.year, index + 1, 1));
                          } else {
                            DateTime fechaBarra = inicioPeriodo.add(Duration(days: index));
                            if (_vistaGrafica == 'Semana') {
                              texto = DateFormat('E', 'es').format(fechaBarra)[0].toUpperCase();
                            } else {
                              texto = fechaBarra.day.toString();
                            }
                          }
                          return Padding(padding: const EdgeInsets.only(top: 8), child: Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                  barGroups: List.generate(cantidadBarras, (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                          toY: datosGrafica[i] ?? 0,
                          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          width: cantidadBarras > 15 ? 6 : 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: (datosGrafica.values.isEmpty ? 0 : datosGrafica.values.reduce((curr, next) => curr > next ? curr : next)) * 1.1, color: Colors.grey.shade100)
                      )
                    ],
                  )),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBotonFiltro(String titulo) {
    bool isSelected = _vistaGrafica == titulo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(titulo),
        selected: isSelected,
        onSelected: (bool selected) {
          if (titulo == 'Personalizado') {
            _seleccionarRangoPersonalizado();
          } else {
            setState(() => _vistaGrafica = titulo);
          }
        },
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
        showCheckmark: false,
      ),
    );
  }
}