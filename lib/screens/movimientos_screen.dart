import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/ingresos_provider.dart';
import '../providers/gastos_provider.dart';
import '../providers/presupuesto_provider.dart';
import '../models/ingreso.dart';
import '../models/gasto_fijo.dart';
import '../providers/dashboard_provider.dart';
import 'presupuesto_base_cero_screen.dart';
import 'ingresos_screen.dart';
import 'gastos_screen.dart';
import 'historial_movimientos_screen.dart';

/// Pantalla unificada: Ingresos + Gastos + Presupuesto base cero
class MovimientosScreen extends ConsumerStatefulWidget {
  const MovimientosScreen({super.key});

  @override
  ConsumerState<MovimientosScreen> createState() => _MovimientosScreenState();
}

typedef _Periodo = ({String label, String? mes});

class _MovimientosScreenState extends ConsumerState<MovimientosScreen> {
  int _periodoIndex = 1; // 0=Semana, 1=Mes, 2=Año
  int _filtroTipo = 0; // 0=Todos, 1=Ingresos, 2=Gastos

  static final List<_Periodo> _periodos = [
    (label: 'Semana', mes: 'week:${_fechaHoy()}'),
    (label: 'Mes',    mes: _mesActual()),
    (label: 'Año',    mes: 'year:${_yearActual()}'),
  ];

  static String _fechaHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yearActual() {
    return DateTime.now().year.toString();
  }

