import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/presupuesto_provider.dart';
import '../providers/virtual_assistant_provider.dart';

class PresupuestoBaseCeroScreen extends ConsumerStatefulWidget {
  const PresupuestoBaseCeroScreen({super.key});

  @override
  ConsumerState<PresupuestoBaseCeroScreen> createState() => _PresupuestoBaseCeroScreenState();
}

class _PresupuestoBaseCeroScreenState extends ConsumerState<PresupuestoBaseCeroScreen> {
  late final String _mesActual;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mesActual = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static const List<_SobrePlantilla> _plantillas = [
    _SobrePlantilla('Arriendo / Vivienda', '#EF4444', 'home'),
    _SobrePlantilla('Alimentación', '#F59E0B', 'restaurant'),
    _SobrePlantilla('Transporte', '#3B82F6', 'directions_car'),
    _SobrePlantilla('Servicios / Facturas', '#8B5CF6', 'receipt_long'),
    _SobrePlantilla('Entretenimiento', '#EC4899', 'celebration'),
    _SobrePlantilla('Ahorro', '#10B981', 'savings'),
    _SobrePlantilla('Deudas / Tarjetas', '#EF4444', 'credit_card'),
    _SobrePlantilla('Salud', '#06B6D4', 'health_and_safety'),
    _SobrePlantilla('Educación', '#6366F1', 'school'),
    _SobrePlantilla('Otro', '#6B7280', 'more_horiz'),
  ];

