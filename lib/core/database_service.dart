import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'amortization_calculator.dart';

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
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute("PRAGMA foreign_keys = ON;");
        // Migraciones de columnas seguras para bases de datos existentes
        await _runSafeMigrations(db);
        // Corrección de cuotas RappiCard
        await _fixRappiCardCuotas(db);
        // Limpieza de datos históricos
        await _cleanupLegacyData(db);
      },
    );
  }
  Future<void> _onCreate(Database db, int version) async {
    await db.execute("PRAGMA foreign_keys = ON;");
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias_ingreso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        icono TEXT NOT NULL,
        color TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');
    
    await db.execute('''
      INSERT INTO categorias_ingreso (nombre, icono, color) VALUES 
      ('Salario', 'payments', '#4CAF50'),
      ('Negocio', 'storefront', '#2196F3'),
      ('Inversiones', 'trending_up', '#9C27B0'),
      ('Otros', 'more_horiz', '#757575')
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias_gasto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        icono TEXT NOT NULL,
        color TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');
    
    await db.execute('''
      INSERT INTO categorias_gasto (nombre, icono, color) VALUES 
      ('Vivienda', 'home', '#F44336'),
      ('Alimentación', 'restaurant', '#FF9800'),
      ('Transporte', 'directions_car', '#03A9F4'),
      ('Educación', 'school', '#9C27B0'),
      ('Entretenimiento', 'sports_esports', '#E91E63'),
      ('Salud', 'favorite', '#00BCD4'),
      ('Otros', 'more_horiz', '#757575')
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tarjetas_credito (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        banco                 TEXT NOT NULL,
        nombre_tarjeta        TEXT NOT NULL,
        cupo_total            REAL NOT NULL DEFAULT 0,
        cupo_disponible       REAL NOT NULL DEFAULT 0,
        fecha_corte           INTEGER NOT NULL DEFAULT 1,
        fecha_pago            INTEGER NOT NULL DEFAULT 15,
        tasa_interes_mensual  REAL NOT NULL DEFAULT 0,
        cupo_avances_total    REAL NOT NULL DEFAULT 0,
        cuota_manejo          REAL NOT NULL DEFAULT 0,
        color                 TEXT NOT NULL DEFAULT '#1976D2',
        notas                 TEXT,
        activa                INTEGER NOT NULL DEFAULT 1,
        creado_en             TEXT DEFAULT (datetime('now')),
        actualizado_en        TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS compras_tarjeta (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        tarjeta_id            INTEGER NOT NULL,
        descripcion           TEXT NOT NULL,
        monto_total           REAL NOT NULL,
        num_cuotas            INTEGER NOT NULL DEFAULT 1,
        fecha_compra          TEXT NOT NULL,
        tasa_interes_mensual  REAL DEFAULT 0,
        es_avance             INTEGER DEFAULT 0,
        creado_en             TEXT DEFAULT (datetime('now')),
        FOREIGN KEY(tarjeta_id) REFERENCES tarjetas_credito(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cuotas_amortizacion (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        compra_id        INTEGER NOT NULL,
        tarjeta_id       INTEGER NOT NULL,
        numero_cuota     INTEGER NOT NULL,
        fecha_vencimiento TEXT NOT NULL,
        saldo_inicial    REAL NOT NULL,
        valor_capital    REAL NOT NULL,
        valor_interes    REAL NOT NULL,
        valor_cuota      REAL NOT NULL,
        saldo_final      REAL NOT NULL,
        estado           TEXT NOT NULL DEFAULT 'pendiente',
        fecha_pago_real  TEXT,
        FOREIGN KEY(compra_id) REFERENCES compras_tarjeta(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gastos_fijos (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id     INTEGER NOT NULL DEFAULT 1,
        sobre_id         INTEGER,
        nombre           TEXT NOT NULL,
        monto            REAL NOT NULL,
        dia_pago         INTEGER NOT NULL DEFAULT 1,
        es_fijo          INTEGER DEFAULT 1,
        mes_referencia   TEXT NOT NULL DEFAULT '',
        notas            TEXT,
        activo           INTEGER NOT NULL DEFAULT 1,
        fecha_ultimo_pago TEXT,
        tipo_frecuencia  TEXT DEFAULT 'Mensual',
        recordatorio_dias INTEGER DEFAULT 1,
        creado_en        TEXT DEFAULT (datetime('now')),
        actualizado_en   TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingresos (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id   INTEGER NOT NULL DEFAULT 1,
        descripcion    TEXT,
        monto          REAL NOT NULL,
        es_fijo        INTEGER DEFAULT 0,
        fecha          TEXT NOT NULL DEFAULT '',
        mes_referencia TEXT NOT NULL DEFAULT '',
        notas          TEXT,
        creado_en      TEXT DEFAULT (datetime('now')),
        actualizado_en TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bolsillos_ahorro (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre           TEXT NOT NULL,
        meta_monto       REAL NOT NULL DEFAULT 0,
        monto_actual     REAL NOT NULL DEFAULT 0,
        fecha_creacion   TEXT NOT NULL DEFAULT (datetime('now')),
        fecha_meta       TEXT,
        color            TEXT NOT NULL DEFAULT '#4CAF50',
        notas            TEXT,
        activo           INTEGER NOT NULL DEFAULT 1,
        cuota_monto      REAL DEFAULT 0,
        frecuencia_cuota TEXT DEFAULT 'Mensual',
        meses_meta       INTEGER,
        actualizado_en   TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cuentas_cobrar (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_deudor TEXT NOT NULL,
        telefono     TEXT,
        monto_total  REAL NOT NULL,
        saldo_pendiente REAL NOT NULL,
        modalidad    TEXT,
        num_cuotas   INTEGER DEFAULT 1,
        valor_cuota  REAL,
        fecha_primer_vencimiento TEXT,
        periodicidad TEXT,
        estado       TEXT NOT NULL DEFAULT 'AL_DIA',
        notas        TEXT,
        creado_en    TEXT DEFAULT (datetime('now')),
        actualizado_en TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suscripciones (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre              TEXT NOT NULL,
        monto               REAL NOT NULL,
        dia_cobro           INTEGER NOT NULL DEFAULT 1,
        frecuencia          TEXT NOT NULL DEFAULT 'Mensual',
        recordatorio_dias   INTEGER NOT NULL DEFAULT 1,
        color               TEXT NOT NULL DEFAULT '#4F46E5',
        notas               TEXT,
        activa              INTEGER NOT NULL DEFAULT 1,
        fecha_ultimo_cobro  TEXT,
        creado_en           TEXT DEFAULT (datetime('now')),
        actualizado_en      TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_logs (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name        TEXT NOT NULL,
        app_label           TEXT,
        titulo              TEXT,
        cuerpo              TEXT,
        monto_detectado     REAL,
        comercio_detectado  TEXT,
        tipo_tarjeta        TEXT,
        parseado            INTEGER DEFAULT 0,
        creado_en           TEXT DEFAULT (datetime('now'))
      )
    ''');

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS presupuesto_sobre_gastos (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        sobre_id  INTEGER NOT NULL,
        monto     REAL NOT NULL,
        concepto  TEXT,
        fecha     TEXT DEFAULT (datetime('now')),
        FOREIGN KEY(sobre_id) REFERENCES presupuesto_sobres(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS logros_misiones (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        clave            TEXT NOT NULL UNIQUE,
        titulo           TEXT NOT NULL,
        descripcion      TEXT NOT NULL,
        icono            TEXT NOT NULL DEFAULT 'emoji_events',
        categoria        TEXT NOT NULL DEFAULT 'general',
        meta_valor       REAL NOT NULL DEFAULT 0,
        progreso         REAL NOT NULL DEFAULT 0,
        completado       INTEGER NOT NULL DEFAULT 0,
        fecha_completado TEXT,
        creado_en        TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Para migraciones futuras: if (oldVersion < 2) { ... }
  }

  Future<void> _runSafeMigrations(Database db) async {
    // Estas migraciones son compatibles con bases de datos anteriores al esquema en código
    try { await db.execute("ALTER TABLE cuotas_amortizacion ADD COLUMN fecha_pago_real TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN mes_referencia TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN es_fijo INTEGER DEFAULT 1;"); } catch (_) {}
    try { await db.execute("ALTER TABLE ingresos ADD COLUMN mes_referencia TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE ingresos ADD COLUMN es_fijo INTEGER DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE compras_tarjeta ADD COLUMN tasa_interes_mensual REAL DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE compras_tarjeta ADD COLUMN es_avance INTEGER DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN tasa_interes_mensual REAL DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN cupo_avances_total REAL DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN cuota_manejo REAL DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN color TEXT DEFAULT '#1976D2';"); } catch (_) {}
    try { await db.execute("ALTER TABLE tarjetas_credito ADD COLUMN notas TEXT;"); } catch (_) {}
    try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN cuota_monto REAL DEFAULT 0;"); } catch (_) {}
    try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN frecuencia_cuota TEXT DEFAULT 'Mensual';"); } catch (_) {}
    try { await db.execute("ALTER TABLE bolsillos_ahorro ADD COLUMN meses_meta INTEGER;"); } catch (_) {}
    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN tipo_frecuencia TEXT DEFAULT 'Mensual';"); } catch (_) {}
    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN recordatorio_dias INTEGER DEFAULT 1;"); } catch (_) {}
    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN sobre_id INTEGER;"); } catch (_) {}

    try { await db.execute("ALTER TABLE gastos_fijos ADD COLUMN actualizado_en TEXT DEFAULT (datetime('now'));"); } catch (_) {}
    try { await db.execute("ALTER TABLE ingresos ADD COLUMN actualizado_en TEXT DEFAULT (datetime('now'));"); } catch (_) {}
    try { await db.execute("ALTER TABLE cuentas_cobrar ADD COLUMN actualizado_en TEXT DEFAULT (datetime('now'));"); } catch (_) {}

    // Tablas de categorias (pueden faltar en versiones viejas)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias_ingreso (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL,
        icono TEXT NOT NULL, color TEXT NOT NULL, activa INTEGER NOT NULL DEFAULT 1
      )
    ''');
    final catIngCount = (await db.rawQuery('SELECT COUNT(*) as c FROM categorias_ingreso')).first['c'] as int;
    if (catIngCount == 0) {
      await db.execute('''
        INSERT INTO categorias_ingreso (nombre, icono, color) VALUES 
        ('Salario', 'payments', '#4CAF50'), ('Negocio', 'storefront', '#2196F3'),
        ('Inversiones', 'trending_up', '#9C27B0'), ('Otros', 'more_horiz', '#757575')
      ''');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias_gasto (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL,
        icono TEXT NOT NULL, color TEXT NOT NULL, activa INTEGER NOT NULL DEFAULT 1
      )
    ''');
    final catGasCount = (await db.rawQuery('SELECT COUNT(*) as c FROM categorias_gasto')).first['c'] as int;
    if (catGasCount == 0) {
      await db.execute('''
        INSERT INTO categorias_gasto (nombre, icono, color) VALUES 
        ('Vivienda', 'home', '#F44336'), ('Alimentacion', 'restaurant', '#FF9800'),
        ('Transporte', 'directions_car', '#03A9F4'), ('Educacion', 'school', '#9C27B0'),
        ('Entretenimiento', 'sports_esports', '#E91E63'), ('Salud', 'favorite', '#00BCD4'),
        ('Otros', 'more_horiz', '#757575')
      ''');
    }

    // Crear tablas que pueden faltar en versiones anteriores
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT, package_name TEXT NOT NULL,
        app_label TEXT, titulo TEXT, cuerpo TEXT, monto_detectado REAL,
        comercio_detectado TEXT, tipo_tarjeta TEXT, parseado INTEGER DEFAULT 0,
        creado_en TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suscripciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL,
        monto REAL NOT NULL, dia_cobro INTEGER NOT NULL DEFAULT 1,
        frecuencia TEXT NOT NULL DEFAULT 'Mensual', recordatorio_dias INTEGER NOT NULL DEFAULT 1,
        color TEXT NOT NULL DEFAULT '#4F46E5', notas TEXT, activa INTEGER NOT NULL DEFAULT 1,
        fecha_ultimo_cobro TEXT, creado_en TEXT DEFAULT (datetime('now')),
        actualizado_en TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presupuesto_sobres (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre_sobre TEXT NOT NULL,
        monto_asignado REAL NOT NULL DEFAULT 0, gastado REAL NOT NULL DEFAULT 0,
        color TEXT NOT NULL DEFAULT '#4F46E5', icono TEXT NOT NULL DEFAULT 'account_balance_wallet',
        mes_referencia TEXT NOT NULL, creado_en TEXT DEFAULT (datetime('now')),
        actualizado_en TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presupuesto_sobre_gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT, sobre_id INTEGER NOT NULL,
        monto REAL NOT NULL, concepto TEXT, fecha TEXT DEFAULT (datetime('now')),
        FOREIGN KEY(sobre_id) REFERENCES presupuesto_sobres(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS logros_misiones (
        id INTEGER PRIMARY KEY AUTOINCREMENT, clave TEXT NOT NULL UNIQUE,
        titulo TEXT NOT NULL, descripcion TEXT NOT NULL, icono TEXT NOT NULL DEFAULT 'emoji_events',
        categoria TEXT NOT NULL DEFAULT 'general', meta_valor REAL NOT NULL DEFAULT 0,
        progreso REAL NOT NULL DEFAULT 0, completado INTEGER NOT NULL DEFAULT 0,
        fecha_completado TEXT, creado_en TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _cleanupLegacyData(Database db) async {
    try {
      await db.execute("DELETE FROM gastos_fijos WHERE nombre LIKE 'Cuota TC:%';");
      await db.transaction((txn) async {
        final rows = await txn.rawQuery("SELECT id FROM compras_tarjeta WHERE descripcion IN ('pago minimo', 'nubank')");
        for (var r in rows) {
          final id = r['id'];
          await txn.delete('cuotas_amortizacion', where: 'compra_id = ?', whereArgs: [id]);
          await txn.delete('compras_tarjeta', where: 'id = ?', whereArgs: [id]);
        }
      });
      await _sincronizarDatosRealesRappiCard(db);
    } catch (_) {}
  }

  static Future<void> _sincronizarDatosRealesRappiCard(Database db) async {
    try {
      final rappi = (await db.rawQuery("SELECT id FROM tarjetas_credito WHERE banco LIKE '%rappi%' OR nombre_tarjeta LIKE '%rappi%'")).firstOrNull;
      if (rappi == null) return;
      final int tId = rappi['id'] as int;

      // Actualizar datos generales de la tarjeta RappiCard segun extracto oficial
      await db.rawUpdate('''
        UPDATE tarjetas_credito
        SET cupo_total = 6100000,
            cupo_disponible = 2464688.99,
            cupo_avances_total = 847689.39,
            fecha_corte = 20,
            fecha_pago = 31,
            tasa_interes_mensual = 2.13,
            actualizado_en = datetime('now')
        WHERE id = ?
      ''', [tId]);

      // Compras segun el extracto oficial
      final comprasReal = [
        {
          'desc': 'AVANCE DIGITAL',
          'monto': 2433000.0,
          'num_cuotas': 4,
          'cuota_act': 1,
          'fecha': '2026-06-20',
          'tasa': 2.1308,
          'es_avance': 1,
          'saldo': 1563676.29,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 390919.07, 'int': 0.0, 'val': 390919.07, 'est': 'PENDIENTE'},
            {'num': 2, 'fecha': '2026-09-30', 'cap': 390919.07, 'int': 33306.91, 'val': 424225.98, 'est': 'PENDIENTE'},
            {'num': 3, 'fecha': '2026-10-31', 'cap': 390919.07, 'int': 24980.18, 'val': 415899.25, 'est': 'PENDIENTE'},
            {'num': 4, 'fecha': '2026-11-30', 'cap': 390919.08, 'int': 16653.46, 'val': 407572.54, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'GOOGLE *LifeAfter',
          'monto': 122000.0,
          'num_cuotas': 2,
          'cuota_act': 1,
          'fecha': '2026-06-25',
          'tasa': 2.1308,
          'es_avance': 0,
          'saldo': 81333.34,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 40666.67, 'int': 2604.49, 'val': 43271.16, 'est': 'PENDIENTE'},
            {'num': 2, 'fecha': '2026-09-30', 'cap': 40666.67, 'int': 866.53, 'val': 41533.20, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'CORP UNIV IBEROAMERICA',
          'monto': 2191271.0,
          'num_cuotas': 6,
          'cuota_act': 2,
          'fecha': '2026-07-16',
          'tasa': 2.1300,
          'es_avance': 0,
          'saldo': 1826059.17,
          'cuotas': [
            {'num': 1, 'fecha': '2026-07-31', 'cap': 365211.83, 'int': 0.0, 'val': 365211.83, 'est': 'PAGADA'},
            {'num': 2, 'fecha': '2026-08-31', 'cap': 365211.83, 'int': 70000.72, 'val': 435212.55, 'est': 'PENDIENTE'},
            {'num': 3, 'fecha': '2026-09-30', 'cap': 365211.83, 'int': 38914.86, 'val': 404126.69, 'est': 'PENDIENTE'},
            {'num': 4, 'fecha': '2026-10-31', 'cap': 365211.83, 'int': 31131.89, 'val': 396343.72, 'est': 'PENDIENTE'},
            {'num': 5, 'fecha': '2026-11-30', 'cap': 365211.83, 'int': 23348.92, 'val': 388560.75, 'est': 'PENDIENTE'},
            {'num': 6, 'fecha': '2026-12-31', 'cap': 365211.85, 'int': 15565.94, 'val': 380777.79, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'PAGO SEGURO EMBEBIDO',
          'monto': 22928.0,
          'num_cuotas': 1,
          'cuota_act': 1,
          'fecha': '2026-07-24',
          'tasa': 0.0,
          'es_avance': 0,
          'saldo': 22928.0,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 22928.0, 'int': 0.0, 'val': 22928.0, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'GOOGLE *Call of Duty M',
          'monto': 24900.0,
          'num_cuotas': 1,
          'cuota_act': 1,
          'fecha': '2026-08-06',
          'tasa': 0.0,
          'es_avance': 0,
          'saldo': 24900.0,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 24900.0, 'int': 0.0, 'val': 24900.0, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'DLO*GOOGLE GOOGLE ONE',
          'monto': 20000.0,
          'num_cuotas': 1,
          'cuota_act': 1,
          'fecha': '2026-08-08',
          'tasa': 0.0,
          'es_avance': 0,
          'saldo': 20000.0,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 20000.0, 'int': 0.0, 'val': 20000.0, 'est': 'PENDIENTE'},
          ]
        },
        {
          'desc': 'GOOGLE *Minecraft Drea',
          'monto': 23609.0,
          'num_cuotas': 1,
          'cuota_act': 1,
          'fecha': '2026-08-11',
          'tasa': 0.0,
          'es_avance': 0,
          'saldo': 23609.0,
          'cuotas': [
            {'num': 1, 'fecha': '2026-08-31', 'cap': 23609.0, 'int': 0.0, 'val': 23609.0, 'est': 'PENDIENTE'},
          ]
        },
      ];

      // Sincronizar compras y generar sus tablas de amortizacion exactas
      await db.transaction((txn) async {
        // Limpiar compras previas de esta tarjeta para dejar los datos oficiales 1:1
        final comprasPrevias = await txn.rawQuery("SELECT id FROM compras_tarjeta WHERE tarjeta_id = ?", [tId]);
        for (var cp in comprasPrevias) {
          await txn.delete('cuotas_amortizacion', where: 'compra_id = ?', whereArgs: [cp['id']]);
        }
        await txn.delete('compras_tarjeta', where: 'tarjeta_id = ?', whereArgs: [tId]);

        for (var cr in comprasReal) {
          final int cid = await txn.insert('compras_tarjeta', {
            'tarjeta_id': tId,
            'descripcion': cr['desc'],
            'monto_total': cr['monto'],
            'num_cuotas': cr['num_cuotas'],
            'cuota_actual': cr['cuota_act'],
            'fecha_compra': cr['fecha'],
            'tasa_interes_mensual': cr['tasa'],
            'es_avance': cr['es_avance'],
            'saldo_capital': cr['saldo'],
          });

          final listaCuotas = cr['cuotas'] as List<Map<String, dynamic>>;
          double saldo = cr['saldo'] as double;

          for (var q in listaCuotas) {
            final double cap = (q['cap'] as num).toDouble();
            final double intVal = (q['int'] as num).toDouble();
            final double valC = (q['val'] as num).toDouble();
            final String fVenc = q['fecha'] as String;
            final String est = q['est'] as String;
            final String? fPago = est == 'PAGADA' ? cr['fecha'] as String : null;

            await txn.insert('cuotas_amortizacion', {
              'compra_id': cid,
              'tarjeta_id': tId,
              'numero_cuota': q['num'],
              'fecha_vencimiento': fVenc,
              'saldo_inicial': saldo,
              'valor_capital': cap,
              'valor_interes': intVal,
              'valor_cuota': valC,
              'saldo_final': saldo - cap,
              'estado': est,
              'fecha_pago_real': fPago
            });
            saldo -= cap;
          }
        }
      });
    } catch (_) {}
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

  static Future<void> _fixRappiCardCuotas(Database db) async {
    try {
      final tarjetas = await db.rawQuery("SELECT * FROM tarjetas_credito WHERE banco LIKE '%rappi%'");
      for (var t in tarjetas) {
        final tId = t['id'];
        final banco = t['banco'].toString();
        final diaCorte = (t['fecha_corte'] as num).toInt();
        final diaPago = (t['fecha_pago'] as num).toInt();

        final compras = await db.rawQuery("SELECT * FROM compras_tarjeta WHERE tarjeta_id = ? AND num_cuotas > 1", [tId]);
        for (var c in compras) {
          final compraId = c['id'] as int;
          final montoTotal = (c['monto_total'] as num).toDouble();
          final tasaMensual = (c['tasa_interes_mensual'] as num).toDouble();
          final numCuotas = c['num_cuotas'] as int;
          final fechaCompra = c['fecha_compra'].toString();

          final cuotasExistentes = await db.rawQuery("SELECT numero_cuota, estado, fecha_pago_real FROM cuotas_amortizacion WHERE compra_id = ?", [compraId]);
          final Map<int, Map<String, dynamic>> estadosExistentes = {};
          for (var q in cuotasExistentes) {
            estadosExistentes[q['numero_cuota'] as int] = {
              'estado': q['estado'],
              'fecha_pago_real': q['fecha_pago_real']
            };
          }

          final nuevaTabla = AmortizationCalculator.generarTablaAmortizacion(
            montoTotal, tasaMensual, numCuotas, fechaCompra, diaCorte, diaPago, banco
          );

          await db.transaction((txn) async {
            await txn.delete('cuotas_amortizacion', where: 'compra_id = ?', whereArgs: [compraId]);
            for (var cuota in nuevaTabla) {
              final numC = cuota['numero_cuota'] as int;
              final est = estadosExistentes[numC]?['estado'] ?? cuota['estado'];
              final fPagoReal = estadosExistentes[numC]?['fecha_pago_real'];

              await txn.insert('cuotas_amortizacion', {
                'compra_id': compraId,
                'tarjeta_id': tId,
                'numero_cuota': numC,
                'fecha_vencimiento': cuota['fecha_vencimiento'],
                'saldo_inicial': cuota['saldo_inicial'],
                'valor_capital': cuota['valor_capital'],
                'valor_interes': cuota['valor_interes'],
                'valor_cuota': cuota['valor_cuota'],
                'saldo_final': cuota['saldo_final'],
                'estado': est,
                'fecha_pago_real': fPagoReal
              });
            }
          });
        }
      }
      print("Migracion de cuotas de RappiCard completada con exito.");
    } catch (e) {
      print("Error al migrar cuotas de RappiCard: $e");
    }
  }
}
