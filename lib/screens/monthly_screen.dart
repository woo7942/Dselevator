import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/check.dart';
import '../models/site.dart';

class MonthlyScreen extends StatefulWidget {
  const MonthlyScreen({super.key});

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<MonthlyCheck> _checks = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _statusFilter = '';

  // 현장 목록
  List<Site> _sites = [];
  Site? _filterSite;
  bool _sitesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
    _load();
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      final sites = await ApiService.getSites();
      if (mounted) setState(() { _sites = sites; _sitesLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _sitesLoaded = true);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final checks = await ApiService.getMonthlyChecks(
        year: _year,
        month: _month,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
      );
      if (mounted) setState(() { _checks = checks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // 현장 필터 적용
  List<MonthlyCheck> get _filtered {
    if (_filterSite == null) return _checks;
    return _checks.where((c) => c.siteId == _filterSite!.id).toList();
  }

  List<MonthlyCheck> get _pending =>
      _filtered.where((c) => c.status != '완료').toList();
  List<MonthlyCheck> get _done =>
      _filtered.where((c) => c.status == '완료').toList();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('월 점검'),
        actions: [
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('새로고침', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.gray600),
          ),
          const SizedBox(width: 2),
          TextButton.icon(
            onPressed: () => _openForm(null),
            icon: const Icon(Icons.add, size: 15),
            label: const Text('점검 등록', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.gray400,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions, size: 16),
                  const SizedBox(width: 6),
                  Text('점검 예정'),
                  if (!_loading && _pending.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _countBadge(_pending.length, AppTheme.warning),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16),
                  const SizedBox(width: 6),
                  Text('점검 완료'),
                  if (!_loading && _done.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _countBadge(_done.length, AppTheme.success),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildTabContent(_pending, isPending: true),
                _buildTabContent(_done, isPending: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        children: [
          // 연월 선택
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  setState(() {
                    if (_month == 1) { _month = 12; _year--; } else _month--;
                  });
                  _load();
                },
              ),
              Expanded(
                child: Center(
                  child: Text('$_year년 $_month월',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  setState(() {
                    if (_month == 12) { _month = 1; _year++; } else _month++;
                  });
                  _load();
                },
              ),
              TextButton(
                onPressed: () {
                  setState(() { _year = DateTime.now().year; _month = DateTime.now().month; });
                  _load();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('이번달', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 현장 필터 + 상태 필터
          Row(
            children: [
              // 현장 검색/선택
              Expanded(
                child: SiteSearchField(
                  sites: _sites,
                  selected: _filterSite,
                  label: '전체 현장',
                  isLoading: !_sitesLoaded,
                  onChanged: (s) => setState(() => _filterSite = s),
                ),
              ),
              const SizedBox(width: 8),
              // 상태 필터
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.gray200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _statusFilter.isEmpty ? '' : _statusFilter,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray700),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('전체상태')),
                    DropdownMenuItem(value: '예정', child: Text('예정')),
                    DropdownMenuItem(value: '완료', child: Text('완료')),
                    DropdownMenuItem(value: '불가', child: Text('불가')),
                    DropdownMenuItem(value: '이월', child: Text('이월')),
                  ],
                  onChanged: (v) { _statusFilter = v ?? ''; _load(); },
                ),
              ),
            ],
          ),
          // 진행률 바
          if (!_loading && _filtered.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '완료 ${_done.length} / 전체 ${_filtered.length}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _filtered.isNotEmpty ? _done.length / _filtered.length : 0,
                      backgroundColor: AppTheme.gray200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filtered.isEmpty ? 0 : (_done.length / _filtered.length * 100).round()}%',
                  style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<MonthlyCheck> items, {required bool isPending}) {
    if (_loading) return const LoadingWidget();
    if (_error != null) return ErrorWidget2(message: _error!, onRetry: _load);
    if (items.isEmpty) {
      return EmptyWidget(
        message: isPending ? '점검 예정 항목이 없습니다' : '완료된 점검이 없습니다',
        icon: isPending ? Icons.pending_actions : Icons.check_circle_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCheckCard(items[i], isPending: isPending),
      ),
    );
  }

  Widget _buildCheckCard(MonthlyCheck check, {required bool isPending}) {
    final hasIssue = check.overallResult != '양호';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? AppTheme.gray200 : AppTheme.success.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 상태 아이콘
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppTheme.warning.withValues(alpha: 0.1)
                            : AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPending ? Icons.pending_actions : Icons.check_circle,
                        size: 20,
                        color: isPending ? AppTheme.warning : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check.siteName != null && check.siteName!.isNotEmpty
                                ? check.siteName!
                                : '현장 미상',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.gray800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            check.elevatorName ?? check.elevatorId.toString(),
                            style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                          ),
                        ],
                      ),
                    ),
                    // 진행중일 때 별도 뱃지 표시
                    if (check.status == '진행중') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('진행중', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      StatusBadge(status: check.status),
                      const SizedBox(width: 4),
                    ],
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _openForm(check);
                        if (v == 'start') _startCheck(check);
                        if (v == 'complete') _completeCheck(check);
                        if (v == 'delete') _delete(check);
                      },
                      itemBuilder: (_) => [
                        if (isPending)
                          const PopupMenuItem(value: 'start', child: Row(children: [Icon(Icons.play_circle_outline, size: 16, color: AppTheme.primary), SizedBox(width: 8), Text('점검 시작')])),
                        if (!isPending || check.status == '진행중')
                          const PopupMenuItem(value: 'complete', child: Row(children: [Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success), SizedBox(width: 8), Text('점검 완료')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: AppTheme.gray500), SizedBox(width: 8), Text('수정')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppTheme.danger), SizedBox(width: 8), Text('삭제', style: TextStyle(color: AppTheme.danger))])),
                      ],
                      child: const Icon(Icons.more_vert, size: 18, color: AppTheme.gray400),
                    ),
                  ],
                ),
                // 날짜/점검자 정보
                if (check.checkDate != null || check.checkerName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (check.checkDate != null) ...[
                        const Icon(Icons.calendar_today, size: 11, color: AppTheme.gray400),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDateTime(check.checkDate),
                          style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (check.checkerName != null) ...[
                        const Icon(Icons.person_outline, size: 11, color: AppTheme.gray400),
                        const SizedBox(width: 3),
                        Text(check.checkerName!, style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                      ],
                    ],
                  ),
                ],
                // 코멘트 (완료시 입력한 내용)
                if (check.nextAction != null && check.nextAction!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gray200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.comment_outlined, size: 12, color: AppTheme.gray400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            check.nextAction!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 이슈 표시
                if (hasIssue || check.issuesFound != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: check.overallResult == '긴급조치필요' ? AppTheme.dangerLight : AppTheme.warningLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: check.overallResult == '긴급조치필요' ? AppTheme.danger : AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '종합: ${check.overallResult}',
                          style: TextStyle(
                            fontSize: 11,
                            color: check.overallResult == '긴급조치필요' ? AppTheme.danger : AppTheme.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (check.issuesFound != null) ...[
                          const Text(' · ', style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
                          Expanded(
                            child: Text(
                              check.issuesFound!,
                              style: const TextStyle(fontSize: 11, color: AppTheme.gray600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 점검 예정/진행중 카드 하단 액션 버튼
          if (check.status != '완료') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: check.status == '진행중'
                  // 진행중: 점검 끝 버튼만 표시
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _completeCheck(check),
                        icon: const Icon(Icons.flag_rounded, size: 15),
                        label: const Text('점검 끝', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: Size.zero,
                        ),
                      ),
                    )
                  // 예정/불가/이월: 점검 시작 버튼만 표시
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startCheck(check),
                        icon: const Icon(Icons.play_arrow_rounded, size: 15),
                        label: const Text('점검 시작', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDateTime(String? s) {
    if (s == null || s.isEmpty) return '-';
    // datetime 포함하면 날짜+시간 표시
    if (s.length >= 16) {
      try {
        final dt = DateTime.parse(s);
        return DateFormat('MM/dd HH:mm').format(dt);
      } catch (_) {}
    }
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  // 점검 시작: 현재 날짜+시간 자동 입력, 상태 → 진행중
  Future<void> _startCheck(MonthlyCheck check) async {
    if (check.status == '진행중') {
      if (mounted) showToast(context, '이미 진행중인 점검입니다.');
      return;
    }
    final now = DateTime.now();
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    try {
      final updated = MonthlyCheck(
        id: check.id,
        elevatorId: check.elevatorId,
        siteId: check.siteId,
        checkYear: check.checkYear,
        checkMonth: check.checkMonth,
        checkDate: nowStr,          // 시작 날짜/시간 자동 기록
        checkerName: check.checkerName,
        status: '진행중',           // 상태 → 진행중
        doorCheck: check.doorCheck ?? '양호',
        motorCheck: check.motorCheck ?? '양호',
        brakeCheck: check.brakeCheck ?? '양호',
        ropeCheck: check.ropeCheck ?? '양호',
        safetyDeviceCheck: check.safetyDeviceCheck ?? '양호',
        lightingCheck: check.lightingCheck ?? '양호',
        emergencyCheck: check.emergencyCheck ?? '양호',
        overallResult: check.overallResult ?? '양호',
        issuesFound: check.issuesFound,
        actionsTaken: check.actionsTaken,
        nextAction: check.nextAction,
      );
      await ApiService.updateMonthlyCheck(check.id!, updated);
      if (mounted) {
        showToast(context, '점검 시작! (${DateFormat('MM/dd HH:mm').format(now)}) — "점검 끝" 버튼으로 완료하세요');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  // 점검 완료: 완료시간 자동 + 코멘트 입력 다이얼로그
  Future<void> _completeCheck(MonthlyCheck check) async {
    final commentCtrl = TextEditingController();
    final overallResult = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CompleteDialog(check: check, commentCtrl: commentCtrl),
    );
    if (overallResult == null) return;

    final now = DateTime.now();
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    try {
      final updated = MonthlyCheck(
        id: check.id,
        elevatorId: check.elevatorId,
        siteId: check.siteId,
        checkYear: check.checkYear,
        checkMonth: check.checkMonth,
        checkDate: check.checkDate ?? nowStr,  // 기존 시작시간 유지, 없으면 지금
        checkerName: check.checkerName,
        status: '완료',
        doorCheck: check.doorCheck ?? '양호',
        motorCheck: check.motorCheck ?? '양호',
        brakeCheck: check.brakeCheck ?? '양호',
        ropeCheck: check.ropeCheck ?? '양호',
        safetyDeviceCheck: check.safetyDeviceCheck ?? '양호',
        lightingCheck: check.lightingCheck ?? '양호',
        emergencyCheck: check.emergencyCheck ?? '양호',
        overallResult: overallResult['result'] ?? '양호',
        issuesFound: check.issuesFound,
        actionsTaken: check.actionsTaken,
        nextAction: overallResult['comment'],  // 코멘트 → nextAction 필드 활용
      );
      await ApiService.updateMonthlyCheck(check.id!, updated);
      if (mounted) {
        showToast(context, '점검 완료 처리되었습니다! (${DateFormat('HH:mm').format(now)})');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _openForm(MonthlyCheck? check) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => MonthlyCheckFormSheet(
        check: check,
        defaultYear: _year,
        defaultMonth: _month,
        sites: _sites,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(MonthlyCheck check) async {
    final ok = await ConfirmDialog.show(context, title: '월 점검 삭제', content: '이 월 점검 기록을 삭제하시겠습니까?');
    if (ok != true) return;
    try {
      await ApiService.deleteMonthlyCheck(check.id!);
      if (mounted) { showToast(context, '점검 기록이 삭제되었습니다.'); _load(); }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ── 점검 완료 다이얼로그 ──────────────────────────────────────
class _CompleteDialog extends StatefulWidget {
  final MonthlyCheck check;
  final TextEditingController commentCtrl;
  const _CompleteDialog({required this.check, required this.commentCtrl});

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  String _result = '양호';
  final _now = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('점검 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          widget.check.siteName ?? '현장',
                          style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),
              // 완료 시간 자동 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '완료 시각: ${DateFormat('yyyy-MM-dd HH:mm').format(_now)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 종합 결과 선택
              const Text('종합 결과', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _resultBtn('양호', AppTheme.success, Icons.check_circle_outline),
                  const SizedBox(width: 6),
                  _resultBtn('불량사항있음', AppTheme.warning, Icons.warning_amber_outlined),
                  const SizedBox(width: 6),
                  _resultBtn('긴급조치필요', AppTheme.danger, Icons.error_outline),
                ],
              ),
              const SizedBox(height: 16),
              // 코멘트 입력
              const Text('점검 코멘트', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray600)),
              const SizedBox(height: 8),
              TextField(
                controller: widget.commentCtrl,
                decoration: InputDecoration(
                  hintText: '점검 중 특이사항이나 메모를 입력하세요',
                  filled: true,
                  fillColor: AppTheme.gray50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.gray200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.gray200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              // 완료 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'result': _result,
                      'comment': widget.commentCtrl.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('점검 완료 저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultBtn(String label, Color color, IconData icon) {
    final sel = _result == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _result = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.12) : AppTheme.gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? color : AppTheme.gray200, width: sel ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: sel ? color : AppTheme.gray400),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: sel ? color : AppTheme.gray400,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 월 점검 폼 시트 ──────────────────────────────────────────
class MonthlyCheckFormSheet extends StatefulWidget {
  final MonthlyCheck? check;
  final int defaultYear;
  final int defaultMonth;
  final List<Site> sites;
  const MonthlyCheckFormSheet({
    super.key,
    this.check,
    required this.defaultYear,
    required this.defaultMonth,
    this.sites = const [],
  });

  @override
  State<MonthlyCheckFormSheet> createState() => _MonthlyCheckFormSheetState();
}

class _MonthlyCheckFormSheetState extends State<MonthlyCheckFormSheet> {
  final _formKey = GlobalKey<FormState>();
  List<Site> _sites = [];
  List<Elevator> _elevators = [];
  Site? _selectedSite;
  int? _selectedElevatorId;
  late int _year = widget.check?.checkYear ?? widget.defaultYear;
  late int _month = widget.check?.checkMonth ?? widget.defaultMonth;
  late String _status = widget.check?.status ?? '예정';
  late String _overallResult = widget.check?.overallResult ?? '양호';
  late final _dateCtrl = TextEditingController(text: widget.check?.checkDate);
  late final _checkerCtrl = TextEditingController(text: widget.check?.checkerName);
  late final _issuesCtrl = TextEditingController(text: widget.check?.issuesFound);
  late final _actionsCtrl = TextEditingController(text: widget.check?.actionsTaken);
  late final _commentCtrl = TextEditingController(text: widget.check?.nextAction);
  bool _saving = false;

  final _checkItems = {
    'door_check': '도어', 'motor_check': '모터', 'brake_check': '브레이크',
    'rope_check': '로프', 'safety_device_check': '안전장치',
    'lighting_check': '조명', 'emergency_check': '비상설비',
  };
  late final Map<String, String> _checkValues = {
    'door_check': widget.check?.doorCheck ?? '양호',
    'motor_check': widget.check?.motorCheck ?? '양호',
    'brake_check': widget.check?.brakeCheck ?? '양호',
    'rope_check': widget.check?.ropeCheck ?? '양호',
    'safety_device_check': widget.check?.safetyDeviceCheck ?? '양호',
    'lighting_check': widget.check?.lightingCheck ?? '양호',
    'emergency_check': widget.check?.emergencyCheck ?? '양호',
  };

  @override
  void initState() {
    super.initState();
    _sites = List.from(widget.sites);
    _selectedElevatorId = widget.check?.elevatorId;

    if (_sites.isEmpty) {
      _loadSites();
    } else {
      // 기존 점검 수정 시 현장 찾기
      if (widget.check != null) {
        _selectedSite = _sites.firstWhere(
          (s) => s.id == widget.check!.siteId,
          orElse: () => _sites.first,
        );
        _loadElevators(_selectedSite!.id!);
      }
    }
  }

  Future<void> _loadSites() async {
    try {
      final sites = await ApiService.getSites();
      if (mounted) {
        setState(() => _sites = sites);
        if (widget.check != null && sites.isNotEmpty) {
          _selectedSite = sites.firstWhere(
            (s) => s.id == widget.check!.siteId,
            orElse: () => sites.first,
          );
          _loadElevators(_selectedSite!.id!);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadElevators(int siteId) async {
    try {
      final elevs = await ApiService.getSiteElevators(siteId);
      if (mounted) {
        setState(() {
          _elevators = elevs;
          if (widget.check == null && elevs.isNotEmpty) {
            _selectedElevatorId = elevs.first.id;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(widget.check == null ? '월 점검 등록' : '월 점검 수정',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 현장 선택 (검색 가능)
                      const Text('현장 *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray600)),
                      const SizedBox(height: 6),
                      SiteSearchField(
                        sites: _sites,
                        selected: _selectedSite,
                        label: '현장 선택',
                        onChanged: (s) {
                          setState(() {
                            _selectedSite = s;
                            _elevators = [];
                            _selectedElevatorId = null;
                          });
                          if (s?.id != null) _loadElevators(s!.id!);
                        },
                      ),
                      const SizedBox(height: 10),
                      // 승강기 선택
                      if (_elevators.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: _selectedElevatorId,
                          decoration: const InputDecoration(
                            labelText: '승강기 *',
                            prefixIcon: Icon(Icons.elevator_outlined, size: 18),
                          ),
                          items: _elevators.map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.displayName, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          validator: (v) => v == null ? '승강기를 선택하세요' : null,
                          onChanged: (v) => setState(() => _selectedElevatorId = v),
                        )
                      else if (_selectedSite != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('승강기를 불러오는 중...', style: TextStyle(fontSize: 12, color: AppTheme.gray400)),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _dateField(_dateCtrl, '점검일')),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            controller: _checkerCtrl,
                            decoration: const InputDecoration(labelText: '점검자'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(labelText: '상태'),
                            items: ['예정', '진행중', '완료', '불가', '이월']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _status = v ?? '예정'),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _overallResult,
                            decoration: const InputDecoration(labelText: '종합 결과'),
                            items: ['양호', '불량사항있음', '긴급조치필요']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _overallResult = v ?? '양호'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('점검 항목',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
                      const SizedBox(height: 8),
                      ..._checkItems.entries.map((e) => _buildCheckItemRow(e.key, e.value)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _issuesCtrl,
                        decoration: const InputDecoration(labelText: '발견된 문제점'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _actionsCtrl,
                        decoration: const InputDecoration(labelText: '즉시 조치 내용'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          labelText: '코멘트/메모',
                          prefixIcon: Icon(Icons.comment_outlined, size: 16),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.check == null ? '등록' : '수정'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItemRow(String key, String label) {
    final val = _checkValues[key] ?? '양호';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray600))),
          ...['양호', '불량', '해당없음'].map((opt) {
            final selected = val == opt;
            Color selColor;
            if (opt == '양호') selColor = AppTheme.success;
            else if (opt == '불량') selColor = AppTheme.danger;
            else selColor = AppTheme.gray400;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _checkValues[key] = opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? selColor.withValues(alpha: 0.1) : AppTheme.gray100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? selColor : Colors.transparent),
                  ),
                  child: Text(opt,
                    style: TextStyle(fontSize: 11, color: selected ? selColor : AppTheme.gray500,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.normal)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2030),
          );
          if (date != null) ctrl.text = date.toIso8601String().substring(0, 10);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSite == null) {
      showToast(context, '현장을 선택해주세요', isError: true);
      return;
    }
    if (_selectedElevatorId == null) {
      showToast(context, '승강기를 선택해주세요', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final check = MonthlyCheck(
        id: widget.check?.id,
        elevatorId: _selectedElevatorId!,
        siteId: _selectedSite!.id!,
        checkYear: _year,
        checkMonth: _month,
        checkDate: _dateCtrl.text.isNotEmpty ? _dateCtrl.text : null,
        checkerName: _checkerCtrl.text.isNotEmpty ? _checkerCtrl.text : null,
        status: _status,
        doorCheck: _checkValues['door_check'] ?? '양호',
        motorCheck: _checkValues['motor_check'] ?? '양호',
        brakeCheck: _checkValues['brake_check'] ?? '양호',
        ropeCheck: _checkValues['rope_check'] ?? '양호',
        safetyDeviceCheck: _checkValues['safety_device_check'] ?? '양호',
        lightingCheck: _checkValues['lighting_check'] ?? '양호',
        emergencyCheck: _checkValues['emergency_check'] ?? '양호',
        overallResult: _overallResult,
        issuesFound: _issuesCtrl.text.isNotEmpty ? _issuesCtrl.text : null,
        actionsTaken: _actionsCtrl.text.isNotEmpty ? _actionsCtrl.text : null,
        nextAction: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      );
      if (widget.check == null) {
        await ApiService.createMonthlyCheck(check);
      } else {
        await ApiService.updateMonthlyCheck(widget.check!.id!, check);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose(); _checkerCtrl.dispose();
    _issuesCtrl.dispose(); _actionsCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }
}
