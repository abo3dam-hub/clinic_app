// lib/core/router/app_router.dart

import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/patients/presentation/screens/patients_screen.dart';
import '../../features/patients/presentation/screens/patient_form_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_screen.dart';
import '../../features/doctors/presentation/screens/doctors_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/visits/presentation/screens/visits_screen.dart';
import '../../features/visits/presentation/screens/visit_detail_screen.dart'; // NEW
import '../../features/invoices/presentation/screens/invoices_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/cash_box/presentation/screens/cash_box_screen.dart';
import '../../features/procedures/presentation/screens/procedures_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/accounting/presentation/screens/accounting_screen.dart'; // NEW
import '../../features/accounting/presentation/screens/statement_screen.dart'; // NEW

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(
        child: child,
        currentRoute: state.fullPath ?? '/dashboard',
      ),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/patients',
          builder: (_, __) => const PatientsScreen(),
          routes: [
            GoRoute(path: 'new', builder: (_, __) => const PatientFormScreen()),
            GoRoute(
              path: ':id',
              builder: (_, state) => PatientDetailScreen(
                  patientId: int.parse(state.pathParameters['id']!)),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (_, state) => PatientFormScreen(
                  patientId: int.tryParse(state.pathParameters['id'] ?? '')),
            ),
          ],
        ),
        GoRoute(
          path: '/doctors',
          builder: (_, __) => const DoctorsScreen(),
        ),
        GoRoute(
          path: '/appointments',
          builder: (_, __) => const AppointmentsScreen(),
        ),
        GoRoute(
          path: '/visits',
          builder: (_, __) => const VisitsScreen(),
          routes: [
            // New visit form
            GoRoute(
              path: 'new',
              builder: (_, __) => const VisitFormScreen(),
            ),
            // FIX: /visits/:id now opens VisitDetailScreen (procedures + invoice)
            // /visits/:id/edit opens VisitFormScreen for metadata editing
            GoRoute(
              path: ':id',
              builder: (_, state) => VisitDetailScreen(
                  visitId: int.parse(state.pathParameters['id']!)),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => VisitFormScreen(
                      visitId: int.tryParse(state.pathParameters['id'] ?? '')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/invoices',
          builder: (_, state) =>
              InvoicesScreen(queryParams: state.uri.queryParameters),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => InvoiceDetailScreen(
                  invoiceId: int.parse(state.pathParameters['id']!)),
            ),
          ],
        ),
        GoRoute(
          path: '/expenses',
          builder: (_, __) => const ExpensesScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (_, __) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/procedures',
          builder: (_, __) => const ProceduresScreen(),
        ),
        GoRoute(
          path: '/cash-box',
          builder: (_, __) => const CashBoxScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, __) => const ReportsScreen(),
        ),
        // NEW: Accounting module (Trial Balance, P&L, Balance Sheet)
        GoRoute(
          path: '/accounting',
          builder: (_, __) => const AccountingScreen(),
        ),
        // NEW: كشف الحساب — شاشة مستقلة
        GoRoute(
          path: '/statement',
          builder: (_, __) => const StatementScreen(),
        ),
        GoRoute(
          path: '/backup',
          builder: (_, __) => const BackupScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
