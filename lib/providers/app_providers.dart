import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/local_repository.dart';

/// Estado del dashboard
class DashboardProvider extends ChangeNotifier {
  Map<String, dynamic>? _data;
  bool  _loading = false;
  String? _error;

  Map<String, dynamic>? get data    => _data;
  bool                   get loading => _loading;
  String?                get error   => _error;

  // Capacidad crediticia
  double get ingresos      => (_data?['data']?['capacidad_crediticia']?['ingresos_mes']      ?? 0).toDouble();
  double get gastosFijos   => (_data?['data']?['capacidad_crediticia']?['total_gastos_fijos'] ?? 0).toDouble();
  double get cuotasTarj    => (_data?['data']?['capacidad_crediticia']?['cuotas_tarjetas_mes'] ?? 0).toDouble();
  double get liquidez      => (_data?['data']?['capacidad_crediticia']?['liquidez_disponible'] ?? 0).toDouble();
  double get pctEndeudamiento => (_data?['data']?['capacidad_crediticia']?['porcentaje_endeudamiento'] ?? 0).toDouble();
  String get nivelRiesgo   => _data?['data']?['capacidad_crediticia']?['nivel_riesgo'] ?? 'BAJO';

  List<dynamic> get tarjetas        => _data?['data']?['tarjetas']        ?? [];
  List<dynamic> get proximasCuotas  => _data?['data']?['proximas_cuotas'] ?? [];
  List<dynamic> get cuentasMora     => _data?['data']?['cuentas_en_mora'] ?? [];
  List<dynamic> get ahorros         => _data?['data']?['ahorros']         ?? [];

  double get totalDeudaTarjetas => (_data?['data']?['totales']?['deuda_tarjetas'] ?? 0).toDouble();
  double get totalCuentasCobrar => (_data?['data']?['totales']?['cuentas_cobrar'] ?? 0).toDouble();
  double get totalAhorros       => (_data?['data']?['totales']?['total_ahorros'] ?? 0).toDouble();

  Future<void> cargar() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _data = await LocalRepository.instance.getDashboard();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// Estado de tarjetas
class TarjetasProvider extends ChangeNotifier {
  List<dynamic> _tarjetas = [];
  List<Map<String, dynamic>> _comprasActivas = [];
  bool    _loading = false;
  String? _error;

  List<dynamic>              get tarjetas       => _tarjetas;
  List<Map<String, dynamic>> get comprasActivas => _comprasActivas;
  bool                       get loading        => _loading;
  String?                    get error          => _error;

  Future<void> cargar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await LocalRepository.instance.getTarjetas();
      _tarjetas = r['data'] ?? [];

      // Cargar compras activas de todas las tarjetas para el resumen
      List<Map<String, dynamic>> allCompras = [];
      for (var t in _tarjetas) {
        final tId = t['id'] as int?;
        if (tId != null) {
          try {
            final cr = await LocalRepository.instance.getComprasTarjeta(tId);
            final lista = cr['data'] as List<dynamic>? ?? [];
            for (var c in lista) {
              if (c is Map) {
                final map = Map<String, dynamic>.from(c);
                final cuotas = (map['cuotas'] as List?) ?? [];
                final todasPagadas = cuotas.isNotEmpty && cuotas.every((cuota) => cuota['estado'] == 'PAGADA');
                final saldo = (map['saldo_capital'] as num?)?.toDouble() ?? 0;
                if (!todasPagadas && saldo > 1) {
                  map['nombre_tarjeta'] = t['nombre_tarjeta'] ?? t['banco'] ?? '';
                  map['tarjeta_color']  = t['color'];
                  map['tarjeta_id']     = tId;
                  allCompras.add(map);
                }
              }
            }
          } catch (_) {}
        }
      }
      _comprasActivas = allCompras;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> getCompras(int tarjetaId) async {
    final r = await LocalRepository.instance.getComprasTarjeta(tarjetaId);
    return r['data'] ?? [];
  }
}

/// Estado de ingresos
class IngresosProvider extends ChangeNotifier {
  List<dynamic> _ingresos = [];
  double        _total    = 0;
  bool    _loading = false;
  String? _error;

  List<dynamic> get ingresos => _ingresos;
  double        get total    => _total;
  bool          get loading  => _loading;
  String?       get error    => _error;

  Future<void> cargar({String? mes}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await LocalRepository.instance.getIngresos(mes: mes);
      _ingresos = r['data'] ?? [];
      double sum = 0;
      for (var i in _ingresos) {
        sum += (i['monto'] as num?)?.toDouble() ?? 0;
      }
      _total = sum;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// Estado de gastos fijos
class GastosProvider extends ChangeNotifier {
  List<dynamic> _gastos = [];
  double        _total  = 0;
  bool    _loading = false;
  String? _error;
  String  _mes = '';

  List<dynamic> get gastos  => _gastos;
  double        get total   => _total;
  bool          get loading => _loading;
  String?       get error   => _error;
  String        get mes     => _mes;

  Future<void> cargar({String? mes}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await LocalRepository.instance.getGastosFijos(mes: mes);
      _gastos = r['data'] ?? [];
      double sum = 0;
      for (var g in _gastos) {
        sum += (g['monto'] as num?)?.toDouble() ?? 0;
      }
      _total = sum;
      _mes   = mes ?? DateFormat('yyyy-MM').format(DateTime.now());
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// Estado de ahorros
class AhorrosProvider extends ChangeNotifier {
  List<dynamic> _ahorros = [];
  bool    _loading = false;
  String? _error;

  List<dynamic> get ahorros  => _ahorros;
  bool          get loading  => _loading;
  String?       get error    => _error;

  Future<void> cargar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await LocalRepository.instance.getAhorros();
      _ahorros = r['data'] ?? [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// Estado de cuentas por cobrar
class CuentasCobrarProvider extends ChangeNotifier {
  List<dynamic> _cuentas = [];
  bool    _loading = false;
  String? _error;

  List<dynamic> get cuentas  => _cuentas;
  bool          get loading  => _loading;
  String?       get error    => _error;

  Future<void> cargar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await LocalRepository.instance.getCuentasCobrar();
      _cuentas = r['data'] ?? [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

/// Estado de Analiticas
class AnalyticsProvider extends ChangeNotifier {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  List<dynamic> get historical => _data?['data']?['historical'] ?? [];
  List<dynamic> get proyeccion => _data?['data']?['proyeccion'] ?? [];
  double get deudaTarjetas => (_data?['data']?['deuda_tarjetas'] ?? 0).toDouble();
  double get cuentasPorCobrar => (_data?['data']?['cuentas_por_cobrar'] ?? 0).toDouble();

  String get mesLibreDeDeuda {
    final proj = proyeccion;
    if (proj.isEmpty) return 'No hay deuda';
    for (var p in proj) {
      if ((p['deuda_restante'] as num) <= 0) {
        return p['label'];
      }
    }
    return proj.last['label']; // si al final todavia hay, retorna el ultimo
  }

  Future<void> cargar({double pctAbonoExtra = 0.0, bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final r = await LocalRepository.instance.getAnalytics(pctAbonoExtra: pctAbonoExtra);
      _data = r;
    } catch (e) {
      if (!silent) _error = e.toString();
    } finally {
      if (!silent) _loading = false;
      notifyListeners();
    }
  }
}
