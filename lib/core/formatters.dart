import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Formateador de moneda colombiana
final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

String formatCOP(double monto) => _cop.format(monto);
String formatCOPStr(dynamic monto) => _cop.format((monto is num) ? monto.toDouble() : double.tryParse('$monto') ?? 0);

/// Formateador de fecha
String formatFecha(String? fecha) {
  if (fecha == null || fecha.isEmpty) return '-';
  try {
    final dt = DateTime.parse(fecha);
    return DateFormat('dd/MM/yyyy', 'es').format(dt);
  } catch (_) {
    return fecha;
  }
}

/// Formateador de mes
String formatMes(String? mes) {
  if (mes == null || mes.isEmpty) return '-';
  try {
    final dt = DateTime.parse('$mes-01');
    return DateFormat('MMMM yyyy', 'es').format(dt);
  } catch (_) {
    return mes;
  }
}

/// Mes actual en formato YYYY-MM
String mesActual() => DateFormat('yyyy-MM').format(DateTime.now());

/// Sumar/restar meses a un formato YYYY-MM
String sumMonths(String baseMonth, int offset) {
  try {
    final dt = DateTime.parse('$baseMonth-01');
    final newDt = DateTime(dt.year, dt.month + offset, 1);
    return DateFormat('yyyy-MM').format(newDt);
  } catch (_) {
    return baseMonth;
  }
}

/// Color hexadecimal a Color de Flutter
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// Color representativo de la tarjeta según banco o nombre (Ej: Nu morado, Rappi negro)
String getTarjetaColorHex(Map<String, dynamic>? tarjeta) {
  if (tarjeta == null) return '#6366F1';
  final banco = (tarjeta['banco']?.toString() ?? '').toLowerCase();
  final nombre = (tarjeta['nombre_tarjeta']?.toString() ?? '').toLowerCase();
  final combined = '$banco $nombre';

  if (combined.contains('nu') || combined.contains('nubank')) {
    return '#820AD1'; // Morado Nu
  }
  if (combined.contains('rappi') || combined.contains('rappicard')) {
    return '#18181B'; // Negro RappiCard
  }
  if (combined.contains('bancolombia')) {
    return '#1E3A8A'; // Azul Bancolombia
  }
  if (combined.contains('davivienda')) {
    return '#DC2626'; // Rojo Davivienda
  }
  if (combined.contains('bbva')) {
    return '#1D4ED8'; // Azul BBVA
  }
  if (combined.contains('falabella')) {
    return '#059669'; // Verde Falabella
  }
  if (combined.contains('scotiabank') || combined.contains('colpatria')) {
    return '#E11D48'; // Rojo Scotiabank / Colpatria
  }
  if (combined.contains('bogota') || combined.contains('bogotá')) {
    return '#0284C7'; // Azul Banco de Bogotá
  }
  if (combined.contains('occidente')) {
    return '#2563EB'; // Azul Occidente
  }
  if (combined.contains('popular')) {
    return '#16A34A'; // Verde Banco Popular
  }
  if (combined.contains('av villas') || combined.contains('avvillas')) {
    return '#DC2626'; // Rojo AV Villas
  }
  if (combined.contains('amex') || combined.contains('american express')) {
    return '#0D9488'; // Teal Amex
  }

  // Si tiene un color guardado en BD que no sea el por defecto genérico, usarlo
  final stored = tarjeta['color']?.toString();
  if (stored != null && stored.isNotEmpty && stored != '#1976D2' && stored != '#000000' && stored != '#6366F1') {
    return stored;
  }
  
  // Color vibrante por defecto (Indigo)
  return '#6366F1';
}

Color getTarjetaColor(Map<String, dynamic>? tarjeta) => hexToColor(getTarjetaColorHex(tarjeta));

/// Formatea porcentaje con 1 decimal
String formatPct(double pct) => '${pct.toStringAsFixed(1)}%';

/// Obtener icono de categoría de manera centralizada
IconData getCategoryIcon(String? iconName) {
  if (iconName == null) return Icons.category_rounded;
  switch (iconName.toLowerCase()) {
    // Ingresos
    case 'work':
    case 'salary':
    case 'empleo':
    case 'trabajo':
    case 'salario':
      return Icons.work_rounded;
    case 'freelance':
    case 'project':
    case 'star':
      return Icons.star_rounded;
    case 'business':
    case 'negocio':
      return Icons.business_center_rounded;
    case 'inversiones':
    case 'investing':
    case 'trending_up':
    case 'trending_up_rounded':
      return Icons.trending_up_rounded;
    // Gastos
    case 'shopping':
    case 'compras':
    case 'mercado':
    case 'comida':
    case 'food':
    case 'grocery':
    case 'shopping_cart':
      return Icons.shopping_cart_rounded;
    case 'entertainment':
    case 'ocio':
    case 'tv':
    case 'netflix':
      return Icons.movie_rounded;
    case 'transport':
    case 'transporte':
    case 'car':
    case 'gasolina':
      return Icons.directions_car_rounded;
    case 'home':
    case 'vivienda':
    case 'services':
    case 'servicios':
      return Icons.home_rounded;
    case 'health':
    case 'salud':
      return Icons.local_hospital_rounded;
    case 'education':
    case 'educacion':
      return Icons.school_rounded;
    default:
      return Icons.category_rounded;
  }
}

