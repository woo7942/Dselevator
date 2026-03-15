import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // 앱 시작 시 서버 데이터 손실 여부 체크 후 자동 복원
  _autoRestoreOnStartup();
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

/// 앱 시작 시 서버 데이터가 너무 적으면 로컬 백업에서 자동 복원
Future<void> _autoRestoreOnStartup() async {
  try {
    // 로컬 백업 현장 수 확인
    final backupCount = await _getLocalBackupSitesCount();
    if (backupCount == 0) {
      // 로컬 백업 없음 - 서버에서 백업 생성
      await ApiService.backupToLocal();
      return;
    }
    // 서버 현장 수 확인 (버전 API로 간단하게 체크)
    final versionData = await ApiService.getVersion();
    final serverSites = (versionData['sites'] as num?)?.toInt() ?? -1;
    if (serverSites >= 0 && serverSites < backupCount ~/ 2) {
      // 서버 데이터가 로컬 백업의 절반 미만이면 복원
      await ApiService.restoreFromLocal();
    } else if (serverSites > 0) {
      // 정상이면 최신 백업 갱신
      await ApiService.backupToLocal();
    }
  } catch (_) {
    // 서버 연결 실패 시 무시
  }
}

Future<int> _getLocalBackupSitesCount() async {
  try {
    final backupTime = await ApiService.getLastBackupTime();
    if (backupTime == null) return 0;
    // SharedPreferences에서 직접 백업 데이터 읽기
    final prefs = await _getPrefs();
    final raw = prefs?.getString('db_backup_v1');
    if (raw == null) return 0;
    final data = (jsonDecode(raw) as Map<String, dynamic>);
    final sites = data['sites'] as List?;
    return sites?.length ?? 0;
  } catch (_) {
    return 0;
  }
}

// SharedPreferences 인스턴스 캐시
Future<SharedPreferences?> _getPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
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
