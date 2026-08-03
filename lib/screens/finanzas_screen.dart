import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/tarjetas_provider.dart';
import '../providers/ahorros_provider.dart';
import '../providers/cuentas_cobrar_provider.dart';
import '../models/tarjeta_credito.dart';
import '../models/bolsillo_ahorro.dart';
import '../models/cuenta_cobrar.dart';
import 'tarjetas/tarjeta_detalle_screen.dart';
import 'tarjetas/tarjetas_screen.dart';
import 'ahorros_screen.dart';
import 'cuentas_cobrar_screen.dart';

/// Pantalla unificada: Tarjetas + Ahorros + Cuentas por Cobrar
class FinanzasScreen extends ConsumerStatefulWidget {
  const FinanzasScreen({super.key});

  @override
  ConsumerState<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends ConsumerState<FinanzasScreen> {
  int _cardIndex = 0;
  bool _verPagadas = false;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarjetasAsync       = ref.watch(tarjetasProvider);
    final comprasActivasAsync = ref.watch(comprasActivasProvider);
    final todasLasComprasAsync = ref.watch(todasLasComprasProvider);
    final ahorrosAsync        = ref.watch(ahorrosProvider);
    final cuentasAsync        = ref.watch(cuentasCobrarProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(tarjetasProvider);
          ref.invalidate(comprasActivasProvider);
          ref.invalidate(todasLasComprasProvider);
          ref.invalidate(ahorrosProvider);
          ref.invalidate(cuentasCobrarProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FinanzasHeader(),
            ),

            // ── Tarjetas de Crédito Header ──────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Mis Tarjetas',
                actionLabel: 'Gestionar',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TarjetasScreen()),
                ).then((_) {
                  ref.invalidate(tarjetasProvider);
                  ref.invalidate(comprasActivasProvider);
                  ref.invalidate(todasLasComprasProvider);
                }),
              ),
            ),

            // ── Carousel tarjetas ───────────────────────────────
            SliverToBoxAdapter(
              child: tarjetasAsync.when(
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (tarjetas) => tarjetas.isEmpty
                    ? _EmptyTarjetas()
                    : _TarjetasCarrusel(
                        tarjetas: tarjetas,
                        currentIndex: _cardIndex,
                        pageController: _pageController,
                        onPageChanged: (i) => setState(() => _cardIndex = i),
                        onTap: (t) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TarjetaDetalleScreen(tarjeta: t),
                          ),
                        ).then((_) {
                          ref.invalidate(tarjetasProvider);
                          ref.invalidate(comprasActivasProvider);
                          ref.invalidate(todasLasComprasProvider);
                        }),
                      ),
              ),
            ),

            // ── Cuotas activas resumen ──────────────────────────
            SliverToBoxAdapter(
              child: comprasActivasAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (compras) {
                  if (compras.isEmpty) return const SizedBox.shrink();
                  final totalCuotas = compras.fold<double>(
                    0,
                    (s, c) => s + ((c['valor_cuota'] as num?)?.toDouble() ?? 0),
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _CuotasResumenCard(
                      totalCuotas: totalCuotas,
                      count: compras.length,
                    ),
                  );
                },
              ),
            ),

            // ── Compras en cuotas ───────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Compras en cuotas',
                actionLabel: '+ Registrar',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TarjetasScreen()),
                ).then((_) {
                  ref.invalidate(comprasActivasProvider);
                  ref.invalidate(todasLasComprasProvider);
                }),
              ),
            ),
            SliverToBoxAdapter(
              child: _SubTabBar(
                selected: _verPagadas ? 1 : 0,
                onSelect: (i) => setState(() => _verPagadas = i == 1),
              ),
            ),
            SliverToBoxAdapter(
              child: todasLasComprasAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (compras) {
                  final filtradas = compras.where((c) => (c['pagada'] == true) == _verPagadas).toList();
                  if (filtradas.isEmpty) {
                    return _EmptySection(
                      icon: Icons.credit_card_rounded,
                      message: _verPagadas ? 'Sin compras pagadas' : 'Sin compras en cuotas activas',
                    );
                  }
                  return _ComprasList(
                    compras: filtradas,
                    onRefresh: () {
                      ref.invalidate(tarjetasProvider);
                      ref.invalidate(comprasActivasProvider);
                      ref.invalidate(todasLasComprasProvider);
                    },
                  );
                },
              ),
            ),

            // ── Metas de ahorro ─────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Metas de Ahorro',
                actionLabel: 'Ver todas',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AhorrosScreen()),
                ).then((_) => ref.invalidate(ahorrosProvider)),
              ),
            ),
            SliverToBoxAdapter(
              child: ahorrosAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (ahorros) => ahorros.isEmpty
                    ? const _EmptySection(
                        icon: Icons.savings_rounded,
                        message: 'Sin metas de ahorro. Crea una desde "+"',
                      )
                    : _MetasList(ahorros: ahorros),
              ),
            ),

            // ── Cuentas por cobrar ──────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Cuentas por Cobrar',
                actionLabel: 'Ver todas',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CuentasCobrarScreen()),
                ).then((_) => ref.invalidate(cuentasCobrarProvider)),
              ),
            ),
            SliverToBoxAdapter(
              child: cuentasAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (cuentas) {
                  final activas = cuentas.where((c) => c.estado != 'CANCELADO').toList();
                  if (activas.isEmpty) {
                    return const _EmptySection(
                      icon: Icons.people_rounded,
                      message: 'Sin deudores activos',
                    );
                  }
                  final total = activas.fold<double>(
                    0,
                    (s, c) => s + c.saldoPendiente,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CuentasCobrarScreen()),
                      ).then((_) => ref.invalidate(cuentasCobrarProvider)),
                      child: _CuentasCobrarCard(total: total, count: activas.length),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _FinanzasHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: const Text(
        'Finanzas',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ── Tarjetas Carousel ─────────────────────────────────────────────────────

class _TarjetasCarrusel extends StatelessWidget {
  final List<TarjetaCredito> tarjetas;
  final int currentIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<TarjetaCredito> onTap;

  const _TarjetasCarrusel({
    required this.tarjetas,
    required this.currentIndex,
    required this.pageController,
    required this.onPageChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: tarjetas.length,
            padEnds: false,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TarjetaCard(
                tarjeta: tarjetas[i],
                onTap: () => onTap(tarjetas[i]),
              ),
            ),
          ),
        ),
        // Dots
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(tarjetas.length, (i) {
              final active = i == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TarjetaCard extends StatelessWidget {
  final TarjetaCredito tarjeta;
  final VoidCallback onTap;

  const _TarjetaCard({required this.tarjeta, required this.onTap});

  LinearGradient _gradient() {
    final hex = tarjeta.color.replaceAll('#', '');
    try {
      final base = Color(int.parse('FF$hex', radix: 16));
      final dark = Color.fromARGB(
        255,
        (base.red * 0.6).round(),
        (base.green * 0.6).round(),
        (base.blue * 0.6).round(),
      );
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [dark, base],
      );
    } catch (_) {
      return AppTheme.cardNuGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final deuda = tarjeta.cupoTotal - tarjeta.cupoDisponible;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: _gradient(),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            // Decorative background blob
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tarjeta.nombreTarjeta.isNotEmpty ? tarjeta.nombreTarjeta : tarjeta.banco,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Icon(Icons.credit_card_rounded, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '•••• ${tarjeta.banco.length >= 4 ? tarjeta.banco.substring(0, 4).toUpperCase() : tarjeta.banco}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disponible', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(
                      formatCOP(tarjeta.cupoDisponible),
                      style: AppTheme.monoStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Deuda', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(
                      formatCOP(deuda),
                      style: AppTheme.monoStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
}

class _EmptyTarjetas extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const _EmptySection(
    icon: Icons.credit_card_off_rounded,
    message: 'Sin tarjetas registradas. Agrégalas desde "+"',
  );
}

// ── Cuotas resumen ────────────────────────────────────────────────────────

class _CuotasResumenCard extends StatelessWidget {
  final double totalCuotas;
  final int count;
  const _CuotasResumenCard({required this.totalCuotas, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cuotas Activas', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                FittedBox(
                  child: Text(
                    '${formatCOP(totalCuotas)} / mes',
                    style: AppTheme.monoStyle(
                      color: AppTheme.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$count compra${count != 1 ? 's' : ''} activa${count != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SubTabBar ────────────────────────────────────────────────────────────

class _SubTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  static const _labels = ['Activas', 'Pagadas'];

  const _SubTabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: active ? AppTheme.primary : AppTheme.borderLight,
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Compras list ──────────────────────────────────────────────────────────

class _ComprasList extends StatelessWidget {
  final List<Map<String, dynamic>> compras;
  final VoidCallback? onRefresh;
  const _ComprasList({required this.compras, this.onRefresh});

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppTheme.primary;
    final hex = hexString.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: compras.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
      itemBuilder: (_, i) {
        final c = compras[i];
        final cuotaActual = (c['cuota_actual'] as num?)?.toInt() ?? 1;
        final numCuotas = (c['num_cuotas'] as num?)?.toInt() ?? 1;
        final pct = (cuotaActual / numCuotas).clamp(0.0, 1.0);
        final valorCuota = (c['valor_cuota'] as num?)?.toDouble() ?? 0.0;
        final tarjetaNombre = c['nombre_tarjeta']?.toString() ?? '';
        final color = _parseColor(c['tarjeta_color']?.toString());
        final tasaMensual = (c['tasa_interes_mensual'] as num?)?.toDouble() ?? 0.0;
        final tasaStr = (tasaMensual * 100).toStringAsFixed(0);

        return GestureDetector(
          onTap: () {
            if (c['tarjeta_obj'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TarjetaDetalleScreen(
                    tarjeta: c['tarjeta_obj'],
                    initialCompraId: c['id'],
                  ),
                ),
              ).then((_) {
                if (onRefresh != null) onRefresh!();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.credit_card_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['descripcion']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tarjetaNombre · $numCuotas cuotas · $tasaStr% interés · Cuota $cuotaActual',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${formatCOP(valorCuota).replaceAll('\$', '').trim()}',
                      style: AppTheme.monoStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 50,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppTheme.borderSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Metas list ────────────────────────────────────────────────────────────

class _MetasList extends StatelessWidget {
  final List<BolsilloAhorro> ahorros;
  const _MetasList({required this.ahorros});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: ahorros.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = ahorros[i];
        final pct = a.metaMonto > 0
            ? (a.montoActual / a.metaMonto).clamp(0.0, 1.0)
            : 0.0;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AhorrosScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.warn.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.savings_rounded, color: AppTheme.warn, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: AppTheme.borderSoft,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warn),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatCOP(a.montoActual)} / ${formatCOP(a.metaMonto)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Cuentas por cobrar card ────────────────────────────────────────────────

class _CuentasCobrarCard extends StatelessWidget {
  final double total;
  final int count;
  const _CuentasCobrarCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(25),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.people_rounded, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Pendiente', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                FittedBox(
                  child: Text(
                    formatCOP(total),
                    style: AppTheme.monoStyle(
                      color: AppTheme.success,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$count deudor${count != 1 ? 'es' : ''} activo${count != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty Section ─────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCardWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
