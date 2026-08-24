import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../core/amortization_calculator.dart';
import '../../core/local_repository.dart';
import '../../core/database_service.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/presupuesto_provider.dart';

class ModalAdelantarPagoTarjeta extends ConsumerStatefulWidget {
  final dynamic tarjeta; // TarjetaCredito o Map
  final VoidCallback onCompletado;

  const ModalAdelantarPagoTarjeta({
    super.key,
    required this.tarjeta,
    required this.onCompletado,
  });

  @override
  ConsumerState<ModalAdelantarPagoTarjeta> createState() => _ModalAdelantarPagoTarjetaState();
}

class _ModalAdelantarPagoTarjetaState extends ConsumerState<ModalAdelantarPagoTarjeta> {
  final TextEditingController _montoController = TextEditingController();
  List<Map<String, dynamic>> _cuotasPendientes = [];
  bool _loadingCuotas = true;

  int? _sobreSeleccionadoId;
  List<Sobre> _sobres = [];
  bool _loadingSobres = true;
  bool _processing = false;

  double _montoIngresado = 0.0;
  double _cuotaMesActual = 0.0;
  double _deudaTotalActiva = 0.0;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(_onMontoChanged);
    _cargarDatos();
  }

  @override
  void dispose() {
    _montoController.removeListener(_onMontoChanged);
    _montoController.dispose();
    super.dispose();
  }

  void _onMontoChanged() {
    final clean = _montoController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final val = double.tryParse(clean) ?? 0.0;
    if (val != _montoIngresado) {
      setState(() {
        _montoIngresado = val;
      });
    }
  }

  void _setMontoRapido(double val) {
    setState(() {
      _montoIngresado = val;
      _montoController.text = val.toInt().toString();
    });
  }

  Future<void> _cargarDatos() async {
    final tId = widget.tarjeta.id as int;
    final mes = mesActual();

    try {
      // 1. Cargar cuotas pendientes de todas las compras de esta tarjeta
      final dbCuotas = await DatabaseService.instance.query('''
        SELECT c.*, cp.descripcion as compra_descripcion, cp.saldo_capital as compra_saldo_capital,
               cp.cuota_actual as compra_cuota_actual, cp.num_cuotas as compra_num_cuotas
        FROM cuotas_amortizacion c
        JOIN compras_tarjeta cp ON c.compra_id = cp.id
        WHERE c.tarjeta_id = ? AND c.estado = 'PENDIENTE'
        ORDER BY c.fecha_vencimiento ASC, c.id ASC
      ''', [tId]);

      final cuotas = dbCuotas.map((e) => Map<String, dynamic>.from(e)).toList();

      double sumaMes = 0.0;
      double sumaDeuda = 0.0;
      final Set<int> comprasVistas = {};

      for (var c in cuotas) {
        final compId = c['compra_id'] as int;
        if (!comprasVistas.contains(compId)) {
          comprasVistas.add(compId);
          sumaDeuda += (c['compra_saldo_capital'] as num?)?.toDouble() ?? 0.0;
        }

        final fVenc = (c['fecha_vencimiento'] as String? ?? '');
        if (fVenc.startsWith(mes)) {
          sumaMes += (c['valor_cuota'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 2. Cargar sobres
      final sobres = await SobresRepository.obtenerSobresDelMes(mes);
      int? defaultSobreId;
      for (var s in sobres) {
        final n = s.nombre.toLowerCase();
        if (n.contains('deuda') || n.contains('tarjeta') || n.contains('crédito') || n.contains('credito')) {
          defaultSobreId = s.id;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _cuotasPendientes = cuotas;
          _cuotaMesActual = sumaMes;
          _deudaTotalActiva = sumaDeuda;
          _sobres = sobres;
          _sobreSeleccionadoId = defaultSobreId;
          _loadingCuotas = false;
          _loadingSobres = false;
          
          // Por defecto sugerir cuota del mes o 0
          if (_cuotaMesActual > 0) {
            _montoIngresado = _cuotaMesActual;
            _montoController.text = _cuotaMesActual.toInt().toString();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCuotas = false;
          _loadingSobres = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCuotas) {
      return Container(
        height: 250,
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final t = widget.tarjeta;
    final tMap = t.toMap();
    final color = getTarjetaColor(tMap);
    final nombreTarjeta = (t.nombreTarjeta as String).isNotEmpty ? t.nombreTarjeta : t.banco;

    final sim = AmortizationCalculator.simularAbonoCascadaTarjeta(
      cuotasPendientes: _cuotasPendientes,
      montoAbono: _montoIngresado,
    );

    final capitalAmortizado = sim['capitalAmortizado'] as double;
    final interesAhorrado = sim['interesAhorrado'] as double;
    final cuotasPagadas = (sim['cuotasPagadas'] as List<Map<String, dynamic>>?) ?? [];
    final excedente = sim['excedenteCupo'] as double;
    final cupoDispo = (t.cupoDisponible as num?)?.toDouble() ?? 0.0;
    final nuevoCupoSimulado = cupoDispo + _montoIngresado;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.payments_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adelantar pago / Abono libre',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      Text(
                        '$nombreTarjeta · Libera cupo y ahorra intereses',
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

            // Tarjeta resumen deuda actual
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cuota del mes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          formatCOP(_cuotaMesActual),
                          style: AppTheme.monoStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deuda diferida', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          formatCOP(_deudaTotalActiva),
                          style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cupo libre', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          formatCOP(cupoDispo),
                          style: AppTheme.monoStyle(color: AppTheme.colorIngresos, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input monto libre
            const Text(
              '¿Cuánto dinero deseas pagar / abonar?',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              style: AppTheme.monoStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: AppTheme.monoStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 24),
                hintText: '0',
                hintStyle: AppTheme.monoStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 24),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.borderLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.borderLight)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 10),

            // Botones de monto rápido
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_cuotaMesActual > 0) ...[
                    _buildChipMonto(
                      label: 'Cuota del mes (${formatCOP(_cuotaMesActual)})',
                      isSelected: _montoIngresado == _cuotaMesActual,
                      onTap: () => _setMontoRapido(_cuotaMesActual),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildChipMonto(
                    label: '\$200.000',
                    isSelected: _montoIngresado == 200000,
                    onTap: () => _setMontoRapido(200000),
                  ),
                  const SizedBox(width: 8),
                  _buildChipMonto(
                    label: '\$400.000',
                    isSelected: _montoIngresado == 400000,
                    onTap: () => _setMontoRapido(400000),
                  ),
                  const SizedBox(width: 8),
                  _buildChipMonto(
                    label: '\$500.000',
                    isSelected: _montoIngresado == 500000,
                    onTap: () => _setMontoRapido(500000),
                  ),
                  const SizedBox(width: 8),
                  if (_deudaTotalActiva > 0)
                    _buildChipMonto(
                      label: 'Pagar toda la deuda (${formatCOP(_deudaTotalActiva)})',
                      isSelected: _montoIngresado == _deudaTotalActiva,
                      onTap: () => _setMontoRapido(_deudaTotalActiva),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card de Simulación y Beneficios en vivo (Estilo Nu / RappiCard)
            if (_montoIngresado > 0) ...[
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              interesAhorrado > 0 ? Icons.savings_rounded : Icons.flash_on_rounded,
                              color: interesAhorrado > 0 ? const Color(0xFF34D399) : AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              interesAhorrado > 0 ? '¡Ahorro en intereses!' : 'Aplicación inteligente',
                              style: TextStyle(
                                color: interesAhorrado > 0 ? const Color(0xFF34D399) : AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (interesAhorrado > 0)
                          Text(
                            formatCOP(interesAhorrado),
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withAlpha(20), height: 1),
                    const SizedBox(height: 12),

                    // Desglose
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cuotas cubiertas:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '${cuotasPagadas.length} cuota(s) saldada(s)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Capital amortizado:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          formatCOP(capitalAmortizado),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    if (excedente > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo a favor / Cupo adicional:', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                          Text(
                            '+ ${formatCOP(excedente)}',
                            style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nuevo cupo disponible:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          formatCOP(nuevoCupoSimulado),
                          style: AppTheme.monoStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Selector de Sobre de presupuesto
            const Text(
              'Descontar este pago de un sobre de presupuesto:',
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

            // Botón de confirmación
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (_processing || _montoIngresado <= 0) ? null : () => _confirmarAbono(interesAhorrado),
                child: _processing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'PAGAR ${formatCOP(_montoIngresado)} A LA TARJETA',
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

  Widget _buildChipMonto({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(40) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarAbono(double interesAhorrado) async {
    setState(() => _processing = true);
    final tId = widget.tarjeta.id as int;

    try {
      final res = await LocalRepository.instance.abonarATarjeta(
        tarjetaId: tId,
        monto: _montoIngresado,
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

          final cuotasLiq = res['cuotasLiquidadas'] ?? 0;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF065F46),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      interesAhorrado > 0
                          ? '¡Pago exitoso! Se abonaron ${formatCOP(_montoIngresado)} ($cuotasLiq cuotas) y ahorraste ${formatCOP(interesAhorrado)} en intereses.'
                          : '¡Pago exitoso! Se abonaron ${formatCOP(_montoIngresado)} a tu tarjeta liberando cupo de inmediato.',
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
              content: Text(res['error']?.toString() ?? 'Error al procesar el abono'),
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
