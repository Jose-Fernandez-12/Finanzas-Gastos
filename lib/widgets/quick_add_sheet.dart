import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Contexto de la tab activa, determina qué acciones muestra el sheet.
enum QuickAddContext {
  inicio,      // 4 acciones: Ingreso, Gasto, Compra TDC, Suscripcion
  movimientos, // 2 acciones: Ingreso, Gasto
  finanzas,    // 3 acciones: Compra TDC, Meta de Ahorro, Nuevo Deudor
  mas,         // 1 accion:   Nueva Suscripcion
}

/// Muestra el bottom sheet de accion rapida, filtrado segun [context].
Future<void> showQuickAddSheet(BuildContext context, QuickAddContext ctx) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuickAddSheet(context: ctx),
  );
}

class QuickAddSheet extends StatelessWidget {
  final QuickAddContext context;

  const QuickAddSheet({super.key, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final actions = _actionsFor(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Titulo
          const Text(
            'Agregar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Acciones filtradas
          ...actions.map((a) => _ActionTile(action: a)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  List<_QuickAction> _actionsFor(QuickAddContext ctx) {
    switch (ctx) {
      case QuickAddContext.inicio:
        return [_ingreso, _gasto, _compraTDC, _suscripcion];
      case QuickAddContext.movimientos:
        return [_ingreso, _gasto];
      case QuickAddContext.finanzas:
        return [_compraTDC, _metaAhorro, _deudor];
      case QuickAddContext.mas:
        return [_suscripcion];
    }
  }

  // ─── Definiciones de acciones ───────────────────────────────
  static const _ingreso = _QuickAction(
    label: 'Registrar Ingreso',
    desc: 'Salario, freelance, otro ingreso',
    iconColor: Color(0xFF10B981),
    iconBg: Color(0xFFD1FAE5),
    icon: Icons.trending_up_rounded,
    route: '/ingresos/nuevo',
  );

  static const _gasto = _QuickAction(
    label: 'Registrar Gasto',
    desc: 'Transporte, comida, servicios',
    iconColor: Color(0xFFEF4444),
    iconBg: Color(0xFFFEE2E2),
    icon: Icons.trending_down_rounded,
    route: '/gastos/nuevo',
  );

  static const _compraTDC = _QuickAction(
    label: 'Compra con TDC',
    desc: 'Registrar compra en cuotas',
    iconColor: Color(0xFF7C3AED),
    iconBg: Color(0xFFEDE9FE),
    icon: Icons.credit_card_rounded,
    route: '/tarjetas/nueva-compra',
  );

  static const _suscripcion = _QuickAction(
    label: 'Nueva Suscripción',
    desc: 'Spotify, Netflix, otro servicio',
    iconColor: Color(0xFFF59E0B),
    iconBg: Color(0xFFFEF3C7),
    icon: Icons.subscriptions_rounded,
    route: '/suscripciones/nueva',
  );

  static const _metaAhorro = _QuickAction(
    label: 'Nueva Meta de Ahorro',
    desc: 'Fondo de emergencia, viaje, etc.',
    iconColor: Color(0xFF3B82F6),
    iconBg: Color(0xFFDBEAFE),
    icon: Icons.savings_rounded,
    route: '/ahorros/nueva',
  );

  static const _deudor = _QuickAction(
    label: 'Nuevo Deudor',
    desc: 'Registrar cuenta por cobrar',
    iconColor: Color(0xFF10B981),
    iconBg: Color(0xFFD1FAE5),
    icon: Icons.person_add_rounded,
    route: '/cuentas-cobrar/nuevo',
  );
}

// ─── Tile de accion ─────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final _QuickAction action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, action.route);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderSoft),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, color: action.iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final String desc;
  final Color iconColor;
  final Color iconBg;
  final IconData icon;
  final String route;

  const _QuickAction({
    required this.label,
    required this.desc,
    required this.iconColor,
    required this.iconBg,
    required this.icon,
    required this.route,
  });
}
