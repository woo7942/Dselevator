import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import '../utils/theme.dart';
import '../utils/image_picker_web.dart' if (dart.library.io) '../utils/image_picker_native.dart' as img_picker;
import '../utils/image_picker_util.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/inspection.dart';
import '../models/site.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<InspectionIssue> _issues = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';
  String _severityFilter = '';
  // 그룹 보기 모드: 'elevator' | 'site' | 'list'
  String _groupMode = 'elevator';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final issues = await ApiService.getIssues(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        severity: _severityFilter.isNotEmpty ? _severityFilter : null,
      );
      if (mounted) setState(() { _issues = issues; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── 통계 계산 ──────────────────────────────────────────────
  Map<String, int> get _stats {
    return {
      '전체': _issues.length,
      '미조치': _issues.where((i) => i.status == '미조치').length,
      '조치중': _issues.where((i) => i.status == '조치중').length,
      '중결함': _issues.where((i) => i.severity == '중결함').length,
      '경결함': _issues.where((i) => i.severity == '경결함').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('검사 지적사항'),
            if (_issues.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${stats['전체']}',
                  style: const TextStyle(
                    fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.gray800,
        elevation: 0,
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
            label: const Text('지적 등록', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.gray400,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 14),
                      SizedBox(width: 4),
                      Text('목록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sms_outlined, size: 14),
                      SizedBox(width: 4),
                      Text('문자 등록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 14),
                      SizedBox(width: 4),
                      Text('파일 등록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── 탭 1: 목록 ────────────────────────────────────────
          Column(
            children: [
              _buildStatsBar(stats),
              _buildFilters(),
              Expanded(
                child: _loading
                    ? const LoadingWidget()
                    : _error != null
                        ? ErrorWidget2(message: _error!, onRetry: _load)
                        : _buildIssueList(),
              ),
            ],
          ),
          // ── 탭 2: 문자 등록 ───────────────────────────────────
          IssuesSmsParserView(onRegistered: () {
            _load();
            _tabCtrl.animateTo(0);
          }),
          // ── 탭 3: 파일 등록 ───────────────────────────────────
          IssuesFileParserView(onRegistered: () {
            _load();
            _tabCtrl.animateTo(0);
          }),
        ],
      ),
    );
  }

  // ── 통계 바 ────────────────────────────────────────────────
  Widget _buildStatsBar(Map<String, int> stats) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _statChip('전체', stats['전체'] ?? 0, AppTheme.gray500),
          const SizedBox(width: 6),
          _statChip('미조치', stats['미조치'] ?? 0, AppTheme.danger),
          const SizedBox(width: 6),
          _statChip('조치중', stats['조치중'] ?? 0, AppTheme.warning),
          const Spacer(),
          // 그룹 모드 전환
          _groupToggle(),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$label $count',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _groupToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _groupBtn('elevator', Icons.elevator_outlined, '호기별'),
          _groupBtn('site', Icons.business_outlined, '현장별'),
          _groupBtn('list', Icons.view_list_outlined, '전체'),
        ],
      ),
    );
  }

  Widget _groupBtn(String mode, IconData icon, String label) {
    final active = _groupMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _groupMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : AppTheme.gray400),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppTheme.gray400)),
          ],
        ),
      ),
    );
  }

  // ── 필터 ──────────────────────────────────────────────────
  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: _statusFilter.isEmpty ? '' : _statusFilter,
              isExpanded: true,
              underline: const SizedBox(),
              isDense: true,
              items: const [
                DropdownMenuItem(value: '', child: Text('전체 상태', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '미조치', child: Text('미조치', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '조치중', child: Text('조치중', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '조치완료', child: Text('조치완료', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '재검사필요', child: Text('재검사필요', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) { setState(() => _statusFilter = v ?? ''); _load(); },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _severityFilter.isEmpty ? '' : _severityFilter,
              isExpanded: true,
              underline: const SizedBox(),
              isDense: true,
              items: const [
                DropdownMenuItem(value: '', child: Text('전체 심각도', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '중결함', child: Text('중결함', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '경결함', child: Text('경결함', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: '권고사항', child: Text('권고사항', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) { setState(() => _severityFilter = v ?? ''); _load(); },
            ),
          ),
        ],
      ),
    );
  }

  // ── 이슈 목록 (그룹 모드) ────────────────────────────────────
  Widget _buildIssueList() {
    if (_issues.isEmpty) {
      return const EmptyWidget(message: '지적사항이 없습니다 ✓', icon: Icons.check_circle_outline);
    }
    switch (_groupMode) {
      case 'elevator': return _buildGroupedByElevator();
      case 'site': return _buildGroupedBySite();
      default: return _buildFlatList();
    }
  }

  // 호기별 그룹핑
  Widget _buildGroupedByElevator() {
    final Map<String, List<InspectionIssue>> grouped = {};
    for (final issue in _issues) {
      final key = '${issue.siteId}_${issue.elevatorId}';
      grouped.putIfAbsent(key, () => []).add(issue);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aIssues = grouped[a]!;
        final bIssues = grouped[b]!;
        final aHasCritical = aIssues.any((i) => i.severity == '중결함') ? 1 : 0;
        final bHasCritical = bIssues.any((i) => i.severity == '중결함') ? 1 : 0;
        if (bHasCritical != aHasCritical) return bHasCritical - aHasCritical;
        return bIssues.length - aIssues.length;
      });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: sortedKeys.length,
        itemBuilder: (_, i) {
          final issues = grouped[sortedKeys[i]]!;
          final sample = issues.first;
          return _buildElevatorGroup(
            siteName: sample.siteName ?? '현장 미상',
            elevatorName: sample.elevatorName ?? sample.elevatorNo ?? '승강기',
            issues: issues,
          );
        },
      ),
    );
  }

  // 현장별 그룹핑
  Widget _buildGroupedBySite() {
    final Map<int, List<InspectionIssue>> grouped = {};
    for (final issue in _issues) {
      grouped.putIfAbsent(issue.siteId, () => []).add(issue);
    }
    final sortedSiteIds = grouped.keys.toList()
      ..sort((a, b) => (grouped[b]!.length) - (grouped[a]!.length));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: sortedSiteIds.length,
        itemBuilder: (_, i) {
          final siteId = sortedSiteIds[i];
          final issues = grouped[siteId]!;
          return _buildSiteGroup(
            siteName: issues.first.siteName ?? '현장 미상',
            issues: issues,
          );
        },
      ),
    );
  }

  // 전체 목록 (날짜순)
  Widget _buildFlatList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _issues.length,
        itemBuilder: (_, i) => _buildIssueCard(_issues[i]),
      ),
    );
  }

  // ── 호기별 그룹 카드 ─────────────────────────────────────
  Widget _buildElevatorGroup({
    required String siteName,
    required String elevatorName,
    required List<InspectionIssue> issues,
  }) {
    final criticalCount = issues.where((i) => i.severity == '중결함').length;
    final unresolved = issues.where((i) => i.status != '조치완료').length;
    final hasUrgent = criticalCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasUrgent
            ? Border.all(color: AppTheme.danger.withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: AppTheme.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: hasUrgent || issues.length <= 2,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: hasUrgent
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.elevator_outlined,
              color: hasUrgent ? AppTheme.danger : AppTheme.primary,
              size: 22,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(siteName,
                style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
              Text(elevatorName,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (criticalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('중결함 $criticalCount',
                    style: const TextStyle(
                      fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: unresolved > 0 ? AppTheme.warningLight : AppTheme.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('미조치 $unresolved',
                  style: TextStyle(
                    fontSize: 10,
                    color: unresolved > 0 ? AppTheme.warning : AppTheme.success,
                    fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18, color: AppTheme.gray400),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            ...issues.asMap().entries.map((e) =>
              _buildIssueRow(e.value, index: e.key + 1)),
          ],
        ),
      ),
    );
  }

  // ── 현장별 그룹 카드 ─────────────────────────────────────
  Widget _buildSiteGroup({
    required String siteName,
    required List<InspectionIssue> issues,
  }) {
    final criticalCount = issues.where((i) => i.severity == '중결함').length;
    final unresolved = issues.where((i) => i.status != '조치완료').length;
    // 호기별 재그룹
    final Map<int, List<InspectionIssue>> byElev = {};
    for (final issue in issues) {
      byElev.putIfAbsent(issue.elevatorId, () => []).add(issue);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: criticalCount > 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business_outlined, color: AppTheme.primary, size: 22),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(siteName,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
              Text('${byElev.length}개 호기  ·  총 ${issues.length}건',
                style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (criticalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerLight, borderRadius: BorderRadius.circular(12)),
                  child: Text('중결함 $criticalCount',
                    style: const TextStyle(
                      fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: unresolved > 0 ? AppTheme.warningLight : AppTheme.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('미조치 $unresolved',
                  style: TextStyle(
                    fontSize: 10,
                    color: unresolved > 0 ? AppTheme.warning : AppTheme.success,
                    fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.expand_more, size: 18, color: AppTheme.gray400),
            ],
          ),
          children: [
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 4),
            // 호기별 소그룹
            ...byElev.entries.map((e) {
              final elevIssues = e.value;
              final elevName = elevIssues.first.elevatorName ??
                  elevIssues.first.elevatorNo ?? '승강기';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 3, height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.info,
                            borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 6),
                        Text(elevName,
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: AppTheme.gray600)),
                        const SizedBox(width: 6),
                        Text('${elevIssues.length}건',
                          style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                      ],
                    ),
                  ),
                  ...elevIssues.asMap().entries.map((en) =>
                    _buildIssueRow(en.value, index: en.key + 1)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── 개별 이슈 행 (그룹 내부) ──────────────────────────────
  Widget _buildIssueRow(InspectionIssue issue, {int index = 1}) {
    final severityColor = issue.severity == '중결함'
        ? AppTheme.danger
        : issue.severity == '경결함'
            ? AppTheme.warning
            : AppTheme.gray400;
    final statusColor = issue.status == '조치완료'
        ? AppTheme.success
        : issue.status == '조치중'
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: severityColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
                child: Center(
                  child: Text('$index',
                    style: TextStyle(
                      fontSize: 10, color: severityColor, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              SeverityBadge(severity: issue.severity),
              const SizedBox(width: 4),
              StatusBadge(status: issue.status),
              const Spacer(),
              if (issue.deadline != null)
                Row(children: [
                  const Icon(Icons.schedule, size: 11, color: AppTheme.gray400),
                  const SizedBox(width: 2),
                  Text(fmtDate(issue.deadline),
                    style: const TextStyle(fontSize: 10, color: AppTheme.gray400)),
                ]),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showIssueMenu(issue),
                child: const Icon(Icons.more_vert, size: 16, color: AppTheme.gray400),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(issue.issueDescription,
            style: const TextStyle(
              fontSize: 12, color: AppTheme.gray800, fontWeight: FontWeight.w500)),
          if (issue.issueCategory != null || issue.legalBasis != null) ...[
            const SizedBox(height: 3),
            Row(children: [
              if (issue.issueCategory != null)
                _miniChip(Icons.folder_outlined, issue.issueCategory!, AppTheme.gray400),
              if (issue.legalBasis != null) ...[
                const SizedBox(width: 6),
                _miniChip(Icons.gavel_outlined, issue.legalBasis!, AppTheme.info),
              ],
            ]),
          ],
          if (issue.actionTaken != null) ...[
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.check_circle_outline, size: 11, color: AppTheme.success),
              const SizedBox(width: 3),
              Expanded(child: Text('조치: ${issue.actionTaken}',
                style: const TextStyle(fontSize: 11, color: AppTheme.success))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  // ── 기존 카드형 (전체 목록 모드) ──────────────────────────
  Widget _buildIssueCard(InspectionIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SeverityBadge(severity: issue.severity),
              const SizedBox(width: 6),
              StatusBadge(status: issue.status),
              const Spacer(),
              if (issue.deadline != null)
                Row(children: [
                  const Icon(Icons.schedule, size: 12, color: AppTheme.gray400),
                  const SizedBox(width: 3),
                  Text(fmtDate(issue.deadline),
                    style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                ]),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showIssueMenu(issue),
                child: const Icon(Icons.more_vert, size: 18, color: AppTheme.gray400),
              ),
            ]),
            const SizedBox(height: 8),
            Text(issue.issueDescription,
              style: const TextStyle(
                fontSize: 13, color: AppTheme.gray800, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.business, size: 12, color: AppTheme.gray400),
              const SizedBox(width: 3),
              Text(issue.siteName ?? '현장 미상',
                style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
              if (issue.elevatorName != null) ...[
                const Text(' · ', style: TextStyle(color: AppTheme.gray300)),
                Text(issue.elevatorName!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
              ],
            ]),
            if (issue.actionTaken != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.successLight, borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 12, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Expanded(child: Text('조치: ${issue.actionTaken}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.success))),
                ]),
              ),
            ],
            // 코멘트 표시
            if (issue.comment != null && issue.comment!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.gray50, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.gray200)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.comment_outlined, size: 12, color: AppTheme.gray400),
                  const SizedBox(width: 4),
                  Expanded(child: Text(issue.comment!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.gray600),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],
            // 첨부파일 뱃지
            if (issue.mediaList.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.attach_file, size: 12, color: AppTheme.info),
                const SizedBox(width: 3),
                Text('첨부파일 ${issue.mediaList.length}개',
                  style: const TextStyle(fontSize: 11, color: AppTheme.info, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                ...issue.mediaList.take(3).map((url) {
                  final isVideo = url.toLowerCase().contains(RegExp(r'\.(mp4|mov|avi|webm|3gp)$'));
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                      size: 14, color: isVideo ? AppTheme.info : AppTheme.primary),
                  );
                }),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _showIssueMenu(InspectionIssue issue) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.gray200, borderRadius: BorderRadius.circular(2)),
            ),
            Text(issue.issueDescription,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            _menuItem(Icons.edit_outlined, '수정', AppTheme.gray700, () {
              Navigator.pop(context);
              _openForm(issue);
            }),
            _menuItem(Icons.check_circle_outline, '조치 처리', AppTheme.success, () {
              Navigator.pop(context);
              _showActionDialog(issue);
            }),
            _menuItem(Icons.delete_outline, '삭제', AppTheme.danger, () {
              Navigator.pop(context);
              _delete(issue);
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _openForm(InspectionIssue? issue) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => IssueFormSheet(issue: issue),
    );
    if (result == true) _load();
  }

  void _showActionDialog(InspectionIssue issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionFormSheet(issue: issue),
    ).then((updated) {
      if (updated == true) _load();
    });
  }

  Future<void> _delete(InspectionIssue issue) async {
    final ok = await ConfirmDialog.show(
      context, title: '지적사항 삭제', content: '이 지적사항을 삭제하시겠습니까?');
    if (ok != true) return;
    try {
      await ApiService.deleteIssue(issue.id!);
      if (mounted) { showToast(context, '지적사항이 삭제되었습니다.'); _load(); }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 문자 파싱 등록 뷰
// ══════════════════════════════════════════════════════════════
class IssuesSmsParserView extends StatefulWidget {
  final VoidCallback onRegistered;
  const IssuesSmsParserView({super.key, required this.onRegistered});

  @override
  State<IssuesSmsParserView> createState() => _IssuesSmsParserViewState();
}

class _IssuesSmsParserViewState extends State<IssuesSmsParserView> {
  final _smsCtrl = TextEditingController();
  List<_ParsedIssue> _parsed = [];
  List<Site> _sites = [];
  Map<int, List<Elevator>> _elevatorCache = {};
  Site? _selectedSite;
  bool _loadingSites = false;
  bool _saving = false;
  String _inspectionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final Map<String, bool> _hogiExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _loadingSites = true);
    try {
      final sites = await ApiService.getSites();
      if (mounted) setState(() { _sites = sites; _loadingSites = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSites = false);
    }
  }

  Future<List<Elevator>> _getElevators(int siteId) async {
    if (_elevatorCache.containsKey(siteId)) return _elevatorCache[siteId]!;
    try {
      final elevs = await ApiService.getSiteElevators(siteId);
      _elevatorCache[siteId] = elevs;
      return elevs;
    } catch (_) { return []; }
  }

  // ── 문자 파싱 로직 ─────────────────────────────────────
  void _parseSms() {
    final text = _smsCtrl.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final issues = <_ParsedIssue>[];

    // 날짜 추출
    String? date;
    final datePat = RegExp(r'(\d{4})[.\-년/](\d{1,2})[.\-월/](\d{1,2})일?');
    final dm = datePat.firstMatch(text);
    if (dm != null) {
      date = '${dm.group(1)}-${dm.group(2)!.padLeft(2,'0')}-${dm.group(3)!.padLeft(2,'0')}';
    }
    if (date != null) {
      setState(() => _inspectionDate = date!);
    }

    // 현장명 자동 매칭
    Site? matchedSite;
    for (final s in _sites) {
      if (text.contains(s.siteName)) { matchedSite = s; break; }
    }

    // 호기 패턴으로 파싱: "1호기", "2호기", "ES-1", "에스컬레이터 1"
    final elevatorPattern = RegExp(
      r'(?:(\d+)호기|(\d+)-(\d+)호기|(ES[\-\s]?\d+)|(에스컬레이터\s*\d+))',
      caseSensitive: false);

    // 호기별 섹션 분리 시도
    final Map<String, List<String>> elevSections = {};
    String currentElev = '';

    for (final line in lines) {
      final m = elevatorPattern.firstMatch(line);
      if (m != null) {
        currentElev = m.group(0) ?? line;
        elevSections.putIfAbsent(currentElev, () => []);
      } else if (currentElev.isNotEmpty && line.isNotEmpty) {
        // 번호로 시작하는 지적사항 라인 (1. 내용, ①내용, - 내용)
        final isIssue = RegExp(r'^[\d①②③④⑤⑥⑦⑧⑨⑩•\-*◎○□]').hasMatch(line);
        if (isIssue || (elevSections[currentElev]?.isEmpty ?? true)) {
          elevSections[currentElev]?.add(line.replaceAll(RegExp(r'^[\d\.\s①②③④⑤•\-*◎○□]+'), '').trim());
        }
      } else if (currentElev.isEmpty) {
        // 호기 구분 없이 단순 지적사항 나열
        final isIssue = RegExp(r'^[\d①②③④⑤⑥⑦⑧⑨⑩•\-*◎○□]').hasMatch(line);
        if (isIssue) {
          final content = line.replaceAll(RegExp(r'^[\d\.\s①②③④⑤•\-*◎○□]+'), '').trim();
          if (content.isNotEmpty) {
            elevSections.putIfAbsent('(호기 미지정)', () => []).add(content);
          }
        }
      }
    }

    // 섹션이 없으면 전체를 단순 지적사항으로 처리
    if (elevSections.isEmpty) {
      final issueLines = lines.where((l) {
        return RegExp(r'^[\d①②③④⑤⑥⑦⑧⑨⑩•\-*◎○□]').hasMatch(l) || l.length > 5;
      }).toList();
      for (int i = 0; i < issueLines.length; i++) {
        final content = issueLines[i].replaceAll(RegExp(r'^[\d\.\s①②③④⑤•\-*◎○□]+'), '').trim();
        if (content.isNotEmpty) {
          issues.add(_ParsedIssue(
            elevatorLabel: '(호기 미지정)',
            description: content,
            severity: _guessSeverity(content),
            issueNo: i + 1,
          ));
        }
      }
    } else {
      for (final entry in elevSections.entries) {
        final elevLabel = entry.key;
        for (int i = 0; i < entry.value.length; i++) {
          final content = entry.value[i];
          if (content.isNotEmpty) {
            issues.add(_ParsedIssue(
              elevatorLabel: elevLabel,
              description: content,
              severity: _guessSeverity(content),
              issueNo: i + 1,
            ));
          }
        }
      }
    }

    setState(() {
      _parsed = issues;
      if (matchedSite != null) _selectedSite = matchedSite;
    });
  }

  // 심각도 자동 추정
  String _guessSeverity(String desc) {
    final upper = desc;
    if (upper.contains('중결함') || upper.contains('불량') ||
        upper.contains('파손') || upper.contains('고장') ||
        upper.contains('누설') || upper.contains('위험') ||
        upper.contains('결함')) {
      return '중결함';
    }
    if (upper.contains('권고') || upper.contains('개선 권장') ||
        upper.contains('점검 필요')) {
      return '권고사항';
    }
    return '경결함';
  }

  Future<void> _save() async {
    if (_parsed.isEmpty) { showToast(context, '파싱된 지적사항이 없습니다', isError: true); return; }
    if (_selectedSite == null) { showToast(context, '현장을 선택해주세요', isError: true); return; }

    setState(() => _saving = true);
    try {
      final site = _selectedSite!;
      final elevators = await _getElevators(site.id!);

      final issuePayloads = <Map<String, dynamic>>[];
      for (final p in _parsed) {
        if (!p.include) continue;
        // 호기 매칭
        Elevator? matchedElev;
        if (p.elevatorLabel != '(호기 미지정)') {
          for (final e in elevators) {
            final eName = (e.elevatorName ?? e.elevatorNo).toLowerCase();
            final pLabel = p.elevatorLabel.toLowerCase();
            if (eName.contains(pLabel) || pLabel.contains(eName.split(' ')[0])) {
              matchedElev = e;
              break;
            }
          }
        }
        matchedElev ??= elevators.isNotEmpty ? elevators.first : null;
        if (matchedElev == null) continue;

        issuePayloads.add({
          'site_id': site.id,
          'elevator_id': matchedElev.id,
          'issue_no': p.issueNo,
          'issue_description': p.description,
          'issue_category': p.category,
          'severity': p.severity,
          'status': '미조치',
          'inspection_date': _inspectionDate,
        });
      }

      if (issuePayloads.isEmpty) {
        showToast(context, '등록할 지적사항을 선택해주세요', isError: true);
        setState(() => _saving = false);
        return;
      }

      await ApiService.createIssuesBulk(issuePayloads);
      if (mounted) {
        showToast(context, '${issuePayloads.length}건 등록 완료!');
        _smsCtrl.clear();
        setState(() { _parsed = []; });
        widget.onRegistered();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _parsed.where((p) => p.include).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.infoLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sms_outlined, color: AppTheme.info, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('문자로 지적사항 등록',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: AppTheme.gray800)),
                  Text('검사 결과 문자를 붙여넣으면 호기별로 자동 분류됩니다',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // ── 문자 입력 ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('검사 결과 문자 입력',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.gray600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _smsCtrl,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: '예시)\n파주프리미엄아울렛 정기검사 결과\n검사일: 2024-05-20\n\n1호기\n① 도어 개폐 불량\n② 조명 불량\n\n2호기\n① 브레이크 라이닝 마모\n\nES-1\n① 핸드레일 손상',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.gray300),
                    filled: true, fillColor: AppTheme.gray50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.gray200)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _parseSms,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('자동 분석'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),

          // ── 파싱 결과 ───────────────────────────────────
          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현장 선택
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Text('${_parsed.length}건 분석 완료',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppTheme.success)),
                  ]),
                  const SizedBox(height: 12),

                  // 검사일
                  Row(children: [
                    const Text('검사일',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.gray600)),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(_inspectionDate) ?? DateTime.now(),
                          firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) {
                          setState(() => _inspectionDate =
                            DateFormat('yyyy-MM-dd').format(d));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.calendar_today, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(_inspectionDate,
                            style: const TextStyle(fontSize: 12, color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 10),

                  // 현장 선택
                  const Text('현장 선택 *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.gray600)),
                  const SizedBox(height: 6),
                  SiteSearchField(
                    sites: _sites,
                    selected: _selectedSite,
                    onChanged: (s) => setState(() => _selectedSite = s),
                    isLoading: _loadingSites,
                  ),
                  const SizedBox(height: 14),

                  // 호기별 지적사항 목록
                  const Text('호기별 지적사항',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.gray600)),
                  const SizedBox(height: 8),
                  ..._buildParsedGroups(),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 20),
                      label: Text(_saving
                          ? '등록 중...'
                          : '$selectedCount건 등록하기',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 사용 가이드
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoLight, borderRadius: BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.info),
                    SizedBox(width: 6),
                    Text('입력 형식 가이드',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppTheme.info)),
                  ]),
                  SizedBox(height: 10),
                  Text('• 호기 구분: "1호기", "2호기", "ES-1", "에스컬레이터 1"',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray700)),
                  SizedBox(height: 4),
                  Text('• 지적사항: "① 내용", "1. 내용", "- 내용" 등',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray700)),
                  SizedBox(height: 4),
                  Text('• 날짜: "2024-05-20", "2024년5월20일" 등',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray700)),
                  SizedBox(height: 4),
                  Text('• 현장명이 등록된 현장과 일치하면 자동 매칭',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildParsedGroups() {
    // 호기별 그룹 구성 (순서 유지)
    final Map<String, List<int>> groups = {};
    final List<String> hogiOrder = [];
    for (int i = 0; i < _parsed.length; i++) {
      final label = _parsed[i].elevatorLabel;
      if (!groups.containsKey(label)) {
        groups[label] = [];
        hogiOrder.add(label);
        // 새 호기는 기본으로 펼쳐둠
        _hogiExpanded.putIfAbsent(label, () => true);
      }
      groups[label]!.add(i);
    }

    // 전체 선택 수
    final totalIncluded = _parsed.where((p) => p.include).length;
    final totalAll = _parsed.length;

    return [
      // 전체 요약 헤더
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.elevator, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('${hogiOrder.length}개 호기',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: AppTheme.primary)),
          const SizedBox(width: 8),
          Text('총 ${totalIncluded}/${totalAll}건 선택',
            style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
          const Spacer(),
          // 전체 선택/해제
          GestureDetector(
            onTap: () {
              final allOn = _parsed.every((p) => p.include);
              setState(() {
                for (int i = 0; i < _parsed.length; i++) {
                  _parsed[i] = _parsed[i].copyWith(include: !allOn);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _parsed.every((p) => p.include) ? '전체 해제' : '전체 선택',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),

      // 호기별 카드
      ...hogiOrder.map((label) {
        final indices = groups[label]!;
        final includedCount = indices.where((i) => _parsed[i].include).length;
        final isExpanded = _hogiExpanded[label] ?? true;
        final allSelected = indices.every((i) => _parsed[i].include);

        // 심각도별 카운트
        final sevCounts = <String, int>{};
        for (final i in indices) {
          final sev = _parsed[i].severity;
          sevCounts[sev] = (sevCounts[sev] ?? 0) + 1;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: includedCount > 0 ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.gray200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 호기 헤더 (탭으로 접기/펼치기)
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                onTap: () => setState(() =>
                  _hogiExpanded[label] = !(isExpanded)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: includedCount > 0
                      ? AppTheme.primaryLight.withValues(alpha: 0.6)
                      : AppTheme.gray50,
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(10),
                      bottom: isExpanded ? Radius.zero : const Radius.circular(10),
                    ),
                  ),
                  child: Row(children: [
                    // 호기 아이콘
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: includedCount > 0 ? AppTheme.primary : AppTheme.gray300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.elevator_outlined, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    // 호기 이름
                    Text(label,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: includedCount > 0 ? AppTheme.primary : AppTheme.gray400)),
                    const SizedBox(width: 8),
                    // 건수 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: includedCount > 0
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.gray100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$includedCount/${indices.length}건',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: includedCount > 0 ? AppTheme.primary : AppTheme.gray400)),
                    ),
                    // 심각도 요약 태그
                    if (sevCounts['중결함'] != null) ...[
                      const SizedBox(width: 4),
                      _sevBadge('중결함', sevCounts['중결함']!),
                    ],
                    if (sevCounts['권고사항'] != null) ...[
                      const SizedBox(width: 4),
                      _sevBadge('권고사항', sevCounts['권고사항']!),
                    ],
                    const Spacer(),
                    // 전체 선택/해제 + 접기 버튼
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          for (final i in indices) {
                            _parsed[i] = _parsed[i].copyWith(include: !allSelected);
                          }
                        });
                      },
                      child: Text(
                        allSelected ? '해제' : '전체',
                        style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16, color: AppTheme.gray400),
                  ]),
                ),
              ),

              // ── 지적사항 목록 (접힐 때 숨김)
              if (isExpanded) ...[
                const Divider(height: 1, color: AppTheme.gray100),
                ...indices.asMap().entries.map((entry) {
                  final isLast = entry.key == indices.length - 1;
                  final i = entry.value;
                  final p = _parsed[i];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.only(left: 8, right: 4),
                          dense: true,
                          value: p.include,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() =>
                            _parsed[i] = p.copyWith(include: v ?? true)),
                          title: Text(
                            p.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: p.include ? AppTheme.gray800 : AppTheme.gray300,
                              decoration: p.include ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(children: [
                              // 검사코드 배지
                              if (p.itemNo != null && p.itemNo!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gray100,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: AppTheme.gray300),
                                  ),
                                  child: Text(p.itemNo!,
                                    style: const TextStyle(
                                      fontSize: 10, color: AppTheme.gray600)),
                                ),
                                const SizedBox(width: 5),
                              ],
                              // 심각도 드롭다운
                              _severityDropdown(i, p),
                            ]),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 48, color: AppTheme.gray100),
                    ],
                  );
                }),
              ],
            ],
          ),
        );
      }),
    ];
  }

  Widget _sevBadge(String label, int count) {
    final Color color;
    switch (label) {
      case '중결함': color = AppTheme.danger; break;
      case '권고사항': color = AppTheme.warning; break;
      default: color = AppTheme.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$label $count',
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _severityDropdown(int index, _ParsedIssue p) {
    return DropdownButton<String>(
      value: p.severity,
      isDense: true,
      underline: const SizedBox(),
      style: const TextStyle(fontSize: 11),
      items: ['중결함','경결함','권고사항'].map((s) => DropdownMenuItem(
        value: s,
        child: Text(s, style: TextStyle(
          fontSize: 11,
          color: s == '중결함' ? AppTheme.danger
              : s == '경결함' ? AppTheme.warning : AppTheme.gray500)),
      )).toList(),
      onChanged: (v) => setState(() {
        _parsed[index] = _parsed[index].copyWith(severity: v ?? '경결함');
      }),
    );
  }

  @override
  void dispose() {
    _smsCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
// 파일 텍스트 파싱 등록 뷰
// ══════════════════════════════════════════════════════════════
class IssuesFileParserView extends StatefulWidget {
  final VoidCallback onRegistered;
  const IssuesFileParserView({super.key, required this.onRegistered});

  @override
  State<IssuesFileParserView> createState() => _IssuesFileParserViewState();
}

class _IssuesFileParserViewState extends State<IssuesFileParserView> {
  final _textCtrl = TextEditingController();
  List<_ParsedIssue> _parsed = [];
  List<Site> _sites = [];
  Map<int, List<Elevator>> _elevatorCache = {};
  Site? _selectedSite;
  bool _loadingSites = false;
  bool _saving = false;
  bool _imageLoading = false;
  // 호기별 접기/펼치기 상태
  final Map<String, bool> _hogiExpanded = {};
  List<PickedImage> _selectedImages = []; // 선택된 캡처 이미지들
  String _inspectionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedFormat = 'table'; // 'table' | 'list' | 'free'
  img_picker.ImageFilePicker? _imagePicker;
  final String _imagePickerViewId = 'img-file-input-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadSites();
    // 웹에서 input element를 미리 DOM에 삽입
    if (kIsWeb) {
      _imagePicker = img_picker.ImageFilePicker();
    }
  }

  Future<void> _loadSites() async {
    setState(() => _loadingSites = true);
    try {
      final sites = await ApiService.getSites();
      if (mounted) setState(() { _sites = sites; _loadingSites = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSites = false);
    }
  }

  Future<List<Elevator>> _getElevators(int siteId) async {
    if (_elevatorCache.containsKey(siteId)) return _elevatorCache[siteId]!;
    try {
      final elevs = await ApiService.getSiteElevators(siteId);
      _elevatorCache[siteId] = elevs;
      return elevs;
    } catch (_) { return []; }
  }


  // ── 캡처 이미지 업로드 및 파싱 ─────────────────────────────────────
  // onTap에서 직접 호출 — async 없음, click()이 동기 실행됨
  void _pickAndParseImages() {
    if (_imageLoading) return;
    if (kIsWeb && _imagePicker != null) {
      _imagePicker!.openPicker(
        onSuccess: (images) => _processImageFiles(images),
      );
    } else {
      _pickNativeImages();
    }
  }

  Future<void> _pickNativeImages() async {
    try {
      final picker = img_picker.ImageFilePicker();
      final images = await picker.pick();
      if (images == null || images.isEmpty) return;
      await _processImageFiles(images);
    } catch (_) {}
  }

  Future<void> _processImageFiles(List<PickedImage> images) async {
    try {
      setState(() {
        _imageLoading = true;
        _selectedImages = images;
      });

      final imageResult = await ApiService.parseImages(
        images.map((img) => (bytes: img.bytes, filename: img.fileName)).toList(),
      );

      if (!mounted) return;

      final issues = <_ParsedIssue>[];
      final parsedIssues = imageResult['parsedIssues'] as List<dynamic>? ?? [];

      for (final item in parsedIssues) {
        final checkCode = item['checkCode'] as String? ?? item['itemNo'] as String?;
        issues.add(_ParsedIssue(
          elevatorLabel: item['elevatorLabel'] as String? ?? '(호기 미지정)',
          description: item['description'] as String? ?? '',
          severity: item['severity'] as String? ?? '경결함',
          issueNo: item['issueNo'] as int? ?? 1,
          itemNo: checkCode,
          category: checkCode != null && checkCode.isNotEmpty ? '검사항목 $checkCode' : null,
        ));
      }

      // 현장명 자동 매칭
      final detectedSite = imageResult['detectedSite'] as String?;
      if (detectedSite != null && detectedSite.isNotEmpty) {
        final normalizedDetected = detectedSite.replaceAll(RegExp(r'[\s\-_]'), '').toLowerCase();
        Site? bestMatch;
        int bestScore = 0;
        for (final s in _sites) {
          final normalizedSite = s.siteName.replaceAll(RegExp(r'[\s\-_]'), '').toLowerCase();
          if (normalizedSite.contains(normalizedDetected) || normalizedDetected.contains(normalizedSite)) {
            final score = normalizedDetected.length + normalizedSite.length;
            if (score > bestScore) { bestScore = score; bestMatch = s; }
            continue;
          }
          int commonLen = 0;
          final shorter = normalizedDetected.length < normalizedSite.length ? normalizedDetected : normalizedSite;
          for (int k = 0; k < shorter.length; k++) {
            if (k < normalizedDetected.length && k < normalizedSite.length &&
                normalizedDetected[k] == normalizedSite[k]) {
              commonLen++;
            } else { break; }
          }
          if (commonLen >= 4 && commonLen > bestScore) { bestScore = commonLen; bestMatch = s; }
        }
        if (bestMatch != null) setState(() => _selectedSite = bestMatch);
      }

      // 날짜 자동 설정
      final detectedDate = imageResult['detectedDate'] as String?;
      if (detectedDate != null && detectedDate.isNotEmpty) {
        setState(() => _inspectionDate = detectedDate);
      }

      setState(() { _parsed = issues; _imageLoading = false; });

      if (issues.isEmpty) {
        showToast(context, '이미지에서 지적사항을 찾지 못했습니다. 텍스트 직접 입력을 사용해보세요', isError: true);
      } else {
        showToast(context, '이미지 ${images.length}장에서 ${issues.length}건 분석 완료!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _imageLoading = false);
        showToast(context, '이미지 파싱 실패: $e', isError: true);
      }
    }
  }

  void _parseFile() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    // 날짜 추출
    final datePat = RegExp(r'(\d{4})[.\-년/](\d{1,2})[.\-월/](\d{1,2})일?');
    final dm = datePat.firstMatch(text);
    if (dm != null) {
      setState(() => _inspectionDate =
        '${dm.group(1)}-${dm.group(2)!.padLeft(2,'0')}-${dm.group(3)!.padLeft(2,'0')}');
    }

    // 현장명 자동 매칭
    Site? matchedSite;
    for (final s in _sites) {
      if (text.contains(s.siteName)) { matchedSite = s; break; }
    }

    final issues = <_ParsedIssue>[];
    if (_selectedFormat == 'table') {
      // 표 형식: 탭 구분 or | 구분 (호기 | 지적사항 | 심각도)
      final rows = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      for (final row in rows) {
        List<String> cols;
        if (row.contains('\t')) {
          cols = row.split('\t').map((c) => c.trim()).toList();
        } else if (row.contains('|')) {
          cols = row.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        } else {
          continue;
        }
        if (cols.length < 2) continue;
        // 헤더 행 스킵
        if (cols[0] == '호기' || cols[0] == '승강기' || cols[0] == 'No' || cols[0] == '번호') continue;

        String elevLabel = '';
        String desc = '';
        String severity = '경결함';

        if (cols.length >= 3) {
          elevLabel = cols[0];
          desc = cols[1];
          final sv = cols[2];
          if (sv.contains('중')) severity = '중결함';
          else if (sv.contains('권고')) severity = '권고사항';
        } else {
          elevLabel = cols[0];
          desc = cols[1];
          severity = _guessSeverity(desc);
        }

        if (desc.isNotEmpty) {
          issues.add(_ParsedIssue(
            elevatorLabel: elevLabel,
            description: desc,
            severity: severity,
            issueNo: issues.where((i) => i.elevatorLabel == elevLabel).length + 1,
          ));
        }
      }
    } else {
      // 자유 형식 (문자 파싱과 동일)
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final elevPat = RegExp(r'(?:(\d+)호기|(\d+)-(\d+)호기|(ES[\-\s]?\d+))', caseSensitive: false);
      String currentElev = '';
      final Map<String, List<String>> sections = {};

      for (final line in lines) {
        final m = elevPat.firstMatch(line);
        if (m != null) {
          currentElev = m.group(0) ?? line;
          sections.putIfAbsent(currentElev, () => []);
        } else if (currentElev.isNotEmpty) {
          final isItem = RegExp(r'^[\d①②③④⑤⑥⑦⑧⑨⑩•\-*◎○□]').hasMatch(line);
          if (isItem) {
            final content = line.replaceAll(RegExp(r'^[\d\.\s①②③④⑤•\-*◎○□]+'), '').trim();
            if (content.isNotEmpty) sections[currentElev]?.add(content);
          }
        }
      }

      if (sections.isEmpty) {
        final itemLines = lines.where((l) =>
          RegExp(r'^[\d①②③④⑤•\-*◎○□]').hasMatch(l)).toList();
        for (int i = 0; i < itemLines.length; i++) {
          final content = itemLines[i].replaceAll(RegExp(r'^[\d\.\s①②③④⑤•\-*◎○□]+'), '').trim();
          if (content.isNotEmpty) {
            issues.add(_ParsedIssue(
              elevatorLabel: '(호기 미지정)',
              description: content,
              severity: _guessSeverity(content),
              issueNo: i + 1,
            ));
          }
        }
      } else {
        for (final entry in sections.entries) {
          for (int i = 0; i < entry.value.length; i++) {
            issues.add(_ParsedIssue(
              elevatorLabel: entry.key,
              description: entry.value[i],
              severity: _guessSeverity(entry.value[i]),
              issueNo: i + 1,
            ));
          }
        }
      }
    }

    setState(() {
      _parsed = issues;
      if (matchedSite != null) _selectedSite = matchedSite;
    });
  }

  String _guessSeverity(String desc) {
    if (desc.contains('중결함') || desc.contains('불량') || desc.contains('파손') ||
        desc.contains('고장') || desc.contains('결함') || desc.contains('위험')) {
      return '중결함';
    }
    if (desc.contains('권고') || desc.contains('개선 권장')) return '권고사항';
    return '경결함';
  }

  Future<void> _save() async {
    if (_parsed.isEmpty) { showToast(context, '파싱된 지적사항이 없습니다', isError: true); return; }
    if (_selectedSite == null) { showToast(context, '현장을 선택해주세요', isError: true); return; }

    setState(() => _saving = true);
    try {
      final site = _selectedSite!;
      final elevators = await _getElevators(site.id!);
      final payloads = <Map<String, dynamic>>[];

      for (final p in _parsed) {
        if (!p.include) continue;
        Elevator? matchedElev;
        for (final e in elevators) {
          final eName = (e.elevatorName ?? e.elevatorNo).toLowerCase();
          final pLabel = p.elevatorLabel.toLowerCase();
          if (eName.contains(pLabel) || pLabel.contains(eName.split(' ')[0])) {
            matchedElev = e; break;
          }
        }
        matchedElev ??= elevators.isNotEmpty ? elevators.first : null;
        if (matchedElev == null) continue;

        payloads.add({
          'site_id': site.id,
          'elevator_id': matchedElev.id,
          'issue_no': p.issueNo,
          'issue_description': p.description,
          'severity': p.severity,
          'status': '미조치',
          'inspection_date': _inspectionDate,
        });
      }

      if (payloads.isEmpty) {
        showToast(context, '등록할 지적사항을 선택해주세요', isError: true);
        setState(() => _saving = false);
        return;
      }

      await ApiService.createIssuesBulk(payloads);
      if (mounted) {
        showToast(context, '${payloads.length}건 등록 완료!');
        _textCtrl.clear();
        setState(() { _parsed = []; });
        widget.onRegistered();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _parsed.where((p) => p.include).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warningLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.upload_file, color: AppTheme.warning, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('파일/텍스트로 지적사항 등록',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: AppTheme.gray800)),
                  Text('캡처 이미지 업로드 또는 텍스트 직접 붙여넣기 지원',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // 형식 선택
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('입력 방법 선택',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.gray600)),
                const SizedBox(height: 8),
                // ── 캡처 이미지 업로드 버튼 ─────────────────────────
                _buildImageUploadButton(),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                _selectedImages[idx].bytes,
                                width: 64, height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2, right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImages.removeAt(idx)),
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // ── 구분선 ──────────────────────────────────────────
                // ── 구분선 ──────────────────────────────────────────
                // ── 구분선 ──────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('또는 텍스트 직접 입력',
                      style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),

                Row(children: [
                  _formatBtn('table', Icons.table_chart_outlined, '표 형식\n(엑셀 복붙)'),
                  const SizedBox(width: 8),
                  _formatBtn('free', Icons.text_snippet_outlined, '자유 형식\n(호기별 목록)'),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _textCtrl,
                  maxLines: 10,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: _selectedFormat == 'table'
                        ? '호기\t지적내용\t심각도\n1호기\t도어 개폐 불량\t중결함\n2호기\t조명 불량\t경결함\nES-1\t핸드레일 손상\t경결함'
                        : '1호기\n① 도어 개폐 불량\n② 조명 교체 필요\n\n2호기\n① 브레이크 마모\n\nES-1\n① 핸드레일 손상',
                    hintStyle: const TextStyle(fontSize: 11, color: AppTheme.gray300),
                    filled: true, fillColor: AppTheme.gray50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.gray200)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _parseFile,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('분석 및 분류'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),

          // 파싱 결과
          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Text('${_parsed.length}건 분석 완료',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppTheme.success)),
                  ]),
                  const SizedBox(height: 12),

                  // 검사일
                  Row(children: [
                    const Text('검사일',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.gray600)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(_inspectionDate) ?? DateTime.now(),
                          firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setState(() =>
                          _inspectionDate = DateFormat('yyyy-MM-dd').format(d));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.calendar_today, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(_inspectionDate,
                            style: const TextStyle(fontSize: 12, color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // 현장 선택
                  const Text('현장 선택 *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.gray600)),
                  const SizedBox(height: 6),
                  SiteSearchField(
                    sites: _sites,
                    selected: _selectedSite,
                    onChanged: (s) => setState(() => _selectedSite = s),
                    isLoading: _loadingSites,
                  ),
                  const SizedBox(height: 14),

                  const Text('호기별 지적사항',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.gray600)),
                  const SizedBox(height: 8),
                  ..._buildParsedGroups(),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 20),
                      label: Text(_saving ? '등록 중...' : '$selectedCount건 등록하기',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  /// 캡처 이미지 업로드 버튼
  Widget _buildImageUploadButton() {
    final hasImages = _selectedImages.isNotEmpty;
    return GestureDetector(
      onTap: _imageLoading ? null : _pickAndParseImages,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: hasImages ? const Color(0xFFEFF6FF) : AppTheme.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImages ? const Color(0xFF3B82F6) : AppTheme.gray200,
            width: hasImages ? 1.5 : 1,
          ),
        ),
        child: _imageLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('이미지 분석 중...', style: TextStyle(fontSize: 13)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: hasImages ? const Color(0xFF3B82F6) : AppTheme.gray300,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasImages ? '이미지 ${_selectedImages.length}장 선택됨' : '검사 결과 캡처 업로드',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: hasImages ? const Color(0xFF1D4ED8) : AppTheme.gray600,
                        ),
                      ),
                      Text(
                        hasImages
                            ? '탭하여 이미지 변경 또는 추가 (여러 장 가능)'
                            : '검사 결과 화면을 캡처한 이미지를 선택하세요',
                        style: const TextStyle(fontSize: 10, color: AppTheme.gray400),
                      ),
                    ],
                  )),
                  const Icon(Icons.photo_library_outlined,
                    color: AppTheme.gray300, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _formatBtn(String mode, IconData icon, String label) {
    final active = _selectedFormat == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFormat = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryLight : AppTheme.gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppTheme.primary : AppTheme.gray200,
              width: active ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: active ? AppTheme.primary : AppTheme.gray400),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                  color: active ? AppTheme.primary : AppTheme.gray400,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParsedGroups() {
    // 호기별 그룹 구성 (순서 유지)
    final Map<String, List<int>> groups = {};
    final List<String> hogiOrder = [];
    for (int i = 0; i < _parsed.length; i++) {
      final label = _parsed[i].elevatorLabel;
      if (!groups.containsKey(label)) {
        groups[label] = [];
        hogiOrder.add(label);
        // 새 호기는 기본으로 펼쳐둠
        _hogiExpanded.putIfAbsent(label, () => true);
      }
      groups[label]!.add(i);
    }

    // 전체 선택 수
    final totalIncluded = _parsed.where((p) => p.include).length;
    final totalAll = _parsed.length;

    return [
      // 전체 요약 헤더
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.elevator, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('${hogiOrder.length}개 호기',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: AppTheme.primary)),
          const SizedBox(width: 8),
          Text('총 ${totalIncluded}/${totalAll}건 선택',
            style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
          const Spacer(),
          // 전체 선택/해제
          GestureDetector(
            onTap: () {
              final allOn = _parsed.every((p) => p.include);
              setState(() {
                for (int i = 0; i < _parsed.length; i++) {
                  _parsed[i] = _parsed[i].copyWith(include: !allOn);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _parsed.every((p) => p.include) ? '전체 해제' : '전체 선택',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),

      // 호기별 카드
      ...hogiOrder.map((label) {
        final indices = groups[label]!;
        final includedCount = indices.where((i) => _parsed[i].include).length;
        final isExpanded = _hogiExpanded[label] ?? true;
        final allSelected = indices.every((i) => _parsed[i].include);

        // 심각도별 카운트
        final sevCounts = <String, int>{};
        for (final i in indices) {
          final sev = _parsed[i].severity;
          sevCounts[sev] = (sevCounts[sev] ?? 0) + 1;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: includedCount > 0 ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.gray200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 호기 헤더 (탭으로 접기/펼치기)
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                onTap: () => setState(() =>
                  _hogiExpanded[label] = !(isExpanded)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: includedCount > 0
                      ? AppTheme.primaryLight.withValues(alpha: 0.6)
                      : AppTheme.gray50,
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(10),
                      bottom: isExpanded ? Radius.zero : const Radius.circular(10),
                    ),
                  ),
                  child: Row(children: [
                    // 호기 아이콘
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: includedCount > 0 ? AppTheme.primary : AppTheme.gray300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.elevator_outlined, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    // 호기 이름
                    Text(label,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: includedCount > 0 ? AppTheme.primary : AppTheme.gray400)),
                    const SizedBox(width: 8),
                    // 건수 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: includedCount > 0
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.gray100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$includedCount/${indices.length}건',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: includedCount > 0 ? AppTheme.primary : AppTheme.gray400)),
                    ),
                    // 심각도 요약 태그
                    if (sevCounts['중결함'] != null) ...[
                      const SizedBox(width: 4),
                      _sevBadge('중결함', sevCounts['중결함']!),
                    ],
                    if (sevCounts['권고사항'] != null) ...[
                      const SizedBox(width: 4),
                      _sevBadge('권고사항', sevCounts['권고사항']!),
                    ],
                    const Spacer(),
                    // 전체 선택/해제 + 접기 버튼
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          for (final i in indices) {
                            _parsed[i] = _parsed[i].copyWith(include: !allSelected);
                          }
                        });
                      },
                      child: Text(
                        allSelected ? '해제' : '전체',
                        style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16, color: AppTheme.gray400),
                  ]),
                ),
              ),

              // ── 지적사항 목록 (접힐 때 숨김)
              if (isExpanded) ...[
                const Divider(height: 1, color: AppTheme.gray100),
                ...indices.asMap().entries.map((entry) {
                  final isLast = entry.key == indices.length - 1;
                  final i = entry.value;
                  final p = _parsed[i];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.only(left: 8, right: 4),
                          dense: true,
                          value: p.include,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() =>
                            _parsed[i] = p.copyWith(include: v ?? true)),
                          title: Text(
                            p.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: p.include ? AppTheme.gray800 : AppTheme.gray300,
                              decoration: p.include ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(children: [
                              // 검사코드 배지
                              if (p.itemNo != null && p.itemNo!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gray100,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: AppTheme.gray300),
                                  ),
                                  child: Text(p.itemNo!,
                                    style: const TextStyle(
                                      fontSize: 10, color: AppTheme.gray600)),
                                ),
                                const SizedBox(width: 5),
                              ],
                              // 심각도 드롭다운
                              _severityDropdown(i, p),
                            ]),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 48, color: AppTheme.gray100),
                    ],
                  );
                }),
              ],
            ],
          ),
        );
      }),
    ];
  }

  Widget _sevBadge(String label, int count) {
    final Color color;
    switch (label) {
      case '중결함': color = AppTheme.danger; break;
      case '권고사항': color = AppTheme.warning; break;
      default: color = AppTheme.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$label $count',
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _severityDropdown(int index, _ParsedIssue p) {
    return DropdownButton<String>(
      value: p.severity,
      isDense: true,
      underline: const SizedBox(),
      style: const TextStyle(fontSize: 11),
      items: ['중결함','경결함','권고사항'].map((s) => DropdownMenuItem(
        value: s,
        child: Text(s, style: TextStyle(
          fontSize: 11,
          color: s == '중결함' ? AppTheme.danger
              : s == '경결함' ? AppTheme.warning : AppTheme.gray500)),
      )).toList(),
      onChanged: (v) => setState(() {
        _parsed[index] = _parsed[index].copyWith(severity: v ?? '경결함');
      }),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _imagePicker?.dispose();
    super.dispose();
  }
}

// ── 파싱된 지적사항 데이터 클래스 ─────────────────────────
class _ParsedIssue {
  final String elevatorLabel;
  final String description;
  final String severity;
  final String? category;
  final String? itemNo;  // 검사항목 번호 (예: 1.2.1.4)
  final int issueNo;
  final bool include;

  const _ParsedIssue({
    required this.elevatorLabel,
    required this.description,
    required this.severity,
    this.category,
    this.itemNo,
    required this.issueNo,
    this.include = true,
  });

  _ParsedIssue copyWith({
    String? elevatorLabel,
    String? description,
    String? severity,
    String? category,
    String? itemNo,
    int? issueNo,
    bool? include,
  }) {
    return _ParsedIssue(
      elevatorLabel: elevatorLabel ?? this.elevatorLabel,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      itemNo: itemNo ?? this.itemNo,
      issueNo: issueNo ?? this.issueNo,
      include: include ?? this.include,
    );
  }
}

// ── 지적사항 등록/수정 폼 ────────────────────────────────────
class IssueFormSheet extends StatefulWidget {
  final InspectionIssue? issue;
  // 검사에서 자동 연동될 때 넘어오는 preset 값들
  final int? presetInspectionId;
  final int? presetSiteId;
  final int? presetElevatorId;
  final String? presetInspectionDate;
  final String? presetInspectorName;
  final String? presetInspectionType;
  final String? presetResult;

  const IssueFormSheet({
    super.key,
    this.issue,
    this.presetInspectionId,
    this.presetSiteId,
    this.presetElevatorId,
    this.presetInspectionDate,
    this.presetInspectorName,
    this.presetInspectionType,
    this.presetResult,
  });

  @override
  State<IssueFormSheet> createState() => _IssueFormSheetState();
}

class _IssueFormSheetState extends State<IssueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  List<Site> _sites = [];
  List<Elevator> _elevators = [];
  int? _selectedSiteId;
  int? _selectedElevatorId;
  late String _severity = widget.issue?.severity ?? '경결함';
  late String _status = widget.issue?.status ?? '미조치';
  late final _descCtrl = TextEditingController(text: widget.issue?.issueDescription);
  late final _catCtrl = TextEditingController(text: widget.issue?.issueCategory);
  late final _legalCtrl = TextEditingController(text: widget.issue?.legalBasis);
  late final _reqCtrl = TextEditingController(text: widget.issue?.actionRequired);
  late final _deadlineCtrl = TextEditingController(text: widget.issue?.deadline);
  late final _commentCtrl = TextEditingController(text: widget.issue?.comment);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // preset 값 우선 적용
    _selectedSiteId = widget.presetSiteId ?? widget.issue?.siteId;
    _selectedElevatorId = widget.presetElevatorId ?? widget.issue?.elevatorId;
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final sites = await ApiService.getSites();
      if (mounted) setState(() => _sites = sites);
      if (_selectedSiteId != null) await _loadElevators(_selectedSiteId!);
    } catch (_) {}
  }

  Future<void> _loadElevators(int siteId) async {
    try {
      final elevs = await ApiService.getSiteElevators(siteId);
      if (mounted) setState(() => _elevators = elevs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isFromInspection = widget.presetInspectionId != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들 바
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.gray200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // 타이틀
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isFromInspection ? AppTheme.warningLight : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFromInspection ? Icons.warning_amber_rounded : Icons.report_problem_outlined,
                    size: 16,
                    color: isFromInspection ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.issue == null ? '지적사항 등록' : '지적사항 수정',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (isFromInspection)
                      Text(
                        '${widget.presetInspectionType ?? ''} ${widget.presetResult ?? ''} 검사에서 자동 연동',
                        style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                      ),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 검사 연동 정보 배너
                      if (isFromInspection) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.infoLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link, size: 14, color: AppTheme.info),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '검사일: ${widget.presetInspectionDate ?? '-'} | 검사자: ${widget.presetInspectorName ?? '-'}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.info),
                              ),
                            ),
                          ]),
                        ),
                      ],
                      // 현장 선택
                      DropdownButtonFormField<int>(
                        value: _selectedSiteId,
                        decoration: const InputDecoration(labelText: '현장 *', isDense: true),
                        items: _sites.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.siteName, style: const TextStyle(fontSize: 13)))).toList(),
                        validator: (v) => v == null ? '현장을 선택하세요' : null,
                        onChanged: isFromInspection ? null : (v) {
                          setState(() { _selectedSiteId = v; _selectedElevatorId = null; _elevators = []; });
                          if (v != null) _loadElevators(v);
                        },
                      ),
                      const SizedBox(height: 8),
                      // 승강기 선택
                      DropdownButtonFormField<int>(
                        value: _selectedElevatorId,
                        decoration: const InputDecoration(labelText: '승강기 *', isDense: true),
                        items: _elevators.map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                        validator: (v) => v == null ? '승강기를 선택하세요' : null,
                        onChanged: isFromInspection ? null : (v) => setState(() => _selectedElevatorId = v),
                      ),
                      const SizedBox(height: 8),
                      // 지적 내용
                      _field(_descCtrl, '지적 내용 *', required: true, maxLines: 2),
                      // 심각도 + 상태
                      Row(children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          value: _severity,
                          decoration: const InputDecoration(labelText: '심각도 *', isDense: true),
                          items: ['중결함','경결함','권고사항'].map((s) => DropdownMenuItem(
                            value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _severity = v ?? '경결함'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: '상태', isDense: true),
                          items: ['미조치','조치중','조치완료','재검사필요'].map((s) => DropdownMenuItem(
                            value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _status = v ?? '미조치'),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      _field(_catCtrl, '지적 분류'),
                      _field(_legalCtrl, '관련 법령/기준'),
                      _field(_reqCtrl, '조치 필요 사항'),
                      _dateField(_deadlineCtrl, '조치 기한'),
                      const SizedBox(height: 4),

                      // ── 코멘트 ───────────────────────────────
                      Row(children: [
                        const Icon(Icons.comment_outlined, size: 14, color: AppTheme.gray500),
                        const SizedBox(width: 5),
                        const Text('코멘트', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray600)),
                      ]),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '추가 설명이나 메모를 입력하세요...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppTheme.gray400),
                          filled: true,
                          fillColor: AppTheme.gray50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.gray200),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // 저장 버튼
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.issue == null ? '등록' : '수정',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, isDense: true),
        maxLines: maxLines,
        validator: required ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null : null,
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label, isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime(2035));
          if (date != null) ctrl.text = date.toIso8601String().substring(0, 10);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final issue = InspectionIssue(
        id: widget.issue?.id,
        inspectionId: widget.presetInspectionId ?? widget.issue?.inspectionId,
        elevatorId: _selectedElevatorId!,
        siteId: _selectedSiteId!,
        issueDescription: _descCtrl.text,
        issueCategory: _catCtrl.text.isNotEmpty ? _catCtrl.text : null,
        legalBasis: _legalCtrl.text.isNotEmpty ? _legalCtrl.text : null,
        severity: _severity,
        status: _status,
        actionRequired: _reqCtrl.text.isNotEmpty ? _reqCtrl.text : null,
        deadline: _deadlineCtrl.text.isNotEmpty ? _deadlineCtrl.text : null,
        inspectionDate: widget.presetInspectionDate ?? widget.issue?.inspectionDate,
        inspectorName: widget.presetInspectorName ?? widget.issue?.inspectorName,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      );
      if (widget.issue == null) {
        await ApiService.createIssue(issue);
      } else {
        await ApiService.updateIssue(widget.issue!.id!, issue);
      }
      if (mounted) {
        showToast(context, widget.issue == null ? '지적사항이 등록되었습니다.' : '지적사항이 수정되었습니다.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _catCtrl.dispose(); _legalCtrl.dispose();
    _reqCtrl.dispose(); _deadlineCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }
}

