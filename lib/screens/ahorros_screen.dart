import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/local_repository.dart';
import '../providers/ahorros_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../models/bolsillo_ahorro.dart';


class AhorrosScreen extends ConsumerStatefulWidget {
  const AhorrosScreen({super.key});
  @override
  ConsumerState<AhorrosScreen> createState() => _AhorrosScreenState();
}

class _AhorrosScreenState extends ConsumerState<AhorrosScreen> {
  @override
  Widget build(BuildContext context) {
    final ahorrosAsync = ref.watch(ahorrosProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_ahorros',
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva meta'),
        backgroundColor: AppTheme.colorAhorros,
      ),
      body: ahorrosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (ahorrosList) {
          // Banner resumen
          final double totalAcumulado = ahorrosList.fold(0, (s, b) => s + b.montoActual);
          final double totalMeta      = ahorrosList.fold(0, (s, b) => s + b.metaMonto);

          return Column(
            children: [
              if (ahorrosList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _BannerAhorros(total: totalAcumulado, meta: totalMeta),
                ),
              Expanded(
                child: ahorrosList.isEmpty
                    ? const Center(child: Text('Sin metas de ahorro', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: ahorrosList.length,
                        itemBuilder: (ctx, i) {
                          final b = ahorrosList[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BolsilloCard(
                              bolsillo: b,
                              onAporte:  () => _showAporteDialog(context, ref, b),
                              onEdit:    () => _showForm(context, ref, bolsillo: b),
                              onDelete:  () => _confirmDelete(context, ref, b),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {BolsilloAhorro? bolsillo}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormAhorro(
        existente: bolsillo,
        onSave: () {
          ref.invalidate(ahorrosProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }

  void _showAporteDialog(BuildContext context, WidgetRef ref, BolsilloAhorro bolsillo) {
    final montoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Aporte a: ${bolsillo.nombre}',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: montoCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Monto del aporte', hintText: '100000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (montoCtrl.text.isEmpty) return;
              await LocalRepository.instance.createAporte(bolsillo.id, {
                'monto':       double.parse(montoCtrl.text),
                'fecha':       DateTime.now().toIso8601String().split('T')[0],
                'descripcion': 'Aporte manual',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(ahorrosProvider);
                ref.invalidate(dashboardProvider);
                ref.read(virtualAssistantProvider.notifier).registerAction('NUEVO_AHORRO', double.parse(montoCtrl.text));
              }
            },
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BolsilloAhorro b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Eliminar bolsillo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas eliminar "${b.nombre}"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalRepository.instance.deleteAhorro(b.id);
              if (context.mounted) {
                ref.invalidate(ahorrosProvider);
                ref.invalidate(dashboardProvider);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Banner resumen ───────────────────────────────────────────────────────────
class _BannerAhorros extends StatelessWidget {
  final double total;
  final double meta;
  const _BannerAhorros({required this.total, required this.meta});

  @override
  Widget build(BuildContext context) {
    final pct = meta > 0 ? (total / meta).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total acumulado', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            _fmtMoney(total),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, fontFamily: 'JetBrains Mono', letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text('de ${_fmtMoney(meta)} en metas activas', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(pct * 100).toStringAsFixed(0)}% del total de metas',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Card de bolsillo ─────────────────────────────────────────────────────────
class _BolsilloCard extends StatelessWidget {
  final BolsilloAhorro bolsillo;
  final VoidCallback onAporte;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BolsilloCard({
    required this.bolsillo,
    required this.onAporte,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final b = bolsillo;
    final color = _hexToColor(b.color);
    final pct   = b.metaMonto > 0 ? (b.montoActual / b.metaMonto).clamp(0.0, 1.0) : 0.0;

    // Calculo de cuotas restantes
    final cuotaActiva = b.cuotaMonto > 0;
    int? cuotasRestantes;
    String? fechaEstimada;
    if (cuotaActiva && b.cuotaMonto > 0) {
      final faltante = b.metaMonto - b.montoActual;
      cuotasRestantes = (faltante / b.cuotaMonto).ceil().clamp(0, 999);
      final now = DateTime.now();
      final fin = DateTime(now.year, now.month + cuotasRestantes);
      const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      fechaEstimada = '${meses[fin.month - 1]} ${fin.year}';
    }

    final atrasado = b.mesesMeta != null && cuotasRestantes != null && cuotasRestantes > (b.mesesMeta ?? 0);

    return GestureDetector(
      onTap: onAporte,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        if (cuotaActiva)
                          Text('${b.frecuenciaCuota} · ${_fmtMoney(b.cuotaMonto)}/cuota',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                        else
                          Text('Meta: ${_fmtMoney(b.metaMonto)}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Progreso circular
                  _CircularProgress(percent: pct, color: color),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: AppTheme.bgCard,
                    onSelected: (v) {
                      if (v == 'edit')   onEdit();
                      if (v == 'delete') onDelete();
                      if (v == 'aporte') onAporte();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'aporte', child: Row(children: [Icon(Icons.add_circle_rounded, size: 16, color: AppTheme.colorAhorros), SizedBox(width: 8), Text('Agregar aporte')])),
                      PopupMenuItem(value: 'edit',   child: Row(children: [Icon(Icons.edit_rounded,         size: 16, color: AppTheme.textSecondary), SizedBox(width: 8), Text('Editar')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded,       size: 16, color: Colors.redAccent),        SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.redAccent))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: color.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              // Montos
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmtMoney(b.montoActual),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color, fontFamily: 'JetBrains Mono')),
                  Text('de ${_fmtMoney(b.metaMonto)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),

              // Info de cuotas
              if (cuotaActiva && cuotasRestantes != null && fechaEstimada != null) ...[
                const SizedBox(height: 8),
                const Divider(color: AppTheme.borderLight, height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notifications_rounded, size: 13, color: atrasado ? AppTheme.colorGastos : AppTheme.colorAhorros),
                    const SizedBox(width: 5),
                    Text(
                      cuotasRestantes == 0
                          ? 'Meta alcanzada'
                          : 'Faltan $cuotasRestantes cuota${cuotasRestantes != 1 ? 's' : ''} · Terminas en $fechaEstimada',
                      style: TextStyle(
                        color: atrasado ? AppTheme.colorGastos : AppTheme.colorAhorros,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (atrasado ? AppTheme.colorGastos : AppTheme.colorIngresos).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        atrasado ? 'Atrasado' : 'En curso',
                        style: TextStyle(
                          color: atrasado ? AppTheme.colorGastos : AppTheme.colorIngresos,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progreso circular SVG ────────────────────────────────────────────────────
class _CircularProgress extends StatelessWidget {
  final double percent;
  final Color color;
  const _CircularProgress({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 4,
            backgroundColor: color.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormAhorro extends StatefulWidget {
  final BolsilloAhorro? existente;
  final VoidCallback onSave;
  const _FormAhorro({this.existente, required this.onSave});

  @override
  State<_FormAhorro> createState() => _FormAhorroState();
}

class _FormAhorroState extends State<_FormAhorro> {
  final _form         = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _metaCtrl     = TextEditingController();
  final _cuotaCtrl    = TextEditingController();
  final _mesesCtrl    = TextEditingController();
  String _frecuencia  = 'Mensual';
  String _modo        = 'cuota'; // 'cuota' | 'meses'
  bool   _saving      = false;

  // Calculo dinamico
  double get _metaVal => double.tryParse(_metaCtrl.text) ?? 0;
  double get _cuotaVal => double.tryParse(_cuotaCtrl.text) ?? 0;
  int    get _mesesVal => int.tryParse(_mesesCtrl.text) ?? 0;

  String get _calculoLabel {
    if (_metaVal <= 0) return '';
    if (_modo == 'cuota' && _cuotaVal > 0) {
      final meses = (_metaVal / _cuotaVal).ceil();
      final fin = DateTime(DateTime.now().year, DateTime.now().month + meses);
      const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      return 'Ahorraras ${_fmtMoney(_cuotaVal)}/${_frecuencia.toLowerCase()} y llegarias en ${m[fin.month-1]} ${fin.year} ($meses meses)';
    }
    if (_modo == 'meses' && _mesesVal > 0) {
      final cuota = _metaVal / _mesesVal;
      return 'Necesitas ahorrar ${_fmtMoney(cuota)}/${_frecuencia.toLowerCase()} para lograrlo en $_mesesVal meses';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final s = widget.existente;
    if (s != null) {
      _nombreCtrl.text = s.nombre;
      _metaCtrl.text   = s.metaMonto.toStringAsFixed(0);
      if (s.cuotaMonto > 0) _cuotaCtrl.text = s.cuotaMonto.toStringAsFixed(0);
      if (s.mesesMeta != null) _mesesCtrl.text = s.mesesMeta.toString();
      _frecuencia = s.frecuenciaCuota;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _metaCtrl.dispose();
    _cuotaCtrl.dispose();
    _mesesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      double cuotaFinal = 0;
      int?   mesesFinal;
      if (_modo == 'cuota' && _cuotaVal > 0) {
        cuotaFinal = _cuotaVal;
        mesesFinal = (_metaVal / _cuotaVal).ceil();
      } else if (_modo == 'meses' && _mesesVal > 0) {
        cuotaFinal = _metaVal / _mesesVal;
        mesesFinal = _mesesVal;
      }

      final data = {
        'nombre':           _nombreCtrl.text.trim(),
        'meta_monto':       _metaVal,
        'fecha_meta':       mesesFinal != null
            ? DateTime(DateTime.now().year, DateTime.now().month + mesesFinal).toIso8601String().split('T')[0]
            : null,
        'cuota_monto':      cuotaFinal,
        'frecuencia_cuota': _frecuencia,
        'meses_meta':       mesesFinal,
        'color':            widget.existente?.color ?? '#3B82F6',
      };

      if (widget.existente != null) {
        await LocalRepository.instance.updateAhorro(widget.existente!.id, data);
      } else {
        await LocalRepository.instance.createAhorro(data);
      }
      if (mounted) { Navigator.pop(context); widget.onSave(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existente != null;
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
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Editar meta de ahorro' : 'Nueva meta de ahorro',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre de la meta', hintText: 'Ej: Vacaciones, MacBook'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _metaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Meta (\$)', hintText: '5000000'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Frecuencia
              DropdownButtonFormField<String>(
                initialValue: _frecuencia,
                decoration: const InputDecoration(labelText: 'Frecuencia de ahorro'),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: ['Mensual', 'Quincenal', 'Semanal'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frecuencia = v!),
              ),
              const SizedBox(height: 16),

              // Tabs Por cuota / Por meses
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    _TabOption(label: 'Por cuota', selected: _modo == 'cuota', onTap: () => setState(() { _modo = 'cuota'; _mesesCtrl.clear(); })),
                    _TabOption(label: 'Por meses', selected: _modo == 'meses', onTap: () => setState(() { _modo = 'meses'; _cuotaCtrl.clear(); })),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_modo == 'cuota')
                TextFormField(
                  controller: _cuotaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: 'Cuota ${_frecuencia.toLowerCase()} (\$)', hintText: '200000'),
                  onChanged: (_) => setState(() {}),
                )
              else
                TextFormField(
                  controller: _mesesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Numero de meses', hintText: '12'),
                  onChanged: (_) => setState(() {}),
                ),

              // Calculo dinamico
              if (_calculoLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorAhorros.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.colorAhorros.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, size: 16, color: AppTheme.colorAhorros),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_calculoLabel,
                            style: const TextStyle(color: AppTheme.colorAhorros, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorAhorros),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Guardar cambios' : 'Crear meta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab option ───────────────────────────────────────────────────────────────
class _TabOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.colorAhorros : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

String _fmtMoney(double v) {
  final n = v.abs();
  if (n >= 1000000) return '\$${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) {
    final str = n.toStringAsFixed(0);
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if ((str.length - i) % 3 == 0 && i != 0) result.write('.');
      result.write(str[i]);
    }
    return '\$$result';
  }
  return '\$${n.toStringAsFixed(0)}';
}
