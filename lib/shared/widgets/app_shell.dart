// lib/shared/widgets/app_shell.dart
// Desktop layout: collapsible RTL sidebar + content area

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Color? accentColor;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.accentColor,
  });
}

const _navItems = [
  _NavItem(
      label: 'الرئيسية',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      route: '/dashboard'),
  _NavItem(
      label: 'سجل المرضى',
      icon: Icons.folder_shared_outlined,
      activeIcon: Icons.folder_shared,
      route: '/patients',
      accentColor: Color(0xFF7C3AED)),
  _NavItem(
      label: 'الأطباء',
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services,
      route: '/doctors'),
  _NavItem(
      label: 'الإجراءات',
      icon: Icons.healing_outlined,
      activeIcon: Icons.healing,
      route: '/procedures'),
  _NavItem(
      label: 'المواعيد',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      route: '/appointments'),
  _NavItem(
      label: 'الزيارات',
      icon: Icons.local_hospital_outlined,
      activeIcon: Icons.local_hospital,
      route: '/visits'),
  _NavItem(
      label: 'الفواتير',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      route: '/invoices'),
  _NavItem(
      label: 'المصروفات',
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      route: '/expenses'),
  _NavItem(
      label: 'المخزون',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      route: '/inventory'),
  _NavItem(
      label: 'الصندوق',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      route: '/cash-box'),
  _NavItem(
      label: 'التقارير',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      route: '/reports'),
  _NavItem(
      label: 'المحاسبة',
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance,
      route: '/accounting'),
];

const _bottomItems = [
  _NavItem(
      label: 'النسخ الاحتياطي',
      icon: Icons.backup_outlined,
      activeIcon: Icons.backup,
      route: '/backup'),
  _NavItem(
      label: 'الإعدادات',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      route: '/settings'),
];

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _expanded = true;
  static const double _ew = 220;
  static const double _cw = 64;

  @override
  Widget build(BuildContext context) {
    // Explicitly force RTL logic for the entire shell
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            // Right Sidebar (First in RTL Row)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _expanded ? _ew : _cw,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(
                        -4, 0), // Shadow towards the content (left)
                  ),
                ],
              ),
              child: _Sidebar(
                expanded: _expanded,
                currentRoute: widget.currentRoute,
                onToggle: () => setState(() => _expanded = !_expanded),
                onNav: (r) => context.go(r),
              ),
            ),
            // Content Area (Left side)
            Expanded(
              child: Container(
                color: AppColors.surface,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool expanded;
  final String currentRoute;
  final VoidCallback onToggle;
  final void Function(String) onNav;

  const _Sidebar({
    required this.expanded,
    required this.currentRoute,
    required this.onToggle,
    required this.onNav,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header / Logo
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital,
                    color: AppColors.primary, size: 24),
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'نظام العيادة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  expanded ? Icons.chevron_right : Icons.chevron_left,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _navItems
                .map((item) => _Tile(
                      item: item,
                      active: currentRoute.startsWith(item.route),
                      expanded: expanded,
                      onTap: () => onNav(item.route),
                    ))
                .toList(),
          ),
        ),

        const Divider(height: 1, color: AppColors.border),
        // Bottom Items
        ..._bottomItems.map((item) => _Tile(
              item: item,
              active: currentRoute.startsWith(item.route),
              expanded: expanded,
              onTap: () => onNav(item.route),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _Tile({
    required this.item,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.accentColor ?? AppColors.primary;
    return Tooltip(
      message: expanded ? '' : item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      accent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: accent.withValues(alpha: 0.22), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 20,
                color: active ? accent : AppColors.textSecondary,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: active ? accent : AppColors.textPrimary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
