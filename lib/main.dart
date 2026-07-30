import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/locked_app.dart';
import 'models/prayer.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/prayer_settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/rep_camera_screen.dart';
import 'screens/prayer_lock_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const KaddApp(),
    ),
  );
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
      supportedLocales: const [Locale('ar')],
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Resolves both the normal in-app route ("/") and the two routes
  /// LockActivity.kt launches directly from native code when a locked app
  /// is foregrounded — see LockActivity's getInitialRoute() for the Kotlin
  /// side of this contract. Keep the two in sync if either changes.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.path == '/lock/rep') {
      final packageName = uri.queryParameters['package'];
      return MaterialPageRoute(
        builder: (context) {
          final state = context.read<AppState>();
          final app = state.apps.firstWhere(
            (a) => a.packageName == packageName,
            orElse: () => state.apps.first,
          );
          return RepCameraScreen(app: app);
        },
      );
    }

    if (uri.path == '/lock/prayer') {
      final prayerRaw = uri.queryParameters['prayer'];
      final prayer = PrayerName.values.firstWhere(
        (p) => p.name == prayerRaw,
        orElse: () => PrayerName.dhuhr,
      );
      return MaterialPageRoute(builder: (_) => PrayerLockScreen(prayer: prayer));
    }

    return MaterialPageRoute(builder: (_) => const RootNav());
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().checkUsageAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.lock_outline), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.apps), label: 'التطبيقات'),
            NavigationDestination(icon: Icon(Icons.mosque_outlined), label: 'الصلاة'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          ],
        ),
      ),
    );
  }
}
