import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'user_manage_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _urlCtrl = TextEditingController(text: ApiService.baseUrl);
  bool _saving = false;
  bool _testing = false;
  bool _testSuccess = false;
  String? _testResult;
  bool _savingSeed = false;
  bool _deduping = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      showToast(context, '서버 주소를 입력하세요.', isError: true);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = false;
    });
    try {
      await ApiService.setBaseUrl(url);
      await ApiService.getDashboard();
      if (mounted) {
        setState(() {
          _testResult = '✅ 연결 성공! 서버에 정상 접속되었습니다.';
          _testSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = '❌ 연결 실패: 주소를 다시 확인해 주세요.';
          _testSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      showToast(context, '서버 주소를 입력하세요.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.setBaseUrl(url);
      if (mounted) {
        showToast(context, 'API 서버 주소가 저장되었습니다. 잠시 후 새로고침 해주세요.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 서버 주소 초기화 (미설정 상태로 되돌리기)
  Future<void> _resetUrl() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 주소 초기화'),
        content: const Text('저장된 API 서버 주소를 삭제하시겠습니까?\n앱 재시작 시 서버 설정 화면이 표시됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ApiService.setBaseUrl('');
    if (mounted) {
      showToast(context, '서버 주소가 초기화되었습니다.');
      setState(() => _urlCtrl.text = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          // 초기화 버튼
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            tooltip: '서버 주소 초기화',
            onPressed: _resetUrl,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── API 서버 설정 ─────────────────────────────────────
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('API 서버 설정',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gray800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '백엔드 서버(Node.js, 포트 8787)가 실행 중인 주소를 입력하세요.',
                    style: TextStyle(fontSize: 12, color: AppTheme.gray500),
                  ),
                  const SizedBox(height: 14),

                  // URL 입력
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'API 서버 URL',
                      hintText: 'http://192.168.1.100:8787',
                      prefixIcon: const Icon(Icons.link, size: 18),
                      suffixIcon: _urlCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _urlCtrl.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '예) http://192.168.0.10:8787  또는  https://내도메인.com',
                      style: TextStyle(fontSize: 11, color: AppTheme.gray400),
                    ),
                  ),

                  // 테스트 결과
                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _testSuccess ? AppTheme.successLight : AppTheme.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testSuccess ? AppTheme.success : AppTheme.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  // 버튼 행
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_testing || _saving) ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  height: 14, width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering, size: 16),
                          label: const Text('연결 테스트'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_testing || _saving) ? null : _saveUrl,
                          icon: _saving
                              ? const SizedBox(
                                  height: 14, width: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 16),
                          label: const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 현재 연결 상태 ────────────────────────────────────
            _ConnectionStatusCard(),
            const SizedBox(height: 16),

            // ── 관리자 메뉴 ──────────────────────────────────────
            Builder(builder: (context) {
              final isAdmin = context.watch<AuthProvider>().isAdmin;
              if (!isAdmin) return const SizedBox.shrink();
              return Column(
                children: [
                  InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            const Text('관리자 메뉴',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.gray800)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('관리자 전용',
                                  style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people_outline, color: AppTheme.primary, size: 18),
                          ),
                          title: const Text('사용자 관리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('계정 추가·삭제, 탭 접근 권한 설정', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.gray400),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserManageScreen()),
                          ),
                        ),
                        const Divider(height: 12),
                        // ── 영구저장 버튼 ──
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _savingSeed
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                              : const Icon(Icons.cloud_upload_outlined, color: Colors.green, size: 18),
                          ),
                          title: const Text('영구저장 (서버 백업)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('현재 데이터를 서버에 영구 저장\n재배포 후에도 데이터가 복원됩니다', style: TextStyle(fontSize: 12)),
                          trailing: _savingSeed
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right, color: AppTheme.gray400),
                          onTap: _savingSeed ? null : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(children: [
                                  Icon(Icons.cloud_upload_outlined, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('영구저장'),
                                ]),
                                content: const Text(
                                  '현재 DB의 모든 현장·승강기 데이터를\n서버에 영구 저장합니다.\n\n재배포(서버 재시작) 후에도\n데이터가 자동으로 복원됩니다.',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('영구저장'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true || !mounted) return;
                            setState(() => _savingSeed = true);
                            try {
                              final res = await ApiService.saveSeed();
                              if (!mounted) return;
                              final saved = res['saved'] as Map<String, dynamic>?;
                              final github = res['github'] ?? 'unknown';
                              final sites = saved?['sites'] ?? 0;
                              final elevs = saved?['elevators'] ?? 0;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Row(children: [
                                    Icon(Icons.check_circle, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('저장 완료'),
                                  ]),
                                  content: Text(
                                    '✅ 현장 $sites개, 승강기 $elevs개 저장 완료\n\n'
                                    'GitHub: ${github == 'pushed' ? '✅ 자동 push 완료' : github == 'no_token' ? '⚠️ GITHUB_TOKEN 미설정\n(서버에서 환경변수 설정 필요)' : '⚠️ $github'}'
                                  ),
                                  actions: [
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
                                  ],
                                ),
                              );
                            } catch (e) {
                              if (mounted) showToast(context, '저장 실패: $e', isError: true);
                            } finally {
                              if (mounted) setState(() => _savingSeed = false);
                            }
                          },
                        ),
                        const Divider(height: 12),
                        // ── 중복 정리 버튼 ──
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.cleaning_services_outlined, color: Colors.orange, size: 18),
                          ),
                          title: const Text('중복 데이터 정리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('동일한 현장명의 중복 항목 자동 제거', style: TextStyle(fontSize: 12)),
                          trailing: _deduping
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right, color: AppTheme.gray400),
                          onTap: _deduping ? null : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('중복 정리'),
                                content: const Text('동일한 이름의 중복 현장을 제거합니다.\n이 작업은 되돌릴 수 없습니다.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('정리'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true || !mounted) return;
                            setState(() => _deduping = true);
                            try {
                              final res = await ApiService.dedupSites();
                              if (!mounted) return;
                              showToast(context,
                                '중복 ${res['removed'] ?? 0}개 제거 완료 (현장 ${res['sites'] ?? 0}개)');
                            } catch (e) {
                              if (mounted) showToast(context, '실패: $e', isError: true);
                            } finally {
                              if (mounted) setState(() => _deduping = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // ── 앱 정보 ──────────────────────────────────────────
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.gray400, size: 18),
                      SizedBox(width: 8),
                      Text('앱 정보',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gray800)),
                    ],
                  ),
                  const Divider(height: 20),
                  _infoRow('앱 이름', '승강기 현장 관리 시스템'),
                  _infoRow('버전', 'v2.8.0'),
                  _infoRow('플랫폼', 'Web / Android'),
                  _infoRow('기능', '현장·승강기 관리, 검사·점검 기록'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 사용 방법 ─────────────────────────────────────────
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline, color: AppTheme.info, size: 18),
                      SizedBox(width: 8),
                      Text('사용 방법',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gray800)),
                    ],
                  ),
                  const Divider(height: 20),
                  _helpRow(Icons.dns, '1. API 서버 URL 입력 후 저장하세요'),
                  _helpRow(Icons.business, '2. 현장 관리에서 건물/현장을 등록하세요'),
                  _helpRow(Icons.elevator, '3. 각 현장에 승강기를 등록하세요'),
                  _helpRow(Icons.assignment, '4. 검사 관리에서 검사 이력을 기록하세요'),
                  _helpRow(Icons.warning_amber, '5. 지적사항을 등록하고 조치 현황을 관리하세요'),
                  _helpRow(Icons.calendar_month, '6. 월 점검 및 분기 점검 현황을 기록하세요'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray400))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, color: AppTheme.gray700))),
        ],
      ),
    );
  }

  Widget _helpRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray600))),
        ],
      ),
    );
  }
}

