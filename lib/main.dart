import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:local_auth/local_auth.dart';

// --- 1. CONFIGURACIÓN PRINCIPAL ---
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const MiAppFinanciera());
}

class MiAppFinanciera extends StatelessWidget {
  const MiAppFinanciera({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Control Financiero Pro',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'ES')],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5), brightness: Brightness.light),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[50],
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5), brightness: Brightness.dark),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
          ),
          themeMode: currentMode,
          home: const PantallaBloqueo(),
        );
      },
    );
  }
}

// --- WIDGET LOGO ---
class CompanyLogo extends StatelessWidget {
  final double height;
  final bool textOnly;
  const CompanyLogo({super.key, this.height = 40, this.textOnly = false});
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String assetPath = isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png';
    return Image.asset(
      assetPath,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.code, color: isDark ? Colors.white : const Color(0xFF3F51B5), size: height),
            if (!textOnly) ...[const SizedBox(width: 8), Text("DEV STUDIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: height * 0.5, color: isDark ? Colors.white : const Color(0xFF3F51B5)))]
        ]);
      },
    );
  }
}

// --- PANTALLA DE BLOQUEO ---
class PantallaBloqueo extends StatefulWidget { const PantallaBloqueo({super.key}); @override State<PantallaBloqueo> createState() => _PantallaBloqueoState(); }
class _PantallaBloqueoState extends State<PantallaBloqueo> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _estaAutenticando = false;

  @override
void initState() {
  super.initState();
  // Esperamos a que la pantalla se dibuje antes de pedir la huella
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _autenticar();
  });
}

  Future<void> _autenticar() async {
    setState(() => _estaAutenticando = true);
    try {
      bool puede = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!puede) { _irAPrincipal(); return; }
      bool ok = await auth.authenticate(localizedReason: 'Acceso Financiero', options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true));
      if (ok) {
        _irAPrincipal();
      } else {
        setState(() => _estaAutenticando = false);
      }
    } on PlatformException catch (_) { setState(() => _estaAutenticando = false); }
  }

  void _irAPrincipal() { Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PantallaPrincipal())); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F51B5),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CompanyLogo(height: 100),
        const SizedBox(height: 40),
        Text("Finanzas Pro", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (!_estaAutenticando) ElevatedButton.icon(onPressed: _autenticar, icon: const Icon(Icons.fingerprint), label: const Text("Entrar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF3F51B5)))
      ]))
    );
  }
}

// --- BASE DE DATOS ---
class DB {
  static Database? _database;
  static const int _dbVersion = 2; 
  static Future<Database> get database async { if (_database != null) return _database!; _database = await _initDB(); return _database!; }
  
