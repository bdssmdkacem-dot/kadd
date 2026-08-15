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
  final AppState state = AppState();

  // Do not block the first Flutter frame on network/native initialization.
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const KaddApp(),
    ),
  );

  unawaited(_initializeSafely(state));
}

Future<void> _initializeSafely(AppState state) async {
  try {
    await state.init();
  } catch (error, stack) {
    debugPrint('Kadd: startup initialization failed: $error');
    debugPrint('Kadd: startup initialization stack:\n$stack');
  }

  try {
    await AdsService.instance.init();
  } catch (error, stack) {
    debugPrint('Kadd: Ads initialization failed: $error');
    debugPrint('Kadd: Ads initialization stack:\n$stack');
  }
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
      initialRoute: '/',
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final Uri uri = Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');

    if (uri.path == '/lock/rep') {
      final String? packageName = uri.queryParameters['package'];
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) {
          final AppState state = context.read<AppState>();
          if (state.apps.isEmpty) return const RootNav();
          final app = packageName == null
              ? state.apps.first
              : state.apps.firstWhere(
                  (item) => item.packageName == packageName,
                  orElse: () => state.apps.first,
                );
          return RepCameraScreen(app: app);
        },
      );
    }

    if (uri.path == '/lock/prayer') {
      final PrayerName prayer = PrayerName.values.firstWhere(
        (item) => item.name == uri.queryParameters['prayer'],
        orElse: () => PrayerName.dhuhr,
      );
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => PrayerLockScreen(prayer: prayer),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> with WidgetsBindingObserver {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkUsageAccessSafely());
    }
  }

  Future<void> _checkUsageAccessSafely() async {
    try {
      await context.read<AppState>().checkUsageAccess();
    } catch (error, stack) {
      debugPrint('Kadd: Usage access check failed: $error');
      debugPrint('Kadd: Usage access stack:\n$stack');
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
          onDestinationSelected: (int index) {
            if (mounted) setState(() => _index = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'التطبيقات',
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque),
              label: 'الصلاة',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'الإحصائيات',
            ),
          ],
        ),
      ),
    );
  }
}
