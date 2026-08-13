import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/prayer.dart';
import 'state/app_state.dart';
import 'services/ads_service.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/prayer_settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/rep_camera_screen.dart';
import 'screens/prayer_lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) {
        final state = AppState();

        // Start initialization safely.
        // Any initialization error is caught so it cannot crash
        // the application during startup.
        unawaited(
          state.init().catchError(
            (Object error, StackTrace stack) {
              debugPrint(
                'Kadd: AppState initialization failed: $error',
              );
              debugPrint(
                'Kadd: AppState initialization stack:\n$stack',
              );
            },
          ),
        );

        return state;
      },
      child: const KaddApp(),
    ),
  );

  // Initialize ads after the first frame.
  // An advertising SDK failure must never prevent Kadd from launching.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      AdsService.instance.init().catchError(
        (Object error, StackTrace stack) {
          debugPrint(
            'Kadd: Ads initialization failed: $error',
          );
          debugPrint(
            'Kadd: Ads initialization stack:\n$stack',
          );
        },
      ),
    );
  });
}

class KaddApp extends StatelessWidget {
  const KaddApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كدّ',
      debugShowCheckedModeBanner: false,

      theme: buildKaddTheme(),

      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],

      onGenerateRoute: _onGenerateRoute,

      // Always start from the root application screen.
      initialRoute: '/',
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? '/';

    Uri uri;

    try {
      uri = Uri.parse(routeName);
    } catch (error, stack) {
      debugPrint(
        'Kadd: Invalid route "$routeName": $error',
      );
      debugPrint('$stack');

      return MaterialPageRoute<void>(
        builder: (_) => const RootNav(),
      );
    }

    // ------------------------------------------------------------
    // REPETITIONS LOCK
    // ------------------------------------------------------------

    if (uri.path == '/lock/rep') {
      final String? packageName = uri.queryParameters['package'];

      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) {
          final AppState state = context.read<AppState>();

          /*
           * LockActivity may launch this route immediately after Android
           * starts the Flutter engine.
           *
           * AppState may not have finished loading installed applications
           * yet. Never call first/firstWhere on an empty list.
           */
          if (state.apps.isEmpty) {
            return const RootNav();
          }

          final app = state.apps.firstWhere(
            (item) {
              if (packageName == null || packageName.isEmpty) {
                return false;
              }

              return item.packageName == packageName;
            },
            orElse: () => state.apps.first,
          );

          return RepCameraScreen(app: app);
        },
      );
    }

    // ------------------------------------------------------------
    // PRAYER LOCK
    // ------------------------------------------------------------

    if (uri.path == '/lock/prayer') {
      final String? prayerRaw = uri.queryParameters['prayer'];

      final PrayerName prayer = PrayerName.values.firstWhere(
        (item) => item.name == prayerRaw,
        orElse: () => PrayerName.dhuhr,
      );

      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => PrayerLockScreen(
          prayer: prayer,
        ),
      );
    }

    // ------------------------------------------------------------
    // ROOT
    // ------------------------------------------------------------

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const RootNav(),
    );
  }
}

// ================================================================
// ROOT NAVIGATION
// ================================================================

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav>
    with WidgetsBindingObserver {
  int _index = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    SettingsScreen(),
    PrayerSettingsScreen(),
    StatsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _checkUsageAccessSafely();
    }
  }

  void _checkUsageAccessSafely() {
    try {
      final AppState appState = context.read<AppState>();

      unawaited(
        appState.checkUsageAccess().catchError(
          (Object error, StackTrace stack) {
            debugPrint(
              'Kadd: Usage access check failed: $error',
            );
            debugPrint(
              'Kadd: Usage access stack:\n$stack',
            );
          },
        ),
      );
    } catch (error, stack) {
      debugPrint(
        'Kadd: Unable to check usage access: $error',
      );
      debugPrint('$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _screens,
        ),

        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,

          selectedIndex: _index,

          onDestinationSelected: (int index) {
            if (!mounted) {
              return;
            }

            setState(() {
              _index = index;
            });
          },

          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(
                Icons.lock_outline,
              ),
              selectedIcon: Icon(
                Icons.lock,
              ),
              label: 'الرئيسية',
            ),

            NavigationDestination(
              icon: Icon(
                Icons.apps_outlined,
              ),
              selectedIcon: Icon(
                Icons.apps,
              ),
              label: 'التطبيقات',
            ),

            NavigationDestination(
              icon: Icon(
                Icons.mosque_outlined,
              ),
              selectedIcon: Icon(
                Icons.mosque,
              ),
              label: 'الصلاة',
            ),

            NavigationDestination(
              icon: Icon(
                Icons.bar_chart_outlined,
              ),
              selectedIcon: Icon(
                Icons.bar_chart,
              ),
              label: 'الإحصائيات',
            ),
          ],
        ),
      ),
    );
  }
}
