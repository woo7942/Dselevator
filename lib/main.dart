import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'utils/theme.dart';
import 'services/api_service.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await ApiService.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const ElevatorManagerApp(),
    ),
  );
}

class ElevatorManagerApp extends StatelessWidget {
  const ElevatorManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '승강기 관리 시스템',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainScreen(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