  static String _mesActual() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mes = _periodos[_periodoIndex].mes;
    final ingresosAsync = ref.watch(ingresosProvider(mes));
    final gastosAsync   = ref.watch(gastosProvider(mes));
    final sobresAsync   = ref.watch(presupuestoProvider(_mesActual()));

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _MovHeader(
              onFilter: () => _mostrarFiltros(context),
            ),
          ),

          // ── Selector de periodo ───────────────────────────────
          SliverToBoxAdapter(
            child: _PeriodSelector(
              selected: _periodoIndex,
              onSelect: (i) => setState(() => _periodoIndex = i),
            ),
          ),

          // ── Resumen ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ResumenCard(
              ingresosAsync: ingresosAsync,
              gastosAsync: gastosAsync,
            ),
          ),

          // ── Sobres de presupuesto ─────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Presupuesto Base Cero',
              actionLabel: '+ Sobre',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PresupuestoBaseCeroScreen()),
              ).then((_) => ref.invalidate(presupuestoProvider(_mesActual()))),
            ),
          ),
          SliverToBoxAdapter(
            child: sobresAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (state) => _SobresCarrusel(
                sobres: state.sobres,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PresupuestoBaseCeroScreen()),
                ).then((_) => ref.invalidate(presupuestoProvider(_mesActual()))),
              ),
            ),
          ),

          // ── Ultimos movimientos ───────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Últimos movimientos',
              actionLabel: 'Ver todo',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialMovimientosScreen()),
              ),
            ),
          ),

          // Combina ingresos y gastos en una lista ordenada por fecha
          ingresosAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (ingresos) => gastosAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (gastos) {
                final items = _buildMovimientos(ingresos, gastos);
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(periodo: _periodos[_periodoIndex].label),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final item = items[i];
                      if (item is _DateHeader) {
                        return _TxDateHeader(label: item.label);
                      } else if (item is _TxItem) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TransactionRow(tx: item),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _mostrarFiltros(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCanvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Todos', style: TextStyle(color: AppTheme.textPrimary)),
                trailing: _filtroTipo == 0 ? const Icon(Icons.check, color: AppTheme.primary) : null,
                onTap: () {
                  setState(() => _filtroTipo = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Solo Ingresos', style: TextStyle(color: AppTheme.textPrimary)),
                trailing: _filtroTipo == 1 ? const Icon(Icons.check, color: AppTheme.primary) : null,
                onTap: () {
                  setState(() => _filtroTipo = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Solo Gastos', style: TextStyle(color: AppTheme.textPrimary)),
                trailing: _filtroTipo == 2 ? const Icon(Icons.check, color: AppTheme.primary) : null,
                onTap: () {
                  setState(() => _filtroTipo = 2);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Combina y ordena ingresos + gastos por fecha, agrupa por dia, filtra por periodo
  List<Object> _buildMovimientos(List<Ingreso> ingresos, List<GastoFijo> gastos) {
    // Unificar en una lista tipada
    final all = <_TxItem>[
      ...ingresos.map((i) => _TxItem(
        id: 'i${i.id}',
        nombre: i.descripcion ?? i.categoriaNombre ?? 'Ingreso',
        categoria: i.categoriaNombre ?? 'Ingreso',
        monto: i.monto,
        fecha: i.fecha,
        isIngreso: true,
        color: i.categoriaColor,
        ingreso: i,
      )),
      ...gastos.map((g) => _TxItem(
        id: 'g${g.id}',
        nombre: g.nombre,
        categoria: g.categoriaNombre ?? 'Gasto',
        monto: g.monto,
        fecha: g.fechaUltimoPago ?? g.mesReferencia,
        isIngreso: false,
        color: g.categoriaColor,
        gasto: g,
      )),
    ];

    if (all.isEmpty) return [];

    // Filtrar en memoria para vistas específicas de Semana y Año
    if (_periodoIndex == 0) { // Semana
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

      all.removeWhere((item) {
        try {
          final dt = DateTime.parse(item.fecha);
          return dt.isBefore(start) || dt.isAfter(end);
        } catch (_) {
          return true; // Excluir si la fecha no tiene formato válido de día en vista semanal (ej. '2026-08' sin pagar)
        }
      });
    } else if (_periodoIndex == 2) { // Año
      final currentYear = DateTime.now().year;
      all.removeWhere((item) {
        try {
          final dt = DateTime.parse(item.fecha);
          return dt.year != currentYear;
        } catch (_) {
          return !item.fecha.startsWith('$currentYear');
        }
      });
    }

    if (_filtroTipo == 1) { // Ingresos
      all.removeWhere((item) => !item.isIngreso);
    } else if (_filtroTipo == 2) { // Gastos
      all.removeWhere((item) => item.isIngreso);
    }

    // Ordenar por fecha DESC
    all.sort((a, b) => b.fecha.compareTo(a.fecha));

    // Agrupar por dia
    final result = <Object>[];
    String? lastDate;
    for (final item in all) {
      final dayKey = item.fecha.length >= 10 ? item.fecha.substring(0, 10) : item.fecha;
      if (dayKey != lastDate) {
        lastDate = dayKey;
        result.add(_DateHeader(label: _formatDayLabel(dayKey)));
      }
      result.add(item);
    }
    return result;
  }

  String _formatDayLabel(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day == today) return 'Hoy';
      if (day == yesterday) return 'Ayer';
      return formatFecha(isoDate);
    } catch (_) {
      return isoDate;
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _MovHeader extends StatelessWidget {
  final VoidCallback onFilter;
  const _MovHeader({required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Movimientos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onFilter,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Selector ───────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  static const _labels = ['Semana', 'Mes', 'Año'];

  const _PeriodSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == selected;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: active ? AppTheme.primary : AppTheme.borderLight,
                    ),
                  ),
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppTheme.textMuted,
                    ),
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

// ── Resumen Card ─────────────────────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  final AsyncValue<List<Ingreso>> ingresosAsync;
  final AsyncValue<List<GastoFijo>> gastosAsync;

  const _ResumenCard({
    required this.ingresosAsync,
    required this.gastosAsync,
  });

  @override
  Widget build(BuildContext context) {
    final ingresos = ingresosAsync.value ?? [];
    final gastos   = gastosAsync.value ?? [];
    final totalInc = ingresos.fold<double>(0, (s, i) => s + i.monto);
    final totalExp = gastos.fold<double>(0, (s, g) => s + g.monto);
    final balance  = totalInc - totalExp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            _ResumenItem(label: 'Ingresos', value: totalInc, color: AppTheme.success),
            _Divider(),
            _ResumenItem(label: 'Gastos', value: totalExp, color: AppTheme.danger),
            _Divider(),
            _ResumenItem(label: 'Balance', value: balance, color: AppTheme.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _ResumenItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ResumenItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatCOP(value),
              style: AppTheme.monoStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 40,
    color: AppTheme.borderSoft,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

// ── Sobres Carrusel ───────────────────────────────────────────────────────

class _SobresCarrusel extends StatelessWidget {
  final List<Sobre> sobres;
  final VoidCallback? onTap;
  const _SobresCarrusel({required this.sobres, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (sobres.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCardWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: const Text(
            'Sin sobres configurados. Toca "+ Sobre" para crear uno.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sobres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: onTap,
          child: _SobreCard(sobre: sobres[i]),
        ),
      ),
    );
  }
}

class _SobreCard extends StatelessWidget {
  final Sobre sobre;
  const _SobreCard({required this.sobre});

  Color _parseColor() {
    try {
      final hex = sobre.color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    final pct = sobre.porcentajeUsado;
    final isOverBudget = pct >= 1.0;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget ? AppTheme.danger.withAlpha(100) : AppTheme.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            sobre.nombre,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: AppTheme.borderSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverBudget ? AppTheme.danger : color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCOP(sobre.disponible),
            style: AppTheme.monoStyle(
              color: isOverBudget ? AppTheme.danger : color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isOverBudget ? 'excedido' : 'de ${formatCOP(sobre.montoAsignado)}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
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

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

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

// ── Transaction list items ────────────────────────────────────────────────

class _TxDateHeader extends StatelessWidget {
  final String label;
  const _TxDateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  final _TxItem tx;
  const _TransactionRow({required this.tx});

  Color _parseCat() {
    if (tx.color == null) return tx.isIngreso ? AppTheme.success : AppTheme.danger;
    try {
      final hex = tx.color!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return tx.isIngreso ? AppTheme.success : AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseCat();
    final bgColor = color.withAlpha(25);

    return InkWell(
      onTap: () {
        if (tx.isIngreso && tx.ingreso != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.bgCard,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => FormIngreso(
              ingreso: tx.ingreso,
              onSave: (_) {
                ref.invalidate(ingresosProvider);
                ref.invalidate(dashboardProvider);
              },
            ),
          );
        } else if (!tx.isIngreso && tx.gasto != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.bgCard,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => FormGasto(
              gastoExistente: tx.gasto,
              onSave: (_) {
                ref.invalidate(gastosProvider);
                ref.invalidate(dashboardProvider);
              },
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: AppTheme.borderLight, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tx.isIngreso ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tx.isIngreso ? 'Ingreso' : 'Gasto'} · ${tx.categoria}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${tx.isIngreso ? '+' : '-'}\$${formatCOP(tx.monto).replaceAll('\$', '').trim()}',
              style: AppTheme.monoStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String periodo;
  const _EmptyState({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCardWarm,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin movimientos este $periodo',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa el botón + para registrar ingresos o gastos',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Data models (privados) ────────────────────────────────────────────────

class _DateHeader {
  final String label;
  const _DateHeader({required this.label});
}

class _TxItem {
  final String id;
  final String nombre;
  final String categoria;
  final double monto;
  final String fecha;
  final bool isIngreso;
  final String? color;
  final Ingreso? ingreso;
  final GastoFijo? gasto;

  const _TxItem({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.fecha,
    required this.isIngreso,
    this.color,
    this.ingreso,
    this.gasto,
  });
}
