import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import '../providers/ingresos_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../models/ingreso.dart';
import 'presupuesto_base_cero_screen.dart';

class IngresosScreen extends ConsumerStatefulWidget {
  const IngresosScreen({super.key});
  @override
  ConsumerState<IngresosScreen> createState() => _IngresosScreenState();
}

class _IngresosScreenState extends ConsumerState<IngresosScreen> {
  final String _mes = mesActual();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ingresosAsync = ref.watch(ingresosProvider(_mes));
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Ingresos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(ingresosProvider(_mes)),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_presupuesto',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PresupuestoBaseCeroScreen()),
              );
            },
            backgroundColor: const Color(0xFF8B5CF6),
            child: const Icon(Icons.mail_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab_ingresos',
            onPressed: () => _showForm(context, ref),
            backgroundColor: AppTheme.colorIngresos,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
      body: ingresosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (ingresosList) {
          double total = 0.0;
          for(var i in ingresosList) total += i.monto;

          return Column(
            children: [
              // Header total del mes estilo summary-card del HTML
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _TotalBanner(
                  label: 'Total Mes Actual',
                  monto: total,
                  color: AppTheme.colorIngresos,
                ),
              ),
              
              // Historial header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Historial Reciente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(formatMes(_mes), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: ingresosList.isEmpty
                    ? const _Empty(mensaje: 'Sin ingresos registrados este mes')
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () async => ref.invalidate(ingresosProvider(_mes)),
                        child: ListView.builder(
                          padding:     const EdgeInsets.all(16).copyWith(top: 4),
                          itemCount:   ingresosList.length,
                          itemBuilder: (ctx, i) => _IngresoItem(
                            ingreso: ingresosList[i],
                            onEdit: (ingresoToEdit) => _showForm(context, ref, ingreso: ingresoToEdit),
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

  void _showForm(BuildContext context, WidgetRef ref, {Ingreso? ingreso}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => FormIngreso(
        ingreso: ingreso,
        onSave: (monto) {
          ref.invalidate(ingresosProvider(_mes));
          ref.invalidate(dashboardProvider);
        }
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
                formatCOP(monto), 
                style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)
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
                    Icon(Icons.trending_up_rounded, color: color, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      '+12.5% vs. anterior', 
                      style: TextStyle(color: AppTheme.colorIngresos, fontSize: 12, fontWeight: FontWeight.w600)
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

class _IngresoItem extends ConsumerWidget {
  final Ingreso ingreso;
  final Function(Ingreso) onEdit;
  const _IngresoItem({required this.ingreso, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = hexToColor(ingreso.categoriaColor ?? '#10B981');
    final String catIconName = ingreso.categoriaIcono ?? 'trending_up';
    final IconData icon = getCategoryIcon(catIconName);

    return GestureDetector(
      onTap: () {
        ref.read(virtualAssistantProvider.notifier).analyzeTransactionItem(
          'ingreso',
          ingreso.monto,
          ingreso.descripcion ?? 'Ingreso',
        );
      },
      child: Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
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
              color: color.withAlpha(20), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingreso.descripcion ?? '', 
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)
                ),
                const SizedBox(height: 3),
                Text(
                  '${ingreso.categoriaNombre ?? 'General'} • ${formatFecha(ingreso.fecha)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${formatCOP(ingreso.monto)}',
                style: AppTheme.monoStyle(color: AppTheme.colorIngresos, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 18),
                onPressed: () => onEdit(ingreso),
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

class FormIngreso extends ConsumerStatefulWidget {
  final Ingreso? ingreso;
  final Function(double) onSave;
  const FormIngreso({super.key, this.ingreso, required this.onSave});

  @override
  ConsumerState<FormIngreso> createState() => _FormIngresoState();
}

class _FormIngresoState extends ConsumerState<FormIngreso> {
  final _form        = GlobalKey<FormState>();
  final _desc        = TextEditingController();
  final _monto       = TextEditingController();
  final _fecha       = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  List<dynamic> _categorias = [];
  int?          _categoriaId;
  bool          _esFijo  = true;
  bool          _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    final r = await LocalRepository.instance.getCategoriasIngreso();
    setState(() => _categorias = r['data'] ?? []);
    if (widget.ingreso != null) {
      final i = widget.ingreso!;
      _categoriaId = i.categoriaId;
      _desc.text = i.descripcion ?? '';
      _monto.text = i.monto.toString();
      _fecha.text = i.fecha;
      _esFijo = i.esFijo == 1;
    } else {
      if (_categorias.isNotEmpty) _categoriaId = _categorias[0]['id'] as int;
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
              const Text('Nuevo ingreso', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),

              if (_categorias.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: _categoriaId,
                  decoration:   const InputDecoration(labelText: 'Categoria'),
                  dropdownColor: AppTheme.surfaceColor,
                  style:        const TextStyle(color: AppTheme.textPrimary),
                  items: _categorias.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['nombre'] as String),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller:  _desc,
                style:       const TextStyle(color: AppTheme.textPrimary),
                decoration:  const InputDecoration(labelText: 'Descripcion', hintText: 'Ej: Salario julio'),
                validator:   (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller:   _monto,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style:        const TextStyle(color: AppTheme.textPrimary),
                decoration:   const InputDecoration(labelText: 'Monto', hintText: '3500000'),
                validator:    (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller:  _fecha,
                style:       const TextStyle(color: AppTheme.textPrimary),
                decoration:  const InputDecoration(labelText: 'Fecha', hintText: 'YYYY-MM-DD'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value:          _esFijo,
                onChanged:      (v) => setState(() => _esFijo = v),
                title:          const Text('Ingreso fijo mensual', style: TextStyle(color: AppTheme.textPrimary)),
                activeColor:    AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.ingreso != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: widget.ingreso != null ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.colorIngresos,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar ingreso'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Eliminar ingreso', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas eliminar "${_desc.text.trim()}"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _saving = true);
              try {
                await LocalRepository.instance.deleteIngreso(widget.ingreso!.id);
                if (mounted) {
                  Navigator.pop(context);
                  widget.onSave(0.0);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final double monto = double.tryParse(_monto.text) ?? 0.0;
      if (widget.ingreso != null && monto <= 0) {
        await LocalRepository.instance.deleteIngreso(widget.ingreso!.id);
      } else {
        final reqData = {
          'categoria_id': _categoriaId,
          'descripcion':  _desc.text.trim(),
          'monto':        monto,
          'es_fijo':      _esFijo ? 1 : 0,
          'fecha':        _fecha.text,
        };
        if (widget.ingreso == null) {
          if (monto > 0) {
            final nombreIngreso = _desc.text.trim();
            await LocalRepository.instance.createIngreso(reqData);
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (context.mounted) {
                ref.read(virtualAssistantProvider.notifier).registerAction('NUEVO_INGRESO', monto, nombreIngreso);
              }
            });
          }
        } else {
          await LocalRepository.instance.updateIngreso(widget.ingreso!.id, reqData);
        }
      }
      if (mounted) { Navigator.pop(context); widget.onSave(monto); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}


class _Empty extends StatelessWidget {
  final String mensaje;
  const _Empty({required this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 52),
        const SizedBox(height: 12),
        Text(mensaje, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    ),
  );
}
