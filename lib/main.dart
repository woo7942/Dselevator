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
//  최상위 라우터 (StatefulWidget: ApiService.needsSetup 변화 감지)
//  흐름: 서버설정 미완료 → ServerSetupScreen
//        서버설정 완료 + 미로그인 → LoginScreen
//        로그인 완료 → MainScreen
// ─────────────────────────────────────────────────────────────────
class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  /// ServerSetupScreen에서 저장 완료 시 이 콜백으로 setState 유도
  void _onServerSaved() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1단계: 서버 주소 미설정 → 서버 설정 화면
    if (ApiService.needsSetup) {
      return ServerSetupScreen(onSaved: _onServerSaved);
    }

    // 2단계: 로그인 안 됨 → 로그인 화면
    if (!auth.isLoggedIn) {
      return LoginScreen(onServerChange: _onServerSaved);
    }

    // 3단계: 로그인 완료 → 메인
    return const MainScreen();
  }
}
