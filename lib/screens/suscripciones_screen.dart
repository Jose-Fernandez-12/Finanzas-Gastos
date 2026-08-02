import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/local_repository.dart';
import '../providers/suscripciones_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../models/suscripcion.dart';

class SuscripcionesScreen extends ConsumerStatefulWidget {
  const SuscripcionesScreen({super.key});
  @override
  ConsumerState<SuscripcionesScreen> createState() => _SuscripcionesScreenState();
}

class _SuscripcionesScreenState extends ConsumerState<SuscripcionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showForm({Suscripcion? suscripcion}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormSuscripcion(
        existente: suscripcion,
        onSave: () => ref.invalidate(suscripcionesProvider),
      ),
    );
  }

  void _confirmDelete(Suscripcion s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Eliminar suscripcion',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas eliminar "${s.nombre}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalRepository.instance.deleteSuscripcion(s.id);
              if (mounted) ref.invalidate(suscripcionesProvider);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(suscripcionesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Suscripciones',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Vencidas / Inactivas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_suscripciones',
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (lista) {
          final activas  = lista.where((s) => s.activa == 1).toList();
          final inactivas = lista.where((s) => s.activa == 0).toList();

          // Banner resumen
          final double totalMes = activas.fold(0, (sum, s) => sum + s.monto);
          final double totalAnual = activas.fold(0, (sum, s) => sum + s.costoAnual);

          return Column(
            children: [
              // --- Banner resumen ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _BannerResumen(totalMes: totalMes, totalAnual: totalAnual, suscripciones: activas),
              ),

              // --- Tabs ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ListaSuscripciones(
                      lista: activas,
                      emptyMsg: 'Sin suscripciones activas',
                      onEdit: (s) => _showForm(suscripcion: s),
                      onDelete: _confirmDelete,
                      onRegistrarCobro: (s) async {
                        await LocalRepository.instance.registrarCobroSuscripcion(s.id);
                        if (mounted) ref.invalidate(suscripcionesProvider);
                      },
                    ),
                    _ListaSuscripciones(
                      lista: inactivas,
                      emptyMsg: 'Sin suscripciones inactivas',
                      onEdit: (s) => _showForm(suscripcion: s),
                      onDelete: _confirmDelete,
                      onRegistrarCobro: null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Banner resumen ───────────────────────────────────────────────────────────
class _BannerResumen extends StatelessWidget {
  final double totalMes;
  final double totalAnual;
  final List<Suscripcion> suscripciones;

  const _BannerResumen({
    required this.totalMes,
    required this.totalAnual,
    required this.suscripciones,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gasto mensual total',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  _fmtMoney(totalMes),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anual proyectado: ${_fmtMoney(totalAnual)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          // Mini-avatares de los primeros 3 servicios
          Column(
            children: [
              Row(
                children: [
                  for (final s in suscripciones.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _MiniAvatar(suscripcion: s, size: 32),
                    ),
                  if (suscripciones.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('+${suscripciones.length - 3}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${suscripciones.length} activa${suscripciones.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
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
}

// ─── Mini avatar de suscripcion ───────────────────────────────────────────────
class _MiniAvatar extends StatelessWidget {
  final Suscripcion suscripcion;
  final double size;
  const _MiniAvatar({required this.suscripcion, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(Suscripcion.colorParaServicio(suscripcion.nombre));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Center(
        child: Text(
          suscripcion.inicial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Lista de suscripciones ───────────────────────────────────────────────────
class _ListaSuscripciones extends StatelessWidget {
  final List<Suscripcion> lista;
  final String emptyMsg;
  final void Function(Suscripcion) onEdit;
  final void Function(Suscripcion) onDelete;
  final Future<void> Function(Suscripcion)? onRegistrarCobro;

  const _ListaSuscripciones({
    required this.lista,
    required this.emptyMsg,
    required this.onEdit,
    required this.onDelete,
    required this.onRegistrarCobro,
  });

  @override
  Widget build(BuildContext context) {
    if (lista.isEmpty) {
      return Center(
        child: Text(emptyMsg,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }

    // Ordenar: primero los que vencen pronto
    final sorted = [...lista]..sort((a, b) => a.diasParaProximoCobro.compareTo(b.diasParaProximoCobro));

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: sorted.length,
        itemBuilder: (ctx, i) => _SuscripcionCard(
          suscripcion: sorted[i],
          onEdit:      () => onEdit(sorted[i]),
          onDelete:    () => onDelete(sorted[i]),
          onCobrar:    onRegistrarCobro != null ? () => onRegistrarCobro!(sorted[i]) : null,
        ),
      ),
    );
  }
}

// ─── Card de suscripcion ──────────────────────────────────────────────────────
class _SuscripcionCard extends StatelessWidget {
  final Suscripcion suscripcion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCobrar;

  const _SuscripcionCard({
    required this.suscripcion,
    required this.onEdit,
    required this.onDelete,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    final s = suscripcion;
    final brandColor = _hexToColor(Suscripcion.colorParaServicio(s.nombre));
    final dias = s.diasParaProximoCobro;
    final vence = s.vencePronto;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: vence ? AppTheme.colorGastos.withAlpha(80) : AppTheme.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar con color de marca
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        s.inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nombre y detalles
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${s.frecuencia} · Cobro dia ${s.diaCobro}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        if (vence)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.colorGastos.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 12, color: AppTheme.colorGastos),
                                  const SizedBox(width: 4),
                                  Text(
                                    dias == 0
                                        ? 'Vence hoy'
                                        : dias == 1
                                            ? 'Vence manana'
                                            : 'Vence en $dias dias',
                                    style: const TextStyle(
                                      color: AppTheme.colorGastos,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.colorIngresos,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'En $dias dias',
                                  style: const TextStyle(
                                    color: AppTheme.colorIngresos,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Monto y acciones
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtMoney(s.monto),
                        style: TextStyle(
                          color: brandColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'JetBrains Mono',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            size: 18, color: AppTheme.textMuted),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: AppTheme.bgCard,
                        onSelected: (v) {
                          if (v == 'edit')    onEdit();
                          if (v == 'delete')  onDelete();
                          if (v == 'cobrar' && onCobrar != null) onCobrar!();
                        },
                        itemBuilder: (_) => [
                          if (onCobrar != null)
                            const PopupMenuItem(
                              value: 'cobrar',
                              child: Row(children: [
                                Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.colorIngresos),
                                SizedBox(width: 8),
                                Text('Marcar pagado'),
                              ]),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}

// ─── Formulario de suscripcion ────────────────────────────────────────────────
class _FormSuscripcion extends StatefulWidget {
  final Suscripcion? existente;
  final VoidCallback onSave;
  const _FormSuscripcion({this.existente, required this.onSave});

  @override
  State<_FormSuscripcion> createState() => _FormSuscripcionState();
}

class _FormSuscripcionState extends State<_FormSuscripcion> {
  final _form        = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _montoCtrl   = TextEditingController();
  String _frecuencia = 'Mensual';
  int    _diaCobro   = 1;
  int    _recordDias = 1;
  bool   _saving     = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existente;
    if (s != null) {
      _nombreCtrl.text = s.nombre;
      _montoCtrl.text  = s.monto.toStringAsFixed(0);
      _frecuencia      = s.frecuencia;
      _diaCobro        = s.diaCobro;
      _recordDias      = s.recordatorioDias;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'nombre':            _nombreCtrl.text.trim(),
        'monto':             double.parse(_montoCtrl.text),
        'dia_cobro':         _diaCobro,
        'frecuencia':        _frecuencia,
        'recordatorio_dias': _recordDias,
        'color':             Suscripcion.colorParaServicio(_nombreCtrl.text.trim()),
      };
      if (widget.existente != null) {
        await LocalRepository.instance.updateSuscripcion(widget.existente!.id, data);
      } else {
        await LocalRepository.instance.createSuscripcion(data);
      }
      if (mounted) { Navigator.pop(context); widget.onSave(); }
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
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Editar suscripcion' : 'Nueva suscripcion',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nombre del servicio',
                  hintText: 'Ej: Netflix, Spotify, Gimnasio',
                  prefixIcon: Icon(Icons.subscriptions_rounded, color: AppTheme.primary),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Preview del avatar al escribir el nombre
              if (_nombreCtrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _hexToColor(Suscripcion.colorParaServicio(_nombreCtrl.text)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _nombreCtrl.text[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Color detectado automaticamente',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              TextFormField(
                controller: _montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Monto (\$)',
                  hintText: '49900',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.primary),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // Frecuencia
              DropdownButtonFormField<String>(
                initialValue: _frecuencia,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia',
                  prefixIcon: Icon(Icons.repeat_rounded, color: AppTheme.primary),
                ),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: ['Mensual', 'Anual', 'Semanal'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frecuencia = v!),
              ),
              const SizedBox(height: 12),

              // Dia de cobro
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dia de cobro', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _diaCobro.toDouble(),
                                  min: 1,
                                  max: 31,
                                  divisions: 30,
                                  activeColor: AppTheme.primary,
                                  inactiveColor: AppTheme.borderLight,
                                  onChanged: (v) => setState(() => _diaCobro = v.round()),
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_diaCobro',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recordatorio
              DropdownButtonFormField<int>(
                initialValue: _recordDias,
                decoration: const InputDecoration(
                  labelText: 'Recordarme',
                  prefixIcon: Icon(Icons.notifications_rounded, color: AppTheme.primary),
                ),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                  DropdownMenuItem(value: 3, child: Text('3 dias antes')),
                  DropdownMenuItem(value: 7, child: Text('1 semana antes')),
                ],
                onChanged: (v) => setState(() => _recordDias = v!),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Guardar cambios' : 'Crear suscripcion'),
                ),
              ),
            ],
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
