import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'models/warranty.dart';
import 'screens/add_edit_warranty_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_controller.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('hu');
  try {
    await NotificationService.instance.initialize();
  } on Object catch (error, stackTrace) {
    debugPrint('Az értesítések nem inicializálódtak: $error\n$stackTrace');
  }

  final controller = AppController();
  await controller.initialize();
  runApp(GaranciaOrApp(controller: controller));
}

class GaranciaOrApp extends StatelessWidget {
  const GaranciaOrApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'GaranciaŐr',
      debugShowCheckedModeBanner: false,
      themeMode: controller.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
      ),
      locale: const Locale('hu'),
      supportedLocales: const [Locale('hu')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MainShell(controller: controller),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        HomeScreen(
          controller: widget.controller,
          onAdd: () => _openForm(context),
        ),
        SettingsScreen(controller: widget.controller),
      ],
    ),
    floatingActionButton: _selectedIndex == 0
        ? FloatingActionButton(
            onPressed: () => _openForm(context),
            tooltip: 'Új garancia hozzáadása',
            child: const Icon(Icons.add),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Kezdőlap',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Beállítások',
        ),
      ],
    ),
  );

  Future<void> _openForm(BuildContext context, {Warranty? warranty}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEditWarrantyScreen(
          controller: widget.controller,
          existing: warranty,
        ),
      ),
    );
  }
}
