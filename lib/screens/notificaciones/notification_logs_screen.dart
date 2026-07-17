import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/notification_listener_channel.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';

/// Pantalla de logs de notificaciones capturadas por el NotificationListenerService.
/// Util para depuracion: muestra el texto crudo de cada notificacion y si fue parseada.
class NotificationLogsScreen extends StatefulWidget {
  const NotificationLogsScreen({super.key});

  @override
  State<NotificationLogsScreen> createState() => _NotificationLogsScreenState();
}

class _NotificationLogsScreenState extends State<NotificationLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await NotificationListenerChannel.instance.getRawLogs();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Limpiar logs', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Se eliminaran todos los registros de notificaciones capturadas.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorGastos, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationListenerChannel.instance.clearRawLogs();
      await _loadLogs();
    }
  }

  void _copyLog(Map<String, dynamic> log) {
    final text = '''
App: ${log['app_label'] ?? ''}
Titulo: ${log['titulo'] ?? ''}
Cuerpo: ${log['cuerpo'] ?? ''}
Monto: ${log['monto_detectado'] ?? 'No detectado'}
Comercio: ${log['comercio_detectado'] ?? 'No detectado'}
Tipo: ${log['tipo_tarjeta'] ?? ''}
Fecha: ${log['timestamp'] ?? ''}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copiado al portapapeles'), backgroundColor: AppTheme.colorAlDia),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Log de Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.colorGastos),
              tooltip: 'Limpiar logs',
              onPressed: _clearLogs,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Actualizar',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _logs.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 60, color: AppTheme.textMuted.withAlpha(100)),
          const SizedBox(height: 16),
          const Text('No hay logs registrados', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Activa el registro en Configuracion para capturar\nlas notificaciones de apps financieras.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_logs.length} notificaciones capturadas. Toca el icono de copia para enviar un log y ajustar los parsers.',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _logs.length,
            itemBuilder: (context, i) => _LogCard(log: _logs[i], onCopy: () => _copyLog(_logs[i])),
          ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onCopy;

  const _LogCard({required this.log, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final parseado    = (log['parseado'] as bool?) ?? false;
    final appLabel    = log['app_label']  as String? ?? 'Desconocida';
    final titulo      = log['titulo']     as String? ?? '';
    final cuerpo      = log['cuerpo']     as String? ?? '';
    final monto       = log['monto_detectado'];
    final comercio    = log['comercio_detectado'] as String?;
    final tipoTarjeta = log['tipo_tarjeta']       as String?;
    final timestamp   = log['timestamp']           as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: parseado ? AppTheme.colorAlDia.withAlpha(60) : AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: parseado ? AppTheme.colorAlDia.withAlpha(20) : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        parseado ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                        size: 12,
                        color: parseado ? AppTheme.colorAlDia : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        parseado ? 'Parseada' : 'No reconocida',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: parseado ? AppTheme.colorAlDia : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(appLabel, style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(timestamp.length > 16 ? timestamp.substring(5, 16) : timestamp,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Titulo y cuerpo (texto crudo)
            if (titulo.isNotEmpty)
              Text(titulo, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            if (cuerpo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(cuerpo, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
            // Datos detectados
            if (parseado) ...[
              const SizedBox(height: 8),
              const Divider(color: AppTheme.borderLight, height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (monto != null)
                    _Chip(
                      icon: Icons.attach_money_rounded,
                      label: formatCOP((monto as num).toDouble()),
                      color: AppTheme.colorGastos,
                    ),
                  if (comercio != null && comercio.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      icon: Icons.store_rounded,
                      label: comercio,
                      color: AppTheme.primary,
                    ),
                  ],
                  if (tipoTarjeta != null && tipoTarjeta.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      icon: Icons.credit_card_rounded,
                      label: tipoTarjeta,
                      color: AppTheme.colorDeudas,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