/// 첨부 미디어 아이템 (로컬 바이트)
class _MediaItem {
  final Uint8List bytes;
  final String fileName;
  final bool isVideo;
  const _MediaItem({required this.bytes, required this.fileName, required this.isVideo});
}

// ══════════════════════════════════════════════════════════════
// 조치 등록 BottomSheet (사진/동영상 + 자동 압축)
// ══════════════════════════════════════════════════════════════
class ActionFormSheet extends StatefulWidget {
  final InspectionIssue issue;
  const ActionFormSheet({super.key, required this.issue});

  @override
  State<ActionFormSheet> createState() => _ActionFormSheetState();
}

class _ActionFormSheetState extends State<ActionFormSheet> {
  late String _status = widget.issue.status;
  late final _actionCtrl  = TextEditingController(text: widget.issue.actionTaken);
  late final _actionByCtrl= TextEditingController(text: widget.issue.actionBy);

  // Before 사진 (조치 전)
  final List<_MediaItem> _beforeItems = [];
  late List<String> _beforeUrls = List<String>.from(
    _parseUrls(widget.issue.photoBefore));

  // After 사진 (조치 후)
  final List<_MediaItem> _afterItems = [];
  late List<String> _afterUrls = List<String>.from(
    _parseUrls(widget.issue.photoAfter));

