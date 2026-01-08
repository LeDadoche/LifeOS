import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/money/presentation/screens/financial_dashboard_screen.dart';
import '../../features/money/presentation/screens/add_transaction_screen.dart';
import '../../features/money/presentation/screens/financial_profile_screen.dart';
import '../../features/money/presentation/screens/recurring_transactions_screen.dart';
import '../../features/money/presentation/screens/categories_management_screen.dart';
import '../../features/money/presentation/screens/savings_goals_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/tasks/presentation/screens/quick_add_task_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/notes/presentation/screens/note_detail_screen.dart';
import '../../features/notes/data/note_model.dart';
import '../../features/agenda/presentation/screens/agenda_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/meals/presentation/screens/kitchen_screen.dart';
import '../../features/dashboard/presentation/screens/customize_dashboard_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.path == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/customize',
        builder: (context, state) => const CustomizeDashboardScreen(),
      ),
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/agenda',
        builder: (context, state) => const AgendaScreen(),
        routes: [
          // Route pour ajouter un événement depuis le widget
          GoRoute(
            path: 'add',
            builder: (context, state) =>
                const AgendaScreen(openAddDialog: true),
          ),
          // Route pour voir un événement spécifique
          GoRoute(
            path: 'event',
            builder: (context, state) {
              final eventId = state.uri.queryParameters['id'];
              return AgendaScreen(
                  highlightEventId:
                      eventId != null ? int.tryParse(eventId) : null);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) {
              final note = state.extra as Note;
              return NoteDetailScreen(note: note);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TasksScreen(),
      ),
      // Route séparée pour l'ajout rapide depuis le widget
      GoRoute(
        path: '/tasks/add',
        builder: (context, state) => const QuickAddTaskScreen(),
      ),
      GoRoute(
        path: '/money',
        builder: (context, state) => const FinancialDashboardScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddTransactionScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const FinancialProfileScreen(),
          ),
          GoRoute(
            path: 'recurring',
            builder: (context, state) => const RecurringTransactionsScreen(),
          ),
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategoriesManagementScreen(),
          ),
          GoRoute(
            path: 'goals',
            builder: (context, state) => const SavingsGoalsScreen(),
          ),
        ],
      ),
    ],
  );
}
