import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/local_repository.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/dashboard_provider.dart';

import '../../providers/presupuesto_provider.dart';
import '../../widgets/common_widgets.dart';
import 'forms.dart';
import 'modal_anticipar_cuotas.dart';
import 'modal_adelantar_pago_tarjeta.dart';

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

  void _abrirModalAdelantarPago(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalAdelantarPagoTarjeta(
        tarjeta: _tarjeta,
        onCompletado: _recargarTodo,
      ),
    );
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
                _TarjetaVisual(
                  tarjeta: t,
                  onAdelantarPago: () => _abrirModalAdelantarPago(context),
                ),
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
                    nombreTarjeta: t.nombreTarjeta.isNotEmpty ? t.nombreTarjeta : t.banco,
                    tarjetaColor: color,
                    initialExpand: widget.initialCompraId != null && c['id'] == widget.initialCompraId,
                    onPagoCuota: _recargarTodo,
                    onEdit: (compraToEdit) => _showFormCompra(context, compra: compraToEdit),
                    onTapCuota: (cuota) {},
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
  final VoidCallback onAdelantarPago;
  const _TarjetaVisual({required this.tarjeta, required this.onAdelantarPago});

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
          Text('Avances disponibles: ${formatCOP(cupoAvances)}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Corte dia ${tarjeta.fechaCorte}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Pago dia ${tarjeta.fechaPago}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          // Botón de Adelantar Pago / Abono libre (Estilo Nu / RappiCard)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onAdelantarPago,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text(
                'Adelantar pago / Abonar a tarjeta',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompraCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  final int tarjetaId;
  final String nombreTarjeta;
  final Color tarjetaColor;
  final VoidCallback onPagoCuota;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onTapCuota;
  final bool initialExpand;

  const _CompraCard({
    required this.compra,
    required this.tarjetaId,
    required this.nombreTarjeta,
    required this.tarjetaColor,
    required this.onPagoCuota,
    required this.onEdit,
    required this.onTapCuota,
    this.initialExpand = false,
  });

  @override
  ConsumerState<_CompraCard> createState() => _CompraCardState();
}

class _CompraCardState extends ConsumerState<_CompraCard> {
  late bool _expandida;

  @override
  void initState() {
    super.initState();
    _expandida = widget.initialExpand;
  }

  void _abrirModalAnticipar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalAnticiparCuotas(
        compra: widget.compra,
        tarjetaId: widget.tarjetaId,
        nombreTarjeta: widget.nombreTarjeta,
        tarjetaColor: widget.tarjetaColor,
        onCompletado: widget.onPagoCuota,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compra;
    final cuotas = (c['cuotas'] as List<dynamic>?) ?? [];
    final cuotaAct = (c['cuota_actual'] as int?) ?? 1;
    final numCuotas = (c['num_cuotas'] as int?) ?? 1;
    final tasa = (c['tasa_interes_mensual'] as num?)?.toDouble() ?? 0;
    final saldo = (c['saldo_capital'] as num?)?.toDouble() ?? 0;

    final cuotasPendientes = cuotas.where((q) => (q['estado'] as String?)?.toUpperCase() == 'PENDIENTE').toList();
    final todasPagadas = cuotas.isNotEmpty && cuotasPendientes.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: todasPagadas ? AppTheme.colorIngresos.withAlpha(60) : AppTheme.borderLight,
        ),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c['descripcion'] as String? ?? '',
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (todasPagadas) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorIngresos.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 11, color: AppTheme.colorIngresos),
                                    SizedBox(width: 3),
                                    Text('PAGADA', style: TextStyle(color: AppTheme.colorIngresos, fontWeight: FontWeight.w800, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todasPagadas
                              ? 'Completada · $numCuotas cuotas pagadas'
                              : '· Cuota $cuotaAct/$numCuotas · Tasa ${tasa.toStringAsFixed(1)}% mensual',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCOP((c['monto_total'] as num).toDouble()),
                        style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        todasPagadas ? 'Saldada' : 'Saldo: ${formatCOP(saldo)}',
                        style: AppTheme.monoStyle(
                          color: todasPagadas ? AppTheme.colorIngresos : AppTheme.colorDeudas,
                          fontSize: 11,
                          fontWeight: todasPagadas ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
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

                  // Banner de accion para Anticipar Cuotas (estilo Nu/Rappi)
                  if (!todasPagadas && cuotasPendientes.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12, top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.colorIngresos.withAlpha(20),
                            AppTheme.primary.withAlpha(20),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.colorIngresos.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.colorIngresos.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on_rounded, color: AppTheme.colorIngresos, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Anticipar cuotas',
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  '${cuotasPendientes.length} cuotas pendientes · Ahorra intereses',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.colorIngresos,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _abrirModalAnticipar(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Anticipar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tabla de amortizacion', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (!todasPagadas && cuotasPendientes.length > 1)
                        InkWell(
                          onTap: () => _abrirModalAnticipar(context),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              'Adelantar varias',
                              style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...cuotas.map((cuota) {
                    final montoCuota = (cuota['valor_cuota'] as num?)?.toDouble() ?? 0.0;
                    return CuotaRow(
                      cuota: cuota,
                      onTapCuota: () => widget.onTapCuota(cuota),
                      onPagar: cuota['estado'] == 'PENDIENTE' ? () async {
                        await _promptPagoCuotaConSobre(
                          context,
                          ref,
                          widget.tarjetaId,
                          c['id'] as int,
                          cuota['id'] as int,
                          montoCuota,
                          widget.onPagoCuota,
                        );
                      } : null,
                    );
                  }),
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

Future<void> _promptPagoCuotaConSobre(
  BuildContext context,
  WidgetRef ref,
  int tarjetaId,
  int compraId,
  int cuotaId,
  double montoCuota,
  VoidCallback onPagoCuota,
) async {
  final mes = mesActual();
  final sobres = await SobresRepository.obtenerSobresDelMes(mes);
  int? sobreSeleccionadoId;

  if (sobres.isNotEmpty) {
    for (var s in sobres) {
      if (s.nombre.toLowerCase().contains('deuda') || s.nombre.toLowerCase().contains('tarjeta')) {
        sobreSeleccionadoId = s.id;
        break;
      }
    }
  }

  if (context.mounted) {
    if (sobres.isEmpty) {
      await LocalRepository.instance.pagarCuota(tarjetaId, compraId, cuotaId);

      onPagoCuota();
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Confirmar pago de cuota', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monto a pagar: ${formatCOP(montoCuota)}', style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              const Text('Descontar este pago de un sobre:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: sobreSeleccionadoId,
                dropdownColor: AppTheme.surfaceColor,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No descontar de ningún sobre')),
                  ...sobres.map((s) => DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text('${s.nombre} (Disp: ${formatCOP(s.disponible)})'),
                  )),
                ],
                onChanged: (v) => setDialogState(() => sobreSeleccionadoId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                await LocalRepository.instance.pagarCuota(tarjetaId, compraId, cuotaId);
                if (sobreSeleccionadoId != null) {
                  await SobresRepository.registrarGastoDirecto(
                    sobreSeleccionadoId!,
                    montoCuota,
                    'Pago Cuota Tarjeta',
                  );
                  ref.invalidate(presupuestoProvider(mes));
                }

                onPagoCuota();
              },
              child: const Text('PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
