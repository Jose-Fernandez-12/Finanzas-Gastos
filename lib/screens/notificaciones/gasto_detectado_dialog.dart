import 'package:flutter/material.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/transaction_classifier.dart';
import '../../core/local_repository.dart';
import '../../core/notification_listener_channel.dart';
import '../../models/tarjeta_credito.dart';

/// Bottom Sheet que aparece cuando se detecta una compra desde una notificacion.
/// Muestra los datos detectados y permite al usuario confirmar, editar o descartar.
class GastoDetectadoDialog extends StatefulWidget {
  final Map<String, dynamic> rawData;
  final int pendingIndex;
  final ClassifiedTransaction classification;
  final VoidCallback onDone;

  const GastoDetectadoDialog({
    super.key,
    required this.rawData,
    required this.pendingIndex,
    required this.classification,
    required this.onDone,
  });

  @override
  State<GastoDetectadoDialog> createState() => _GastoDetectadoDialogState();
}

class _GastoDetectadoDialogState extends State<GastoDetectadoDialog> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _montoCtrl;
  late String _tipoSeleccionado; // 'credito' | 'simple'
  bool _saving = false;
  List<Map<String, dynamic>> _tarjetas = [];
  TarjetaCredito? _tarjetaSeleccionada;

  @override
  void initState() {
    super.initState();
    final comercio = widget.rawData['comercio'] as String? ?? '';
    final monto    = widget.rawData['monto']    as double? ?? 0.0;
    _descCtrl  = TextEditingController(text: comercio.isNotEmpty ? comercio : 'Compra detectada');
    _montoCtrl = TextEditingController(text: monto.toStringAsFixed(0));

    _tipoSeleccionado = widget.classification.route == TransactionRoute.creditCard
        ? 'credito'
        : 'simple';
    _tarjetaSeleccionada = widget.classification.tarjetaMatch;

    if (_tipoSeleccionado == 'credito') _loadTarjetas();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTarjetas() async {
    final result = await LocalRepository.instance.getTarjetas();
    if (mounted) {
      setState(() {
        _tarjetas = List<Map<String, dynamic>>.from(result['data'] ?? []);
        // Seleccionar la tarjeta detectada si la hay
        if (_tarjetaSeleccionada != null) {
                  // ya esta seleccionada desde classification
        } else if (_tarjetas.isNotEmpty) {
          _tarjetaSeleccionada = TarjetaCredito.fromMap(_tarjetas.first);
        }
      });
    }
  }

  Future<void> _save() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '').replaceAll('.', '')) ?? 0.0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido'), backgroundColor: AppTheme.colorGastos),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_tipoSeleccionado == 'credito' && _tarjetaSeleccionada != null) {
        // Crear como gasto_fijo simple en el mes actual (compra rapida, sin amortizacion)
        // Nota: el usuario puede luego ir a Tarjetas y registrar la amortizacion completa si lo desea
        final mesActualStr = mesActual();
        await LocalRepository.instance.createGastoFijo({
          'categoria_id':   TransactionClassifier.suggestCategoryId(_descCtrl.text),
          'nombre':         _descCtrl.text.trim(),
          'monto':          monto,
          'dia_pago':       _tarjetaSeleccionada!.fechaPago,
          'notas':          'Auto-detectado · TC ${_tarjetaSeleccionada!.banco}',
          'es_fijo':        0,
          'mes_referencia': mesActualStr,
        });
      } else {
        // Gasto simple
        final mesActualStr = mesActual();
        await LocalRepository.instance.createGastoFijo({
          'categoria_id':   TransactionClassifier.suggestCategoryId(_descCtrl.text),
          'nombre':         _descCtrl.text.trim(),
          'monto':          monto,
          'dia_pago':       DateTime.now().day,
          'notas':          'Auto-detectado · ${widget.rawData['app_label'] ?? ''}',
          'es_fijo':        0,
          'mes_referencia': mesActualStr,
        });
      }

      await NotificationListenerChannel.instance.dismissPendingTransaction(widget.pendingIndex);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto registrado correctamente'),
            backgroundColor: AppTheme.colorAlDia,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    await NotificationListenerChannel.instance.dismissPendingTransaction(widget.pendingIndex);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLabel    = widget.rawData['app_label']    as String? ?? 'App';
    final tsLabel     = widget.rawData['timestamp']     as String? ?? '';
    final tipoTarjeta = widget.rawData['tipo_tarjeta']  as String? ?? '';

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compra detectada', style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Desde $appLabel · ${tsLabel.length > 10 ? tsLabel.substring(0, 16) : tsLabel}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                onPressed: _discard,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Badge tipo
          if (tipoTarjeta.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: tipoTarjeta.contains('credito')
                    ? AppTheme.primary.withAlpha(20)
                    : AppTheme.colorIngresos.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tipoTarjeta == 'credito' ? 'Tarjeta de credito'
                    : tipoTarjeta == 'credito_avance' ? 'Avance de efectivo'
                    : tipoTarjeta == 'debito' ? 'Debito'
                    : 'Tipo desconocido',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: tipoTarjeta.contains('credito') ? AppTheme.primary : AppTheme.colorIngresos,
                ),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(color: AppTheme.borderLight),
          const SizedBox(height: 16),

          // Monto grande
          Center(
            child: Text(
              formatCOP(double.tryParse(_montoCtrl.text.replaceAll(',', '').replaceAll('.', '')) ?? 0),
              style: const TextStyle(
                color: AppTheme.colorGastos, fontSize: 32, fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Campo descripcion
          TextFormField(
            controller: _descCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Descripcion',
              prefixIcon: Icon(Icons.edit_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),

          // Campo monto
          TextFormField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),

          // Tipo de registro
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registrar como:', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TipoChip(
                      label: 'Gasto simple',
                      icon: Icons.receipt_long_rounded,
                      selected: _tipoSeleccionado == 'simple',
                      onTap: () => setState(() => _tipoSeleccionado = 'simple'),
                    ),
                    const SizedBox(width: 8),
                    _TipoChip(
                      label: 'Tarjeta de credito',
                      icon: Icons.credit_card_rounded,
                      selected: _tipoSeleccionado == 'credito',
                      onTap: () {
                        setState(() => _tipoSeleccionado = 'credito');
                        if (_tarjetas.isEmpty) _loadTarjetas();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Selector de tarjeta (si aplica)
          if (_tipoSeleccionado == 'credito' && _tarjetas.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _tarjetaSeleccionada?.id,
              dropdownColor: AppTheme.bgCard,
              decoration: const InputDecoration(labelText: 'Tarjeta'),
              style: const TextStyle(color: AppTheme.textPrimary),
              items: _tarjetas.map((t) => DropdownMenuItem<int>(
                value: t['id'] as int,
                child: Text('${t['banco']} · ${t['nombre_tarjeta']}'),
              )).toList(),
              onChanged: (id) {
                final match = _tarjetas.where((t) => t['id'] == id).toList();
                if (match.isNotEmpty) {
                  setState(() => _tarjetaSeleccionada = TarjetaCredito.fromMap(match.first));
                }
              },
            ),
          ],

          const SizedBox(height: 24),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _discard,
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar gasto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TipoChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? AppTheme.primary : AppTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
