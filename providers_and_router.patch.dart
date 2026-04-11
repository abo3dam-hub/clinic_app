// PATCH: lib/core/providers/repository_providers.dart
// Add to bottom of existing file:

/*
import '../../features/accounting/data/repositories/ledger_repository.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
    (ref) => LedgerRepository(ref.watch(databaseHelperProvider)));
*/

// ─────────────────────────────────────────────────────────────────────────────

// PATCH: lib/core/providers/service_providers.dart
// Add to the Services section (after excelExportServiceProvider):

/*
import '../../features/accounting/domain/services/journal_service.dart';
import '../../features/accounting/data/repositories/ledger_repository.dart';

final journalServiceProvider = Provider<JournalService>(
    (ref) => JournalService(ref.watch(ledgerRepositoryProvider)));
*/

// ─────────────────────────────────────────────────────────────────────────────

// PATCH: lib/core/router/app_router.dart
// Change /visits/:id route — split into detail vs edit:

/*
// REMOVE this route:
GoRoute(
  path: ':id',
  builder: (_, state) => VisitFormScreen(
      visitId: int.tryParse(state.pathParameters['id'] ?? '')),
),

// REPLACE WITH:
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

// Also add import at top:
import '../../features/visits/presentation/screens/visit_detail_screen.dart';

// Add new accounting route inside ShellRoute.routes:
GoRoute(
  path: '/accounting',
  builder: (_, __) => const AccountingScreen(),
),
// Import:
import '../../features/accounting/presentation/screens/accounting_screen.dart';
*/

// ─────────────────────────────────────────────────────────────────────────────
// PATCH: lib/shared/widgets/app_shell.dart  (sidebar navigation)
// Add accounting entry to nav items list:

/*
// In the NavigationItem list (or wherever you define nav items), add:
NavigationItem(
  path: '/accounting',
  icon: Icons.account_balance_outlined,
  label: 'المحاسبة',
),
*/
