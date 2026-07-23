import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import '../providers/gastos_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../models/gasto_fijo.dart';

class GastosScreen extends ConsumerStatefulWidget {
  const GastosScreen({super.key});
  @override
  ConsumerState<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends ConsumerState<GastosScreen> {
  final String _mes = mesActual();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(virtualAssistantProvider.notifier).setCurrentView('gastos');
    });
  }

  @override
  Widget build(BuildContext context) {
    final gastosAsync = ref.watch(gastosProvider(_mes));
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Gastos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(gastosProvider(_mes)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_gastos',
        onPressed: () => _showForm(context, ref),
        backgroundColor: AppTheme.colorGastos,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: gastosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (gastosList) {
          final mesStr = _mes;
          double total = 0.0;
          for(var g in gastosList) total += g.monto;

          return Column(
            children: [
              // Header total del mes estilo summary-card del HTML
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _TotalBanner(
                  label: 'Total Gastos (${formatMes(mesStr)})',
                  monto: total,
                  color: AppTheme.colorGastos,
                ),
              ),

              // Historial header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Historial de Gastos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(formatMes(mesStr), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.colorGastos)),
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: gastosList.isEmpty
                    ? Center(child: Text('Sin gastos registrados en ${formatMes(mesStr)}', style: const TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () async => ref.invalidate(gastosProvider(_mes)),
                        child: ListView.builder(
                          padding:     const EdgeInsets.all(16).copyWith(top: 4),
                          itemCount:   gastosList.length,
                          itemBuilder: (ctx, i) => _GastoItem(
                            gasto: gastosList[i],
                            onEdit: () => _showForm(context, ref, gasto: gastosList[i]),
                            onDelete: () => _confirmDelete(context, ref, gastosList[i]),
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

  void _showForm(BuildContext context, WidgetRef ref, {GastoFijo? gasto}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormGasto(
        gastoExistente: gasto,
        onSave: (monto) {
          ref.invalidate(gastosProvider(_mes));
          ref.invalidate(dashboardProvider);
          if (gasto == null) {
            ref.read(virtualAssistantProvider.notifier).registerAction('NUEVO_GASTO', monto);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GastoFijo gasto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Eliminar gasto', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas eliminar "${gasto.nombre}"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalRepository.instance.deleteGastoFijo(gasto.id);
              if (context.mounted) {
                ref.invalidate(gastosProvider(_mes));
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

class _TotalBanner extends StatelessWidget {
  final String label;
  final double monto;
  final Color  color;
  const _TotalBanner({required this.label, required this.monto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(16),
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
        // Línea decorativa superior en degradado
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [color, color.withAlpha(120)],
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
              Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Text(
                '-${formatCOP(monto)}', 
                style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_down_rounded, color: color, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Avance presupuesto', 
                      style: TextStyle(color: AppTheme.colorGastos, fontSize: 12, fontWeight: FontWeight.w600)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GastoItem extends ConsumerWidget {
  final GastoFijo gasto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GastoItem({required this.gasto, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = hexToColor(gasto.categoriaColor ?? '#EF4444');
    final String? ultimoPago = gasto.fechaUltimoPago;
    final String currentMonth = DateTime.now().toString().substring(0, 7);
    final bool isPaidThisMonth = ultimoPago != null && ultimoPago.startsWith(currentMonth);
    final bool esFijo = gasto.esFijo == 1;
    final String mesRef = gasto.mesReferencia.isNotEmpty ? gasto.mesReferencia : currentMonth;
    final String catIconName = gasto.categoriaIcono ?? 'shopping_cart';
    final IconData icon = isPaidThisMonth ? Icons.check_circle_rounded : getCategoryIcon(catIconName);
    final Color itemColor = isPaidThisMonth ? Colors.green : color;

    return GestureDetector(
      onTap: () {
        ref.read(virtualAssistantProvider.notifier).analyzeTransactionItem(
          'gasto',
          gasto.monto,
          gasto.nombre,
        );
      },
      child: Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPaidThisMonth ? Colors.green.withAlpha(12) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isPaidThisMonth ? Colors.green.withAlpha(50) : AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: itemColor.withAlpha(20), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: itemColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gasto.nombre, 
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)
                ),
                const SizedBox(height: 3),
                Text(
                  esFijo
                      ? '${gasto.categoriaNombre ?? 'Fijo'} • Fijo mensual • Día ${gasto.diaPago}'
                      : '${gasto.categoriaNombre ?? 'Variable'} • Gasto del mes (${formatMes(mesRef)})',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${formatCOP(gasto.monto)}',
                style: AppTheme.monoStyle(color: AppTheme.colorGastos, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 2),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted, size: 18),
                color: AppTheme.bgCard,
                onSelected: (val) async {
                  if (val == 'pay') {
                    try {
                      await LocalRepository.instance.pagarGastoFijo(gasto.id);
                      if (context.mounted) {
                        ref.invalidate(gastosProvider(currentMonth)); // Assuming _mes is currentMonth here roughly, or just reload current
                        ref.invalidate(dashboardProvider);
                      }
                      onDelete(); // Dummy call if necessary to conform to signature changes
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al pagar: $e')));
                    }
                  }
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  if (!isPaidThisMonth)
                    const PopupMenuItem(value: 'pay', child: Text('Marcar Pagado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                ],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _FormGasto extends StatefulWidget {
  final Function(double) onSave;
  final GastoFijo? gastoExistente;
  const _FormGasto({required this.onSave, this.gastoExistente});

  @override
  State<_FormGasto> createState() => _FormGastoState();
}

class _FormGastoState extends State<_FormGasto> {
  final _form   = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _monto  = TextEditingController();
  final _dia    = TextEditingController();
  List<dynamic> _categorias = [];
  int?  _categoriaId;
  bool  _esFijo = true;
  bool  _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.gastoExistente != null) {
      _nombre.text = widget.gastoExistente!.nombre;
      _monto.text  = widget.gastoExistente!.monto.toString();
      _dia.text    = widget.gastoExistente!.diaPago.toString();
      _categoriaId = widget.gastoExistente!.categoriaId;
      _esFijo      = widget.gastoExistente!.esFijo == 1;
    }
    LocalRepository.instance.getCategoriasGasto().then((r) {
      setState(() {
        _categorias  = r['data'] ?? [];
        if (_categorias.isNotEmpty && _categoriaId == null) {
          _categoriaId = _categorias[0]['id'] as int;
        }
      });
    });
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
              Text(widget.gastoExistente != null ? 'Editar gasto' : 'Nuevo gasto', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              if (_categorias.isNotEmpty)
                DropdownButtonFormField<int>(
                  value:        _categoriaId,
                  decoration:   const InputDecoration(labelText: 'Categoria'),
                  dropdownColor: AppTheme.surfaceColor,
                  style:        const TextStyle(color: AppTheme.textPrimary),
                  items: _categorias.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                    value: c['id'] as int, child: Text(c['nombre'] as String),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre, style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Arriendo o Cena'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _monto, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Monto', hintText: '1200000'),
                    validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dia, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Dia pago', hintText: '5'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              SwitchListTile(
                value:          _esFijo,
                onChanged:      (v) => setState(() => _esFijo = v),
                title:          const Text('¿Es gasto fijo mensual?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle:       const Text('Si está activo, se repetirá cada mes. Si se apaga, solo existirá en el mes actual y luego se limpiará automáticamente.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                activeColor:    AppTheme.colorGastos,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorGastos),
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Guardar gasto'),
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
      final data = {
        'categoria_id': _categoriaId,
        'nombre':       _nombre.text.trim(),
        'monto':        double.parse(_monto.text),
        'dia_pago':     _dia.text.isEmpty ? null : int.parse(_dia.text),
        'es_fijo':      _esFijo ? 1 : 0,
        'mes_referencia': mesActual(),
      };
      
      if (widget.gastoExistente != null) {
        await LocalRepository.instance.updateGastoFijo(widget.gastoExistente!.id, data);
      } else {
        await LocalRepository.instance.createGastoFijo(data);
      }
      if (mounted) { Navigator.pop(context); widget.onSave(double.parse(_monto.text)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
