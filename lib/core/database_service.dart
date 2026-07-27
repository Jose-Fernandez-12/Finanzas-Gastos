import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finanzas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, filePath);

    // Comprobar si la base de datos ya existe
    var exists = await databaseExists(path);

    if (!exists) {
      // Debería ocurrir solo la primera vez que se lanza la app
      print("Creando nueva copia de la base de datos desde los assets");

      // Asegurarse de que el directorio padre existe
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copiar de los assets
      ByteData data = await rootBundle.load(join("assets/db", filePath));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Escribir y volcar los bytes copiados
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      print("Abriendo base de datos existente");
    }

    // Abrir la base de datos
    return await openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        // Habilitar foreign keys si no están habilitadas por defecto
        await db.execute("PRAGMA foreign_keys = ON;");
        // Crear tabla de logs de notificaciones si no existe (migracion no destructiva)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notification_logs (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name    TEXT NOT NULL,
            app_label       TEXT,
            titulo          TEXT,
            cuerpo          TEXT,
            monto_detectado REAL,
            comercio_detectado TEXT,
            tipo_tarjeta    TEXT,
            parseado        INTEGER DEFAULT 0,
            creado_en       TEXT DEFAULT (datetime('now'))
          )
        ''');

        // Tabla de suscripciones (modulo independiente)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suscripciones (
            id                INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre            TEXT NOT NULL,
            monto             REAL NOT NULL,
            dia_cobro         INTEGER NOT NULL DEFAULT 1,
            frecuencia        TEXT NOT NULL DEFAULT 'Mensual',
            recordatorio_dias INTEGER NOT NULL DEFAULT 1,
            color             TEXT NOT NULL DEFAULT '#4F46E5',
            notas             TEXT,
            activa            INTEGER NOT NULL DEFAULT 1,
            fecha_ultimo_cobro TEXT,
            creado_en         TEXT DEFAULT (datetime('now')),
            actualizado_en    TEXT DEFAULT (datetime('now'))
          )
        ''');


        // Migraciones de columnas seguras (no destructivas) para bases de datos existentes
        try { await db.execute("ALTER TABLE cuotas_amortizacion ADD COLUMN fecha_pago_real TEXT;"); } catch (_) {}
        try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN mes_referencia TEXT;"); } catch (_) {}
        try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN es_fijo INTEGER DEFAULT 1;"); } catch (_) {}
        try { await db.execute("ALTER TABLE ingresos ADD COLUMN mes_referencia TEXT;"); } catch (_) {}
        try { await db.execute("ALTER TABLE ingresos ADD COLUMN es_fijo INTEGER DEFAULT 0;"); } catch (_) {}
        try { await db.execute("ALTER TABLE compras_tarjeta ADD COLUMN tasa_interes_mensual REAL DEFAULT 0;"); } catch (_) {}
        try { await db.execute("ALTER TABLE compras_tarjeta ADD COLUMN es_avance INTEGER DEFAULT 0;"); } catch (_) {}
        try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN tasa_interes_mensual REAL DEFAULT 0;"); } catch (_) {}

        // Migraciones para Ahorros (Cuotas y metas)
        try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN cuota_monto REAL DEFAULT 0;"); } catch (_) {}
        try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN frecuencia_cuota TEXT DEFAULT 'Mensual';"); } catch (_) {}
        try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN meses_meta INTEGER;"); } catch (_) {}

        // Migraciones para Suscripciones (Gastos Fijos expandidos)
        try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN tipo_frecuencia TEXT DEFAULT 'Mensual';"); } catch (_) {}
        try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN recordatorio_dias INTEGER DEFAULT 1;"); } catch (_) {}

        // Tabla de presupuesto base cero (sobres virtuales)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS presupuesto_sobres (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_sobre    TEXT NOT NULL,
            monto_asignado  REAL NOT NULL DEFAULT 0,
            gastado         REAL NOT NULL DEFAULT 0,
            color           TEXT NOT NULL DEFAULT '#4F46E5',
            icono           TEXT NOT NULL DEFAULT 'account_balance_wallet',
            mes_referencia  TEXT NOT NULL,
            creado_en       TEXT DEFAULT (datetime('now')),
            actualizado_en  TEXT DEFAULT (datetime('now'))
          )
        ''');

        // Tabla de logros y misiones (gamificación)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS logros_misiones (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            clave           TEXT NOT NULL UNIQUE,
            titulo          TEXT NOT NULL,
            descripcion     TEXT NOT NULL,
            icono           TEXT NOT NULL DEFAULT 'emoji_events',
            categoria       TEXT NOT NULL DEFAULT 'general',
            meta_valor      REAL NOT NULL DEFAULT 0,
            progreso        REAL NOT NULL DEFAULT 0,
            completado      INTEGER NOT NULL DEFAULT 0,
            fecha_completado TEXT,
            creado_en       TEXT DEFAULT (datetime('now'))
          )
        ''');
      },
    );
  }

  // --- Métodos de utilidad generales para envolver las operaciones ---

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    return await db.rawQuery(sql, arguments);
  }

  Future<Map<String, dynamic>?> getOne(String sql, [List<dynamic>? arguments]) async {
    final rows = await query(sql, arguments);
    if (rows.isNotEmpty) {
      return rows.first;
    }
    return null;
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.insert(table, values);
  }
  
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    return await db.rawInsert(sql, arguments);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    final db = await instance.database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    return await db.rawUpdate(sql, arguments);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await instance.database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
  
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    return await db.rawDelete(sql, arguments);
  }

  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    await db.execute(sql, arguments);
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await instance.database;
    return await db.transaction(action);
  }

  Future close() async {
    final db = await instance.database;
    _database = null;
    return db.close();
  }
}
