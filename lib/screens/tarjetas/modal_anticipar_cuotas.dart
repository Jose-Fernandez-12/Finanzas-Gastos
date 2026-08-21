import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/amortization_calculator.dart';
import '../../core/local_repository.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/presupuesto_provider.dart';

class ModalAnticiparCuotas extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  final int tarjetaId;
  final String nombreTarjeta;
  final Color tarjetaColor;
  final VoidCallback onCompletado;

  const ModalAnticiparCuotas({
    super.key,
    required this.compra,
    required this.tarjetaId,
    required this.nombreTarjeta,
    required this.tarjetaColor,
    required this.onCompletado,
  });

  @override
  ConsumerState<ModalAnticiparCuotas> createState() => _ModalAnticiparCuotasState();
}

class _ModalAnticiparCuotasState extends ConsumerState<ModalAnticiparCuotas> {
  late List<Map<String, dynamic>> _cuotasPendientes;
  int _cantidadSeleccionada = 1;
  int? _sobreSeleccionadoId;
  List<Sobre> _sobres = [];
  bool _loadingSobres = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    final todasCuotas = (widget.compra['cuotas'] as List<dynamic>?) ?? [];
    _cuotasPendientes = todasCuotas
        .where((c) => (c['estado'] as String?)?.toUpperCase() == 'PENDIENTE')
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    _cuotasPendientes.sort((a, b) => ((a['numero_cuota'] as int?) ?? 0).compareTo((b['numero_cuota'] as int?) ?? 0));
    _cantidadSeleccionada = _cuotasPendientes.isNotEmpty ? 1 : 0;

