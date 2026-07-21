import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/notification_listener_channel.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/transaction_classifier.dart';
import 'gasto_detectado_dialog.dart';

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

  void _registerFromLog(Map<String, dynamic> log) async {
    final texto = '${log['titulo'] ?? ''} ${log['cuerpo'] ?? ''}';
    double? monto = (log['monto_detectado'] as num?)?.toDouble();
    if (monto == null || monto <= 0) {
      final match = RegExp(r'(?:recibiste|llegó|transferencia|abono|consignación|\$|COP[\s$]*)\s*([\d.,]+)', caseSensitive: false).firstMatch(texto);
      if (match != null) {
        final raw = match.group(1) ?? '';
        final clean = raw.replaceAll(RegExp(r'\.(?=\d{3}(?:\D|$))'), '').replaceAll(',', '.').replaceAll(RegExp(r'\.(?=\d{3}\b)'), '');
        final lim = raw.replaceAll('.', '').replaceAll(',', '');
        monto = double.tryParse(lim) ?? double.tryParse(clean) ?? 0.0;
      }
    }

    String comercio = (log['comercio_detectado'] as String? ?? '').trim();
    if (comercio.isEmpty) {
      final rem = RegExp(r'(?:dinero|transferencia)\s+de\s+(.+?)(?:\s+con|\s*\.|$)', caseSensitive: false).firstMatch(texto);
      if (rem != null) {
        comercio = rem.group(1)!.trim();
      } else {
        comercio = (log['app_label'] as String? ?? 'Notificación').trim();
      }
    }

    String tipo = (log['tipo_tarjeta'] as String? ?? '').trim().toLowerCase();
    if (tipo.isEmpty || tipo == 'desconocido') {
      if (texto.toLowerCase().contains('recibiste') || texto.toLowerCase().contains('llegó dinero')) {
        tipo = 'ingreso';
      } else if (texto.toLowerCase().contains('crédito') || texto.toLowerCase().contains('credito')) {
        tipo = 'credito';
      } else {
        tipo = 'debito';
      }
    }

    final rawData = {
      'app_label': log['app_label'] ?? 'App',
      'package_name': log['package_name'] ?? '',
      'titulo': log['titulo'] ?? '',
      'cuerpo': log['cuerpo'] ?? '',
      'monto': monto ?? 0.0,
      'comercio': comercio,
      'tipo_tarjeta': tipo,
      'timestamp': log['timestamp'] ?? '',
    };

    final classification = await TransactionClassifier.classify(rawData);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GastoDetectadoDialog(
        rawData: rawData,
        classification: classification,
        pendingIndex: -1,
        onDone: () => _loadLogs(),
      ),
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
            tooltip: 'Refrescar',
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 56, color: AppTheme.textMuted.withAlpha(80)),
          const SizedBox(height: 12),
          const Text('No hay logs capturados',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Las notificaciones recibidas apareceran aqui.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_logs.length} notificaciones capturadas. Toca el icono de registro (+) para procesar o copiar.',
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
            itemBuilder: (context, i) => _LogCard(
              log: _logs[i],
              onCopy: () => _copyLog(_logs[i]),
              onRegister: () => _registerFromLog(_logs[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onCopy;
  final VoidCallback onRegister;

  const _LogCard({required this.log, required this.onCopy, required this.onRegister});

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
                  onTap: onRegister,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                        SizedBox(width: 3),
                        Text('Registrar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
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
                      color: tipoTarjeta == 'ingreso' ? AppTheme.colorIngresos : AppTheme.colorGastos,
                    ),
                  if (comercio != null && comercio.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      icon: tipoTarjeta == 'ingreso' ? Icons.person_rounded : Icons.store_rounded,
                      label: comercio,
                      color: AppTheme.primary,
                    ),
                  ],
                  if (tipoTarjeta != null && tipoTarjeta.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Chip(
                      icon: tipoTarjeta == 'ingreso' ? Icons.savings_rounded : Icons.credit_card_rounded,
                      label: tipoTarjeta,
                      color: tipoTarjeta == 'ingreso' ? AppTheme.colorIngresos : AppTheme.colorDeudas,
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
