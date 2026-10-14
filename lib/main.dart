import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'notification_service.dart';
import 'screens/planning_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await NotificationService.init();
  final state = AppState();
  await state.load();
  runApp(ChangeNotifierProvider.value(value: state, child: const KanleApp()));
}

class KanleApp extends StatelessWidget {
  const KanleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primarySeed = Color(0xFF6C5CE7);

    return MaterialApp(
      title: 'Kanlé',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        cardColor: Colors.white,
        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          indicatorColor: primarySeed.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
          surface: const Color(0xFF171722),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        cardColor: const Color(0xFF171722),
        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          backgroundColor: const Color(0xFF13131B),
          indicatorColor: primarySeed.withOpacity(0.28),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _pages = [
    PlanningScreen(),
    RoutinesScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_timeline_outlined),
            selectedIcon: Icon(Icons.view_timeline_rounded),
            label: 'Planning',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_rounded),
            selectedIcon: Icon(Icons.repeat_on_rounded),
            label: 'Routines',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
