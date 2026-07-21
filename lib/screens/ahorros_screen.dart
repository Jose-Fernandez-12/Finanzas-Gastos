import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/local_repository.dart';
import '../providers/ahorros_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/bolsillo_ahorro.dart';
import '../widgets/common_widgets.dart';

class AhorrosScreen extends ConsumerStatefulWidget {
  const AhorrosScreen({super.key});
  @override
  ConsumerState<AhorrosScreen> createState() => _AhorrosScreenState();
}

class _AhorrosScreenState extends ConsumerState<AhorrosScreen> {
  @override
  // initState not needed since watch handles initial load

  @override
  Widget build(BuildContext context) {
    final ahorrosAsync = ref.watch(ahorrosProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_ahorros',
        onPressed: () => _showForm(context, ref),
        icon:      const Icon(Icons.add_rounded),
        label:     const Text('Nueva meta'),
        backgroundColor: AppTheme.colorAhorros,
      ),
      body: ahorrosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (ahorrosList) {
          if (ahorrosList.isEmpty) {
            return const Center(child: Text('Sin metas de ahorro', style: TextStyle(color: AppTheme.textSecondary)));
          }
          return ListView.builder(
            padding:     const EdgeInsets.all(16),
            itemCount:   ahorrosList.length,
            itemBuilder: (ctx, i) {
              final b = ahorrosList[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _showAporteDialog(context, ref, b),
                  child: ProgresoAhorroBar(bolsillo: b),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormAhorro(onSave: () => ref.invalidate(ahorrosProvider)),
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
          controller:  montoCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style:       const TextStyle(color: AppTheme.textPrimary),
          decoration:  const InputDecoration(labelText: 'Monto del aporte', hintText: '100000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (montoCtrl.text.isEmpty) return;
              await LocalRepository.instance.createAporte(bolsillo.id, {
                'monto': double.parse(montoCtrl.text),
                'fecha': DateTime.now().toIso8601String().split('T')[0],
                'descripcion': 'Aporte manual',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(ahorrosProvider);
                ref.invalidate(dashboardProvider);
              }
            },
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }
}

class _FormAhorro extends StatefulWidget {
  final VoidCallback onSave;
  const _FormAhorro({required this.onSave});

  @override
  State<_FormAhorro> createState() => _FormAhorroState();
}

class _FormAhorroState extends State<_FormAhorro> {
  final _form  = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _meta   = TextEditingController();
  final _fecha  = TextEditingController();
  bool  _saving = false;

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
              const Text('Nueva meta de ahorro', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre, style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Vacaciones'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _meta, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Meta (\$)', hintText: '5000000'),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fecha, style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Fecha objetivo (opcional)', hintText: 'YYYY-MM-DD'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorAhorros),
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Crear meta'),
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
      await LocalRepository.instance.createAhorro({
        'nombre':     _nombre.text.trim(),
        'meta_monto': double.parse(_meta.text),
        'fecha_meta': _fecha.text.isEmpty ? null : _fecha.text,
      });
      if (mounted) { Navigator.pop(context); widget.onSave(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