  static Future<Database> _initDB() async {
    String path = p.join(await getDatabasesPath(), 'finanzas_pro.db'); 
    return await openDatabase(
      path, version: _dbVersion,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE movimientos(id TEXT PRIMARY KEY, titulo TEXT, monto REAL, fecha TEXT, categoria TEXT, esIngreso INTEGER)');
        await db.execute('CREATE TABLE categorias(id TEXT PRIMARY KEY, nombre TEXT, iconoCode INTEGER, colorValue INTEGER, esIngreso INTEGER, macroCategoria TEXT)');
        await db.execute('CREATE TABLE patrimonio(id TEXT PRIMARY KEY, fecha TEXT, totalDinero REAL, dineroInvertido REAL)');
        await _insertarCategoriasPorDefecto(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE categorias ADD COLUMN macroCategoria TEXT DEFAULT 'Necesidad'");
          await db.execute('CREATE TABLE patrimonio(id TEXT PRIMARY KEY, fecha TEXT, totalDinero REAL, dineroInvertido REAL)');
          await db.execute("UPDATE categorias SET macroCategoria = 'Necesidad' WHERE esIngreso = 0");
          await db.execute("UPDATE categorias SET macroCategoria = 'Ingreso' WHERE esIngreso = 1");
          await db.execute("UPDATE categorias SET macroCategoria = 'Deseo' WHERE nombre LIKE '%Ocio%' OR nombre LIKE '%Regalo%' OR nombre LIKE '%Restaurante%'");
          await db.execute("UPDATE categorias SET macroCategoria = 'Ahorro' WHERE nombre LIKE '%Inversión%' OR nombre LIKE '%Ahorro%'");
        }
      },
    );
  }

  static Future<void> _insertarCategoriasPorDefecto(Database db) async {
    List<CategoriaModelo> data = [
      CategoriaModelo(id: '1', nombre: 'Comida', iconoCode: Icons.restaurant.codePoint, colorValue: Colors.orange.value, esIngreso: false, macroCategoria: 'Necesidad'),
      CategoriaModelo(id: '2', nombre: 'Transporte', iconoCode: Icons.directions_car.codePoint, colorValue: Colors.blue.value, esIngreso: false, macroCategoria: 'Necesidad'),
      CategoriaModelo(id: '3', nombre: 'Casa', iconoCode: Icons.home.codePoint, colorValue: Colors.purple.value, esIngreso: false, macroCategoria: 'Necesidad'),
      CategoriaModelo(id: '4', nombre: 'Ocio', iconoCode: Icons.movie.codePoint, colorValue: Colors.pink.value, esIngreso: false, macroCategoria: 'Deseo'),
      CategoriaModelo(id: '5', nombre: 'Ahorro/Inversión', iconoCode: Icons.savings.codePoint, colorValue: Colors.teal.value, esIngreso: false, macroCategoria: 'Ahorro'),
      CategoriaModelo(id: '6', nombre: 'Otros Gastos', iconoCode: Icons.category.codePoint, colorValue: Colors.grey.value, esIngreso: false, macroCategoria: 'Necesidad'),
      CategoriaModelo(id: '10', nombre: 'Nómina', iconoCode: Icons.work.codePoint, colorValue: Colors.green.value, esIngreso: true, macroCategoria: 'Ingreso'),
      CategoriaModelo(id: '12', nombre: 'Inversión (Retorno)', iconoCode: Icons.trending_up.codePoint, colorValue: Colors.indigo.value, esIngreso: true, macroCategoria: 'Ingreso'),
    ];
    for (var c in data) {
      await db.insert('categorias', c.toMap());
    }
  }

  // Métodos CRUD
  static Future<int> insertMov(Movimiento m) async { final db = await database; return await db.insert('movimientos', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); }
  static Future<List<Movimiento>> getMovimientos() async { final db = await database; final maps = await db.query('movimientos', orderBy: "fecha DESC"); return List.generate(maps.length, (i) => Movimiento.fromMap(maps[i])); }
  static Future<int> updateMov(Movimiento m) async { final db = await database; return await db.update('movimientos', m.toMap(), where: 'id = ?', whereArgs: [m.id]); }
  static Future<int> deleteMov(String id) async { final db = await database; return await db.delete('movimientos', where: 'id = ?', whereArgs: [id]); }
  static Future<List<CategoriaModelo>> getCategorias() async { final db = await database; final maps = await db.query('categorias'); return List.generate(maps.length, (i) => CategoriaModelo.fromMap(maps[i])); }
  static Future<int> insertCategoria(CategoriaModelo c) async { final db = await database; return await db.insert('categorias', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); }
  static Future<int> updateCategoria(CategoriaModelo c) async { final db = await database; return await db.update('categorias', c.toMap(), where: 'id = ?', whereArgs: [c.id]); }
  static Future<int> deleteCategoria(String id) async { final db = await database; var cat = (await db.query('categorias', where: 'id = ?', whereArgs: [id])).first; String dest = ((cat['esIngreso'] as int) == 1) ? 'Otros Ingresos' : 'Otros Gastos'; await db.update('movimientos', {'categoria': dest}, where: 'categoria = ?', whereArgs: [cat['nombre']]); return await db.delete('categorias', where: 'id = ?', whereArgs: [id]); }
  static Future<int> insertPatrimonio(PatrimonioModelo p) async { final db = await database; return await db.insert('patrimonio', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); }
  static Future<int> updatePatrimonio(PatrimonioModelo p) async { final db = await database; return await db.update('patrimonio', p.toMap(), where: 'id = ?', whereArgs: [p.id]); }
  static Future<List<PatrimonioModelo>> getPatrimonio() async { final db = await database; final maps = await db.query('patrimonio', orderBy: "fecha ASC"); return List.generate(maps.length, (i) => PatrimonioModelo.fromMap(maps[i])); }
  static Future<int> deletePatrimonio(String id) async { final db = await database; return await db.delete('patrimonio', where: 'id = ?', whereArgs: [id]); }
}

// --- MODELOS ---
class CategoriaModelo { 
  String id; String nombre; int iconoCode; int colorValue; bool esIngreso; String macroCategoria; 
  CategoriaModelo({required this.id, required this.nombre, required this.iconoCode, required this.colorValue, required this.esIngreso, required this.macroCategoria}); 
  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'iconoCode': iconoCode, 'colorValue': colorValue, 'esIngreso': esIngreso ? 1 : 0, 'macroCategoria': macroCategoria}; 
  factory CategoriaModelo.fromMap(Map<String, dynamic> map) => CategoriaModelo(id: map['id'], nombre: map['nombre'], iconoCode: map['iconoCode'], colorValue: map['colorValue'], esIngreso: (map['esIngreso'] ?? 0) == 1, macroCategoria: map['macroCategoria'] ?? (map['esIngreso'] == 1 ? 'Ingreso' : 'Necesidad')); 
}
class Movimiento { String id; String titulo; double monto; DateTime fecha; String categoria; bool esIngreso; Movimiento({required this.id, required this.titulo, required this.monto, required this.fecha, required this.categoria, required this.esIngreso}); Map<String, dynamic> toMap() => {'id': id, 'titulo': titulo, 'monto': monto, 'fecha': fecha.toIso8601String(), 'categoria': categoria, 'esIngreso': esIngreso ? 1 : 0}; factory Movimiento.fromMap(Map<String, dynamic> map) => Movimiento(id: map['id'], titulo: map['titulo'], monto: map['monto'], fecha: DateTime.parse(map['fecha']), categoria: map['categoria'] ?? 'General', esIngreso: (map['esIngreso'] ?? 0) == 1); }
class PatrimonioModelo { String id; DateTime fecha; double totalDinero; double dineroInvertido; PatrimonioModelo({required this.id, required this.fecha, required this.totalDinero, required this.dineroInvertido}); Map<String, dynamic> toMap() => {'id': id, 'fecha': fecha.toIso8601String(), 'totalDinero': totalDinero, 'dineroInvertido': dineroInvertido}; factory PatrimonioModelo.fromMap(Map<String, dynamic> map) => PatrimonioModelo(id: map['id'], fecha: DateTime.parse(map['fecha']), totalDinero: map['totalDinero'], dineroInvertido: map['dineroInvertido']); }

