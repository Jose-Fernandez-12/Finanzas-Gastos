import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/notification_listener_channel.dart';
import 'notificaciones/notification_logs_screen.dart';

import 'dart:io';
import 'package:path/path.dart' hide context;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// Pantalla de configuracion
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _permissionGranted = false;
  bool _loggingEnabled = false;
  bool _loadingPerms = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationListenerChannel.instance.isPermissionGranted();
    final logging = await NotificationListenerChannel.instance.isLoggingEnabled();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _loggingEnabled    = logging;
        _loadingPerms      = false;
      });
    }
  }

  Future<void> _borrarDatos(BuildContext context) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Borrar todos los datos?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Esto eliminara la base de datos actual y restaurara los datos de prueba originales la proxima vez que abras la app. La app se cerrara.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Si, borrar todo'),
          ),
        ],
      ),
    );

    if (conf == true) {
      Directory dir = await getApplicationDocumentsDirectory();
      String path = join(dir.path, 'finanzas.db');
      await deleteDatabase(path);
      exit(0);
    }
  }

  Future<void> _exportData() async {
    try {
      Directory dir = await getApplicationDocumentsDirectory();
      String path = join(dir.path, 'finanzas.db');
      if (await File(path).exists()) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Copia de seguridad de Mis Finanzas (finanzas.db)',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay base de datos para exportar')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        final backupPath = result.files.single.path!;
        
        if (!mounted) return;
        final conf = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('¿Importar copia de seguridad?', style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text('Esto reemplazará todos tus datos actuales con los del archivo seleccionado. La app se cerrará para aplicar los cambios.', style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Importar'),
              ),
            ],
          ),
        );

        if (conf == true) {
          Directory dir = await getApplicationDocumentsDirectory();
          String targetPath = join(dir.path, 'finanzas.db');
          
          await deleteDatabase(targetPath);
          await File(backupPath).copy(targetPath);
          
          exit(0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Configuracion',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Seccion: Modo Local ─────────────────────────────────
            _SectionHeader(title: 'Modo Local (Offline)', icon: Icons.storage_rounded),
            const SizedBox(height: 10),
            _InfoCard(
              child: const Text(
                'La aplicacion esta configurada para funcionar 100% de manera local. Todos tus datos se guardan de forma segura en este dispositivo usando SQLite.\n\nNo se requiere conexion a internet ni a un servidor externo.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
              ),
            ),

            const SizedBox(height: 32),

            // ─── Seccion: Captura automatica ─────────────────────────
            _SectionHeader(title: 'Captura automatica de gastos', icon: Icons.notifications_active_rounded),
            const SizedBox(height: 4),
            const Text(
              'Detecta compras desde notificaciones de Google Pay, Nu, Bancolombia y mas.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),

            _InfoCard(
              child: _loadingPerms
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)))
                  : Column(
                      children: [
                        // Estado del permiso
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _permissionGranted
                                    ? AppTheme.colorAlDia.withAlpha(20)
                                    : AppTheme.colorGastos.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _permissionGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: _permissionGranted ? AppTheme.colorAlDia : AppTheme.colorGastos,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _permissionGranted ? 'Acceso activo' : 'Sin acceso',
                                    style: TextStyle(
                                      color: _permissionGranted ? AppTheme.colorAlDia : AppTheme.colorGastos,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _permissionGranted
                                        ? 'Las notificaciones de pago seran detectadas'
                                        : 'Otorga el permiso para activar la captura',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _permissionGranted,
                              activeTrackColor: AppTheme.primary.withAlpha(100),
                              activeColor: AppTheme.primary,
                              onChanged: (val) async {
                                // Siempre abrir la configuracion, ya sea para apagar o prender
                                await NotificationListenerChannel.instance.openPermissionSettings();
                                // Esperar un momento a que el usuario regrese
                                await Future.delayed(const Duration(seconds: 1));
                                _checkPermissions();
                              },
                            ),
                          ],
                        ),

                        if (_permissionGranted) ...[
                          const SizedBox(height: 12),
                          const Divider(color: AppTheme.borderLight),
                          const SizedBox(height: 8),

                          // Toggle de logging
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Guardar log de notificaciones',
                                        style: TextStyle(
                                            color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('Registra el texto crudo de cada notificacion de pago.',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _loggingEnabled,
                                activeTrackColor: AppTheme.primary.withAlpha(100),
                                activeColor: AppTheme.primary,
                                onChanged: (val) async {
                                  await NotificationListenerChannel.instance.setLoggingEnabled(val);
                                  setState(() => _loggingEnabled = val);
                                },
                              ),
                            ],
                          ),

                          // Boton ver logs
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.list_alt_rounded, size: 16),
                              label: const Text('Ver log de notificaciones'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationLogsScreen()),
                              ),
                            ),
                          ),
                          
                          // Boton escanear notificaciones activas actuales
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.document_scanner_rounded, size: 16),
                              label: const Text('Escanear notificaciones actuales'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Escaneando notificaciones...')),
                                );
                                await NotificationListenerChannel.instance.fetchActiveNotifications();
                                // Wait a bit for native side to process and create pending transactions
                                await Future.delayed(const Duration(milliseconds: 1000));
                                
                                // Show pending transactions (this triggers the first one, which then chains if there are more)
                                final pending = await NotificationListenerChannel.instance.getPendingTransactions();
                                if (pending.isEmpty && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No se encontraron notificaciones de pagos pendientes.')),
                                  );
                                } else if (mounted) {
                                  // Just reload Dashboard or let Dashboard handle it? 
                                  // The Dashboard handles it in `initState`, but we are in Settings.
                                  // Let's pop back to Dashboard so it can trigger them, or we can trigger the dialog here?
                                  // Wait, Dashboard only checks on `initState` or when it receives an event stream. 
                                  // Let's just pop to root to let Dashboard handle it.
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                              },
                            ),
                          ),
                        ],

                        // Apps soportadas
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.borderLight),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Apps soportadas:', style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            _AppChip(label: 'Google Pay'),
                            _AppChip(label: 'Nu'),
                            _AppChip(label: 'Bancolombia'),
                            _AppChip(label: 'Rappi Pay'),
                            _AppChip(label: 'Nequi'),
                            _AppChip(label: 'Davivienda'),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 32),

            // ─── Seccion: Copias de Seguridad ────────────────────────
            _SectionHeader(title: 'Copias de Seguridad', icon: Icons.backup_rounded),
            const SizedBox(height: 10),
            _InfoCard(
              child: Column(
                children: [
                  const Text(
                    'Exporta tu base de datos para guardarla en otro lugar o impórtala si cambiaste de dispositivo o reinstalaste la app.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Exportar'),
                          onPressed: _exportData,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Importar'),
                          onPressed: _importData,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),



            // ─── Seccion: Peligroso ──────────────────────────────────
            _SectionHeader(title: 'Zona de peligro', icon: Icons.warning_amber_rounded, color: AppTheme.colorGastos),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Borrar todos los datos'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => _borrarDatos(context),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets helpers ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _AppChip extends StatelessWidget {
  final String label;
  const _AppChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Text(label, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