  static List<String> _parseUrls(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    // 단일 URL 문자열인 경우
    if (raw.startsWith('http') || raw.startsWith('/upload')) return [raw];
    return [];
  }

  bool _saving    = false;
  bool _uploading = false;
  String _uploadStatus  = '';
  double _uploadProgress = 0.0;
  int _uploadFileIndex   = 0;
  int _uploadFileTotal   = 0;

  late final _picker = img_picker.ImageFilePicker();

  // ── 이미지 압축 (최대 1MB, JPEG 품질 단계적 감소) ──────────
  /// 웹 환경에서 순수 Dart로 JPEG 리인코딩 없이 크기만 체크 후 경고
  /// 실제 압축은 서버에서 처리하거나 Canvas API를 이용해야 하므로
  /// 여기서는 10MB 초과 파일만 거부, 1MB~10MB는 경고 표시
  static const int _maxBytes = 100 * 1024 * 1024; // 100MB 거부
  static const int _warnBytes = 10 * 1024 * 1024; // 10MB 이상 경고

  Future<List<_MediaItem>> _compressAndAdd(List<PickedImage> imgs) async {
    final result = <_MediaItem>[];
    for (final img in imgs) {
      final isVideo = img.fileName.toLowerCase().contains(
          RegExp(r'\.(mp4|mov|avi|webm|3gp)$'));
      if (img.bytes.length > _maxBytes) {
        if (mounted) {
          showToast(context,
            '${img.fileName}: 파일 크기가 너무 큽니다 (최대 100MB)',
            isError: true);
        }
        continue;
      }
      if (!isVideo && img.bytes.length > _warnBytes) {
        // 이미지 자동 압축: 해상도 축소 시뮬레이션 (실제 픽셀 조작 없이 bytes 그대로 전송)
        // 서버 측 sharp/jimp 라이브러리로 압축 처리됨
        if (mounted) {
          showToast(context,
            '${img.fileName}: ${(img.bytes.length / 1024 / 1024).toStringAsFixed(1)}MB → 서버에서 자동 압축됩니다');
        }
      }
      result.add(_MediaItem(bytes: img.bytes, fileName: img.fileName, isVideo: isVideo));
    }
    return result;
  }

