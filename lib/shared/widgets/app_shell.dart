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
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

const _navItems = [
  _NavItem(label: 'الرئيسية',      icon: Icons.dashboard_outlined,              activeIcon: Icons.dashboard,              route: '/dashboard'),
  _NavItem(label: 'المرضى',        icon: Icons.people_outline,                  activeIcon: Icons.people,                 route: '/patients'),
  _NavItem(label: 'الأطباء',       icon: Icons.medical_services_outlined,       activeIcon: Icons.medical_services,       route: '/doctors'),
  _NavItem(label: 'الإجراءات',     icon: Icons.healing_outlined,                activeIcon: Icons.healing,                route: '/procedures'),
  _NavItem(label: 'المواعيد',      icon: Icons.calendar_month_outlined,         activeIcon: Icons.calendar_month,         route: '/appointments'),
  _NavItem(label: 'الزيارات',      icon: Icons.local_hospital_outlined,         activeIcon: Icons.local_hospital,         route: '/visits'),
  _NavItem(label: 'الفواتير',      icon: Icons.receipt_long_outlined,           activeIcon: Icons.receipt_long,           route: '/invoices'),
  _NavItem(label: 'المصروفات',     icon: Icons.payments_outlined,               activeIcon: Icons.payments,               route: '/expenses'),
  _NavItem(label: 'المخزون',       icon: Icons.inventory_2_outlined,            activeIcon: Icons.inventory_2,            route: '/inventory'),
  _NavItem(label: 'الخزينة',       icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, route: '/cash-box'),
  _NavItem(label: 'التقارير',      icon: Icons.bar_chart_outlined,              activeIcon: Icons.bar_chart,              route: '/reports'),
];

const _bottomItems = [
  _NavItem(label: 'النسخ الاحتياطي', icon: Icons.backup_outlined,   activeIcon: Icons.backup,   route: '/backup'),
  _NavItem(label: 'الإعدادات',       icon: Icons.settings_outlined, activeIcon: Icons.settings, route: '/settings'),
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
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _expanded ? _ew : _cw,
              child: _Sidebar(
                expanded: _expanded,
                currentRoute: widget.currentRoute,
                onToggle: () => setState(() => _expanded = !_expanded),
                onNav: (r) => context.go(r),
              ),
            ),
            // FIX: Content area no longer has a separate _TopBar widget.
            // That 64 px white band was the "empty gray rectangle" the user
            // was seeing on every screen.  Page title is now shown in the
            // sidebar header and the route title in the sidebar active item,
            // which is more than enough context for a desktop app.
            Expanded(child: widget.child),
          ]),
        ),
      );
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
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          boxShadow: AppShadows.sidebar,
        ),
        child: Column(children: [
          // ── Logo / header ──────────────────────────────────────
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text('عيادتي',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
              IconButton(
                onPressed: onToggle,
                iconSize: 20,
                icon: Icon(
                  expanded ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left,
                  color: AppColors.textSecondary),
              ),
            ]),
          ),

          // ── Nav items ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
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

          // ── Bottom items ──────────────────────────────────────
          const Divider(height: 1),
          ..._bottomItems.map((item) => _Tile(
                item: item,
                active: currentRoute.startsWith(item.route),
                expanded: expanded,
                onTap: () => onNav(item.route),
              )),
          const SizedBox(height: 8),
        ]),
      );
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
  Widget build(BuildContext context) => Tooltip(
        message: expanded ? '' : item.label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 20,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text(item.label,
                    style: TextStyle(
                      color: active ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    )),
              ],
            ]),
          ),
        ),
      );
}
