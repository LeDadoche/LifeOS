import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_auth.dart';
import 'core/router/app_router.dart';
import 'core/services/app_upgrade_service.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_callback_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

/// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 [Main] Starting LifeOS...');

  // 1. Initialisation de Supabase (Connexion au Cloud)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  debugPrint('✅ [Main] Supabase initialized');

  // 2. Configuration de la locale pour les dates
  await initializeDateFormatting('fr_FR', null);

  // 3. Initialisation du service de notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  debugPrint('✅ [Main] Notifications initialized');

  // 4. Initialisation du service HomeWidget (mobile only)
  final homeWidgetService = HomeWidgetService();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await homeWidgetService.initialize();
    debugPrint('✅ [Main] HomeWidget service initialized');

    // 5. Register widget background callback (mobile only)
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    debugPrint('✅ [Main] Widget callback registered');

    // 6. Initial widget refresh if user is logged in
    if (Supabase.instance.client.auth.currentUser != null) {
      homeWidgetService.refreshAllWidgets();
      debugPrint('✅ [Main] Initial widget refresh triggered');
    }
  } else {
    debugPrint('ℹ️ [Main] HomeWidget skipped (not on mobile)');
  }

  // 7. Check for initial deep link (widget launch) - mobile only
  Uri? initialUri;
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    debugPrint('🔗 [Main] Initial launch URI: $initialUri');
  }

  runApp(
    ProviderScope(
      child: LifeOSApp(initialUri: initialUri),
    ),
  );
}

class LifeOSApp extends ConsumerStatefulWidget {
  final Uri? initialUri;

  const LifeOSApp({super.key, this.initialUri});

  @override
  ConsumerState<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends ConsumerState<LifeOSApp> {
  @override
  void initState() {
    super.initState();

    // Listen for widget clicks while app is running (mobile only)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      HomeWidget.widgetClicked.listen(_handleWidgetClick);
    }

    // Handle initial URI if app was launched from widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialUri != null) {
        _handleWidgetClick(widget.initialUri);
      }
    });
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;

    debugPrint('🔗 [LifeOSApp] Widget click received: $uri');
    debugPrint('🔗 [LifeOSApp] Host: ${uri.host}, Path: ${uri.path}');

    // Convert lifeos:// URI to GoRouter path
    final host = uri.host;
    final path = uri.path;

    String? routePath;

    switch (host) {
      case 'tasks':
        if (path == '/add') {
          routePath = '/tasks/add';
        } else {
          routePath = '/tasks';
        }
        break;
      case 'agenda':
        if (path == '/add') {
          routePath = '/agenda/add';
        } else if (path == '/event') {
          // Construire le chemin avec le query parameter
          final eventId = uri.queryParameters['id'];
          if (eventId != null) {
            routePath = '/agenda/event?id=$eventId';
          } else {
            routePath = '/agenda';
          }
        } else if (path == '/refresh') {
          // Refresh ne navigue pas, juste rafraîchit les données
          debugPrint('🔄 [LifeOSApp] Agenda refresh requested');
          return;
        } else {
          routePath = '/agenda';
        }
        break;
      case 'settings':
        routePath = '/settings';
        break;
    }

    if (routePath != null) {
      final path = routePath; // Variable locale pour la promotion de type
      debugPrint('🔗 [LifeOSApp] Will navigate to: $path');

      // Use post-frame callback to ensure navigation happens after rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final router = ref.read(goRouterProvider);

        // Si on vient d'un deep link vers une sous-page,
        // on s'assure que le dashboard est visité d'abord pour initialiser les providers
        if (path.contains('/add') || path.contains('/event')) {
          debugPrint(
              '🔗 [LifeOSApp] Deep link detected, initializing dashboard first...');
          // D'abord aller au dashboard pour initialiser
          router.go('/');
          // Puis naviguer vers la destination avec un petit délai
          Future.delayed(const Duration(milliseconds: 100), () {
            debugPrint('🔗 [LifeOSApp] Now navigating to: $path');
            router.push(path);
          });
        } else {
          debugPrint('🔗 [LifeOSApp] Executing navigation to: $path');
          router.go(path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeState = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(themeState.scheme),
      darkTheme: AppTheme.dark(themeState.scheme),
      themeMode: themeState.mode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      // Wrapper pour les mises à jour automatiques
      builder: (context, child) {
        return AppUpgradeService.wrapWithUpgrader(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