  void _pickBefore() {
    _picker.openPicker(
      onSuccess: (imgs) async {
        final items = await _compressAndAdd(imgs);
        if (mounted) setState(() => _beforeItems.addAll(items));
      },
    );
  }

  void _pickAfter() {
    _picker.openPicker(
      onSuccess: (imgs) async {
        final items = await _compressAndAdd(imgs);
        if (mounted) setState(() => _afterItems.addAll(items));
      },
    );
  }

  Future<void> _save() async {
    if (_saving || _uploading) return; // 중복 호출 방지
    setState(() { _saving = true; _uploading = false; _uploadStatus = '준비 중...'; _uploadProgress = 0; });

    try {
      List<String> newBeforeUrls = [];
      List<String> newAfterUrls  = [];

      final totalFiles = _beforeItems.length + _afterItems.length;

      if (totalFiles > 0) {
        if (!mounted) return;
        setState(() {
          _saving = false; _uploading = true;
          _uploadFileTotal = totalFiles; _uploadFileIndex = 0;
          _uploadProgress  = 0.0; _uploadStatus = '파일 업로드 준비 중...';
        });

        // Before 업로드 (조치 전 사진/동영상)
        if (_beforeItems.isNotEmpty) {
          newBeforeUrls = await ApiService.uploadFiles(
            _beforeItems.map((m) => m.bytes).toList(),
            _beforeItems.map((m) => m.fileName).toList(),
            onProgress: (fileIdx, total, progress) {
              if (!mounted) return;
              final item = _beforeItems[fileIdx];
              final label = item.isVideo ? '동영상' : '사진';
              final pct = (progress * 100).toInt();
              String statusMsg;
              if (progress >= 0.9) {
                statusMsg = item.isVideo
                    ? '조치 전 동영상 서버 처리 중... (${fileIdx + 1}/$totalFiles)'
                    : '조치 전 $label 서버 저장 중... (${fileIdx + 1}/$totalFiles)';
              } else {
                statusMsg = '조치 전 $label 전송 중 (${fileIdx + 1}/$totalFiles) $pct%';
              }
              setState(() {
                _uploadFileIndex = fileIdx + 1;
                _uploadProgress  = progress;
                _uploadStatus    = statusMsg;
              });
            },
          );
        }

        // After 업로드 (조치 후 사진/동영상)
        if (_afterItems.isNotEmpty) {
          newAfterUrls = await ApiService.uploadFiles(
            _afterItems.map((m) => m.bytes).toList(),
            _afterItems.map((m) => m.fileName).toList(),
            onProgress: (fileIdx, total, progress) {
              if (!mounted) return;
              final globalIdx = _beforeItems.length + fileIdx;
              final item = _afterItems[fileIdx];
              final label = item.isVideo ? '동영상' : '사진';
              final pct = (progress * 100).toInt();
              String statusMsg;
              if (progress >= 0.9) {
                statusMsg = item.isVideo
                    ? '조치 후 동영상 서버 처리 중... (${globalIdx + 1}/$totalFiles)'
                    : '조치 후 $label 서버 저장 중... (${globalIdx + 1}/$totalFiles)';
              } else {
                statusMsg = '조치 후 $label 전송 중 (${globalIdx + 1}/$totalFiles) $pct%';
              }
              setState(() {
                _uploadFileIndex = globalIdx + 1;
                _uploadProgress  = progress;
                _uploadStatus    = statusMsg;
              });
            },
          );
        }

        if (!mounted) return;
        setState(() {
          _uploading = false; _saving = true;
          _uploadProgress = 1.0; _uploadStatus = '저장 중...';
        });
      } else {
        if (!mounted) return;
        setState(() { _saving = true; _uploading = false; _uploadStatus = '저장 중...'; });
      }

      final allBefore = [..._beforeUrls, ...newBeforeUrls];
      final allAfter  = [..._afterUrls,  ...newAfterUrls];
      final beforeJson = allBefore.isEmpty ? null : '[${allBefore.map((u) => '"$u"').join(',')}]';
      final afterJson  = allAfter.isEmpty  ? null : '[${allAfter.map((u)  => '"$u"').join(',')}]';

      await ApiService.updateIssueAction(
        widget.issue.id!,
        status:      _status,
        actionTaken: _actionCtrl.text.isNotEmpty  ? _actionCtrl.text  : null,
        actionDate:  DateTime.now().toIso8601String().substring(0, 10),
        actionBy:    _actionByCtrl.text.isNotEmpty ? _actionByCtrl.text : null,
        photoBefore: beforeJson,
        photoAfter:  afterJson,
      );

      if (mounted) {
        showToast(context, '조치가 저장되었습니다.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString().replaceFirst('Exception: ', '');
        showToast(context, '저장 실패: $errMsg', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false; _uploading = false;
          _uploadStatus = ''; _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _actionCtrl.dispose();
    _actionByCtrl.dispose();
    _picker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppTheme.gray200, borderRadius: BorderRadius.circular(2)),
            )),
            // 헤더
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('조치 내용 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  widget.issue.issueDescription.length > 30
                    ? '${widget.issue.issueDescription.substring(0, 30)}...'
                    : widget.issue.issueDescription,
                  style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                ),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(height: 20),

            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 처리 상태
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: '처리 상태 *', isDense: true),
                    items: ['미조치','조치중','조치완료','재검사필요']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 10),

