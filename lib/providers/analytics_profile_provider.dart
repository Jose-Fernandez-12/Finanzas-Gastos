import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── IDs de módulos disponibles ───────────────────────────────────────────────
class AnalyticsModuleIds {
  static const String termometro = 'termometro';
  static const String estresCash = 'estres_cash';
  static const String endeudamiento = 'endeudamiento';
  static const String resumenCards = 'resumen_cards';
  static const String radarHormiga = 'radar_hormiga';
  static const String flujoCaja = 'flujo_caja';
  static const String simuladorPagos = 'simulador_pagos';
  static const String caminoDeuda = 'camino_deuda';
  static const String categorias = 'categorias';
  static const String interesQuemado = 'interes_quemado';
  static const String esclavitudFinanciera = 'esclavitud_financiera';
  static const String dependenciaTarjetas = 'dependencia_tarjetas';
  static const String eficienciaAhorro = 'eficiencia_ahorro';
  static const String reporteDetallado = 'reporte_detallado';

  /// Todos los módulos disponibles con su etiqueta amigable
  static const Map<String, String> labels = {
    termometro: 'Plata Libre de Culpa',
    estresCash: 'Calendario de Estrés de Efectivo',
    endeudamiento: 'Estado de Endeudamiento',
    resumenCards: 'Resumen Ingresos / Gastos',
    radarHormiga: 'Radar Gastos Hormiga',
    flujoCaja: 'Flujo de Caja',
    simuladorPagos: 'Simulador Inteligente de Pagos',
    caminoDeuda: 'Camino a Cero Deuda',
    categorias: 'Gastos por Categoría',
    interesQuemado: 'Interés Quemado (al Banco)',
    esclavitudFinanciera: 'Días de Trabajo vs Deuda',
    dependenciaTarjetas: 'Dependencia por Tarjeta',
    eficienciaAhorro: 'Eficiencia de Ahorro',
    reporteDetallado: 'Reporte Detallado (Exportable)',
  };

  static const Map<String, String> icons = {
    termometro: '💧',
    estresCash: '⚡',
    endeudamiento: '📊',
    resumenCards: '📋',
    radarHormiga: '🐜',
    flujoCaja: '📈',
    simuladorPagos: '🚀',
    caminoDeuda: '🎯',
    categorias: '🥧',
    interesQuemado: '🔥',
    esclavitudFinanciera: '⏳',
    dependenciaTarjetas: '🏦',
    eficienciaAhorro: '💡',
    reporteDetallado: '📄',
  };

  static List<String> get allIds => labels.keys.toList();
}

// ─── Modelo ───────────────────────────────────────────────────────────────────
class AnalyticsProfile {
  final String id;
  final String nombre;
  final List<String> modulos;
  final bool esPorDefecto;

  const AnalyticsProfile({
    required this.id,
    required this.nombre,
    required this.modulos,
    this.esPorDefecto = false,
  });

  AnalyticsProfile copyWith({
    String? id,
    String? nombre,
    List<String>? modulos,
    bool? esPorDefecto,
  }) {
    return AnalyticsProfile(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      modulos: modulos ?? this.modulos,
      esPorDefecto: esPorDefecto ?? this.esPorDefecto,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'modulos': modulos,
    'esPorDefecto': esPorDefecto,
  };

  factory AnalyticsProfile.fromJson(Map<String, dynamic> json) => AnalyticsProfile(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    modulos: List<String>.from(json['modulos'] as List),
    esPorDefecto: json['esPorDefecto'] as bool? ?? false,
  );
}

// ─── Perfiles predeterminados ─────────────────────────────────────────────────
List<AnalyticsProfile> _defaultProfiles() {
  return [
    AnalyticsProfile(
      id: 'completo_pro',
      nombre: 'Completo Pro',
      esPorDefecto: true,
      modulos: AnalyticsModuleIds.allIds,
    ),
    AnalyticsProfile(
      id: 'cero_deuda',
      nombre: 'Enfoque Cero Deuda',
      modulos: [
        AnalyticsModuleIds.termometro,
        AnalyticsModuleIds.interesQuemado,
        AnalyticsModuleIds.simuladorPagos,
        AnalyticsModuleIds.caminoDeuda,
        AnalyticsModuleIds.dependenciaTarjetas,
        AnalyticsModuleIds.esclavitudFinanciera,
      ],
    ),
    AnalyticsProfile(
      id: 'control_diario',
      nombre: 'Control Diario',
      modulos: [
        AnalyticsModuleIds.termometro,
        AnalyticsModuleIds.estresCash,
        AnalyticsModuleIds.resumenCards,
        AnalyticsModuleIds.flujoCaja,
        AnalyticsModuleIds.radarHormiga,
        AnalyticsModuleIds.eficienciaAhorro,
      ],
    ),
    AnalyticsProfile(
      id: 'perfil_reporte',
      nombre: 'Reporte Detallado',
      modulos: [
        AnalyticsModuleIds.reporteDetallado,
      ],
    ),
  ];
}

// ─── Estado ───────────────────────────────────────────────────────────────────
class AnalyticsProfileState {
  final List<AnalyticsProfile> perfiles;
  final String perfilActivoId;

