import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ServerSetupScreen
//  - API 서버 주소가 미설정일 때 가장 먼저 표시되는 화면
//  - 저장 성공 시 _RootRouter가 자동으로 LoginScreen으로 전환
// ─────────────────────────────────────────────────────────────────
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _show('서버 주소를 입력하세요.', isError: true);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = false;
    });
    try {
      // 임시로 baseUrl 설정 후 ping
      await ApiService.setBaseUrl(url);
      await ApiService.getDashboard();
      setState(() {
        _testResult = '✅ 연결 성공! 서버에 정상 접속되었습니다.';
        _testSuccess = true;
      });
    } catch (e) {
      // 실패하면 baseUrl 다시 비움
      await ApiService.setBaseUrl('');
      setState(() {
        _testResult = '❌ 연결 실패: 주소를 다시 확인해 주세요.';
        _testSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _show('서버 주소를 입력하세요.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.setBaseUrl(url);
      // needsSetup이 false가 되면 _RootRouter가 자동으로 LoginScreen으로 이동
      if (mounted) setState(() {}); // rebuild 트리거
    } catch (e) {
      if (mounted) _show('저장 실패: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 영역
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.elevator, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  '승강기 관리 시스템',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elevator Manager',
                  style: TextStyle(fontSize: 13, color: AppTheme.gray400),
                ),
                const SizedBox(height: 32),

                // 안내 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API 서버 주소 설정이 필요합니다',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '백엔드 서버(Node.js, 포트 8787)가 실행 중인 주소를 입력하세요. '
                              '한 번 설정하면 다음부터는 이 화면이 표시되지 않습니다.',
                              style: TextStyle(fontSize: 12, color: AppTheme.gray600, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 입력 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API 서버 주소',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'http://192.168.1.100:8787',
                          hintStyle: TextStyle(color: AppTheme.gray300, fontSize: 13),
                          prefixIcon: const Icon(Icons.dns_outlined, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        onSubmitted: (_) => _test(),
                      ),
                      const SizedBox(height: 6),

                      // 입력 예시
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '예) http://192.168.0.10:8787  또는  https://내도메인.com',
                          style: TextStyle(fontSize: 11, color: AppTheme.gray400),
                        ),
                      ),

                      // 테스트 결과
                      if (_testResult != null) ...[
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _testSuccess
                                ? AppTheme.successLight
                                : AppTheme.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _testSuccess
                                  ? AppTheme.success
                                  : AppTheme.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 버튼 영역
                      Row(
                        children: [
                          // 연결 테스트
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_testing || _saving) ? null : _test,
                              icon: _testing
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.wifi_tethering, size: 16),
                              label: const Text('연결 테스트'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary),
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // 저장 후 로그인으로
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_testing || _saving) ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('저장 후 시작'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 하단 도움말
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gray100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline, size: 14, color: AppTheme.gray400),
                          const SizedBox(width: 6),
                          Text(
                            '서버 주소를 모르시나요?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.gray600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _helpItem('💻', '서버 PC에서 cmd 실행 → `ipconfig` → IPv4 주소 확인'),
                      _helpItem('🔢', '포트는 기본 8787 (서버 설정에 따라 다를 수 있음)'),
                      _helpItem('🌐', '외부 접속 시 공인 IP 또는 도메인 + 포트 포워딩 필요'),
                      _helpItem('🔒', 'https 사용 시 인증서 설정이 필요합니다'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _helpItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: AppTheme.gray500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