                  // 조치 내용
                  TextField(
                    controller: _actionCtrl,
                    maxLines: 3,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: '조치 내용',
                      isDense: true,
                      hintText: '수행한 조치 내용을 입력하세요',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.gray400),
                      filled: true,
                      fillColor: AppTheme.gray50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.gray200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.gray200)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 조치자
                  TextField(
                    controller: _actionByCtrl,
                    enabled: !busy,
                    decoration: const InputDecoration(labelText: '조치자', isDense: true),
                  ),
                  const SizedBox(height: 14),

                  // ── 조치 전 사진/동영상 ────────────────────────
                  _mediaSectionHeader(
                    icon: Icons.camera_alt_outlined,
                    label: '조치 전 사진 / 동영상',
                    color: AppTheme.warning,
                    count: _beforeUrls.length + _beforeItems.length,
                    onAdd: busy ? null : _pickBefore,
                  ),
                  const SizedBox(height: 8),
                  _mediaGrid(
                    existingUrls: _beforeUrls,
                    newItems: _beforeItems,
                    onRemoveExisting: busy ? null : (i) => setState(() => _beforeUrls.removeAt(i)),
                    onRemoveNew: busy ? null : (i) => setState(() => _beforeItems.removeAt(i)),
                    onAdd: busy ? null : _pickBefore,
                    accentColor: AppTheme.warning,
                  ),
                  const SizedBox(height: 14),

                  // ── 조치 후 사진/동영상 ────────────────────────
                  _mediaSectionHeader(
                    icon: Icons.check_circle_outline,
                    label: '조치 후 사진 / 동영상',
                    color: AppTheme.success,
                    count: _afterUrls.length + _afterItems.length,
                    onAdd: busy ? null : _pickAfter,
                  ),
                  const SizedBox(height: 8),
                  _mediaGrid(
                    existingUrls: _afterUrls,
                    newItems: _afterItems,
                    onRemoveExisting: busy ? null : (i) => setState(() => _afterUrls.removeAt(i)),
                    onRemoveNew: busy ? null : (i) => setState(() => _afterItems.removeAt(i)),
                    onAdd: busy ? null : _pickAfter,
                    accentColor: AppTheme.success,
                  ),
                  const SizedBox(height: 6),

                  // 용량 안내
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 13, color: AppTheme.info),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '파일당 최대 100MB • 이미지 10MB 이상 자동 압축\n동영상 30MB 이상 시 서버에서 자동 압축 (mp4, mov, avi, webm)',
                          style: TextStyle(fontSize: 10, color: AppTheme.info, height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ]),
              ),
            ),

            // ── 업로드 진행률 바 (업로드 중일 때만) ────────────
            if (_uploading) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상태 텍스트 + 퍼센트
                    Row(children: [
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadStatus.isNotEmpty ? _uploadStatus : '업로드 중...',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // 90% 이상(서버 처리 중)이면 퍼센트 숨기고 애니 표시
                      if (_uploadProgress < 0.9)
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    // 진행률 바: 90% 미만=확정값, 90% 이상=indeterminate(무한 애니)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        // value가 null이면 indeterminate 애니메이션
                        value: _uploadProgress >= 0.9 ? null : _uploadProgress,
                        minHeight: 8,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 안내 문구
                    Text(
                      _uploadProgress >= 0.9
                          ? '서버에서 파일을 처리하고 있습니다. 잠시만 기다려주세요...'
                          : (_uploadFileTotal > 0 ? '파일 $_uploadFileIndex / $_uploadFileTotal' : ''),
                      style: const TextStyle(fontSize: 10, color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 저장 버튼
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: busy ? AppTheme.gray300 : AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving && !_uploading
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 8),
                        Text('저장 중...', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ])
                    : Text(
                        busy ? '업로드 중...' : '조치 저장',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required int count,
    VoidCallback? onAdd,
  }) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count개', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
      const Spacer(),
      if (onAdd != null)
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_photo_alternate_outlined, size: 13, color: color),
              const SizedBox(width: 4),
              Text('추가', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
    ]);
  }

  Widget _mediaGrid({
    required List<String> existingUrls,
    required List<_MediaItem> newItems,
    required void Function(int)? onRemoveExisting,
    required void Function(int)? onRemoveNew,
    VoidCallback? onAdd,
    required Color accentColor,
  }) {
    final total = existingUrls.length + newItems.length;
    if (total == 0) {
      return GestureDetector(
        onTap: onAdd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gray200, style: BorderStyle.solid),
          ),
          child: Column(children: [
            Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppTheme.gray300),
            const SizedBox(height: 5),
            Text('탭하여 사진 또는 동영상 추가',
              style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
          ]),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1,
      ),
      itemCount: total + 1,
      itemBuilder: (_, idx) {
        // 마지막: 추가 버튼
        if (idx == total) {
          return GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.gray200),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline, size: 24, color: accentColor.withValues(alpha: 0.6)),
                const SizedBox(height: 4),
                Text('추가', style: TextStyle(fontSize: 11, color: accentColor.withValues(alpha: 0.6))),
              ]),
            ),
          );
        }
        // 기존 저장 URL
        if (idx < existingUrls.length) {
          final url = existingUrls[idx];
          final isVid = url.toLowerCase().contains(RegExp(r'\.(mp4|mov|avi|webm|3gp)$'));
          return _urlThumb(url: url, isVideo: isVid, accentColor: accentColor,
            onRemove: onRemoveExisting != null ? () => onRemoveExisting(idx) : null,
            onTap: () => _previewUrl(url: url, isVideo: isVid),
          );
        }
        // 새 파일
        final nIdx = idx - existingUrls.length;
        final item = newItems[nIdx];
        return _localThumb(item: item, accentColor: accentColor,
          onRemove: onRemoveNew != null ? () => onRemoveNew(nIdx) : null,
          onTap: () => item.isVideo ? _previewLocalVideo(item) : _previewLocalImage(item),
        );
      },
    );
  }

  Widget _urlThumb({
    required String url, required bool isVideo, required Color accentColor,
    VoidCallback? onTap, VoidCallback? onRemove,
  }) {
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    final name = url.split('/').last;
    final short = name.length > 12 ? '${name.substring(0,10)}..' : name;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Stack(children: [
          // 실제 미리보기: 이미지는 Image.network, 동영상은 아이콘+이름
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: isVideo
              ? Container(
                  color: AppTheme.infoLight,
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.play_circle_fill_rounded, size: 36, color: accentColor),
                    const SizedBox(height: 4),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(short, style: TextStyle(fontSize: 9, color: accentColor),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ])),
                )
              : Image.network(
                  fullUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.primaryLight,
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.image_rounded, size: 28, color: accentColor),
                      const SizedBox(height: 4),
                      Text(short, style: TextStyle(fontSize: 9, color: accentColor),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                  ),
                ),
          ),
          // 동영상: 재생 오버레이
          if (isVideo)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
          // 이미지: 탭 힌트
          if (!isVideo)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
                child: const Text('탭하여 보기',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: Colors.white)),
              ),
            ),
          // X 버튼
          if (onRemove != null)
            Positioned(top: 3, right: 3,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.85), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              )),
        ]),
      ),
    );
  }

  Widget _localThumb({
    required _MediaItem item, required Color accentColor,
    VoidCallback? onTap, VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: item.isVideo ? AppTheme.warningLight : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        ),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: item.isVideo
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.videocam_rounded, size: 28, color: accentColor),
                  const SizedBox(height: 4),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      item.fileName.length > 12 ? '${item.fileName.substring(0,10)}..' : item.fileName,
                      style: TextStyle(fontSize: 9, color: accentColor),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    )),
                  // 용량 표시
                  const SizedBox(height: 2),
                  Text(_formatBytes(item.bytes.length),
                    style: const TextStyle(fontSize: 8, color: AppTheme.gray400)),
                ]))
              : Image.memory(item.bytes, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          ),
          // NEW 뱃지
          Positioned(top: 3, left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
              child: const Text('NEW', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          // 용량 뱃지 (이미지)
          if (!item.isVideo)
            Positioned(bottom: 3, left: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_formatBytes(item.bytes.length),
                  style: const TextStyle(fontSize: 8, color: Colors.white)),
              )),
          // X 버튼
          if (onRemove != null)
            Positioned(top: 3, right: 3,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.85), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              )),
        ]),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  void _previewUrl({required String url, required bool isVideo}) {
    // 절대 URL 구성 (서버 baseUrl + 상대경로)
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';

    if (isVideo) {
      _showVideoPlayer(fullUrl, url.split('/').last);
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(fullUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.gray100, padding: const EdgeInsets.all(24),
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image, size: 48, color: AppTheme.gray400),
                      SizedBox(height: 8),
                      Text('이미지를 불러올 수 없습니다', style: TextStyle(color: AppTheme.gray500)),
                    ]),
                  ),
                ),
              ),
              Positioned(top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                )),
            ]),
          ),
        ),
      );
    }
  }

  void _showVideoPlayer(String fullUrl, String fileName) {
    // HTML5 video 태그를 HtmlElementView로 삽입
    const viewType = 'video-player-view';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      '${viewType}_${fullUrl.hashCode}',
      (int viewId) {
        final video = web.HTMLVideoElement()
          ..src = fullUrl
          ..controls = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '12px'
          ..style.backgroundColor = '#000';
        return video;
      },
    );

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 파일명 + 닫기
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                const Icon(Icons.videocam_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  fileName.length > 30 ? '${fileName.substring(0,28)}..' : fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                )),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ]),
            ),
            // 비디오 플레이어
            Container(
              height: 280,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: HtmlElementView(viewType: '${viewType}_${fullUrl.hashCode}'),
            ),
          ],
        ),
      ),
    );
  }

  void _previewLocalImage(_MediaItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(item.bytes, fit: BoxFit.contain),
            ),
            Positioned(top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              )),
          ]),
        ),
      ),
    );
  }

  // 로컬 동영상 미리보기 (업로드 전 - Blob URL 사용)
  void _previewLocalVideo(_MediaItem item) {
    // Blob URL 생성: bytes → Blob → object URL
    final mime = _localVideoMime(item.fileName);
    final blob = web.Blob(
      [item.bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final blobUrl = web.URL.createObjectURL(blob);
    final viewKey = 'local-video-${item.fileName.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewKey, (int _) {
      final video = web.HTMLVideoElement()
        ..src = blobUrl
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '0 0 12px 12px'
        ..style.backgroundColor = '#000';
      return video;
    });

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.videocam_rounded, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  item.fileName.length > 28 ? '${item.fileName.substring(0,26)}..' : item.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text('로컬 파일 • ${_formatBytes(item.bytes.length)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ])),
              GestureDetector(
                onTap: () {
                  web.URL.revokeObjectURL(blobUrl); // 메모리 해제
                  Navigator.pop(context);
                },
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ]),
          ),
          // 비디오 플레이어
          Container(
            height: 300,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: HtmlElementView(viewType: viewKey),
          ),
        ]),
      ),
    ).then((_) {
      // 다이얼로그 닫힐 때 Blob URL 해제 (혹시 닫기 버튼 외 방법으로 닫힌 경우)
      try { web.URL.revokeObjectURL(blobUrl); } catch (_) {}
    });
  }

  static String _localVideoMime(String filename) {
    switch (filename.toLowerCase().split('.').last) {
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'avi':  return 'video/x-msvideo';
      case 'webm': return 'video/webm';
      case '3gp':  return 'video/3gpp';
      default:     return 'video/mp4';
    }
  }
}
