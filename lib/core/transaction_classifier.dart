import 'database_service.dart';
import '../models/tarjeta_credito.dart';

/// Resultado de clasificar una transaccion detectada desde una notificacion.
enum TransactionRoute {
  /// La tarjeta es de credito y esta registrada en la app → ofrecer compra_tarjeta
  creditCard,
  /// Pago con debito, efectivo u otro → crear gasto_fijo simple
  simpleExpense,
  /// No se puede determinar el tipo → preguntar al usuario
  unknown,
}

class ClassifiedTransaction {
  final TransactionRoute route;
  final Map<String, dynamic> rawData;

  /// Solo presente si route == creditCard: la tarjeta registrada que coincide
  final TarjetaCredito? tarjetaMatch;

  const ClassifiedTransaction({
    required this.route,
    required this.rawData,
    this.tarjetaMatch,
  });
}

/// Clasifica una transaccion detectada y determina la ruta de registro correcta.
class TransactionClassifier {
  /// Tipos de tarjeta que identifican credito
  static const _creditTypes = {'credito', 'credito_avance'};
  /// Tipos de tarjeta que identifican debito/efectivo
  static const _debitTypes  = {'debito', 'efectivo', 'transferencia'};

  /// Mapa de paquete → banco para emparejar con tarjetas registradas
  static const _packageToBanco = {
    'com.nu.production'                   : 'nu',
    'com.bancolombia.smv'                 : 'bancolombia',
    'com.rappi.pay'                       : 'rappi',
    'com.google.android.apps.walletnfcrel': null, // Google Pay puede ser cualquier banco
    'com.nequi.mobilebanking'             : 'nequi',
    'co.com.davivienda.mobileapp'         : 'davivienda',
  };

  /// Clasifica la transaccion consultando las tarjetas registradas en la app.
  static Future<ClassifiedTransaction> classify(Map<String, dynamic> rawData) async {
    final tipoTarjeta = (rawData['tipo_tarjeta'] as String? ?? '').toLowerCase();
    final pkg = rawData['package_name'] as String? ?? '';

    // 1. Si es debito/efectivo por tipo detectado → gasto simple directamente
    if (_debitTypes.contains(tipoTarjeta)) {
      return ClassifiedTransaction(route: TransactionRoute.simpleExpense, rawData: rawData);
    }

    // 2. Si es credito o credito_avance → buscar tarjeta registrada
    if (_creditTypes.contains(tipoTarjeta)) {
      final tarjeta = await _findMatchingCard(pkg);
      if (tarjeta != null) {
        return ClassifiedTransaction(
          route: TransactionRoute.creditCard,
          rawData: rawData,
          tarjetaMatch: tarjeta,
        );
      }
      // Credito pero sin tarjeta registrada → gasto simple
      return ClassifiedTransaction(route: TransactionRoute.simpleExpense, rawData: rawData);
    }

    // 3. Tipo desconocido → preguntar al usuario
    return ClassifiedTransaction(route: TransactionRoute.unknown, rawData: rawData);
  }

  /// Busca en la base de datos una tarjeta cuyo banco coincida con la app que genero la notificacion.
  static Future<TarjetaCredito?> _findMatchingCard(String packageName) async {
    try {
      final bancoKeyword = _packageToBanco[packageName];
      final tarjetas = await DatabaseService.instance.query(
        "SELECT * FROM tarjetas_credito WHERE activa = 1"
      );
      if (tarjetas.isEmpty) return null;

      for (final row in tarjetas) {
        final banco = (row['banco'] as String? ?? '').toLowerCase();
        if (bancoKeyword != null && banco.contains(bancoKeyword)) {
          return TarjetaCredito.fromMap(row);
        }
      }

      // Si no hay keyword especifica (Google Pay) → retornar null para que el usuario elija
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sugiere una categoria basada en el nombre del comercio.
  static int suggestCategoryId(String comercio) {
    final c = comercio.toLowerCase();
    if (_matchesAny(c, ['supermercado', 'exito', 'carulla', 'jumbo', 'olimpica', 'mercado', 'lider', 'd1', 'ara', 'metro'])) return 1; // Alimentacion
    if (_matchesAny(c, ['restaurante', 'mcdonald', 'burger', 'pizza', 'subway', 'crepes', 'cafe', 'panaderia'])) return 1; // Alimentacion
    if (_matchesAny(c, ['netflix', 'spotify', 'youtube', 'amazon', 'disney', 'hbo', 'streaming'])) return 4; // Entretenimiento
    if (_matchesAny(c, ['uber', 'cabify', 'taxi', 'transporte', 'gasolina', 'combustible'])) return 5; // Transporte
    if (_matchesAny(c, ['farmacia', 'drogueria', 'salud', 'clinica', 'medico', 'hospital'])) return 6; // Salud
    if (_matchesAny(c, ['zara', 'h&m', 'ropa', 'falabella', 'ripley', 'liverpool'])) return 3; // Ropa
    return 2; // General / Otros
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