  const AnalyticsProfileState({
    required this.perfiles,
    required this.perfilActivoId,
  });

  AnalyticsProfile get perfilActivo =>
      perfiles.firstWhere((p) => p.id == perfilActivoId, orElse: () => perfiles.first);

  Set<String> get modulosActivos => perfilActivo.modulos.toSet();

  AnalyticsProfileState copyWith({
    List<AnalyticsProfile>? perfiles,
    String? perfilActivoId,
  }) {
    return AnalyticsProfileState(
      perfiles: perfiles ?? this.perfiles,
      perfilActivoId: perfilActivoId ?? this.perfilActivoId,
    );
  }
}

// ─── Notifier (Riverpod 3.x — usa Notifier en lugar de StateNotifier) ─────────
const _kPrefKey = 'analytics_profiles_v1';
const _kActivoKey = 'analytics_active_profile_v1';

class AnalyticsProfileNotifier extends Notifier<AnalyticsProfileState> {
  @override
  AnalyticsProfileState build() {
    // Estado inicial sincrónico; la carga real ocurre en _load()
    final initial = AnalyticsProfileState(
      perfiles: _defaultProfiles(),
      perfilActivoId: 'completo_pro',
    );
    Future.microtask(() => _load());
    return initial;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefKey);
      final activo = prefs.getString(_kActivoKey);

      List<AnalyticsProfile> perfiles;
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        perfiles = decoded.map((e) => AnalyticsProfile.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        perfiles = _defaultProfiles();
      }

      // Asegurar que el perfil "Reporte Detallado" siempre esté disponible,
      // incluso si se cargó de caché anterior.
      if (!perfiles.any((p) => p.id == 'perfil_reporte')) {
        perfiles.add(
          const AnalyticsProfile(
            id: 'perfil_reporte',
            nombre: 'Reporte Detallado',
            modulos: [AnalyticsModuleIds.reporteDetallado],
          ),
        );
        // Guardar para que quede persistente en la caché de SharedPreferences
        final encoded = jsonEncode(perfiles.map((p) => p.toJson()).toList());
        await prefs.setString(_kPrefKey, encoded);
      }

      String perfilActivoId = activo ?? perfiles.firstWhere((p) => p.esPorDefecto, orElse: () => perfiles.first).id;
      if (!perfiles.any((p) => p.id == perfilActivoId)) {
        perfilActivoId = perfiles.first.id;
      }

      state = AnalyticsProfileState(perfiles: perfiles, perfilActivoId: perfilActivoId);
    } catch (e) {
      debugPrint('Error loading analytics profiles: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.perfiles.map((p) => p.toJson()).toList());
      await prefs.setString(_kPrefKey, encoded);
      await prefs.setString(_kActivoKey, state.perfilActivoId);
    } catch (e) {
      debugPrint('Error saving analytics profiles: $e');
    }
  }

  void seleccionarPerfil(String id) {
    if (!state.perfiles.any((p) => p.id == id)) return;
    state = state.copyWith(perfilActivoId: id);
    _save();
  }

  Future<void> crearPerfil(String nombre, List<String> modulos) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final nuevo = AnalyticsProfile(id: id, nombre: nombre, modulos: modulos);
    final nuevos = [...state.perfiles, nuevo];
    state = AnalyticsProfileState(perfiles: nuevos, perfilActivoId: id);
    await _save();
  }

  Future<void> actualizarNombre(String id, String nuevoNombre) async {
    final nuevos = state.perfiles.map((p) => p.id == id ? p.copyWith(nombre: nuevoNombre) : p).toList();
    state = state.copyWith(perfiles: nuevos);
    await _save();
  }

  Future<void> actualizarModulos(String id, List<String> modulos) async {
    final nuevos = state.perfiles.map((p) => p.id == id ? p.copyWith(modulos: modulos) : p).toList();
    state = state.copyWith(perfiles: nuevos);
    await _save();
  }

  Future<void> setPerfilPorDefecto(String id) async {
    final nuevos = state.perfiles
        .map((p) => p.copyWith(esPorDefecto: p.id == id))
        .toList();
    state = state.copyWith(perfiles: nuevos);
    await _save();
  }

  Future<void> eliminarPerfil(String id) async {
    if (state.perfiles.length <= 1) return;
    final nuevos = state.perfiles.where((p) => p.id != id).toList();
    String activoId = state.perfilActivoId;
    if (activoId == id) {
      activoId = nuevos.firstWhere((p) => p.esPorDefecto, orElse: () => nuevos.first).id;
    }
    state = AnalyticsProfileState(perfiles: nuevos, perfilActivoId: activoId);
    await _save();
  }

  Future<void> restaurarPredeterminados() async {
    final defaults = _defaultProfiles();
    state = AnalyticsProfileState(perfiles: defaults, perfilActivoId: 'completo_pro');
    await _save();
  }
}

// ─── Provider (Riverpod 3.x) ──────────────────────────────────────────────────
final analyticsProfileProvider =
    NotifierProvider<AnalyticsProfileNotifier, AnalyticsProfileState>(
  AnalyticsProfileNotifier.new,
);
