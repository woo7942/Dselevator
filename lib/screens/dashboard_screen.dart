import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/check.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;
  String _selectedTeam = '전체';   // 팀 탭 선택
  List<String> _teamOptions = ['전체', '파주1팀', '파주2팀'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.getTeams();
      if (mounted && teams.isNotEmpty) {
        setState(() => _teamOptions = ['전체', ...teams]);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getDashboard(
        team: _selectedTeam != '전체' ? _selectedTeam : null,
      );
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('대시보드'),
            if (_selectedTeam != '전체') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _teamBgColor(_selectedTeam),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedTeam,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _teamFgColor(_selectedTeam),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // 팀 탭바
          _buildTeamTabBar(),
          // 콘텐츠
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? ErrorWidget2(message: _error!, onRetry: _load)
                    : _buildDashboard(),
          ),
        ],
      ),
    );
  }

  // ── 팀 탭바 ──────────────────────────────────────────────────
  Widget _buildTeamTabBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.gray200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.group_outlined, size: 15, color: AppTheme.gray500),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _teamOptions.map((t) {
                final isSelected = t == _selectedTeam;
                Color selColor = t == '전체'
                    ? AppTheme.primary
                    : _teamFgColor(t);
                return GestureDetector(
                  onTap: () {
                    if (_selectedTeam == t) return;
                    setState(() => _selectedTeam = t);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? selColor.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? selColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected ? selColor : AppTheme.gray500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _teamFgColor(String team) {
    switch (team) {
      case '파주1팀': return const Color(0xFF1565C0);
      case '파주2팀': return const Color(0xFF6A1B9A);
      default: return AppTheme.primary;
    }
  }

  Color _teamBgColor(String team) {
    switch (team) {
      case '파주1팀': return const Color(0xFFE3F2FD);
      case '파주2팀': return const Color(0xFFF3E5F5);
      default: return AppTheme.primaryLight;
    }
  }

  Widget _buildDashboard() {
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 전체 보기일 때만 팀별 요약 카드 표시
            if (_selectedTeam == '전체' && d.teamStats.isNotEmpty) ...[
              _buildTeamSummaryRow(d),
              const SizedBox(height: 16),
            ],
            _buildKpiGrid(d),
            const SizedBox(height: 16),
            _buildStatsRow(d),
            const SizedBox(height: 16),
            _buildUpcomingInspections(d),
            const SizedBox(height: 16),
            _buildRecentIssues(d),
          ],
        ),
      ),
    );
  }

  // ── 팀별 요약 카드 (전체 보기 시) ────────────────────────────
  Widget _buildTeamSummaryRow(DashboardData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '팀별 현황',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: d.teamStats.map((t) {
            final m = t as Map<String, dynamic>;
            final team = m['team']?.toString() ?? '';
            final siteCount = (m['site_count'] as num?)?.toInt() ?? 0;
            final elevCount = (m['elevator_count'] as num?)?.toInt() ?? 0;
            final faultCount = (m['fault_count'] as num?)?.toInt() ?? 0;
            final warnCount = (m['warning_count'] as num?)?.toInt() ?? 0;
            final pendIssues = (m['pending_issues'] as num?)?.toInt() ?? 0;
            final critIssues = (m['critical_issues'] as num?)?.toInt() ?? 0;
            final fg = _teamFgColor(team);
            final bg = _teamBgColor(team);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTeam = team);
                  _load();
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: d.teamStats.last == t ? 0 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: fg.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: fg.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 팀 색상 헤더
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, size: 14, color: fg),
                            const SizedBox(width: 6),
                            Text(
                              team,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, size: 14, color: fg.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                      // 통계 내용
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // 현장 / 승강기
                            Row(
                              children: [
                                _teamStatItem(Icons.business, '$siteCount', '현장', AppTheme.info),
                                const SizedBox(width: 8),
                                _teamStatItem(Icons.elevator, '$elevCount', '승강기', AppTheme.primary),
                              ],
                            ),
                            if (faultCount > 0 || warnCount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (faultCount > 0)
                                    _teamStatItem(Icons.error_outline, '$faultCount', '고장', AppTheme.danger),
                                  if (faultCount > 0 && warnCount > 0)
                                    const SizedBox(width: 8),
                                  if (warnCount > 0)
                                    _teamStatItem(Icons.warning_amber, '$warnCount', '주의', AppTheme.warning),
                                ],
                              ),
                            ],
                            if (pendIssues > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: critIssues > 0
                                      ? AppTheme.dangerLight
                                      : AppTheme.warningLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 12,
                                      color: critIssues > 0 ? AppTheme.danger : AppTheme.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '미조치 $pendIssues건${critIssues > 0 ? " (중결함 $critIssues)" : ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: critIssues > 0 ? AppTheme.danger : AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.successLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                                    SizedBox(width: 4),
                                    Text('지적사항 없음',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.success,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _teamStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(DashboardData d) {
    final elevators = d.elevators;
    final issues = d.pendingIssues;
    final faultCount = (elevators?['fault'] as num?)?.toInt() ?? 0;
    final warningCount = (elevators?['warning'] as num?)?.toInt() ?? 0;
    final elevatorsCount = (elevators?['count'] as num?)?.toInt() ?? 0;
    final issuesTotal = (issues?['total'] as num?)?.toInt() ?? 0;
    final issuesCritical = (issues?['critical'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKpiCard(_KpiData(
              icon: Icons.business,
              iconBg: AppTheme.infoLight,
              iconColor: AppTheme.info,
              value: '${d.sites}',
              label: '관리 현장',
              subLabel: '운영중',
              subColor: AppTheme.success,
              subBg: AppTheme.successLight,
            ))),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(_KpiData(
              icon: Icons.elevator,
              iconBg: AppTheme.primaryLight,
              iconColor: AppTheme.primary,
              value: '$elevatorsCount',
              label: '관리 승강기',
              subLabel: faultCount > 0 ? '고장 $faultCount대' : '정상',
              subColor: faultCount > 0 ? AppTheme.danger : AppTheme.success,
              subBg: faultCount > 0 ? AppTheme.dangerLight : AppTheme.successLight,
              extraLabel: warningCount > 0 ? '주의 $warningCount대' : null,
              extraColor: AppTheme.warning,
            ))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildKpiCard(_KpiData(
              icon: Icons.warning_amber,
              iconBg: AppTheme.dangerLight,
              iconColor: AppTheme.danger,
              value: '$issuesTotal',
              label: '지적사항 미조치',
              subLabel: issuesCritical > 0 ? '중결함 $issuesCritical건' : '미조치',
              subColor: AppTheme.danger,
              subBg: AppTheme.dangerLight,
              extraLabel: issuesCritical == 0 && issuesTotal == 0 ? '이상없음' : null,
              extraColor: AppTheme.success,
            ))),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(_KpiData(
              icon: Icons.calendar_today,
              iconBg: AppTheme.warningLight,
              iconColor: AppTheme.warning,
              value: '${d.upcomingInspections}',
              label: '검사 예정',
              subLabel: '30일 이내',
              subColor: d.upcomingInspections > 0 ? AppTheme.warning : AppTheme.gray400,
              subBg: d.upcomingInspections > 0 ? AppTheme.warningLight : AppTheme.gray100,
            ))),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(_KpiData kpi) {
    return InfoCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kpi.iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.iconColor, size: 16),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kpi.subBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    kpi.subLabel,
                    style: TextStyle(fontSize: 10, color: kpi.subColor, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kpi.value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.gray800),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.label,
            style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (kpi.extraLabel != null) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (kpi.extraColor ?? AppTheme.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                kpi.extraLabel!,
                style: TextStyle(
                  fontSize: 10,
                  color: kpi.extraColor ?? AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(DashboardData d) {
    final monthly = d.monthlyStats;
    final quarterly = d.quarterlyStats;
    final issues = d.pendingIssues;

    final monthlyTotal = (monthly?['total'] as num?)?.toInt() ?? 0;
    final monthlyDone = (monthly?['done'] as num?)?.toInt() ?? 0;
    final monthlyPct = monthlyTotal > 0 ? monthlyDone / monthlyTotal : 0.0;

    final quarterlyTotal = (quarterly?['total'] as num?)?.toInt() ?? 0;
    final quarterlyDone = (quarterly?['done'] as num?)?.toInt() ?? 0;
    final quarterlyPct = quarterlyTotal > 0 ? quarterlyDone / quarterlyTotal : 0.0;

    final issuesTotal = (issues?['total'] as num?)?.toInt() ?? 0;
    final issuesCritical = (issues?['critical'] as num?)?.toInt() ?? 0;
    final issuesMinor = (issues?['minor'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        // 점검 현황 행
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDonutCard(
              icon: Icons.calendar_month,
              iconColor: const Color(0xFF8B5CF6),
              title: '이번달 월점검',
              done: monthlyDone,
              total: monthlyTotal,
              pct: monthlyPct,
              color: AppTheme.primary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildDonutCard(
              icon: Icons.memory,
              iconColor: const Color(0xFFF59E0B),
              title: '이번 분기점검',
              done: quarterlyDone,
              total: quarterlyTotal,
              pct: quarterlyPct,
              color: const Color(0xFFF59E0B),
            )),
          ],
        ),
        const SizedBox(height: 10),
        // 지적사항 현황 (전체 너비)
        _buildIssueStatsCard(
          total: issuesTotal,
          critical: issuesCritical,
          minor: issuesMinor,
        ),
      ],
    );
  }

  Widget _buildDonutCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int done,
    required int total,
    required double pct,
    required Color color,
  }) {
    return InfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray700),
                overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(value: pct, color: color, radius: 8, showTitle: false),
                          PieChartSectionData(value: 1 - pct, color: AppTheme.gray200, radius: 8, showTitle: false),
                        ],
                        centerSpaceRadius: 20,
                        sectionsSpace: 0,
                      ),
                    ),
                    Text('$done/$total',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.gray700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(pct * 100).round()}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                  const Text('완료율', style: TextStyle(fontSize: 11, color: AppTheme.gray500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueStatsCard({required int total, required int critical, required int minor}) {
    return InfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, size: 14, color: AppTheme.primary),
              const SizedBox(width: 4),
              const Text('지적사항 현황',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: total > 0 ? AppTheme.dangerLight : AppTheme.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '총 $total건',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: total > 0 ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildProgressRow('중결함', critical, total, AppTheme.danger)),
              const SizedBox(width: 12),
              Expanded(child: _buildProgressRow('경결함', minor, total, AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            Text('$count건', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppTheme.gray200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingInspections(DashboardData d) {
    final list = d.upcomingInspectionList;
    return InfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.event_note, size: 16, color: AppTheme.info),
                const SizedBox(width: 6),
                Text(
                  '검사 일정 (30일 이내)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: list.isEmpty ? AppTheme.gray100 : AppTheme.infoLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${list.length}건',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: list.isEmpty ? AppTheme.gray400 : AppTheme.info,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('검사관리 →', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '30일 이내 예정된 검사가 없습니다 ✓',
                style: TextStyle(color: AppTheme.gray400, fontSize: 13),
              ),
            )
          else
            ...list.map((item) {
              final m = item as Map<String, dynamic>;
              final daysRemaining = (m['days_remaining'] as num?)?.toInt() ?? 0;
              final isUrgent = daysRemaining <= 7;
              final isWarning = daysRemaining <= 14;
              final urgentColor = isUrgent
                  ? AppTheme.danger
                  : isWarning
                      ? AppTheme.warning
                      : AppTheme.info;
              final urgentBg = isUrgent
                  ? AppTheme.dangerLight
                  : isWarning
                      ? AppTheme.warningLight
                      : AppTheme.infoLight;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: urgentBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Text(
                                daysRemaining == 0 ? 'D-Day' : 'D-$daysRemaining',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: urgentColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['site_name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.gray800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (m['elevator_name'] != null)
                                Text(
                                  '${m['elevator_no'] ?? ''} ${m['elevator_name']}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.gray400),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m['inspection_type']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fmtDate(m['next_inspection_date']?.toString()),
                              style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentIssues(DashboardData d) {    return InfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, size: 16, color: AppTheme.danger),
                const SizedBox(width: 6),
                const Text('미조치 지적사항 (긴급순)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('전체보기 →', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (d.recentIssues.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('미조치 지적사항이 없습니다 ✓',
                style: TextStyle(color: AppTheme.gray400, fontSize: 13)),
            )
          else
            ...d.recentIssues.map((issue) {
              final m = issue as Map<String, dynamic>;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['site_name']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.gray800)),
                              Text(m['elevator_name']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            m['issue_description']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SeverityBadge(severity: m['severity']?.toString() ?? ''),
                        const SizedBox(width: 4),
                        StatusBadge(status: m['status']?.toString() ?? ''),
                        const SizedBox(width: 8),
                        Text(fmtDate(m['deadline']?.toString()),
                          style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _KpiData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final String subLabel;
  final Color subColor;
  final Color subBg;
  final String? extraLabel;
  final Color? extraColor;

  _KpiData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subLabel,
    required this.subColor,
    required this.subBg,
    this.extraLabel,
    this.extraColor,
  });
}
