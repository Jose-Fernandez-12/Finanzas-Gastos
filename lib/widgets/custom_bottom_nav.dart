import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Navbar personalizado con 4 tabs + FAB central elevado.
/// El índice 2 es el FAB; al tocarlo dispara [onFabTap] en lugar de navegar.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onFabTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onFabTap,
  });

  static const _items = [
    _NavItem(icon: Icons.home_rounded,        label: 'Inicio'),
    _NavItem(icon: Icons.swap_horiz_rounded,  label: 'Movimientos'),
    _NavItem(icon: null,                       label: 'Agregar'),   // FAB — index 2
    _NavItem(icon: Icons.credit_card_rounded,  label: 'Finanzas'),
    _NavItem(icon: Icons.more_horiz_rounded,   label: 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              if (i == 2) return _buildFab();
              return _buildTab(i);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    // Mapeo de index real → index de pantalla (saltamos el 2 del FAB)
    final screenIndex = index < 2 ? index : index - 1;
    final isActive = currentIndex == screenIndex;
    final item = _items[index];

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(screenIndex),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isActive ? AppTheme.primary : AppTheme.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isActive ? AppTheme.primary : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Expanded(
      child: GestureDetector(
        onTap: onFabTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FAB elevado — se sale 18px hacia arriba
            Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.fabShadow,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                'Agregar',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