// ── 현재 연결 상태 카드 ─────────────────────────────────────────
class _ConnectionStatusCard extends StatefulWidget {
  @override
  State<_ConnectionStatusCard> createState() => _ConnectionStatusCardState();
}

class _ConnectionStatusCardState extends State<_ConnectionStatusCard> {
  bool _checking = false;
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (ApiService.needsSetup) {
      setState(() => _connected = false);
      return;
    }
    setState(() {
      _checking = true;
      _connected = null;
    });
    try {
      await ApiService.getDashboard();
      if (mounted) setState(() { _connected = true; _checking = false; });
    } catch (_) {
      if (mounted) setState(() { _connected = false; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = ApiService.baseUrl;
    Color bgColor;
    Color fgColor;
    IconData icon;
    String statusText;

    if (_checking) {
      bgColor = const Color(0xFFFFF9C4);
      fgColor = const Color(0xFFF57F17);
      icon = Icons.wifi_find;
      statusText = '연결 확인 중...';
    } else if (_connected == true) {
      bgColor = AppTheme.successLight;
      fgColor = AppTheme.success;
      icon = Icons.check_circle_outline;
      statusText = '정상 연결됨';
    } else {
      bgColor = AppTheme.dangerLight;
      fgColor = AppTheme.danger;
      icon = Icons.error_outline;
      statusText = url.isEmpty ? '서버 주소 미설정' : '연결 실패';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _checking
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: fgColor))
              : Icon(icon, color: fgColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fgColor),
                ),
                if (url.isNotEmpty)
                  Text(
                    url,
                    style: TextStyle(
                        fontSize: 11,
                        color: fgColor.withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 새로고침 버튼
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: fgColor),
            onPressed: _checking ? null : _check,
            tooltip: '연결 재확인',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
