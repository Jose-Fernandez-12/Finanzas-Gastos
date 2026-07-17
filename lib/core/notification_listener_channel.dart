import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Canal de comunicacion entre Flutter y el NotificationListenerService nativo de Android.
/// Solo funciona en Android. En otras plataformas, todos los metodos son no-ops.
class NotificationListenerChannel {
  static final NotificationListenerChannel instance = NotificationListenerChannel._();
  NotificationListenerChannel._();

  static const MethodChannel _method = MethodChannel('gastos_app/notification_control');
  static const EventChannel  _event  = EventChannel('gastos_app/notification_events');

  Stream<Map<String, dynamic>>? _eventStream;

  /// Stream de transacciones detectadas en tiempo real (solo cuando la app esta abierta)
  Stream<Map<String, dynamic>> get transactionStream {
    _eventStream ??= _event
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  /// Verifica si el usuario concedio el permiso de acceso a notificaciones
  Future<bool> isPermissionGranted() async {
    try {
      final result = await _method.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla del sistema: Ajustes > Acceso a notificaciones
  Future<void> openPermissionSettings() async {
    try {
      await _method.invokeMethod('openPermissionSettings');
    } catch (_) {}
  }

  /// Retorna si el logging de notificaciones crudas esta habilitado
  Future<bool> isLoggingEnabled() async {
    try {
      final result = await _method.invokeMethod<bool>('isLoggingEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Habilita o deshabilita el logging de notificaciones crudas
  Future<void> setLoggingEnabled(bool enabled) async {
    try {
      await _method.invokeMethod('setLoggingEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  /// Obtiene la lista de transacciones pendientes de confirmar
  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    try {
      final json = await _method.invokeMethod<String>('getPendingTransactions');
      if (json == null || json.isEmpty || json == '[]') return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Elimina todas las transacciones pendientes
  Future<void> clearPendingTransactions() async {
    try {
      await _method.invokeMethod('clearPendingTransactions');
    } catch (_) {}
  }

  /// Elimina una transaccion pendiente especifica por indice
  Future<void> dismissPendingTransaction(int index) async {
    try {
      await _method.invokeMethod('dismissPendingTransaction', {'index': index});
    } catch (_) {}
  }

  /// Obtiene el log de notificaciones crudas capturadas
  Future<List<Map<String, dynamic>>> getRawLogs() async {
    try {
      final json = await _method.invokeMethod<String>('getRawLogs');
      if (json == null || json.isEmpty || json == '[]') return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Limpia todos los logs de notificaciones crudas
  Future<void> clearRawLogs() async {
    try {
      await _method.invokeMethod('clearRawLogs');
    } catch (_) {}
  }
}
