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
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState state = AppState();

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
        builder: (_) => _LockRepEntry(packageName: packageName),
      );
    }

    if (uri.path == '/lock/prayer') {
      final PrayerName prayer = PrayerName.values.firstWhere(
        (item) => item.name == uri.queryParameters['prayer'],
        orElse: () => PrayerName.dhuhr,
      );
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _LockPrayerEntry(prayer: prayer),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const _StartupEntry(),
    );
  }
}

class _StartupEntry extends StatelessWidget {
  const _StartupEntry();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.ink,
            body: Center(child: CircularProgressIndicator(color: AppColors.unlock)),
          );
        }
        return state.onboardingComplete ? const RootNav() : const OnboardingScreen();
      },
    );
  }
}

class _LockRepEntry extends StatelessWidget {
  final String? packageName;
  const _LockRepEntry({this.packageName});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.ink,
            body: Center(child: CircularProgressIndicator(color: AppColors.unlock)),
          );
        }

        final requested = packageName?.trim();
        if (requested == null || requested.isEmpty) {
          return const _InvalidLockEntry();
        }

        LockedAppCandidate? candidate;
        for (final item in state.apps) {
          if (item.packageName == requested) {
            candidate = LockedAppCandidate(item);
            break;
          }
        }

        final app = candidate?.app;
        if (app == null || !app.isEnabled) {
          return const _InvalidLockEntry();
        }

        return RepCameraScreen(app: app);
      },
    );
  }
}

class LockedAppCandidate {
  final dynamic app;
  LockedAppCandidate(this.app);
}

class _InvalidLockEntry extends StatelessWidget {
  const _InvalidLockEntry();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.signal),
                const SizedBox(height: 16),
                Text('تعذر التحقق من التطبيق المقفول', textAlign: TextAlign.center, style: AppTextStyles.kufi(size: 18)),
                const SizedBox(height: 8),
                Text('لم يتم منح أي وقت فتح. ارجع إلى كدّ وحاول من جديد.', textAlign: TextAlign.center, style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                const SizedBox(height: 18),
                KaddPrimaryButton(label: 'إغلاق', onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockPrayerEntry extends StatelessWidget {
  final PrayerName prayer;
  const _LockPrayerEntry({required this.prayer});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.ink,
            body: Center(child: CircularProgressIndicator(color: AppColors.unlock)),
          );
        }
        return PrayerLockScreen(prayer: prayer);
      },
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
      unawaited(_refreshOnResume());
    }
  }

  Future<void> _refreshOnResume() async {
    final appState = context.read<AppState>();
    try {
      await appState.checkUsageAccess();
      await appState.loadAvailableApps(forceRefresh: true);
    } catch (error, stack) {
      debugPrint('Kadd: resume refresh failed: $error');
      debugPrint('Kadd: resume refresh stack:\n$stack');
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
            NavigationDestination(icon: Icon(Icons.lock_outline), selectedIcon: Icon(Icons.lock), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'التطبيقات'),
            NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque), label: 'الصلاة'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          ],
        ),
      ),
    );
  }
}