    _cargarSobres();
  }

  Future<void> _cargarSobres() async {
    final mes = mesActual();
    try {
      final sobres = await SobresRepository.obtenerSobresDelMes(mes);
      if (mounted) {
        setState(() {
          _sobres = sobres;
          _loadingSobres = false;
          for (var s in sobres) {
            final n = s.nombre.toLowerCase();
            if (n.contains('deuda') || n.contains('tarjeta') || n.contains('crédito') || n.contains('credito')) {
              _sobreSeleccionadoId = s.id;
              break;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSobres = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cuotasPendientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppTheme.colorIngresos, size: 48),
            const SizedBox(height: 12),
            const Text(
              '¡Compra 100% al día!',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay cuotas pendientes para esta compra.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }

    final calculo = AmortizationCalculator.calcularAhorroAnticipo(_cuotasPendientes, _cantidadSeleccionada);
    final capitalPagar = calculo['capitalTotal'] as double;
    final interesAhorrado = calculo['interesAhorrado'] as double;
    final totalOriginal = calculo['totalOriginal'] as double;
    final saldoActual = (widget.compra['saldo_capital'] as num?)?.toDouble() ?? 0.0;
    final nuevoSaldo = max(0.0, saldoActual - capitalPagar);
    final maxCuotas = _cuotasPendientes.length;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.colorIngresos.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: AppTheme.colorIngresos, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Anticipar cuotas',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      Text(
                        'Ahorra intereses futuros y libera cupo',
                        style: TextStyle(color: AppTheme.textSecondary.withAlpha(200), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resumen de la compra
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.tarjetaColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.compra['descripcion'] as String? ?? 'Compra',
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.nombreTarjeta} · Saldo: ${formatCOP(saldoActual)}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$maxCuotas pendientes',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selector de Cuotas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '¿Cuántas cuotas deseas adelantar?',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  '$_cantidadSeleccionada de $maxCuotas',
                  style: AppTheme.monoStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Controles de selección de cuotas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.primary, size: 28),
                    onPressed: _cantidadSeleccionada > 1
                        ? () => setState(() => _cantidadSeleccionada--)
                        : null,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: AppTheme.primary,
                        overlayColor: AppTheme.primary.withAlpha(40),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _cantidadSeleccionada.toDouble(),
                        min: 1,
                        max: maxCuotas.toDouble(),
                        divisions: maxCuotas > 1 ? maxCuotas - 1 : 1,
                        onChanged: (val) => setState(() => _cantidadSeleccionada = val.round()),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 28),
                    onPressed: _cantidadSeleccionada < maxCuotas
                        ? () => setState(() => _cantidadSeleccionada++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Botones de acceso rápido
            Row(
              children: [
                _buildQuickButton(
                  label: '1 cuota',
                  isSelected: _cantidadSeleccionada == 1,
                  onTap: () => setState(() => _cantidadSeleccionada = 1),
                ),
                const SizedBox(width: 8),
                if (maxCuotas > 2) ...[
                  _buildQuickButton(
                    label: '${(maxCuotas / 2).ceil()} cuotas (Mitad)',
                    isSelected: _cantidadSeleccionada == (maxCuotas / 2).ceil(),
                    onTap: () => setState(() => _cantidadSeleccionada = (maxCuotas / 2).ceil()),
                  ),
                  const SizedBox(width: 8),
                ],
                _buildQuickButton(
                  label: 'Todas ($maxCuotas)',
                  isSelected: _cantidadSeleccionada == maxCuotas,
                  onTap: () => setState(() => _cantidadSeleccionada = maxCuotas),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Card de Beneficio y Ahorro en Intereses (Estilo Nu / Rappi)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: interesAhorrado > 0
                      ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                      : [AppTheme.surfaceColor, AppTheme.surfaceColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: interesAhorrado > 0 ? const Color(0xFF10B981).withAlpha(100) : AppTheme.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (interesAhorrado > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.savings_rounded, color: Color(0xFF34D399), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Ahorro en intereses: ${formatCOP(interesAhorrado)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withAlpha(20), height: 1),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total programado sin anticipo:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        formatCOP(totalOriginal),
                        style: TextStyle(
                          color: interesAhorrado > 0 ? Colors.white54 : Colors.white70,
                          fontSize: 12,
                          decoration: interesAhorrado > 0 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  if (interesAhorrado > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento de intereses futuros:', style: TextStyle(color: Color(0xFF34D399), fontSize: 12)),
                        Text('- ${formatCOP(interesAhorrado)}', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar hoy (Capital):',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        formatCOP(capitalPagar),
                        style: AppTheme.monoStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Beneficios inmediatos
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Liberas ${formatCOP(capitalPagar)} de cupo en tu tarjeta de inmediato. Tu nuevo saldo será ${formatCOP(nuevoSaldo)}.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Selector de Sobre (Opcional)
            const Text(
              'Descontar de un sobre de presupuesto (opcional):',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _loadingSobres
                ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                : DropdownButtonFormField<int?>(
                    value: _sobreSeleccionadoId,
                    dropdownColor: AppTheme.surfaceColor,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      fillColor: AppTheme.surfaceColor,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.borderLight)),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No descontar de ningún sobre'),
                      ),
                      ..._sobres.where((s) => s.id != null).map((s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text('${s.nombre} (Disponible: ${formatCOP(s.disponible)})'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _sobreSeleccionadoId = v),
                  ),
            const SizedBox(height: 24),

            // Botón de Confirmación
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _processing ? null : () => _confirmarAnticipo(capitalPagar, interesAhorrado),
                child: _processing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            interesAhorrado > 0
                                ? 'PAGAR ${formatCOP(capitalPagar)} (Ahorras ${formatCOP(interesAhorrado)})'
                                : 'PAGAR ${formatCOP(capitalPagar)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderLight),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarAnticipo(double montoCapital, double ahorro) async {
    setState(() => _processing = true);
    try {
      final res = await LocalRepository.instance.anticiparCuotas(
        tarjetaId: widget.tarjetaId,
        compraId: widget.compra['id'] as int,
        cantidadCuotas: _cantidadSeleccionada,
        sobreId: _sobreSeleccionadoId,
      );

      if (res['ok'] == true) {
        if (mounted) {
          final mes = mesActual();
          ref.invalidate(tarjetasProvider);
          ref.invalidate(comprasActivasProvider);
          ref.invalidate(todasLasComprasProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(presupuestoProvider(mes));

          Navigator.pop(context);
          widget.onCompletado();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF065F46),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ahorro > 0
                          ? '¡Anticipo exitoso! Pagaste ${formatCOP(montoCapital)} y ahorraste ${formatCOP(ahorro)} en intereses.'
                          : '¡Anticipo exitoso! Se pagaron $_cantidadSeleccionada cuota(s) (${formatCOP(montoCapital)}).',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Error al procesar el anticipo'),
              backgroundColor: AppTheme.colorGastos,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: AppTheme.colorGastos,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
