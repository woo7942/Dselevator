import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _urlCtrl = TextEditingController(text: ApiService.baseUrl);
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API 서버 설정
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('API 서버 설정',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('승강기 관리 백엔드 API 서버 주소를 입력하세요.',
                    style: TextStyle(fontSize: 12, color: AppTheme.gray500)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API 서버 URL',
                      hintText: 'https://8787-itvxovwjc5r0tvfptlnxw-b32ec7bb.sandbox.novita.ai',
                      prefixIcon: Icon(Icons.link, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_testResult != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _testResult!.startsWith('✅') ? AppTheme.successLight : AppTheme.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testResult!.startsWith('✅') ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
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
                          onPressed: _saving ? null : _saveUrl,
                          icon: _saving
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

            // 앱 정보
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.gray400, size: 18),
                      SizedBox(width: 8),
                      Text('앱 정보',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                    ],
                  ),
                  const Divider(height: 20),
                  _infoRow('앱 이름', '승강기 현장 관리 시스템'),
                  _infoRow('버전', 'v1.0.0'),
                  _infoRow('개발', 'Elevator Manager Team'),
                  _infoRow('현장/승강기 관리', '검사 이력 및 점검 기록 관리'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 빠른 도움말
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline, color: AppTheme.info, size: 18),
                      SizedBox(width: 8),
                      Text('사용 방법',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                    ],
                  ),
                  const Divider(height: 20),
                  _helpRow(Icons.dns, '1. 위 API 서버 URL에 백엔드 서버 주소를 입력하세요'),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray400))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.gray700))),
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.gray600))),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      await ApiService.setBaseUrl(_urlCtrl.text);
      await ApiService.getDashboard();
      if (mounted) setState(() => _testResult = '✅ 연결 성공! API 서버에 정상 접속되었습니다.');
    } catch (e) {
      if (mounted) setState(() => _testResult = '❌ 연결 실패: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveUrl() async {
    setState(() => _saving = true);
    try {
      await ApiService.setBaseUrl(_urlCtrl.text);
      if (mounted) {
        showToast(context, 'API 서버 주소가 저장되었습니다.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }
}
