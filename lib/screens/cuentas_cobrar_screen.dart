import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import '../providers/app_providers.dart';

class CuentasCobrarScreen extends StatefulWidget {
  const CuentasCobrarScreen({super.key});
  @override
  State<CuentasCobrarScreen> createState() => _CuentasCobrarScreenState();
}

class _CuentasCobrarScreenState extends State<CuentasCobrarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CuentasCobrarProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: () => context.read<CuentasCobrarProvider>().cargar(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 28),
      ),
      body: Consumer<CuentasCobrarProvider>(
        builder: (context, prov, _) {
          if (prov.loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

          // Calcular el total pendiente de cobro
          double totalPendiente = 0.0;
          for (var c in prov.cuentas) {
            if (c['estado'] != 'CANCELADO') {
              totalPendiente += (c['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
            }
          }

          return Column(
            children: [
              // Summary card at the top
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _SummaryCard(monto: totalPendiente),
              ),

              // Title Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Deudores activos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
              ),

              Expanded(
                child: prov.cuentas.isEmpty
                    ? const Center(child: Text('Sin cuentas por cobrar', style: TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () => prov.cargar(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16).copyWith(top: 4),
                          itemCount: prov.cuentas.length,
                          itemBuilder: (ctx, i) => _CuentaItem(
                            cuenta: prov.cuentas[i],
                            onPago: () {
                              prov.cargar();
                              context.read<DashboardProvider>().cargar();
                            },
                            onEdit: () => _showForm(context, cuenta: prov.cuentas[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, {Map<String, dynamic>? cuenta}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormCuenta(
        cuenta: cuenta,
        onSave: () {
          context.read<CuentasCobrarProvider>().cargar();
          context.read<DashboardProvider>().cargar();
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double monto;
  const _SummaryCard({required this.monto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [AppTheme.secondary, AppTheme.primary],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Text('TOTAL PENDIENTE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(
                  formatCOP(monto),
                  style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaItem extends StatelessWidget {
  final Map<String, dynamic> cuenta;
  final VoidCallback         onPago;
  final VoidCallback         onEdit;
  const _CuentaItem({required this.cuenta, required this.onPago, required this.onEdit});

  String getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final estado = cuenta['estado'] as String? ?? 'AL_DIA';
    final color  = estado == 'MORA'      ? AppTheme.colorMora
                 : estado == 'CANCELADO' ? AppTheme.colorCancelado
                 : AppTheme.colorAlDia;
    final saldo  = (cuenta['saldo_pendiente'] as num?)?.toDouble() ?? 0;
    final total  = (cuenta['monto_total']     as num?)?.toDouble() ?? 1;
    final pct    = ((total - saldo) / total * 100).clamp(0.0, 100.0);
    final String deudorNombre = cuenta['nombre_deudor'] as String? ?? 'Deudor';

    return Container(
      margin:  const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Info, Status & Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  getInitials(deudorNombre),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deudorNombre,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cuenta['notas']?.toString() ?? 'Préstamo personal',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCOP(saldo),
                    style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado == 'AL_DIA' ? 'AL DÍA' : estado.replaceAll('_', ' '),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar (percentage returned)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           pct / 100,
              minHeight:       5,
              backgroundColor: AppTheme.borderLight,
              valueColor:      AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (cuenta['telefono'] != null) ...[
            const SizedBox(height: 6),
            Text('Tel: ${cuenta['telefono']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
          
          // Footer: Límite & Registrar Pago (WhatsApp button omitted as requested)
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderLight, style: BorderStyle.solid, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Límite: ${cuenta['fecha_primer_vencimiento'] != null ? formatFecha(cuenta['fecha_primer_vencimiento'].toString()) : 'Por definir'}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Editar',
                    ),
                    const SizedBox(width: 10),
                    if (estado != 'CANCELADO')
                      OutlinedButton(
                        onPressed: () => _showPagoDialog(context, cuenta, onPago),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Registrar pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPagoDialog(BuildContext context, Map<String, dynamic> cuenta, VoidCallback onPago) {
    final montoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Pago de ${cuenta['nombre_deudor']}',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller:  montoCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style:       const TextStyle(color: AppTheme.textPrimary),
          decoration:  InputDecoration(
            labelText: 'Monto recibido',
            hintText:  'Max: ${formatCOP((cuenta['saldo_pendiente'] as num).toDouble())}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (montoCtrl.text.isEmpty) return;
              try {
                await LocalRepository.instance.registrarPago(cuenta['id'] as int, {
                  'monto_pagado': double.parse(montoCtrl.text),
                  'fecha_pago':   DateTime.now().toIso8601String().split('T')[0],
                });
                if (context.mounted) { Navigator.pop(context); onPago(); }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}

class _FormCuenta extends StatefulWidget {
  final Map<String, dynamic>? cuenta;
  final VoidCallback onSave;
  const _FormCuenta({this.cuenta, required this.onSave});

  @override
  State<_FormCuenta> createState() => _FormCuentaState();
}

class _FormCuentaState extends State<_FormCuenta> {
  final _form        = GlobalKey<FormState>();
  final _nombre      = TextEditingController();
  final _telefono    = TextEditingController();
  final _monto       = TextEditingController();
  final _cuotas      = TextEditingController(text: '1');
  final _vencimiento = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  String _modalidad  = 'CUOTAS';
  bool   _saving     = false;

  bool get _isEditing => widget.cuenta != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.cuenta!;
      _nombre.text     = c['nombre_deudor']?.toString() ?? '';
      _telefono.text   = c['telefono']?.toString() ?? '';
      _monto.text      = (c['monto_total'] as num?)?.toStringAsFixed(0) ?? '';
      _cuotas.text     = (c['num_cuotas'] as num?)?.toString() ?? '1';
      _vencimiento.text = c['fecha_primer_vencimiento']?.toString() ?? '';
      _modalidad       = c['modalidad']?.toString() ?? 'CUOTAS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Editar deudor' : 'Nuevo deudor',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre, style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre del deudor', hintText: 'Nombre completo'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono, keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Telefono (opcional)', hintText: '310...'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monto, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Monto total prestado', hintText: '500000'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value:        _modalidad,
                decoration:   const InputDecoration(labelText: 'Modalidad de pago'),
                dropdownColor: AppTheme.surfaceColor,
                style:        const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'CONTADO', child: Text('Contado (un pago)')),
                  DropdownMenuItem(value: 'CUOTAS',  child: Text('En cuotas')),
                ],
                onChanged: (v) => setState(() => _modalidad = v!),
              ),
              if (_modalidad == 'CUOTAS') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuotas, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Numero de cuotas', hintText: '4'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _vencimiento, style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Fecha primer vencimiento', hintText: 'YYYY-MM-DD'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : Text(_isEditing ? 'Guardar cambios' : 'Registrar deudor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'nombre_deudor':            _nombre.text.trim(),
        'telefono':                 _telefono.text.isEmpty ? null : _telefono.text.trim(),
        'monto_total':              double.parse(_monto.text),
        'modalidad':                _modalidad,
        'num_cuotas':               int.parse(_cuotas.text.isEmpty ? '1' : _cuotas.text),
        'fecha_primer_vencimiento': _vencimiento.text,
      };
      if (_isEditing) {
        await LocalRepository.instance.updateCuentaCobrar(widget.cuenta!['id'] as int, payload);
      } else {
        await LocalRepository.instance.createCuentaCobrar(payload);
      }
      if (mounted) { Navigator.pop(context); widget.onSave(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