  static const Map<String, IconData> _iconMap = {
    'home': Icons.home_rounded,
    'restaurant': Icons.restaurant_rounded,
    'directions_car': Icons.directions_car_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'celebration': Icons.celebration_rounded,
    'savings': Icons.savings_rounded,
    'credit_card': Icons.credit_card_rounded,
    'health_and_safety': Icons.health_and_safety_rounded,
    'school': Icons.school_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final presupuestoAsync = ref.watch(presupuestoProvider(_mesActual));

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presupuesto Base Cero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              formatMes(_mesActual),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearSobre(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Sobre', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: presupuestoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (estado) => _buildBody(estado),
      ),
    );
  }

  Widget _buildBody(PresupuestoState estado) {
    // Rocky reacciona al estado del presupuesto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rockyReact(estado);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Header con balance ---
        _buildBalanceHeader(estado),
        const SizedBox(height: 20),

        // --- Barra de distribución ---
        _buildDistributionBar(estado),
        const SizedBox(height: 24),

        // --- Lista de sobres ---
        if (estado.sobres.isEmpty)
          _buildEmptyState()
        else
          ...estado.sobres.map((s) => _SobreCard(
            sobre: s,
            iconMap: _iconMap,
            onEdit: () => _showEditarSobre(context, s),
            onDelete: () => _confirmarEliminar(s),
          )),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBalanceHeader(PresupuestoState estado) {
    final sinAsignar = estado.sinAsignar;
    final isNeg = sinAsignar < -1;
    final isPerfect = sinAsignar.abs() < 1;
    final headerColor = isPerfect
        ? const Color(0xFF10B981)
        : (isNeg ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPerfect
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : (isNeg
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: headerColor.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INGRESOS DEL MES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white.withAlpha(180)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCOP(estado.ingresosMes),
                    style: AppTheme.monoStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Icon(
                isPerfect ? Icons.check_circle_rounded : (isNeg ? Icons.error_rounded : Icons.pending_rounded),
                color: Colors.white,
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPerfect ? '¡PRESUPUESTO CUADRADO!' : 'SIN ASIGNAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
                Text(
                  formatCOP(sinAsignar.abs()),
                  style: AppTheme.monoStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(PresupuestoState estado) {
    if (estado.sobres.isEmpty || estado.ingresosMes <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DISTRIBUCIÓN',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                ...estado.sobres.map((s) {
                  final frac = s.montoAsignado / estado.ingresosMes;
                  if (frac <= 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: (frac * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: _parseColor(s.color),
                    ),
                  );
                }),
                if (estado.sinAsignar > 0)
                  Expanded(
                    flex: (estado.sinAsignar / estado.ingresosMes * 1000).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFFE5E7EB)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.mail_outline_rounded, size: 48, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text(
            'Sin sobres aún',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca "Nuevo Sobre" para empezar a repartir tus ingresos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
          ),
        ],
      ),
    );
  }

  void _rockyReact(PresupuestoState estado) {
    if (estado.ingresosMes <= 0) return;

    final assistant = ref.read(virtualAssistantProvider.notifier);
    if (ref.read(virtualAssistantProvider).isAction) return;

    if (estado.cuadrado && estado.sobres.isNotEmpty) {
      assistant.showActionMessage(
        '¡Perfecto! Todo tu dinero tiene un trabajo asignado. Base cero logrado.',
        AssistantAnimation.celebration,
      );
    } else if (estado.sinAsignar < -1) {
      assistant.showActionMessage(
        '¡Cuidado! Has asignado ${formatCOP(estado.sinAsignar.abs())} más de lo que ganas.',
        AssistantAnimation.glitch,
      );
    }
  }

  void _showCrearSobre(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CrearSobreSheet(
        plantillas: _plantillas,
        iconMap: _iconMap,
        mesReferencia: _mesActual,
        onCreado: () {
          ref.invalidate(presupuestoProvider(_mesActual));
        },
      ),
    );
  }

  void _showEditarSobre(BuildContext context, Sobre sobre) {
    final controller = TextEditingController(text: sobre.montoAsignado.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar: ${sobre.nombre}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto asignado',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final monto = double.tryParse(controller.text) ?? 0;
              await SobresRepository.actualizar(sobre.id!, montoAsignado: monto);
              ref.invalidate(presupuestoProvider(_mesActual));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(Sobre sobre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sobre'),
        content: Text('¿Eliminar "${sobre.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              await SobresRepository.eliminar(sobre.id!);
              ref.invalidate(presupuestoProvider(_mesActual));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}

// ---------------------------------------------------------------------------
// Sobre Card (visual premium tipo "sobre de correo")
// ---------------------------------------------------------------------------
class _SobreCard extends StatelessWidget {
  final Sobre sobre;
  final Map<String, IconData> iconMap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SobreCard({
    required this.sobre,
    required this.iconMap,
    required this.onEdit,
    required this.onDelete,
  });

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(sobre.color);
    final icon = iconMap[sobre.icono] ?? Icons.account_balance_wallet_rounded;

    return GestureDetector(
      onTap: onEdit,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header del sobre (simula la solapa)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(20), color.withAlpha(8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sobre.nombre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCOP(sobre.montoAsignado),
                        style: AppTheme.monoStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'asignado',
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Cuerpo del sobre
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sobre.porcentajeUsado,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation(
                        sobre.porcentajeUsado > 0.9 ? const Color(0xFFEF4444) : color,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gastado: ${formatCOP(sobre.gastado)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                      Text(
                        'Disponible: ${formatCOP(sobre.disponible)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sobre.disponible < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
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

// ---------------------------------------------------------------------------
// Bottom Sheet para crear un nuevo sobre
// ---------------------------------------------------------------------------
class _CrearSobreSheet extends StatefulWidget {
  final List<_SobrePlantilla> plantillas;
  final Map<String, IconData> iconMap;
  final String mesReferencia;
  final VoidCallback onCreado;

  const _CrearSobreSheet({
    required this.plantillas,
    required this.iconMap,
    required this.mesReferencia,
    required this.onCreado,
  });

  @override
  State<_CrearSobreSheet> createState() => _CrearSobreSheetState();
}

class _CrearSobreSheetState extends State<_CrearSobreSheet> {
  int _selectedIndex = 0;
  final _montoController = TextEditingController();

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CREAR NUEVO SOBRE',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),

          // Grid de plantillas
          SizedBox(
            height: 120,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.55,
              ),
              itemCount: widget.plantillas.length,
              itemBuilder: (_, i) {
                final p = widget.plantillas[i];
                final selected = _selectedIndex == i;
                final color = _parseColor(p.color);
                final icon = widget.iconMap[p.icono] ?? Icons.more_horiz_rounded;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? color.withAlpha(20) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: selected ? color : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.nombre,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? color : const Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Monto
          TextField(
            controller: _montoController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Monto a asignar',
              prefixText: '\$ ',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 16),

          // Botón
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(_montoController.text) ?? 0;
                final plantilla = widget.plantillas[_selectedIndex];
                final sobre = Sobre(
                  nombre: plantilla.nombre,
                  montoAsignado: monto,
                  color: plantilla.color,
                  icono: plantilla.icono,
                  mesReferencia: widget.mesReferencia,
                );
                await SobresRepository.crear(sobre);
                widget.onCreado();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('CREAR SOBRE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plantilla base para categorías de sobres
// ---------------------------------------------------------------------------
class _SobrePlantilla {
  final String nombre;
  final String color;
  final String icono;
  const _SobrePlantilla(this.nombre, this.color, this.icono);
}