// --- PANTALLA PRINCIPAL (TODO EL CÓDIGO DENTRO) ---
class PantallaPrincipal extends StatefulWidget { const PantallaPrincipal({super.key}); @override State<PantallaPrincipal> createState() => _PantallaPrincipalState(); }

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  List<Movimiento> _movimientos = [];
  List<CategoriaModelo> _categorias = [];
  List<PatrimonioModelo> _patrimonio = [];
  bool _cargando = true;
  String _filtroFecha = 'Mes'; 
  DateTimeRange? _rangoPersonalizado;

  @override void initState() { super.initState(); _cargarDatos(); }
  Future<void> _cargarDatos() async { final m = await DB.getMovimientos(); final c = await DB.getCategorias(); final p = await DB.getPatrimonio(); setState(() { _movimientos = m; _categorias = c; _patrimonio = p; _cargando = false; }); }
  
  CategoriaModelo _getInfoCategoria(String n) { 
    try { return _categorias.firstWhere((c) => c.nombre == n); } 
    catch (e) { return CategoriaModelo(id: '0', nombre: n, iconoCode: Icons.help.codePoint, colorValue: Colors.grey.value, esIngreso: false, macroCategoria: 'Necesidad'); } 
  }

  // --- FILTROS Y UTILS ---
  List<Movimiento> _getMovimientosFiltrados() {
    DateTime now = DateTime.now(); DateTime start, end;
    if (_filtroFecha == 'Semana') { start = now.subtract(Duration(days: now.weekday - 1)); end = start.add(const Duration(days: 6, hours: 23, minutes: 59)); }
    else if (_filtroFecha == 'Mes') { start = DateTime(now.year, now.month, 1); end = DateTime(now.year, now.month + 1, 0, 23, 59); }
    else if (_filtroFecha == 'Año') { start = DateTime(now.year, 1, 1); end = DateTime(now.year, 12, 31, 23, 59); }
    else if (_filtroFecha == 'Rango' && _rangoPersonalizado != null) { start = _rangoPersonalizado!.start; end = _rangoPersonalizado!.end.add(const Duration(hours: 23, minutes: 59)); }
    else { return _movimientos; }
    return _movimientos.where((m) => m.fecha.isAfter(start.subtract(const Duration(seconds: 1))) && m.fecha.isBefore(end)).toList();
  }

  String _getTituloBalance() {
    final f = DateFormat('dd/MM/yy', 'es');
    if (_filtroFecha == 'Rango' && _rangoPersonalizado != null) return "Balance (${f.format(_rangoPersonalizado!.start)} - ${f.format(_rangoPersonalizado!.end)})";
    DateTime now = DateTime.now(); DateTime s = now, e = now;
    if (_filtroFecha == 'Semana') { s = now.subtract(Duration(days: now.weekday - 1)); e = s.add(const Duration(days: 6)); }
    else if (_filtroFecha == 'Mes') { s = DateTime(now.year, now.month, 1); e = DateTime(now.year, now.month + 1, 0); }
    else if (_filtroFecha == 'Año') { s = DateTime(now.year, 1, 1); e = DateTime(now.year, 12, 31); }
    return "Balance (${f.format(s)} - ${f.format(e)})";
  }

  Future<void> _seleccionarRango() async { final p = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), currentDate: DateTime.now(), saveText: 'Aplicar'); if (p != null) setState(() { _rangoPersonalizado = p; _filtroFecha = 'Rango'; }); }
  
  Widget _botonFiltro(String txt) { 
    bool act = _filtroFecha == txt; 
    return GestureDetector(onTap: () => setState(() => _filtroFecha = txt), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: act ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(txt, style: TextStyle(color: act ? Colors.blue[900] : Colors.white, fontWeight: act ? FontWeight.bold : FontWeight.normal, fontSize: 12)))); 
  }

  // --- IMPORT / EXPORT ---
  Future<void> _exportarCSV() async {
    String opcion = await showDialog(context: context, builder: (ctx) => SimpleDialog(title: const Text("Exportar CSV"), children: [SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Todo'), child: const Text("Todo el Histórico")), SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Mes'), child: const Text("Mes Actual")), SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Rango'), child: const Text("Seleccionar Fechas..."))])) ?? 'Cancelar';
    if (opcion == 'Cancelar') return;
    List<Movimiento> aExportar = _movimientos;
    if (opcion == 'Mes') { DateTime now = DateTime.now(); aExportar = _movimientos.where((m) => m.fecha.month == now.month && m.fecha.year == now.year).toList(); }
    else if (opcion == 'Rango') { final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), currentDate: DateTime.now()); if (r == null) return; aExportar = _movimientos.where((m) => m.fecha.isAfter(r.start.subtract(const Duration(seconds: 1))) && m.fecha.isBefore(r.end.add(const Duration(hours: 23)))).toList(); }
    try {
      List<List<dynamic>> rows = []; rows.add(["Fecha", "Tipo", "Categoría", "Concepto", "Monto"]); 
      for (var m in aExportar) {
        rows.add([DateFormat('yyyy-MM-dd').format(m.fecha), m.esIngreso ? 'Ingreso' : 'Gasto', m.categoria, m.titulo, m.monto]);
      }
      String csv = const ListToCsvConverter().convert(rows); final dir = await getTemporaryDirectory(); final path = "${dir.path}/Finanzas_Export.csv"; final file = File(path); await file.writeAsString(csv); final box = context.findRenderObject() as RenderBox?; await Share.shareXFiles([XFile(path)], text: 'Mis Finanzas', sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _importarCSV() async {
    bool? conf = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Importar CSV"), content: const Text("Formato: Fecha (AAAA-MM-DD), Tipo, Categ, Concepto, Monto"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Seleccionar"))]));
    if (conf != true) return;
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (res != null) {
        File file = File(res.files.single.path!); final input = file.openRead(); final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();
        int imp = 0; int ini = 0; if (fields.isNotEmpty && double.tryParse(fields[0][4].toString()) == null) ini = 1;
        for (int i = ini; i < fields.length; i++) {
          var row = fields[i]; if (row.length < 5) continue;
          String fechaStr = row[0].toString(); String tipoStr = row[1].toString().toLowerCase(); String catN = row[2].toString(); String tit = row[3].toString(); String mStr = row[4].toString().replaceAll(',', '.');
          DateTime fecha = DateTime.tryParse(fechaStr) ?? DateTime.now(); double monto = double.tryParse(mStr) ?? 0.0; bool esIng = tipoStr.contains('ingreso') || tipoStr == '1';
          CategoriaModelo? catM; try { catM = _categorias.firstWhere((c) => c.nombre.toLowerCase() == catN.toLowerCase()); } catch (_) {}
          if (catM == null) { catM = CategoriaModelo(id: DateTime.now().millisecondsSinceEpoch.toString()+i.toString(), nombre: catN, iconoCode: Icons.category.codePoint, colorValue: Colors.grey.value, esIngreso: esIng, macroCategoria: esIng ? 'Ingreso' : 'Necesidad'); await DB.insertCategoria(catM); _categorias.add(catM); }
          Movimiento mov = Movimiento(id: DateTime.now().millisecondsSinceEpoch.toString()+i.toString(), titulo: tit, monto: monto, fecha: fecha, categoria: catM.nombre, esIngreso: esIng); await DB.insertMov(mov); imp++;
        }
        _cargarDatos(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importados $imp movimientos.')));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  // --- CRUD HELPERS ---
  void _borrarMov(String id) async { await DB.deleteMov(id); _cargarDatos(); }
  void _borrarPatrimonio(String id) async { await DB.deletePatrimonio(id); _cargarDatos(); }
  void _gestionarCats() async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCategorias())); _cargarDatos(); }

  // --- BUILD METODO PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget currentTab;
    switch (_indiceActual) { case 0: currentTab = _buildDashboard(); break; case 1: currentTab = _buildAnalisis(); break; case 2: currentTab = _buildPatrimonio(); break; default: currentTab = _buildDashboard(); }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(8.0), child: CompanyLogo(textOnly: true)), leadingWidth: 40,
        title: const Text('Finanzas Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        foregroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: Icon(themeNotifier.value == ThemeMode.light ? Icons.dark_mode : Icons.light_mode), onPressed: () => themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
          IconButton(icon: const Icon(Icons.category), tooltip: "Categorías", onPressed: _gestionarCats),
          PopupMenuButton<String>(
            onSelected: (val) { if(val == 'export') _exportarCSV(); else if(val == 'import') _importarCSV(); },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // AQUI ESTABA EL ERROR DE 'const' - ELIMINADO
              PopupMenuItem<String>(value: 'export', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Exportar CSV'))),
              // AQUI ESTABA EL ERROR DEL NOMBRE DEL ICONO - CORREGIDO
              PopupMenuItem<String>(value: 'import', child: ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Importar CSV'))),
            ],
          ),
        ],
      ),
      body: currentTab,
      bottomNavigationBar: NavigationBar(selectedIndex: _indiceActual, onDestinationSelected: (i) => setState(() => _indiceActual = i), backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white, destinations: const [NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Flujo'), NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Análisis'), NavigationDestination(icon: Icon(Icons.show_chart), label: 'Patrimonio')]),
      floatingActionButton: _indiceActual != 1 ? FloatingActionButton.extended(onPressed: () => _indiceActual == 2 ? _agregarOEditarPatrimonio() : _agregarOEditar(), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, icon: Icon(_indiceActual == 2 ? Icons.save_as : Icons.add), label: Text(_indiceActual == 2 ? "Registrar" : "Añadir")) : null,
    );
  }

  // --- WIDGETS TABS ---
  Widget _buildDashboard() {
    final filtrados = _getMovimientosFiltrados(); double ingresos = 0, gastos = 0; for (var m in filtrados) { if (m.esIngreso) {
      ingresos += m.monto;
    } else {
      gastos += m.monto;
    } } double balance = ingresos - gastos;
    return Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_botonFiltro("Semana"), _botonFiltro("Mes"), _botonFiltro("Año"), IconButton(icon: Icon(Icons.calendar_month, color: _filtroFecha == 'Rango' ? Colors.white : Colors.white54), onPressed: _seleccionarRango)]),
            const SizedBox(height: 10), Text(_getTituloBalance(), style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 5), Text("${balance >= 0 ? '+' : ''}${balance.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16), const SizedBox(width: 4), const Text("Ingresos", style: TextStyle(color: Colors.white70))]), Text("${ingresos.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(children: [const Text("Gastos", style: TextStyle(color: Colors.white70)), const SizedBox(width: 4), const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 16)]), Text("${gastos.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))])])
        ])),
        Expanded(child: filtrados.isEmpty ? const Center(child: Text('Sin movimientos')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: filtrados.length, itemBuilder: (ctx, i) { final m = filtrados[i]; final c = _getInfoCategoria(m.categoria); return Dismissible(key: ValueKey(m.id), background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) => _borrarMov(m.id), child: Card(elevation: 0, color: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.1))), child: ListTile(leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Color(c.colorValue).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(IconData(c.iconoCode, fontFamily: 'MaterialIcons'), color: Color(c.colorValue))), title: Text(m.titulo, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${m.categoria} • ${DateFormat('dd/MM/yy').format(m.fecha)}"), trailing: Text('${m.esIngreso ? '+' : '-'}${m.monto.toStringAsFixed(2)} €', style: TextStyle(color: m.esIngreso ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)), onTap: () => _agregarOEditar(movExistente: m)))); }))
    ]);
  }

  Widget _buildAnalisis() {
    final filtrados = _getMovimientosFiltrados(); final ingresos = filtrados.where((m) => m.esIngreso).fold(0.0, (sum, m) => sum + m.monto); final gastos = filtrados.where((m) => !m.esIngreso).toList();
    double necesidad = 0, deseo = 0, ahorro = 0; for (var g in gastos) { final cat = _getInfoCategoria(g.categoria); if (cat.macroCategoria == 'Necesidad') necesidad += g.monto; else if (cat.macroCategoria == 'Deseo') deseo += g.monto; else if (cat.macroCategoria == 'Ahorro') ahorro += g.monto; else necesidad += g.monto; }
    double base = ingresos > 0 ? ingresos : (necesidad + deseo + ahorro); if (base == 0) base = 1;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [_botonFiltro("Semana"), _botonFiltro("Mes"), _botonFiltro("Año"), IconButton(icon: Icon(Icons.calendar_month, color: _filtroFecha == 'Rango' ? Colors.white : Colors.white54), onPressed: _seleccionarRango)]), const SizedBox(height: 5), Text(_getTituloBalance(), style: const TextStyle(color: Colors.white70, fontSize: 13))])),
        const SizedBox(height: 20), Row(children: [const Text("Regla 50/30/20", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.info_outline, color: Colors.blue), onPressed: () => showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("¿Qué es la Regla 50/30/20?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), SizedBox(height: 10), Text("Divide tus ingresos netos en 3 categorías:"), SizedBox(height: 15), ListTile(leading: CircleAvatar(backgroundColor: Colors.blue, radius: 5), title: Text("50% NECESIDADES"), subtitle: Text("Imprescindibles: Casa, comida, luz...")), ListTile(leading: CircleAvatar(backgroundColor: Colors.pink, radius: 5), title: Text("30% DESEOS"), subtitle: Text("Opcionales: Ocio, caprichos, cenas...")), ListTile(leading: CircleAvatar(backgroundColor: Colors.teal, radius: 5), title: Text("20% AHORRO"), subtitle: Text("Futuro: Inversión, deuda, colchón..."))]))))]),
        const SizedBox(height: 10), Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [_buildBarra503020("Necesidades (50%)", necesidad, base * 0.5, Colors.blue), const SizedBox(height: 15), _buildBarra503020("Deseos (30%)", deseo, base * 0.3, Colors.pink), const SizedBox(height: 15), _buildBarra503020("Ahorro/Inv (20%)", ahorro, base * 0.2, Colors.teal)]))),
        const SizedBox(height: 30), const Text("Distribución de Gastos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), SizedBox(height: 250, child: _buildChartPastel(gastos, necesidad + deseo + ahorro))
    ]));
  }
  Widget _buildBarra503020(String l, double a, double o, Color c) { double p = o > 0 ? (a / o) : 0; if (p > 1) p = 1; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.bold)), Text("${a.toStringAsFixed(0)}€ / ${o.toStringAsFixed(0)}€", style: TextStyle(color: Colors.grey[600], fontSize: 12))]), const SizedBox(height: 5), LinearProgressIndicator(value: p, backgroundColor: c.withOpacity(0.1), color: c, minHeight: 10, borderRadius: BorderRadius.circular(5))]); }
  Widget _buildChartPastel(List<Movimiento> gastos, double total) { Map<String, double> cats = {}; for (var g in gastos) {
    cats[g.categoria] = (cats[g.categoria] ?? 0) + g.monto;
  } List<PieChartSectionData> sections = []; cats.forEach((k, v) { final c = _getInfoCategoria(k); final pct = (v / total) * 100; if (pct > 2) sections.add(PieChartSectionData(color: Color(c.colorValue), value: pct, title: '', radius: 50)); }); return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Expanded(child: AspectRatio(aspectRatio: 1, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2)))), const SizedBox(width: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: cats.entries.map((e) { final c = _getInfoCategoria(e.key); return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(c.colorValue), shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(c.nombre, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)), Text("${e.value.toStringAsFixed(0)}€", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])); }).toList()))]))); }

  // === TAB 3: PATRIMONIO ===
  Widget _buildPatrimonio() {
    if (_patrimonio.isEmpty) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.show_chart, size: 60, color: Colors.grey), const SizedBox(height: 10), const Text("Registra tu patrimonio mensual", style: TextStyle(fontSize: 16)), ElevatedButton(onPressed: _agregarOEditarPatrimonio, child: const Text("Registrar Primer Dato"))])); }
    final ultimo = _patrimonio.last; final beneficio = ultimo.totalDinero - ultimo.dineroInvertido; final pctRentabilidad = ultimo.dineroInvertido > 0 ? (beneficio / ultimo.dineroInvertido) * 100 : 0.0;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(color: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildPatrimonioItem("Total", "${ultimo.totalDinero.toStringAsFixed(0)} €", Colors.white), _buildPatrimonioItem("Invertido", "${ultimo.dineroInvertido.toStringAsFixed(0)} €", Colors.white70)]), const Divider(color: Colors.white24, height: 30), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildPatrimonioItem("Beneficio", "${beneficio > 0 ? '+' : ''}${beneficio.toStringAsFixed(0)} €", beneficio >= 0 ? Colors.greenAccent : Colors.redAccent), _buildPatrimonioItem("Rentabilidad", "${pctRentabilidad > 0 ? '+' : ''}${pctRentabilidad.toStringAsFixed(2)}%", beneficio >= 0 ? Colors.greenAccent : Colors.redAccent)])]))),
        const SizedBox(height: 20), const Text("Evolución Patrimonio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), SizedBox(height: 300, child: _buildChartPatrimonio()), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width: 5), const Text("Valor Total", style: TextStyle(fontSize: 12)), const SizedBox(width: 20), Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)), const SizedBox(width: 5), const Text("Dinero Invertido", style: TextStyle(fontSize: 12))]),
        const SizedBox(height: 20), const Text("Histórico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._patrimonio.reversed.map((p) => ListTile(title: Text(DateFormat('MMMM yyyy', 'es').format(p.fecha).toUpperCase()), subtitle: Text("Inv: ${p.dineroInvertido.toStringAsFixed(0)}€ | Tot: ${p.totalDinero.toStringAsFixed(0)}€"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _agregarOEditarPatrimonio(patrimonioExistente: p)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _borrarPatrimonio(p.id))]))).toList(),
        const SizedBox(height: 80), // ESPACIO EXTRA PARA QUE EL FAB NO TAPE
    ]));
  }
  Widget _buildPatrimonioItem(String label, String value, Color color) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))]); }
  Widget _buildChartPatrimonio() { List<FlSpot> st = []; List<FlSpot> si = []; for (int i = 0; i < _patrimonio.length; i++) { st.add(FlSpot(i.toDouble(), _patrimonio[i].totalDinero)); si.add(FlSpot(i.toDouble(), _patrimonio[i].dineroInvertido)); } return LineChart(LineChartData(gridData: FlGridData(show: true, drawVerticalLine: false), titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (val, meta) { int i = val.toInt(); if (i >= 0 && i < _patrimonio.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('MMM yy', 'es').format(_patrimonio[i].fecha), style: const TextStyle(fontSize: 10))); return const Text(''); })), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: st, isCurved: true, color: Colors.green, barWidth: 4, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1))), LineChartBarData(spots: si, isCurved: true, color: Colors.grey, barWidth: 3, dotData: const FlDotData(show: true), dashArray: [5, 5])])); }

  void _agregarOEditarPatrimonio({PatrimonioModelo? patrimonioExistente}) {
    final isEditing = patrimonioExistente != null; final totalCtrl = TextEditingController(text: isEditing ? patrimonioExistente.totalDinero.toString() : ''); final invCtrl = TextEditingController(text: isEditing ? patrimonioExistente.dineroInvertido.toString() : ''); DateTime fecha = isEditing ? patrimonioExistente.fecha : DateTime.now(); double ultimoInvertido = 0.0; if (!isEditing && _patrimonio.isNotEmpty) ultimoInvertido = _patrimonio.last.dineroInvertido;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModal) => AlertDialog(title: Text(isEditing ? "Editar Registro" : "Nuevo Registro"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: "Dinero Total (Valor Actual)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)), const SizedBox(height: 10), if (!isEditing) TextField(controller: invCtrl, decoration: InputDecoration(labelText: "Aportado Nuevo (Desde último)", helperText: "Se sumará a: ${ultimoInvertido.toStringAsFixed(0)}€"), keyboardType: const TextInputType.numberWithOptions(decimal: true)) else TextField(controller: invCtrl, decoration: const InputDecoration(labelText: "Dinero Invertido (Total Acumulado)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)), const SizedBox(height: 10), ListTile(title: Text("Fecha: ${DateFormat('dd/MM/yy').format(fecha)}"), trailing: const Icon(Icons.calendar_today), onTap: () async { final p = await showDatePicker(context: context, initialDate: fecha, firstDate: DateTime(2020), lastDate: DateTime.now()); if (p != null) setModal(() => fecha = p); })]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async { if (totalCtrl.text.isEmpty || invCtrl.text.isEmpty) return; double inputInv = double.parse(invCtrl.text.replaceAll(',', '.')); double dinFinal = isEditing ? inputInv : ultimoInvertido + inputInv; final nuevo = PatrimonioModelo(id: isEditing ? patrimonioExistente.id : DateTime.now().millisecondsSinceEpoch.toString(), fecha: fecha, totalDinero: double.parse(totalCtrl.text.replaceAll(',', '.')), dineroInvertido: dinFinal); if (isEditing) {
      await DB.updatePatrimonio(nuevo);
    } else {
      await DB.insertPatrimonio(nuevo);
    } _cargarDatos(); Navigator.pop(ctx); }, child: const Text("Guardar"))])));
  }

  void _agregarOEditar({Movimiento? movExistente}) {
    final isEditing = movExistente != null; bool esIngreso = isEditing ? movExistente.esIngreso : false;
    final tituloCtrl = TextEditingController(text: isEditing ? movExistente.titulo : ''); final montoCtrl = TextEditingController(text: isEditing ? movExistente.monto.toString() : '');
    DateTime fecha = isEditing ? movExistente.fecha : DateTime.now();
    List<CategoriaModelo> cats = _categorias.where((c) => c.esIngreso == esIngreso).toList();
    String catSel = isEditing ? movExistente.categoria : (cats.isNotEmpty ? cats.first.nombre : 'General');
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (ctx) => StatefulBuilder(builder: (context, setModal) {
      cats = _categorias.where((c) => c.esIngreso == esIngreso).toList(); if (!cats.any((c) => c.nombre == catSel) && cats.isNotEmpty) catSel = cats.first.nombre;
      return Padding(padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isEditing ? 'Editar' : 'Nuevo', style: Theme.of(context).textTheme.headlineSmall), if(isEditing) IconButton(onPressed: (){Navigator.pop(context); _borrarMov(movExistente.id);}, icon: const Icon(Icons.delete, color: Colors.red))]), const SizedBox(height: 10),
        Container(decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15)), child: Row(children: [Expanded(child: GestureDetector(onTap: () => setModal(() => esIngreso = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: !esIngreso ? Colors.red.shade100 : Colors.transparent, borderRadius: BorderRadius.circular(15)), child: const Center(child: Text("GASTO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))))), Expanded(child: GestureDetector(onTap: () => setModal(() => esIngreso = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: esIngreso ? Colors.green.shade100 : Colors.transparent, borderRadius: BorderRadius.circular(15)), child: const Center(child: Text("INGRESO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))))])),
        const SizedBox(height: 20), TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Concepto', border: OutlineInputBorder())), const SizedBox(height: 15), TextField(controller: montoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder())), const SizedBox(height: 15),
        Row(children: [Expanded(child: InkWell(onTap: () async { final p = await showDatePicker(context: context, initialDate: fecha, firstDate: DateTime(2020), lastDate: DateTime.now()); if(p != null) setModal(() => fecha = p); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yy').format(fecha))))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField(value: catSel, items: cats.map((c) => DropdownMenuItem(value: c.nombre, child: Text(c.nombre, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setModal(() => catSel = v!)))]),
        const SizedBox(height: 25), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: esIngreso ? Colors.green : Colors.red, foregroundColor: Colors.white), onPressed: () async { if (tituloCtrl.text.isEmpty) return; final m = Movimiento(id: isEditing ? movExistente.id : DateTime.now().millisecondsSinceEpoch.toString(), titulo: tituloCtrl.text, monto: double.parse(montoCtrl.text.replaceAll(',', '.')), fecha: fecha, categoria: catSel, esIngreso: esIngreso); if (isEditing) {
          await DB.updateMov(m);
        } else {
          await DB.insertMov(m);
        } _cargarDatos(); Navigator.pop(context); }, child: const Text("GUARDAR")))
      ]));
    }));
  }
}

