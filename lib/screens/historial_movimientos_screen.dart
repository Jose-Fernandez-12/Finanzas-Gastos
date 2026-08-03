import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/dao/ingresos_dao.dart';
import '../core/dao/gastos_dao.dart';
import '../models/ingreso.dart';
import '../models/gasto_fijo.dart';
import '../providers/ingresos_provider.dart';
import '../providers/gastos_provider.dart';
import '../providers/dashboard_provider.dart';
import 'ingresos_screen.dart';
import 'gastos_screen.dart';

final allIngresosProvider = FutureProvider<List<Ingreso>>((ref) async {
  return await IngresosDao.instance.getIngresos(mes: 'all');
});

final allGastosProvider = FutureProvider<List<GastoFijo>>((ref) async {
  return await GastosDao.instance.getGastosFijos(mes: 'all');
});

class HistorialMovimientosScreen extends ConsumerStatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  ConsumerState<HistorialMovimientosScreen> createState() => _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState extends ConsumerState<HistorialMovimientosScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingresosAsync = ref.watch(allIngresosProvider);
    final gastosAsync = ref.watch(allGastosProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Historial de Movimientos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Column(
        children: [
          // Buscador premium
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por concepto o categoría...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Lista de movimientos unificada
          Expanded(
            child: ingresosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (err, _) => Center(child: Text('Error al cargar ingresos: $err')),
              data: (ingresos) => gastosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (err, _) => Center(child: Text('Error al cargar gastos: $err')),
                data: (gastos) {
                  final items = _buildAndFilterMovimientos(ingresos, gastos);

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted.withAlpha(120)),
                          const SizedBox(height: 12),
                          const Text('No se encontraron movimientos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      if (item is _DateHeader) {
                        return _TxDateHeader(label: item.label);
                      } else if (item is _TxItem) {
                        return _TransactionRow(tx: item);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Object> _buildAndFilterMovimientos(List<Ingreso> ingresos, List<GastoFijo> gastos) {
    var filteredIngresos = ingresos;
    var filteredGastos = gastos;

    if (_searchQuery.isNotEmpty) {
      filteredIngresos = ingresos.where((i) {
        final desc = (i.descripcion ?? '').toLowerCase();
        final cat = (i.categoriaNombre ?? '').toLowerCase();
        return desc.contains(_searchQuery) || cat.contains(_searchQuery);
      }).toList();

      filteredGastos = gastos.where((g) {
        final name = g.nombre.toLowerCase();
        final cat = (g.categoriaNombre ?? '').toLowerCase();
        return name.contains(_searchQuery) || cat.contains(_searchQuery);
      }).toList();
    }

    final all = <_TxItem>[
      ...filteredIngresos.map((i) => _TxItem(
            id: 'i${i.id}',
            nombre: i.descripcion ?? i.categoriaNombre ?? 'Ingreso',
            categoria: i.categoriaNombre ?? 'Ingreso',
            monto: i.monto,
            fecha: i.fecha,
            isIngreso: true,
            color: i.categoriaColor,
            ingreso: i,
          )),
      ...filteredGastos.map((g) => _TxItem(
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

    all.sort((a, b) => b.fecha.compareTo(a.fecha));

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

class _TxDateHeader extends StatelessWidget {
  final String label;
  const _TxDateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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
                ref.invalidate(allIngresosProvider);
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
                ref.invalidate(allGastosProvider);
                ref.invalidate(gastosProvider);
                ref.invalidate(dashboardProvider);
              },
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                tx.isIngreso ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${tx.isIngreso ? 'Ingreso' : 'Gasto'} · ${tx.categoria}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${tx.isIngreso ? '+' : '-'}${formatCOP(tx.monto)}',
              style: AppTheme.monoStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
