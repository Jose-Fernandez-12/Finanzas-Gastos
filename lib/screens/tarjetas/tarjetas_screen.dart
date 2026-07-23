import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/virtual_assistant_provider.dart';
import 'tarjeta_detalle_screen.dart';
import 'forms.dart';

class TarjetasScreen extends ConsumerWidget {
  const TarjetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarjetasAsync = ref.watch(tarjetasProvider);
    final comprasAsync = ref.watch(comprasActivasProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: SafeArea(
        child: Column(
          children: [
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
                        onPressed: () => _onNuevaCompra(context, ref),
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
                        onPressed: () => _showFormTarjeta(context, ref),
                        icon: const Icon(Icons.add_card_rounded, color: AppTheme.textSecondary),
                        tooltip: 'Nueva tarjeta',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: tarjetasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (err, _) => Center(child: Text('Error: ')),
                data: (tarjetas) {
                  if (tarjetas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.credit_card_off_rounded, color: AppTheme.textMuted, size: 60),
                          const SizedBox(height: 16),
                          const Text('No tienes tarjetas registradas', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 20),
                          ElevatedButton(onPressed: () => _showFormTarjeta(context, ref), child: const Text('Agregar primera tarjeta')),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      ref.invalidate(tarjetasProvider);
                      ref.invalidate(comprasActivasProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCarousel(context, ref, tarjetas),
                          comprasAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (err, stack) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Error al cargar cuotas: $err', style: const TextStyle(color: Colors.red)),
                            ),
                            data: (compras) => _buildCuotasActivasSection(context, ref, tarjetas, compras),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, WidgetRef ref, List<dynamic> tarjetas) {
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
              ref.invalidate(tarjetasProvider);
              ref.invalidate(comprasActivasProvider);
              ref.invalidate(dashboardProvider);
            }),
          );
        },
      ),
    );
  }

  Widget _buildCuotasActivasSection(BuildContext context, WidgetRef ref, List<dynamic> tarjetas, List<Map<String, dynamic>> compras) {
    double totalMes = 0;
    for (var t in tarjetas) {
      totalMes += (t.cuotaMesActual as num?)?.toDouble() ?? 0;
    }
    if (totalMes == 0) {
      for (var c in compras) {
        final cuotaVal = (c['valor_cuota'] as num?)?.toDouble() ?? (c['cuota_mensual'] as num?)?.toDouble() ?? 0;
        totalMes += cuotaVal;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cuotas Activas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Total: ${formatCOP(totalMes)} /mes', style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
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
                dynamic tarjeta;
                try {
                  tarjeta = tarjetas.firstWhere((t) => t.id == tId);
                } catch (_) {
                  tarjeta = null;
                }
                
                // Rocky analiza la cuota antes de navegar
                double cuotaVal = (c['valor_cuota'] as num?)?.toDouble() ?? (c['cuota_mensual'] as num?)?.toDouble() ?? 0;
                final numCuotas = (c['num_cuotas'] as int?) ?? 1;
                if (cuotaVal == 0 && numCuotas > 0) {
                  final montoTotal = (c['monto_total'] as num?)?.toDouble() ?? 0;
                  cuotaVal = montoTotal / numCuotas;
                }
                final banco = tarjeta?.banco ?? 'la tarjeta';
                final interes = (c['tasa_interes'] as num?)?.toDouble() ?? 0.0;
                ref.read(virtualAssistantProvider.notifier).analyzeCuota(cuotaVal, banco, interes);

                if (tarjeta != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TarjetaDetalleScreen(tarjeta: tarjeta, initialCompraId: c['id'] as int?)),
                  ).then((_) {
                    ref.invalidate(tarjetasProvider);
                    ref.invalidate(comprasActivasProvider);
                    ref.invalidate(dashboardProvider);
                  });
                }
              },
            )),
        ],
      ),
    );
  }

  void _onNuevaCompra(BuildContext context, WidgetRef ref) {
    final tarjetasOpt = ref.read(tarjetasProvider).value;
    if (tarjetasOpt == null || tarjetasOpt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes registrar al menos una tarjeta primero.'), backgroundColor: AppTheme.colorGastos),
      );
      return;
    }
    if (tarjetasOpt.length == 1) {
      _showFormCompra(context, ref, tarjeta: tarjetasOpt.first);
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
            ...tarjetasOpt.map((t) {
              final color = getTarjetaColor(t.toMap());
              return ListTile(
                leading: CircleAvatar(backgroundColor: color.withAlpha(40), child: Icon(Icons.credit_card_rounded, color: color)),
                title: Text(t.nombreTarjeta.isNotEmpty ? t.nombreTarjeta : t.banco, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                subtitle: Text('Cupo dispo: ${formatCOP(t.cupoDisponible)}', style: const TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFormCompra(context, ref, tarjeta: t);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showFormTarjeta(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FormTarjeta(onSave: () {
        ref.invalidate(tarjetasProvider);
        ref.invalidate(dashboardProvider);
      }),
    );
  }

  void _showFormCompra(BuildContext context, WidgetRef ref, {required dynamic tarjeta, Map<String, dynamic>? compra}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FormCompra(
        tarjetaId: tarjeta.id,
        compra: compra,
        tasaDefecto: tarjeta.tasaInteresMensual ?? 0,
        onSave: () {
          ref.invalidate(tarjetasProvider);
          ref.invalidate(comprasActivasProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }
}

class _TarjetaCarouselCard extends StatelessWidget {
  final dynamic tarjeta;
  final VoidCallback onTap;
  const _TarjetaCarouselCard({required this.tarjeta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tMap = tarjeta.toMap();
    final color = getTarjetaColor(tMap);
    final cupoDispo = tarjeta.cupoDisponible;
    final nombre = tarjeta.nombreTarjeta.isNotEmpty ? tarjeta.nombreTarjeta : tarjeta.banco;
    final idStr = tarjeta.id.toString();

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
                      '**** **** **** ',
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
    
    final cuotaAct = (compra['cuota_actual'] as int?) ?? 1;
    final numCuotas = (compra['num_cuotas'] as int?) ?? 1;
    final pct = (cuotaAct / numCuotas * 100).clamp(0.0, 100.0);

    double cuotaVal = (compra['valor_cuota'] as num?)?.toDouble() ?? (compra['cuota_mensual'] as num?)?.toDouble() ?? 0;
    if (cuotaVal == 0 && numCuotas > 0) {
      final montoTotal = (compra['monto_total'] as num?)?.toDouble() ?? 0;
      cuotaVal = montoTotal / numCuotas;
    }

    final color = Color(int.parse((compra['tarjeta_color'] ?? '#1976D2').replaceFirst('#', '0xFF')));

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
                      Text(tarjetaNombre, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
                Text('${pct.toStringAsFixed(0)}%', style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
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
