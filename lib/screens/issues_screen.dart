import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/pdf_picker_web.dart' as pdf_picker;
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppTheme.primary, size: 18),
            ),
            onPressed: () => _openForm(null),
          ),
          const SizedBox(width: 4),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => IssueFormSheet(issue: issue),
    );
    if (result == true) _load();
  }

  void _showActionDialog(InspectionIssue issue) {
    final actionCtrl = TextEditingController(text: issue.actionTaken);
    final actionByCtrl = TextEditingController(text: issue.actionBy);
    String status = issue.status;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('조치 처리', style: TextStyle(fontSize: 16)),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: '처리 상태'),
                items: ['미조치','조치중','조치완료','재검사필요']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setS(() => status = v ?? '조치완료'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actionCtrl,
                decoration: const InputDecoration(labelText: '조치 내용'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actionByCtrl,
                decoration: const InputDecoration(labelText: '조치자'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.updateIssueAction(
                  issue.id!, status: status,
                  actionTaken: actionCtrl.text.isNotEmpty ? actionCtrl.text : null,
                  actionDate: DateTime.now().toIso8601String().substring(0, 10),
                  actionBy: actionByCtrl.text.isNotEmpty ? actionByCtrl.text : null,
                );
                if (mounted) { showToast(context, '조치가 처리되었습니다.'); _load(); }
              } catch (e) {
                if (mounted) showToast(context, e.toString(), isError: true);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
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
                  _loadingSites
                      ? const CircularProgressIndicator()
                      : DropdownButtonFormField<Site>(
                          value: _selectedSite,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.business_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          hint: const Text('현장 선택'),
                          items: _sites.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.siteName, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (s) => setState(() => _selectedSite = s),
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
    final Map<String, List<int>> groups = {};
    for (int i = 0; i < _parsed.length; i++) {
      groups.putIfAbsent(_parsed[i].elevatorLabel, () => []).add(i);
    }
    return groups.entries.map((entry) {
      final label = entry.key;
      final indices = entry.value;
      final includedCount = indices.where((i) => _parsed[i].include).length;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.gray50, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gray100)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 호기 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
              child: Row(children: [
                const Icon(Icons.elevator_outlined, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                const SizedBox(width: 6),
                Text('$includedCount/${indices.length}건',
                  style: const TextStyle(fontSize: 11, color: AppTheme.info)),
                const Spacer(),
                // 전체 선택/해제
                GestureDetector(
                  onTap: () {
                    final allSelected = indices.every((i) => _parsed[i].include);
                    setState(() {
                      for (final i in indices) {
                        _parsed[i] = _parsed[i].copyWith(include: !allSelected);
                      }
                    });
                  },
                  child: Text(
                    indices.every((i) => _parsed[i].include) ? '전체해제' : '전체선택',
                    style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                ),
              ]),
            ),
            // 지적사항 아이템들
            ...indices.map((i) {
              final p = _parsed[i];
              return StatefulBuilder(
                builder: (ctx, setS) => CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  dense: true,
                  value: p.include,
                  onChanged: (v) => setState(() {
                    _parsed[i] = p.copyWith(include: v ?? true);
                  }),
                  title: Text(p.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.include ? AppTheme.gray800 : AppTheme.gray300,
                      decoration: p.include ? null : TextDecoration.lineThrough)),
                  subtitle: Row(children: [
                    if (p.itemNo != null && p.itemNo!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.gray100,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppTheme.gray300),
                        ),
                        child: Text(p.itemNo!,
                          style: const TextStyle(fontSize: 10, color: AppTheme.gray600)),
                      ),
                    _severityDropdown(i, p),
                  ]),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
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
  bool _pdfLoading = false;
  String? _pdfFileName;
  String _inspectionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedFormat = 'table'; // 'table' | 'list' | 'free'
  pdf_picker.PdfFilePicker? _pdfPicker;

  @override
  void initState() {
    super.initState();
    _loadSites();
    // 웹에서 input element를 미리 DOM에 삽입
    if (kIsWeb) {
      _pdfPicker = pdf_picker.PdfFilePicker();
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

  // ── PDF 파일 업로드 및 파싱 ─────────────────────────────────────
  Future<void> _pickAndParsePdf() async {
    try {
      // 웹: 미리 초기화된 PdfFilePicker 사용 (DOM에 input이 이미 삽입됨)
      // 네이티브: 전역 pickPdfFile() 사용
      final picked = kIsWeb && _pdfPicker != null
          ? await _pdfPicker!.pick()
          : await pdf_picker.pickPdfFile();
      if (picked == null) return;

      final bytes = picked.$1;
      final fileName = picked.$2;

      setState(() { _pdfLoading = true; _pdfFileName = fileName; });

      // 서버 PDF 파싱 API 호출
      final pdfResult = await ApiService.parsePdf(bytes, fileName);

      if (!mounted) return;

      // 파싱된 결과를 _ParsedIssue 목록으로 변환
      final issues = <_ParsedIssue>[];
      final parsedIssues = pdfResult['parsedIssues'] as List<dynamic>? ?? [];

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

      // 현장명 자동 매칭 (스마트 매칭)
      final detectedSite = pdfResult['detectedSite'] as String?;
      if (detectedSite != null && detectedSite.isNotEmpty) {
        // 정규화: 공백 제거, 소문자 변환
        final normalizedDetected = detectedSite.replaceAll(RegExp(r'[\s\-_]'), '').toLowerCase();
        
        Site? bestMatch;
        int bestScore = 0;
        
        for (final s in _sites) {
          final normalizedSite = s.siteName.replaceAll(RegExp(r'[\s\-_]'), '').toLowerCase();
          
          // 완전 포함 관계
          if (normalizedSite.contains(normalizedDetected) || normalizedDetected.contains(normalizedSite)) {
            final score = normalizedDetected.length + normalizedSite.length;
            if (score > bestScore) {
              bestScore = score;
              bestMatch = s;
            }
            continue;
          }
          
          // 앞 부분 일치 (처음 4자 이상 겹치면 후보)
          int commonLen = 0;
          final shorter = normalizedDetected.length < normalizedSite.length ? normalizedDetected : normalizedSite;
          for (int k = 0; k < shorter.length; k++) {
            if (k < normalizedDetected.length && k < normalizedSite.length &&
                normalizedDetected[k] == normalizedSite[k]) {
              commonLen++;
            } else {
              break;
            }
          }
          if (commonLen >= 4) {
            if (commonLen > bestScore) {
              bestScore = commonLen;
              bestMatch = s;
            }
          }
        }
        
        if (bestMatch != null) {
          setState(() => _selectedSite = bestMatch);
        }
      }

      // 날짜 자동 설정
      final detectedDate = pdfResult['detectedDate'] as String?;
      if (detectedDate != null && detectedDate.isNotEmpty) {
        setState(() => _inspectionDate = detectedDate);
      }

      setState(() {
        _parsed = issues;
        _pdfLoading = false;
      });

      if (issues.isEmpty) {
        showToast(context, 'PDF에서 지적사항을 찾지 못했습니다. 텍스트 직접 입력을 시도해보세요', isError: true);
      } else {
        showToast(context, 'PDF에서 ${issues.length}건 지적사항 분석 완료!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pdfLoading = false);
        showToast(context, 'PDF 파싱 실패: $e', isError: true);
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
                  Text('PDF 파일 업로드 또는 텍스트 직접 붙여넣기 지원',
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
                const Text('입력 형식',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.gray600)),
                const SizedBox(height: 8),
                // ── PDF 업로드 버튼 ──────────────────────────────
                GestureDetector(
                  onTap: _pdfLoading ? null : _pickAndParsePdf,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _pdfFileName != null
                          ? const Color(0xFFEFF6FF)
                          : AppTheme.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _pdfFileName != null
                            ? const Color(0xFF3B82F6)
                            : AppTheme.gray200,
                        width: _pdfFileName != null ? 1.5 : 1,
                      ),
                    ),
                    child: _pdfLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('PDF 분석 중...', style: TextStyle(fontSize: 13)),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: _pdfFileName != null
                                      ? const Color(0xFF3B82F6)
                                      : AppTheme.gray300,
                                  borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.picture_as_pdf,
                                  color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pdfFileName != null
                                        ? _pdfFileName!
                                        : 'PDF 파일 업로드',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _pdfFileName != null
                                          ? const Color(0xFF1D4ED8)
                                          : AppTheme.gray600,
                                    ),
                                  ),
                                  Text(
                                    _pdfFileName != null
                                        ? '파일을 다시 선택하려면 탭하세요'
                                        : '검사 결과 PDF를 업로드하면 자동으로 지적사항을 추출합니다',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.gray400,
                                    ),
                                  ),
                                ],
                              )),
                              const Icon(Icons.upload_file,
                                color: AppTheme.gray300, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

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
                  DropdownButtonFormField<Site>(
                    value: _selectedSite,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.business_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('현장 선택'),
                    items: _sites.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.siteName, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (s) => setState(() => _selectedSite = s),
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
    final Map<String, List<int>> groups = {};
    for (int i = 0; i < _parsed.length; i++) {
      groups.putIfAbsent(_parsed[i].elevatorLabel, () => []).add(i);
    }
    return groups.entries.map((entry) {
      final label = entry.key;
      final indices = entry.value;
      final includedCount = indices.where((i) => _parsed[i].include).length;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.gray50, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gray100)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningLight.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
              child: Row(children: [
                const Icon(Icons.elevator_outlined, size: 14, color: AppTheme.warning),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                const SizedBox(width: 6),
                Text('$includedCount/${indices.length}건',
                  style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final allSelected = indices.every((i) => _parsed[i].include);
                    setState(() {
                      for (final i in indices) {
                        _parsed[i] = _parsed[i].copyWith(include: !allSelected);
                      }
                    });
                  },
                  child: Text(
                    indices.every((i) => _parsed[i].include) ? '전체해제' : '전체선택',
                    style: const TextStyle(fontSize: 10, color: AppTheme.info)),
                ),
              ]),
            ),
            ...indices.map((i) {
              final p = _parsed[i];
              return CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                dense: true,
                value: p.include,
                onChanged: (v) => setState(() {
                  _parsed[i] = p.copyWith(include: v ?? true);
                }),
                title: Text(p.description, style: TextStyle(
                  fontSize: 12,
                  color: p.include ? AppTheme.gray800 : AppTheme.gray300,
                  decoration: p.include ? null : TextDecoration.lineThrough)),
                subtitle: Row(children: [
                  if (p.itemNo != null && p.itemNo!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppTheme.gray300),
                      ),
                      child: Text(p.itemNo!,
                        style: const TextStyle(fontSize: 10, color: AppTheme.gray600)),
                    ),
                  DropdownButton<String>(
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
                      _parsed[i] = _parsed[i].copyWith(severity: v ?? '경결함');
                    }),
                  ),
                ]),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _pdfPicker?.dispose();
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
  const IssueFormSheet({super.key, this.issue});

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.issue?.siteId;
    _selectedElevatorId = widget.issue?.elevatorId;
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final sites = await ApiService.getSites();
      if (mounted) setState(() => _sites = sites);
      if (_selectedSiteId != null) _loadElevators(_selectedSiteId!);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.gray200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Text(widget.issue == null ? '지적사항 등록' : '지적사항 수정',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedSiteId,
                        decoration: const InputDecoration(labelText: '현장 *'),
                        items: _sites.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.siteName, style: const TextStyle(fontSize: 13)))).toList(),
                        validator: (v) => v == null ? '현장을 선택하세요' : null,
                        onChanged: (v) {
                          setState(() { _selectedSiteId = v; _selectedElevatorId = null; _elevators = []; });
                          if (v != null) _loadElevators(v);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedElevatorId,
                        decoration: const InputDecoration(labelText: '승강기 *'),
                        items: _elevators.map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                        validator: (v) => v == null ? '승강기를 선택하세요' : null,
                        onChanged: (v) => setState(() => _selectedElevatorId = v),
                      ),
                      const SizedBox(height: 8),
                      _field(_descCtrl, '지적 내용 *', required: true, maxLines: 2),
                      Row(children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          value: _severity,
                          decoration: const InputDecoration(labelText: '심각도 *'),
                          items: ['중결함','경결함','권고사항'].map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _severity = v ?? '경결함'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: '상태'),
                          items: ['미조치','조치중','조치완료','재검사필요'].map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _status = v ?? '미조치'),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      _field(_catCtrl, '지적 분류'),
                      _field(_legalCtrl, '관련 법령/기준'),
                      _field(_reqCtrl, '조치 필요 사항'),
                      _dateField(_deadlineCtrl, '조치 기한'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.issue == null ? '등록' : '수정'),
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
        decoration: InputDecoration(labelText: label),
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
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16)),
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
            firstDate: DateTime.now(), lastDate: DateTime(2030));
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
        elevatorId: _selectedElevatorId!,
        siteId: _selectedSiteId!,
        issueDescription: _descCtrl.text,
        issueCategory: _catCtrl.text.isNotEmpty ? _catCtrl.text : null,
        legalBasis: _legalCtrl.text.isNotEmpty ? _legalCtrl.text : null,
        severity: _severity,
        status: _status,
        actionRequired: _reqCtrl.text.isNotEmpty ? _reqCtrl.text : null,
        deadline: _deadlineCtrl.text.isNotEmpty ? _deadlineCtrl.text : null,
      );
      if (widget.issue == null) {
        await ApiService.createIssue(issue);
      } else {
        await ApiService.updateIssue(widget.issue!.id!, issue);
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
    _descCtrl.dispose(); _catCtrl.dispose(); _legalCtrl.dispose();
    _reqCtrl.dispose(); _deadlineCtrl.dispose();
    super.dispose();
  }
}