// --- PANTALLA CATEGORÍAS ---
class PantallaCategorias extends StatefulWidget { const PantallaCategorias({super.key}); @override State<PantallaCategorias> createState() => _PantallaCategoriasState(); }
class _PantallaCategoriasState extends State<PantallaCategorias> {
  List<CategoriaModelo> _categorias = []; bool _mostrarIngresos = false; @override void initState() { super.initState(); _cargar(); } void _cargar() async { final list = await DB.getCategorias(); setState(() => _categorias = list); } void _editar(CategoriaModelo? cat) { showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => EditorCategoria(categoria: cat, onSave: _cargar)); } void _borrar(CategoriaModelo cat) async { if (cat.nombre.contains('Otros') || cat.nombre == 'General') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes borrar las categorías por defecto'))); return; } await DB.deleteCategoria(cat.id); _cargar(); } @override Widget build(BuildContext context) { final listaVisible = _categorias.where((c) => c.esIngreso == _mostrarIngresos).toList(); return Scaffold(appBar: AppBar(title: const Text("Mis Categorías")), body: Column(children: [Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Expanded(child: ElevatedButton(onPressed: () => setState(() => _mostrarIngresos = false), style: ElevatedButton.styleFrom(backgroundColor: !_mostrarIngresos ? Colors.red : Colors.grey[200], foregroundColor: !_mostrarIngresos ? Colors.white : Colors.black), child: const Text("Gastos"))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: () => setState(() => _mostrarIngresos = true), style: ElevatedButton.styleFrom(backgroundColor: _mostrarIngresos ? Colors.green : Colors.grey[200], foregroundColor: _mostrarIngresos ? Colors.white : Colors.black), child: const Text("Ingresos")))])), Expanded(child: ListView.builder(itemCount: listaVisible.length, itemBuilder: (ctx, i) { final cat = listaVisible[i]; return ListTile(leading: CircleAvatar(backgroundColor: Color(cat.colorValue).withOpacity(0.2), child: Icon(IconData(cat.iconoCode, fontFamily: 'MaterialIcons'), color: Color(cat.colorValue))), title: Text(cat.nombre), subtitle: Text(_mostrarIngresos ? '' : cat.macroCategoria, style: TextStyle(fontSize: 12, color: Colors.grey[600])), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(cat)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _borrar(cat))])); }))]), floatingActionButton: FloatingActionButton(onPressed: () => _editar(null), child: const Icon(Icons.add))); } }
class EditorCategoria extends StatefulWidget { final CategoriaModelo? categoria; final VoidCallback onSave; const EditorCategoria({super.key, this.categoria, required this.onSave}); @override State<EditorCategoria> createState() => _EditorCategoriaState(); }
class _EditorCategoriaState extends State<EditorCategoria> { late TextEditingController _nameCtrl; late int _selectedColor; late int _selectedIcon; late bool _esIngreso; late String _macroCat; final List<Color> _colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.amber, Colors.brown, Colors.pink, Colors.indigo, Colors.cyan, Colors.lime]; final List<IconData> _icons = [Icons.category, Icons.work, Icons.home, Icons.restaurant, Icons.directions_car, Icons.shopping_cart, Icons.health_and_safety, Icons.school, Icons.card_giftcard, Icons.attach_money, Icons.savings, Icons.trending_up, Icons.flight, Icons.pets, Icons.sports_esports, Icons.child_friendly, Icons.local_bar, Icons.fitness_center]; final List<String> _macros = ['Necesidad', 'Deseo', 'Ahorro']; @override void initState() { super.initState(); _nameCtrl = TextEditingController(text: widget.categoria?.nombre ?? ''); _selectedColor = widget.categoria?.colorValue ?? Colors.blue.value; _selectedIcon = widget.categoria?.iconoCode ?? Icons.category.codePoint; _esIngreso = widget.categoria?.esIngreso ?? false; _macroCat = widget.categoria?.macroCategoria ?? 'Necesidad'; } @override Widget build(BuildContext context) { return Padding(padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.categoria == null ? "Nueva Categoría" : "Editar Categoría", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 15), if (widget.categoria == null) Row(children: [const Text("Tipo: "), Switch(value: _esIngreso, onChanged: (val) => setState(() => _esIngreso = val), activeColor: Colors.green, inactiveThumbColor: Colors.red), Text(_esIngreso ? "INGRESO" : "GASTO", style: TextStyle(fontWeight: FontWeight.bold, color: _esIngreso ? Colors.green : Colors.red))]), const SizedBox(height: 15), TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder())), const SizedBox(height: 15), if (!_esIngreso) DropdownButtonFormField<String>(value: _macroCat, decoration: const InputDecoration(labelText: "Rol (50/30/20)", border: OutlineInputBorder()), items: _macros.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => _macroCat = v!)), if (!_esIngreso) const SizedBox(height: 15), const Text("Color:"), SizedBox(height: 50, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _colors.length, itemBuilder: (ctx, i) { final c = _colors[i]; return GestureDetector(onTap: () => setState(() => _selectedColor = c.value), child: Container(margin: const EdgeInsets.only(right: 10), width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: _selectedColor == c.value ? Border.all(width: 3) : null))); })), const SizedBox(height: 15), const Text("Icono:"), SizedBox(height: 50, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _icons.length, itemBuilder: (ctx, i) { final ic = _icons[i]; return GestureDetector(onTap: () => setState(() => _selectedIcon = ic.codePoint), child: Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _selectedIcon == ic.codePoint ? Colors.grey[300] : null, borderRadius: BorderRadius.circular(10)), child: Icon(ic, color: Color(_selectedColor)))); })), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async { if (_nameCtrl.text.isEmpty) return; final nueva = CategoriaModelo(id: widget.categoria?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), nombre: _nameCtrl.text, iconoCode: _selectedIcon, colorValue: _selectedColor, esIngreso: _esIngreso, macroCategoria: _esIngreso ? 'Ingreso' : _macroCat); if (widget.categoria == null) {
  await DB.insertCategoria(nueva);
} else {
  await DB.updateCategoria(nueva);
} widget.onSave(); Navigator.pop(context); }, child: const Text("GUARDAR")))])); } }