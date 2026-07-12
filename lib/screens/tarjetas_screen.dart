import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import '../providers/app_providers.dart';
import '../widgets/common_widgets.dart';

class TarjetasScreen extends StatefulWidget {
  const TarjetasScreen({super.key});
  @override
  State<TarjetasScreen> createState() => _TarjetasScreenState();
}

class _TarjetasScreenState extends State<TarjetasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TarjetasProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: SafeArea(
        child: Consumer<TarjetasProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Header como en el diseño
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Tarjetas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                          SizedBox(height: 2),
                          Text('Gestión y cuotas', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _onNuevaCompra(context, provider),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Compra'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _showFormTarjeta(context),
                            icon: const Icon(Icons.add_card_rounded, color: AppTheme.textSecondary),
                            tooltip: 'Nueva tarjeta',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: provider.loading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : provider.tarjetas.isEmpty
                          ? _EmptyState(
                              icon: Icons.credit_card_off_rounded,
                              mensaje: 'No tienes tarjetas registradas',
                              accion: 'Agregar primera tarjeta',
                              onTap: () => _showFormTarjeta(context),
                            )
                          : RefreshIndicator(
                              color: AppTheme.primary,
                              onRefresh: provider.cargar,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCarousel(context, provider),
                                    _buildCuotasActivasSection(context, provider),
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, TarjetasProvider provider) {
    final tarjetas = provider.tarjetas;
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: tarjetas.length,
        itemBuilder: (ctx, i) {
          final t = tarjetas[i];
          return _TarjetaCarouselCard(
            tarjeta: t,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TarjetaDetalleScreen(tarjeta: t)),
            ).then((_) {
              provider.cargar();
              context.read<DashboardProvider>().cargar();
            }),
          );
        },
      ),
    );
  }

  Widget _buildCuotasActivasSection(BuildContext context, TarjetasProvider provider) {
    double totalMes = 0;
    for (var t in provider.tarjetas) {
      totalMes += (t['cuota_mes_actual'] as num?)?.toDouble() ?? 0;
    }
    if (totalMes == 0) {
      for (var c in provider.comprasActivas) {
        final cuotaVal = (c['valor_cuota'] as num?)?.toDouble() ?? (c['cuota_mensual'] as num?)?.toDouble() ?? 0;
        totalMes += cuotaVal;
      }
    }

    final compras = provider.comprasActivas;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cuotas Activas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Total: ${formatCOP(totalMes)}/mes', style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (compras.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Center(
                child: Text('No tienes cuotas activas este mes.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ),
            )
          else
            ...compras.map((c) => _CuotaActivaCard(
              compra: c,
              onTap: () {
                final tId = c['tarjeta_id'];
                final tarjeta = provider.tarjetas.firstWhere((t) => t['id'] == tId, orElse: () => null);
                if (tarjeta != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TarjetaDetalleScreen(tarjeta: tarjeta, initialCompraId: c['id'] as int?)),
                  ).then((_) {
                    provider.cargar();
                    context.read<DashboardProvider>().cargar();
                  });
                }
              },
            )),
        ],
      ),
    );
  }

  void _onNuevaCompra(BuildContext context, TarjetasProvider provider) {
    if (provider.tarjetas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes registrar al menos una tarjeta primero.'), backgroundColor: AppTheme.colorGastos),
      );
      return;
    }
    if (provider.tarjetas.length == 1) {
      _showFormCompra(context, tarjeta: provider.tarjetas.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona una tarjeta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            ...provider.tarjetas.map((t) {
              final color = getTarjetaColor(t);
              return ListTile(
                leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(Icons.credit_card_rounded, color: color)),
                title: Text(t['nombre_tarjeta']?.toString() ?? t['banco']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                subtitle: Text('Cupo dispo: ${formatCOP((t['cupo_disponible'] as num?)?.toDouble() ?? 0)}', style: const TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFormCompra(context, tarjeta: t);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showFormTarjeta(BuildContext context) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   AppTheme.bgCard,
      shape:             const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:           (_) => _FormTarjeta(onSave: () {
        context.read<TarjetasProvider>().cargar();
        context.read<DashboardProvider>().cargar();
      }),
    );
  }

  void _showFormCompra(BuildContext context, {required Map<String, dynamic> tarjeta, Map<String, dynamic>? compra}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormCompra(
        tarjetaId:    tarjeta['id'] as int,
        compra:       compra,
        tasaDefecto:  (tarjeta['tasa_interes_mensual'] as num?)?.toDouble() ?? 0,
        onSave: () {
          context.read<TarjetasProvider>().cargar();
          context.read<DashboardProvider>().cargar();
        },
      ),
    );
  }
}

class _TarjetaCarouselCard extends StatelessWidget {
  final Map<String, dynamic> tarjeta;
  final VoidCallback onTap;
  const _TarjetaCarouselCard({required this.tarjeta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = getTarjetaColor(tarjeta);
    final cupoDispo = (tarjeta['cupo_disponible'] as num?)?.toDouble() ?? 0;
    final nombre = tarjeta['nombre_tarjeta']?.toString() ?? tarjeta['banco']?.toString() ?? 'Tarjeta';
    final idStr = tarjeta['id']?.toString() ?? '4289';
    final mask = idStr.padLeft(4, '0');

    final width = MediaQuery.of(context).size.width - 60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color, color.withAlpha(210)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withAlpha(70), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(25),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    _buildCardLogo(nombre),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUPO DISPONIBLE',
                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCOP(cupoDispo),
                      style: AppTheme.monoStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '**** **** **** $mask',
                      style: AppTheme.monoStyle(color: Colors.white.withAlpha(200), fontSize: 13, letterSpacing: 2),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLogo(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('visa')) {
      return const Text('VISA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic));
    }
    return SizedBox(
      width: 36,
      height: 22,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(150))),
          ),
          Positioned(
            left: 14,
            child: Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(150))),
          ),
        ],
      ),
    );
  }
}

