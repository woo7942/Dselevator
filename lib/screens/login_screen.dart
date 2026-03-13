import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  /// 서버 주소 변경 시 상위 라우터에 알리는 콜백
  final VoidCallback? onServerChange;
  const LoginScreen({super.key, this.onServerChange});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _nameFocus = FocusNode();
  final _pinFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _nameFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty) { _showError('이름을 입력해주세요.'); return; }
    if (pin.isEmpty)  { _showError('핀번호를 입력해주세요.'); return; }
    if (pin.length < 4 || pin.length > 6) {
      _showError('핀번호는 4~6자리여야 합니다.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(name, pin);

    if (!mounted) return;
    if (!success) {
      _showError(auth.error ?? '로그인 실패');
      _pinController.clear();
    }
  }

  /// 서버 주소 변경 다이얼로그
  Future<void> _changeServer() async {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    bool saving = false;
    bool testing = false;
    String? testMsg;
    bool testOk = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.dns_outlined, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text('API 서버 변경', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: InputDecoration(
                  labelText: 'API 서버 URL',
                  hintText: 'http://192.168.1.100:8787',
                  prefixIcon: const Icon(Icons.link, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (testMsg != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: testOk ? AppTheme.successLight : AppTheme.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    testMsg!,
                    style: TextStyle(
                      fontSize: 12,
                      color: testOk ? AppTheme.success : AppTheme.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            // 연결 테스트
            OutlinedButton.icon(
              onPressed: (saving || testing) ? null : () async {
                setS(() { testing = true; testMsg = null; testOk = false; });
                try {
                  await ApiService.setBaseUrl(ctrl.text.trim());
                  await ApiService.getDashboard();
                  setS(() { testMsg = '✅ 연결 성공!'; testOk = true; });
                } catch (_) {
                  await ApiService.setBaseUrl(ApiService.baseUrl); // 롤백
                  setS(() { testMsg = '❌ 연결 실패'; testOk = false; });
                } finally {
                  setS(() => testing = false);
                }
              },
              icon: testing
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering, size: 14),
              label: const Text('테스트'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            // 저장
            ElevatedButton.icon(
              onPressed: (saving || testing) ? null : () async {
                final url = ctrl.text.trim();
                if (url.isEmpty) return;
                setS(() => saving = true);
                await ApiService.setBaseUrl(url);
                if (ctx.mounted) Navigator.pop(ctx);
                // 상위 라우터에 알림
                widget.onServerChange?.call();
              },
              icon: saving
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 14),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.isLoading;
    final serverUrl = ApiService.baseUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── 로고 ──────────────────────────────────────────
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.elevator_outlined, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  '승강기 관리 시스템',
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '로그인하여 계속하세요',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),

                // ── 서버 주소 표시 배너 ────────────────────────────
                GestureDetector(
                  onTap: _changeServer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dns_outlined, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            serverUrl.isEmpty ? '서버 주소 미설정' : serverUrl,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 13, color: Colors.white.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 로그인 카드 ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름
                      const Text('이름',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _pinFocus.requestFocus(),
                        decoration: InputDecoration(
                          hintText: '한글 이름 입력',
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1A237E)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2)),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 핀번호
                      const Text('핀번호',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pinController,
                        focusNode: _pinFocus,
                        enabled: !isLoading,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: '4~6자리 숫자',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A237E)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2)),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('로그인',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  '관리자에게 계정 발급을 요청하세요',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                ),

                // ── 서버 변경 텍스트 버튼 ─────────────────────────
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _changeServer,
                  icon: const Icon(Icons.settings_ethernet, size: 14, color: Colors.white54),
                  label: const Text('서버 주소 변경',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
