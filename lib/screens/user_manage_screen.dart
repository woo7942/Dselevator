import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';

// ────────────────────────────────────────────────────────────
//  UserManageScreen  - 사용자 목록 + 탭별 접근 권한 관리
// ────────────────────────────────────────────────────────────
class UserManageScreen extends StatefulWidget {
  const UserManageScreen({super.key});

  @override
  State<UserManageScreen> createState() => _UserManageScreenState();
}

class _UserManageScreenState extends State<UserManageScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getUsers();
      setState(() {
        _users = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) showToast(context, '사용자 목록 오류: $e', isError: true);
    }
  }

  // 현재 유저의 tab_permissions 문자열 → Set<String>
  Set<String> _parsePerms(Map<String, dynamic> u) {
    final raw = u['tab_permissions'] as String?;
    if (raw == null || raw.isEmpty) return {};  // 비어있으면 → 모두허용(표시는 전체ON)
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  }

  // ── 사용자 추가 ─────────────────────────────────────────────
  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String role = 'user';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_add, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('사용자 추가', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '이름 (한글)',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '핀번호 (4~6자리)',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: '권한',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('일반 사용자')),
                  DropdownMenuItem(value: 'admin', child: Text('관리자')),
                ],
                onChanged: (v) => setS(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty || pin.isEmpty) {
                  showToast(context, '이름과 핀번호를 입력해주세요.', isError: true);
                  return;
                }
                if (pin.length < 4) {
                  showToast(context, '핀번호는 4자리 이상이어야 합니다.', isError: true);
                  return;
                }
                try {
                  await ApiService.createUser(name, pin, role);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadUsers();
                  if (mounted) showToast(context, '$name 사용자가 추가되었습니다.');
                } catch (e) {
                  if (mounted) showToast(context, '추가 실패: $e', isError: true);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 사용자 수정 (PIN/역할/활성화) ──────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final pinCtrl = TextEditingController();
    String role = user['role'] as String? ?? 'user';
    bool isActive = (user['is_active'] as int? ?? 1) == 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${user['name']} 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '새 핀번호 (변경 시만 입력)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: '권한', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('일반 사용자')),
                  DropdownMenuItem(value: 'admin', child: Text('관리자')),
                ],
                onChanged: (v) => setS(() => role = v!),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('활성 상태'),
                value: isActive,
                onChanged: (v) => setS(() => isActive = v),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final pin = pinCtrl.text.trim().isEmpty ? null : pinCtrl.text.trim();
                if (pin != null && pin.length < 4) {
                  showToast(context, '핀번호는 4자리 이상이어야 합니다.', isError: true);
                  return;
                }
                try {
                  await ApiService.updateUser(
                    user['id'] as int,
                    pin: pin,
                    role: role,
                    isActive: isActive ? 1 : 0,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadUsers();
                  if (mounted) showToast(context, '${user['name']} 정보가 수정되었습니다.');
                } catch (e) {
                  if (mounted) showToast(context, '수정 실패: $e', isError: true);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 탭 권한 설정 다이얼로그 ────────────────────────────────
  Future<void> _showPermissionDialog(Map<String, dynamic> user) async {
    final isAdmin = (user['role'] as String?) == 'admin';
    if (isAdmin) {
      showToast(context, '관리자는 모든 탭에 자동 접근 가능합니다.');
      return;
    }

    // 현재 권한 파싱 (비어있으면 모두 허용 = 전체 선택)
    final currentPerms = _parsePerms(user);
    final selected = <String>{};
    if (currentPerms.isEmpty) {
      // 미설정(=모두허용) → 전체 ON으로 표시
      selected.addAll(kAppTabs.map((t) => t.key));
    } else {
      selected.addAll(currentPerms);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        (user['name'] as String).isNotEmpty
                            ? (user['name'] as String)[0]
                            : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const Text('탭별 접근 권한 설정',
                              style: TextStyle(fontSize: 12, color: AppTheme.gray500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 4),
                // 안내 텍스트
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppTheme.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '허용된 탭만 사이드바에 표시됩니다. 모두 ON이면 전체 탭 접근 가능.',
                          style: const TextStyle(fontSize: 11, color: AppTheme.info),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 전체 선택/해제 버튼
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setS(() => selected.addAll(kAppTabs.map((t) => t.key))),
                      icon: const Icon(Icons.check_box_outlined, size: 15),
                      label: const Text('전체 선택', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setS(() => selected.clear()),
                      icon: const Icon(Icons.check_box_outline_blank, size: 15),
                      label: const Text('전체 해제', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 탭 목록 토글
                ...kAppTabs.map((tab) {
                  final isOn = selected.contains(tab.key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isOn
                          ? AppTheme.primary.withValues(alpha: 0.06)
                          : AppTheme.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOn
                            ? AppTheme.primary.withValues(alpha: 0.3)
                            : AppTheme.gray200,
                      ),
                    ),
                    child: SwitchListTile(
                      value: isOn,
                      onChanged: (v) => setS(() {
                        if (v) selected.add(tab.key);
                        else selected.remove(tab.key);
                      }),
                      title: Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOn ? AppTheme.primary : AppTheme.gray700,
                        ),
                      ),
                      secondary: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isOn
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : AppTheme.gray100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _tabIcon(tab.key),
                          size: 16,
                          color: isOn ? AppTheme.primary : AppTheme.gray400,
                        ),
                      ),
                      activeColor: AppTheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      dense: true,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 전체 선택 → null 저장(= 제한없음)
                      final allKeys = kAppTabs.map((t) => t.key).toSet();
                      final permStr = selected.containsAll(allKeys)
                          ? ''          // 모두 허용 = 빈 문자열
                          : selected.join(',');
                      try {
                        await ApiService.updateUser(
                          user['id'] as int,
                          tabPermissions: permStr,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadUsers();
                        if (mounted) showToast(context, '${user['name']} 권한이 저장되었습니다.');
                      } catch (e) {
                        if (mounted) showToast(context, '저장 실패: $e', isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('권한 저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 삭제 ────────────────────────────────────────────────────
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: '사용자 삭제',
      content: '${user['name']} 사용자를 삭제하시겠습니까?',
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteUser(user['id'] as int);
      await _loadUsers();
      if (mounted) showToast(context, '${user['name']} 사용자가 삭제되었습니다.');
    } catch (e) {
      if (mounted) showToast(context, '삭제 실패: $e', isError: true);
    }
  }

  // ── 탭 아이콘 ────────────────────────────────────────────────
  IconData _tabIcon(String key) {
    switch (key) {
      case 'dashboard':   return Icons.dashboard_outlined;
      case 'sites':       return Icons.business_outlined;
      case 'inspections': return Icons.assignment_outlined;
      case 'issues':      return Icons.warning_amber_outlined;
      case 'monthly':     return Icons.calendar_month_outlined;
      case 'quarterly':   return Icons.memory_outlined;
      default:            return Icons.tab_outlined;
    }
  }

  // ── 권한 요약 텍스트 ─────────────────────────────────────────
  String _permSummary(Map<String, dynamic> u) {
    if ((u['role'] as String?) == 'admin') return '전체 탭 (관리자)';
    final perms = _parsePerms(u);
    if (perms.isEmpty) return '전체 탭 허용';
    final labels = kAppTabs
        .where((t) => perms.contains(t.key))
        .map((t) => t.label)
        .join(', ');
    return labels.isEmpty ? '접근 불가' : labels;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: const Text('사용자 관리'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers, tooltip: '새로고침'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('사용자 추가'),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _users.isEmpty
              ? const EmptyWidget(message: '등록된 사용자가 없습니다.', icon: Icons.people_outline)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    final isActive = (u['is_active'] as int? ?? 1) == 1;
                    final isAdmin = u['role'] == 'admin';
                    final perms = _parsePerms(u);
                    final allAllowed = perms.isEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.gray200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 유저 헤더
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isAdmin
                                      ? AppTheme.primary
                                      : AppTheme.gray400,
                                  child: Text(
                                    (u['name'] as String).isNotEmpty
                                        ? (u['name'] as String)[0]
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            u['name'] as String? ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppTheme.gray800),
                                          ),
                                          const SizedBox(width: 7),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAdmin
                                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                                  : AppTheme.gray100,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isAdmin ? '관리자' : '일반',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isAdmin
                                                    ? AppTheme.primary
                                                    : AppTheme.gray500,
                                              ),
                                            ),
                                          ),
                                          if (!isActive) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.danger.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                '비활성',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.danger,
                                                    fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      // 권한 요약
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.tab_outlined,
                                            size: 12,
                                            color: isAdmin
                                                ? AppTheme.primary
                                                : allAllowed
                                                    ? AppTheme.success
                                                    : AppTheme.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _permSummary(u),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isAdmin
                                                    ? AppTheme.primary
                                                    : allAllowed
                                                        ? AppTheme.success
                                                        : AppTheme.warning,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 액션 버튼
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 탭 권한 버튼 (일반 사용자만)
                                    if (!isAdmin)
                                      Tooltip(
                                        message: '탭 권한 설정',
                                        child: InkWell(
                                          onTap: () => _showPermissionDialog(u),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.primary.withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.tune, size: 14, color: AppTheme.primary),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  '권한',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.primary,
                                                      fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: AppTheme.gray500, size: 18),
                                      onPressed: () => _showEditDialog(u),
                                      tooltip: '수정',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppTheme.danger, size: 18),
                                      onPressed: () => _deleteUser(u),
                                      tooltip: '삭제',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 탭 권한 미리보기 바 (일반 사용자)
                          if (!isAdmin) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '탭 접근 권한',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.gray400,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 5,
                                    runSpacing: 5,
                                    children: kAppTabs.map((tab) {
                                      final allowed = allAllowed || perms.contains(tab.key);
                                      return GestureDetector(
                                        onTap: () => _showPermissionDialog(u),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: allowed
                                                ? AppTheme.success.withValues(alpha: 0.1)
                                                : AppTheme.gray100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: allowed
                                                  ? AppTheme.success.withValues(alpha: 0.4)
                                                  : AppTheme.gray200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                allowed ? Icons.check_circle : Icons.block,
                                                size: 10,
                                                color: allowed
                                                    ? AppTheme.success
                                                    : AppTheme.gray300,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                tab.label,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: allowed
                                                      ? AppTheme.success
                                                      : AppTheme.gray400,
                                                  fontWeight: allowed
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
