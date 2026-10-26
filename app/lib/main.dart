import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'api.dart';
import 'screens/dashboard.dart';
import 'screens/settings.dart';
import 'screens/unlock.dart';
import 'theme.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// Tab aktif di navigasi bawah. Dipakai layar lain untuk melompat ke Pengaturan.
final homeTab = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.load();
  try {
    final saved = await const FlutterSecureStorage().read(key: 'theme_mode');
    themeMode.value = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  } catch (_) {
    themeMode.value = ThemeMode.dark;
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => ShadApp(
        title: 'Penilaian Owner',
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Home(),
      ),
    );
  }
}

/// Kerangka dengan navigasi bawah: Dashboard & Pengaturan.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _unlocked = Api.i.token.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return UnlockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    final scheme = ShadTheme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: homeTab,
      builder: (context, tab, _) => Scaffold(
        backgroundColor: scheme.background,
        body: IndexedStack(
          index: tab,
          children: const [DashboardScreen(), SettingsScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => homeTab.value = i,
          backgroundColor: scheme.background,
          indicatorColor: scheme.accent,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
          ],
        ),
      ),
    );
  }
}