class _CuotaActivaCard extends StatelessWidget {
  final Map<String, dynamic> compra;
  final VoidCallback onTap;
  const _CuotaActivaCard({required this.compra, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final desc = compra['descripcion']?.toString() ?? 'Compra';
    final tarjetaNombre = compra['nombre_tarjeta']?.toString() ?? 'Tarjeta';
    final fecha = formatFecha(compra['fecha_compra']?.toString());
    
    final cuotaAct = (compra['cuota_actual'] as int?) ?? 1;
    final numCuotas = (compra['num_cuotas'] as int?) ?? 1;
    final pct = (cuotaAct / numCuotas * 100).clamp(0.0, 100.0);

    double cuotaVal = (compra['valor_cuota'] as num?)?.toDouble() ?? (compra['cuota_mensual'] as num?)?.toDouble() ?? 0;
    if (cuotaVal == 0 && numCuotas > 0) {
      final montoTotal = (compra['monto_total'] as num?)?.toDouble() ?? 0;
      cuotaVal = montoTotal / numCuotas;
    }

    final color = getTarjetaColor(compra);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(desc, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('$tarjetaNombre • Compra $fecha', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCOP(cuotaVal),
                      style: AppTheme.monoStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    const Text('/ mes', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cuota $cuotaAct de $numCuotas', style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text('${pct.round()}%', style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Detalle de tarjeta con compras y amortizacion ----
class TarjetaDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> tarjeta;
  final int? initialCompraId;
  const TarjetaDetalleScreen({super.key, required this.tarjeta, this.initialCompraId});

  @override
  State<TarjetaDetalleScreen> createState() => _TarjetaDetalleScreenState();
}

class _TarjetaDetalleScreenState extends State<TarjetaDetalleScreen> {
  late Map<String, dynamic> _tarjeta = Map.from(widget.tarjeta);
  List<dynamic> _compras = [];
  bool          _loading = true;

  @override
  void initState() {
    super.initState();
    _recargarTodo();
  }

  Future<void> _recargarTodo() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<TarjetasProvider>().getCompras(_tarjeta['id'] as int);
      if (!mounted) return;
      await context.read<TarjetasProvider>().cargar();
      if (!mounted) return;
      await context.read<DashboardProvider>().cargar();

      final lista = context.read<TarjetasProvider>().tarjetas;
      final index = lista.indexWhere((t) => t['id'] == _tarjeta['id']);
      if (index != -1 && mounted) {
        _tarjeta = Map.from(lista[index]);
      }

      // Filtrar compras para que si ya se pagaron todas las cuotas, desaparezcan de la vista
      final activas = data.where((c) {
        final cuotas = (c['cuotas'] as List?) ?? [];
        if (cuotas.isNotEmpty && cuotas.every((cuota) => cuota['estado'] == 'PAGADA')) {
          return false;
        }
        final saldo = (c['saldo_capital'] as num?)?.toDouble() ?? 0;
        return saldo > 1; // Si saldo <= 1, desaparece
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
    final color = getTarjetaColor(t);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Text('${t['banco']} — ${t['nombre_tarjeta']}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
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
                builder: (_) => _FormTarjeta(
                  tarjeta: t,
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
                // Header tarjeta
                _TarjetaVisual(tarjeta: t),
                const SizedBox(height: 20),

                // Compras con amortizacion
                if (_compras.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Sin compras registradas',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ..._compras.map((c) => _CompraCard(
                    compra: c,
                    tarjetaId: t['id'] as int,
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
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.bgCard,
      shape:              const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder:            (_) => _FormCompra(
        tarjetaId:    _tarjeta['id'] as int,
        compra:       compra,
        tasaDefecto:  (_tarjeta['tasa_interes_mensual'] as num?)?.toDouble() ?? 0,
        onSave:       _recargarTodo,
      ),
    );
  }
}

// ---- Widget visual de tarjeta de credito ----
class _TarjetaVisual extends StatelessWidget {
  final Map<String, dynamic> tarjeta;
  const _TarjetaVisual({required this.tarjeta});

  @override
  Widget build(BuildContext context) {
    final color    = getTarjetaColor(tarjeta);
    final cupoTotal = (tarjeta['cupo_total'] as num).toDouble();
    final cupoDispo = (tarjeta['cupo_disponible'] as num).toDouble();
    double cupoAvances = (tarjeta['cupo_avances_disponible'] as num?)?.toDouble() ?? 0.0;
    if (cupoAvances > cupoDispo) cupoAvances = cupoDispo;
    final usoPct    = ((cupoTotal - cupoDispo) / cupoTotal * 100).clamp(0.0, 100.0);

    return Container(
      width:   double.infinity,
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
              Text(tarjeta['banco'] as String? ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Icon(Icons.credit_card_rounded, color: Colors.white70, size: 30),
            ],
          ),
          const SizedBox(height: 14),
          Text(tarjeta['nombre_tarjeta'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cupo disponible', style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(formatCOP(cupoDispo),
                    style: AppTheme.monoStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Cupo total', style: TextStyle(color: Colors.white60, fontSize: 11)),
                Text(formatCOP(cupoTotal),
                    style: AppTheme.monoStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Text('Avances disponibles: ${formatCOP(cupoAvances)}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           usoPct / 100,
              minHeight:       6,
              backgroundColor: Colors.white.withAlpha(40),
              valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Corte dia ${tarjeta['fecha_corte']}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Pago dia ${tarjeta['fecha_pago']}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Card de compra con tabla de amortizacion colapsable ----
class _CompraCard extends StatefulWidget {
  final Map<String, dynamic> compra;
  final int                  tarjetaId;
  final VoidCallback         onPagoCuota;
  final Function(Map<String, dynamic>) onEdit;
  final bool                 initialExpand;
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
    final c         = widget.compra;
    final cuotas    = (c['cuotas'] as List<dynamic>?) ?? [];
    final cuotaAct  = (c['cuota_actual'] as int?) ?? 1;
    final numCuotas = (c['num_cuotas'] as int?) ?? 1;
    final tasa      = (c['tasa_interes_mensual'] as num?)?.toDouble() ?? 0;

    return Container(
      margin:     const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:        AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Encabezado de la compra
          InkWell(
            onTap:        () => setState(() => _expandida = !_expandida),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['descripcion'] as String? ?? '',
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${formatFecha(c['fecha_compra']?.toString())} · Cuota $cuotaAct/$numCuotas · Tasa ${formatPct(tasa * 100)} mensual',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCOP((c['monto_total'] as num).toDouble()),
                          style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Saldo: ${formatCOP((c['saldo_capital'] as num).toDouble())}',
                          style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 11)),
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
                    turns:    _expandida ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child:    const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Tabla de amortizacion expandible
          AnimatedCrossFade(
            duration:       const Duration(milliseconds: 250),
            firstChild:     const SizedBox.shrink(),
            secondChild:    Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Colors.white.withAlpha(15)),
                  const Text('Tabla de amortizacion',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...cuotas.map((cuota) => CuotaRow(
                    cuota:    cuota,
                    onPagar:  cuota['estado'] == 'PENDIENTE' ? () async {
                      await LocalRepository.instance.pagarCuota(
                        widget.tarjetaId,
                        c['id'] as int,
                        cuota['id'] as int,
                      );
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

// ---- Formulario nueva/editar tarjeta ----
class _FormTarjeta extends StatefulWidget {
  final Map<String, dynamic>? tarjeta;
  final VoidCallback onSave;
  const _FormTarjeta({this.tarjeta, required this.onSave});

  @override
  State<_FormTarjeta> createState() => _FormTarjetaState();
}

class _FormTarjetaState extends State<_FormTarjeta> {
  final _form   = GlobalKey<FormState>();
  final _banco  = TextEditingController();
  final _nombre = TextEditingController();
  final _cupo   = TextEditingController();
  final _corte  = TextEditingController();
  final _pago   = TextEditingController();
  final _tasa   = TextEditingController();
  final _pctAvances = TextEditingController(text: '100');
  final _cuotaManejo = TextEditingController(text: '0');
  bool  _saving = false;

  @override
  void initState() {
    super.initState();
    _banco.addListener(_onBancoChanged);
    if (widget.tarjeta != null) {
      final t = widget.tarjeta!;
      _banco.text  = t['banco']?.toString() ?? '';
      _nombre.text = t['nombre_tarjeta']?.toString() ?? '';
      _cupo.text   = t['cupo_total']?.toString() ?? '';
      _corte.text  = t['fecha_corte']?.toString() ?? '';
      _pago.text   = t['fecha_pago']?.toString() ?? '';
      _tasa.text   = t['tasa_interes_mensual']?.toString() ?? '';
      _pctAvances.text = t['cupo_avances_total']?.toString() ?? '0';
      _cuotaManejo.text = t['cuota_manejo']?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    _banco.removeListener(_onBancoChanged);
    super.dispose();
  }

  void _onBancoChanged() {
    _autoFillTasa();
  }

  void _autoFillTasa() {
    final b = _banco.text.toLowerCase();
    if (_tasa.text == '0' || _tasa.text.isEmpty) {
      if (b.contains('nu') || b.contains('nubank')) {
        _tasa.text = '2.11';
      } else if (b.contains('rappi') || b.contains('rappicard')) {
        _tasa.text = '2.07'; // ~28.17% E.A.
      }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text(widget.tarjeta == null ? 'Nueva tarjeta de credito' : 'Editar tarjeta',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              _Field(ctrl: _banco,  label: 'Banco',        hint: 'Ej: Bancolombia'),
              _Field(ctrl: _nombre, label: 'Nombre',       hint: 'Ej: Visa Oro'),
              _Field(ctrl: _cupo,   label: 'Cupo total',   hint: '5000000', keyboardType: TextInputType.number),
              Row(children: [
                Expanded(child: _Field(ctrl: _corte, label: 'Dia de corte',  hint: '15', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _pago,  label: 'Dia de pago (opcional)', hint: 'Calculado auto.', keyboardType: TextInputType.number, isRequired: false)),
              ]),
              _Field(ctrl: _tasa, label: 'Tasa mensual por defecto (%)', hint: '1.8', keyboardType: TextInputType.number),
              Row(children: [
                Expanded(child: _Field(ctrl: _pctAvances, label: 'Cupo Avances (\$)', hint: '2460736', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _cuotaManejo, label: 'Cuota de manejo (\$)', hint: '0', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Guardar tarjeta'),
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
      int corte = int.parse(_corte.text);
      int pago = 0;
      if (_pago.text.isNotEmpty) {
        pago = int.parse(_pago.text);
      } else {
        pago = corte + 15;
        if (pago > 30) pago -= 30; // Aproximacion a mes comercial de 30 dias
      }

      final data = {
        'banco':                _banco.text.trim(),
        'nombre_tarjeta':       _nombre.text.trim(),
        'color':                getTarjetaColorHex({'banco': _banco.text.trim(), 'nombre_tarjeta': _nombre.text.trim()}),
        'cupo_total':           double.parse(_cupo.text),
        'fecha_corte':          corte,
        'fecha_pago':           pago,
        'tasa_interes_mensual': double.parse(_tasa.text.isEmpty ? '0' : _tasa.text),
        'cupo_avances_total':   double.parse(_pctAvances.text.isEmpty ? '0' : _pctAvances.text),
        'cuota_manejo':         double.parse(_cuotaManejo.text.isEmpty ? '0' : _cuotaManejo.text),
      };

      if (widget.tarjeta != null) {
        await LocalRepository.instance.updateTarjeta(widget.tarjeta!['id'] as int, data);
      } else {
        await LocalRepository.instance.createTarjeta(data);
      }
      
      if (mounted) { Navigator.pop(context); widget.onSave(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---- Formulario nueva compra ----
class _FormCompra extends StatefulWidget {
  final int      tarjetaId;
  final double   tasaDefecto;
  final Map<String, dynamic>? compra;
  final VoidCallback onSave;
  const _FormCompra({required this.tarjetaId, required this.tasaDefecto, this.compra, required this.onSave});

  @override
  State<_FormCompra> createState() => _FormCompraState();
}

class _FormCompraState extends State<_FormCompra> {
  final _form       = GlobalKey<FormState>();
  final _desc       = TextEditingController();
  final _comercio   = TextEditingController();
  final _monto      = TextEditingController();
  final _cuotas     = TextEditingController(text: '1');
  final _tasa       = TextEditingController();
  final _fecha      = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
  String _tipoTasa  = 'MENSUAL';
  bool   _esAvance  = false;
  bool   _saving    = false;

  @override
  void initState() {
    super.initState();
    if (widget.compra != null) {
      final c = widget.compra!;
      _desc.text = (c['descripcion']?.toString() ?? '').replaceAll(RegExp(r'^\(Avance\)\s*'), '');
      _comercio.text = c['comercio']?.toString() ?? '';
      _monto.text = c['monto_total']?.toString() ?? '';
      _cuotas.text = c['num_cuotas']?.toString() ?? '1';
      _tasa.text = c['tipo_tasa_ingresada'] == 'EA' 
          ? ((c['tasa_interes_mensual'] as num? ?? 0) * 100).toStringAsFixed(2) // Approximate for now, but usually we just want to show the original if possible, we'll just show the saved value
          : ((c['tasa_interes_mensual'] as num? ?? 0) * 100).toStringAsFixed(2);
      _fecha.text = c['fecha_compra']?.toString() ?? '';
      _tipoTasa = c['tipo_tasa_ingresada']?.toString() ?? 'MENSUAL';
      _esAvance = (c['es_avance'] as int? ?? 0) == 1;
    } else {
      _tasa.text = (widget.tasaDefecto * 100).toStringAsFixed(2);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              const Text('Registrar compra',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Es un avance de efectivo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                value: _esAvance,
                onChanged: (val) => setState(() => _esAvance = val),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              _Field(ctrl: _desc,    label: _esAvance ? 'Motivo del avance' : 'Descripcion',    hint: _esAvance ? 'Ej: Efectivo para viaje' : 'Ej: Televisor Samsung'),
              if (!_esAvance) _Field(ctrl: _comercio,label: 'Comercio',        hint: 'Ej: Exito (opcional)'),
              _Field(ctrl: _monto,   label: 'Monto total',    hint: '1500000', keyboardType: TextInputType.number),
              _Field(ctrl: _cuotas,  label: 'Numero de cuotas', hint: '12', keyboardType: TextInputType.number),

              // Tasa con selector de tipo
              Row(children: [
                Expanded(child: _Field(ctrl: _tasa, label: 'Tasa de interes (%)', hint: '1.8', keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value:       _tipoTasa,
                    decoration:  const InputDecoration(labelText: 'Tipo de tasa'),
                    dropdownColor: AppTheme.surfaceColor,
                    style:       const TextStyle(color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'MENSUAL', child: Text('Mensual')),
                      DropdownMenuItem(value: 'EA',      child: Text('E.A. Anual')),
                    ],
                    onChanged: (v) => setState(() => _tipoTasa = v!),
                  ),
                ),
              ]),
              _Field(ctrl: _fecha, label: 'Fecha de compra', hint: 'YYYY-MM-DD'),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'El sistema calculara automaticamente la tabla de amortizacion con el sistema de cuota fija (Frances) y la proyectara mes a mes.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : const Text('Generar amortizacion y guardar'),
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
      final descFinal = _esAvance ? '(Avance) ${_desc.text.trim()}' : _desc.text.trim();
      final comercioFinal = _esAvance ? 'Avance en efectivo' : _comercio.text.trim();

      final reqData = {
        'descripcion':    descFinal,
        'comercio':       comercioFinal,
        'monto_total':    double.parse(_monto.text),
        'num_cuotas':     int.parse(_cuotas.text),
        'tasa_ingresada': double.parse(_tasa.text.isEmpty ? '0' : _tasa.text),
        'tipo_tasa':      _tipoTasa,
        'fecha_compra':   _fecha.text,
        'es_avance':      _esAvance,
      };

      final result = widget.compra == null
          ? await LocalRepository.instance.createCompra(widget.tarjetaId, reqData)
          : await LocalRepository.instance.updateCompra(widget.tarjetaId, widget.compra!['id'] as int, reqData);

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        final cuotaFija = result['data']?['cuota_fija'];
        if (cuotaFija != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Amortizacion generada. Cuota mensual: ${formatCOP(cuotaFija.toDouble())}'),
              backgroundColor: AppTheme.colorAlDia,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.colorGastos));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ---- Widget campo de texto reutilizable ----
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final String                hint;
  final TextInputType         keyboardType;
  final bool                  isRequired;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller:  ctrl,
      keyboardType: keyboardType,
      style:       const TextStyle(color: AppTheme.textPrimary),
      decoration:  InputDecoration(labelText: label, hintText: hint),
      validator:   (v) => isRequired && (v == null || v.trim().isEmpty) ? 'Requerido' : null,
    ),
  );
}

// _TarjetaCard reemplazada por _TarjetaCarouselCard y _CuotaActivaCard

class _EmptyState extends StatelessWidget {
  final IconData     icon;
  final String       mensaje;
  final String       accion;
  final VoidCallback onTap;
  const _EmptyState({required this.icon, required this.mensaje, required this.accion, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 60),
        const SizedBox(height: 16),
        Text(mensaje, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onTap, child: Text(accion)),
      ],
    ),
  );
}
