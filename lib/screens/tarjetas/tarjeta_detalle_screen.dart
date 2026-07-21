import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/local_repository.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/virtual_assistant_provider.dart';
import '../../widgets/common_widgets.dart';
import 'forms.dart';

class TarjetaDetalleScreen extends ConsumerStatefulWidget {
  final dynamic tarjeta;
  final int? initialCompraId;
  const TarjetaDetalleScreen({super.key, required this.tarjeta, this.initialCompraId});

  @override
  ConsumerState<TarjetaDetalleScreen> createState() => _TarjetaDetalleScreenState();
}

class _TarjetaDetalleScreenState extends ConsumerState<TarjetaDetalleScreen> {
  late dynamic _tarjeta = widget.tarjeta;
  List<dynamic> _compras = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _recargarTodo();
    Future.microtask(() {
      if (mounted) ref.read(virtualAssistantProvider.notifier).setCurrentView('tarjetas');
    });
  }

  Future<void> _recargarTodo() async {
    setState(() => _loading = true);
    try {
      final tId = _tarjeta.id;
      final data = await LocalRepository.instance.getComprasTarjeta(tId); // Reemplazar con DAO
      if (!mounted) return;
      ref.invalidate(tarjetasProvider);
      ref.invalidate(comprasActivasProvider);
      ref.invalidate(dashboardProvider);

      final lista = await ref.read(tarjetasProvider.future);
      final index = lista.indexWhere((t) => t.id == tId);
      if (index != -1 && mounted) {
        _tarjeta = lista[index];
      }

      final activas = (data['data'] as List<dynamic>).where((c) {
        final cuotas = (c['cuotas'] as List?) ?? [];
        if (cuotas.isNotEmpty && cuotas.every((cuota) => cuota['estado'] == 'PAGADA')) {
          return false;
        }
        final saldo = (c['saldo_capital'] as num?)?.toDouble() ?? 0;
        return saldo > 1;
      }).toList();

      if (mounted) {
        setState(() { _compras = activas; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tarjeta;
    final tMap = t.toMap();
    final color = getTarjetaColor(tMap);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Text('${t.banco} — ${t.nombreTarjeta}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.bgCard,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => FormTarjeta(
                  tarjeta: t.toMap(),
                  onSave: () {
                    _recargarTodo();
                  }
                ),
              );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_tarjeta_detalle',
        onPressed: () => _showFormCompra(context),
        icon:  const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('Registrar compra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TarjetaVisual(tarjeta: t),
                const SizedBox(height: 20),
                if (_compras.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Sin compras registradas', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ..._compras.map((c) => _CompraCard(
                    compra: c,
                    tarjetaId: t.id,
                    initialExpand: widget.initialCompraId != null && c['id'] == widget.initialCompraId,
                    onPagoCuota: _recargarTodo,
                    onEdit: (compraToEdit) => _showFormCompra(context, compra: compraToEdit),
                  )),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  void _showFormCompra(BuildContext context, {Map<String, dynamic>? compra}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FormCompra(
        tarjetaId: _tarjeta.id,
        compra: compra,
        tasaDefecto: _tarjeta.tasaInteresMensual ?? 0,
        onSave: _recargarTodo,
      ),
    );
  }
}

class _TarjetaVisual extends StatelessWidget {
  final dynamic tarjeta;
  const _TarjetaVisual({required this.tarjeta});

  @override
  Widget build(BuildContext context) {
    final tMap = tarjeta.toMap();
    final color = getTarjetaColor(tMap);
    final cupoTotal = tarjeta.cupoTotal;
    final cupoDispo = tarjeta.cupoDisponible;
    double cupoAvances = tarjeta.cupoAvancesDisponible ?? 0.0;
    if (cupoAvances > cupoDispo) cupoAvances = cupoDispo;
    final usoPct = ((cupoTotal - cupoDispo) / cupoTotal * 100).clamp(0.0, 100.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color, color.withAlpha(160)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tarjeta.banco, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Icon(Icons.credit_card_rounded, color: Colors.white70, size: 30),
            ],
          ),
          const SizedBox(height: 14),
          Text(tarjeta.nombreTarjeta, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cupo disponible', style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(formatCOP(cupoDispo), style: AppTheme.monoStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Cupo total', style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(formatCOP(cupoTotal), style: AppTheme.monoStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Text('Avances disponibles: ', style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usoPct / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withAlpha(40),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Corte dia ', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Pago dia ', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompraCard extends StatefulWidget {
  final Map<String, dynamic> compra;
  final int tarjetaId;
  final VoidCallback onPagoCuota;
  final Function(Map<String, dynamic>) onEdit;
  final bool initialExpand;
  const _CompraCard({required this.compra, required this.tarjetaId, required this.onPagoCuota, required this.onEdit, this.initialExpand = false});

  @override
  State<_CompraCard> createState() => _CompraCardState();
}

class _CompraCardState extends State<_CompraCard> {
  late bool _expandida;

  @override
  void initState() {
    super.initState();
    _expandida = widget.initialExpand;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compra;
    final cuotas = (c['cuotas'] as List<dynamic>?) ?? [];
    final cuotaAct = (c['cuota_actual'] as int?) ?? 1;
    final numCuotas = (c['num_cuotas'] as int?) ?? 1;
    final tasa = (c['tasa_interes_mensual'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandida = !_expandida),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['descripcion'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('· Cuota $cuotaAct/$numCuotas · Tasa ${tasa.toStringAsFixed(1)}% mensual', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCOP((c['monto_total'] as num).toDouble()), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Saldo: ${formatCOP((c['saldo_capital'] as num?)?.toDouble() ?? 0)}', style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                    onPressed: () => widget.onEdit(c),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expandida ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.white.withAlpha(15)),
                  const Text('Tabla de amortizacion', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...cuotas.map((cuota) => CuotaRow(
                    cuota: cuota,
                    onPagar: cuota['estado'] == 'PENDIENTE' ? () async {
                      await LocalRepository.instance.pagarCuota(widget.tarjetaId, c['id'] as int, cuota['id'] as int);
                      widget.onPagoCuota();
                    } : null,
                  )),
                ],
              ),
            ),
            crossFadeState: _expandida ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}
