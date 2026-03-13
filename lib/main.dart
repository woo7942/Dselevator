import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'utils/theme.dart';
import 'services/api_service.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/server_setup_screen.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await ApiService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
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
      home: const _RootRouter(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  최상위 라우터: 서버 설정 → 로그인 → 메인 순서로 화면 결정
// ─────────────────────────────────────────────────────────────────
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1단계: API 서버 주소가 설정되어 있지 않으면 서버 설정 화면
    if (ApiService.needsSetup) {
      return const ServerSetupScreen();
    }

    // 2단계: 로그인 안 되어 있으면 로그인 화면
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    // 3단계: 로그인 완료 → 메인 화면
    return const MainScreen();
  }
}
