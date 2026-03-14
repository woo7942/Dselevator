import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/inspection.dart';
import '../models/site.dart';
import 'issues_screen.dart' show IssueFormSheet;

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({super.key});

  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Inspection> _inspections = [];
  List<Inspection> _filteredInspections = [];
  bool _loading = true;
  String? _error;
  String _selectedTeam = '전체';

  // 캘린더 상태
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Inspection>> _eventMap = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 실시간 데이터 변경 구독
  late final _dataChangeSub = ApiService.onDataChanged.listen((type) {
    if (type == 'inspection' && mounted) _load();
  });

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedDay = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _dataChangeSub.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final inspections = await ApiService.getInspections();
      if (mounted) {
        setState(() {
          _inspections = inspections;
          _applyTeamFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyTeamFilter() {
    if (_selectedTeam == '전체') {
      _filteredInspections = List.from(_inspections);
    } else {
      _filteredInspections = _inspections.where((ins) {
        // site_name 기준으로 팀 필터 (site 객체에 team 없으므로 siteId 기반은 어려워 이름으로 필터)
        return ins.teamName == _selectedTeam;
      }).toList();
    }
    _buildEventMap(_filteredInspections);
  }

  void _buildEventMap(List<Inspection> inspections) {
    final map = <DateTime, List<Inspection>>{};
    for (final ins in inspections) {
      try {
        final d = _normalizeDate(DateTime.parse(ins.inspectionDate));
        map.putIfAbsent(d, () => []).add(ins);
      } catch (_) {}
    }
    _eventMap = map;
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Inspection> _getEventsForDay(DateTime day) {
    return _eventMap[_normalizeDate(day)] ?? [];
  }

  // 현재 포커스된 달의 검사 통계
  Map<String, int> _getMonthStats() {
    final stats = {'예정': 0, '합격': 0, '조건부합격': 0, '불합격': 0, '보류': 0, '전체': 0};
    for (final ins in _filteredInspections) {
      try {
        final d = DateTime.parse(ins.inspectionDate);
        if (d.year == _focusedDay.year && d.month == _focusedDay.month) {
          stats['전체'] = (stats['전체'] ?? 0) + 1;
          if (stats.containsKey(ins.result)) {
            stats[ins.result] = (stats[ins.result] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('검사 관리'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.gray800,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sms_outlined, color: AppTheme.info, size: 18),
            ),
            tooltip: '문자로 등록',
            onPressed: _openSmsParser,
          ),
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
            label: const Text('검사 등록', style: TextStyle(fontSize: 12)),
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
                      Icon(Icons.calendar_month, size: 15),
                      SizedBox(width: 5),
                      Text('캘린더', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 15),
                      SizedBox(width: 5),
                      Text('목록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const LoadingWidget()
          : _error != null
              ? ErrorWidget2(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    TeamTabBar(
                      selected: _selectedTeam,
                      onChanged: (t) {
                        setState(() => _selectedTeam = t);
                        _applyTeamFilter();
                        if (mounted) setState(() {});
                      },
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildCalendarView(),
                          _buildListView(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── 캘린더 탭 ─────────────────────────────────────────────
  Widget _buildCalendarView() {
    final selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());
    final stats = _getMonthStats();

    return Column(
      children: [
        // ── 월별 통계 헤더 ──────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              _statChip('전체', stats['전체'] ?? 0, AppTheme.gray500),
              const SizedBox(width: 6),
              _statChip('예정', stats['예정'] ?? 0, AppTheme.info),
              const SizedBox(width: 6),
              _statChip('합격', stats['합격'] ?? 0, AppTheme.success),
              const SizedBox(width: 6),
              _statChip('불합격', stats['불합격'] ?? 0, AppTheme.danger),
              const Spacer(),
              // 캘린더 포맷 토글
              GestureDetector(
                onTap: () {
                  setState(() {
                    _calendarFormat = _calendarFormat == CalendarFormat.month
                        ? CalendarFormat.twoWeeks
                        : CalendarFormat.month;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _calendarFormat == CalendarFormat.month
                            ? Icons.unfold_less
                            : Icons.unfold_more,
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _calendarFormat == CalendarFormat.month ? '2주 보기' : '월 보기',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── 캘린더 ──────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TableCalendar<Inspection>(
            locale: 'ko_KR',
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            daysOfWeekHeight: 28,
            rowHeight: 46,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.gray800),
              leftChevronIcon: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_left, color: AppTheme.primary, size: 20),
              ),
              rightChevronIcon: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right, color: AppTheme.primary, size: 20),
              ),
              headerPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(fontSize: 12, color: AppTheme.gray500, fontWeight: FontWeight.w500),
              weekendStyle: TextStyle(fontSize: 12, color: AppTheme.danger.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(2),
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              defaultTextStyle: const TextStyle(fontSize: 13, color: AppTheme.gray700),
              weekendTextStyle: TextStyle(fontSize: 13, color: AppTheme.danger.withValues(alpha: 0.8)),
              markerDecoration: const BoxDecoration(
                color: AppTheme.primary, shape: BoxShape.circle),
              markerSize: 4.5,
              markersMaxCount: 1,
              markersAlignment: Alignment.bottomCenter,
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                // 결과별 색상 도트 표시
                final colors = events.take(3).map((e) {
                  switch (e.result) {
                    case '합격': return AppTheme.success;
                    case '불합격': return AppTheme.danger;
                    case '조건부합격': return AppTheme.warning;
                    default: return AppTheme.info;
                  }
                }).toList();
                return Positioned(
                  bottom: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...colors.map((c) => Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      )),
                      if (events.length > 3)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(left: 0.8),
                          decoration: const BoxDecoration(
                            color: AppTheme.gray300, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        // 구분선
        Container(height: 1, color: AppTheme.gray100),
        // ── 선택된 날짜 이벤트 ───────────────────────────────
        Expanded(
          child: selectedEvents.isEmpty
              ? _buildEmptyDay()
              : Column(
                  children: [
                    // 날짜 헤더
                    _buildDayHeader(selectedEvents),
                    // 이벤트 목록
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: selectedEvents.length,
                        itemBuilder: (_, i) => _buildEventCard(selectedEvents[i]),
                      ),
                    ),
                  ],
                ),
        ),
      ],
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

  Widget _buildDayHeader(List<Inspection> events) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.gray100)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedDay != null
                    ? DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDay!)
                    : '',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.gray800),
              ),
              Text('검사 ${events.length}건',
                style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _openForm(null, presetDate: _selectedDay),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('추가', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay() {
    final dateStr = _selectedDay != null
        ? DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay!)
        : '오늘';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.event_available_outlined,
                size: 36, color: AppTheme.gray300),
            ),
            const SizedBox(height: 16),
            Text('$dateStr 검사 없음',
              style: const TextStyle(fontSize: 14, color: AppTheme.gray500,
                fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('이 날짜에 등록된 검사가 없습니다',
              style: TextStyle(fontSize: 12, color: AppTheme.gray300)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openForm(null, presetDate: _selectedDay),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('검사 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Inspection ins) {
    final resultColor = _resultColor(ins.result);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: resultColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetail(ins),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 현장명 + 결과 배지
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ins.siteName ?? '현장 미지정',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14,
                            color: AppTheme.gray800),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _infoChip(Icons.assignment_outlined, ins.inspectionType,
                              AppTheme.info),
                            const SizedBox(width: 6),
                            if (ins.inspectorName != null)
                              _infoChip(Icons.person_outline, ins.inspectorName!,
                                AppTheme.gray500),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: ins.result == '예정' ? 0.08 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: resultColor.withValues(alpha: ins.result == '예정' ? 0.5 : 0.3),
                            width: ins.result == '예정' ? 1.2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ins.result == '예정') ...[
                              Icon(Icons.schedule, size: 10, color: resultColor),
                              const SizedBox(width: 3),
                            ],
                            Text(ins.result,
                              style: TextStyle(
                                fontSize: 11, color: resultColor,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionBtn(Icons.edit_outlined, AppTheme.gray400,
                            () => _openForm(ins)),
                          const SizedBox(width: 2),
                          _actionBtn(Icons.delete_outline, AppTheme.danger,
                            () => _delete(ins)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              // 하단: 추가 정보 (검사기관, 다음검사일)
              if (ins.inspectionAgency != null || ins.nextInspectionDate != null) ...[
                const Divider(height: 12, thickness: 0.5),
                Row(
                  children: [
                    if (ins.inspectionAgency != null) ...[
                      _infoChip(Icons.domain_outlined, ins.inspectionAgency!,
                        AppTheme.gray400),
                      const SizedBox(width: 8),
                    ],
                    if (ins.nextInspectionDate != null &&
                        ins.nextInspectionDate!.isNotEmpty)
                      _infoChip(Icons.event_repeat_outlined,
                        '다음: ${ins.nextInspectionDate}', AppTheme.warning),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.gray500)),
      ],
    );
  }

  Color _resultColor(String result) {
    switch (result) {
      case '합격': return AppTheme.success;
      case '불합격': return AppTheme.danger;
      case '조건부합격': return AppTheme.warning;
      case '예정': return AppTheme.info;
      default: return AppTheme.gray400;
    }
  }

  // ── 목록 탭 ─────────────────────────────────────────────────
  Widget _buildListView() {
    if (_filteredInspections.isEmpty) {
      return const EmptyWidget(message: '검사 기록이 없습니다', icon: Icons.assignment_outlined);
    }
    // 날짜 내림차순 정렬
    final sorted = List<Inspection>.from(_filteredInspections)
      ..sort((a, b) {
        try {
          return DateTime.parse(b.inspectionDate)
              .compareTo(DateTime.parse(a.inspectionDate));
        } catch (_) {
          return 0;
        }
      });

    // 날짜별 그룹핑
    final grouped = <String, List<Inspection>>{};
    for (final ins in sorted) {
      final key = ins.inspectionDate.substring(0, 7); // yyyy-MM
      grouped.putIfAbsent(key, () => []).add(ins);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: grouped.length,
      itemBuilder: (_, groupIdx) {
        final monthKey = grouped.keys.elementAt(groupIdx);
        final items = grouped[monthKey]!;
        String monthLabel = monthKey;
        try {
          final d = DateTime.parse('$monthKey-01');
          monthLabel = DateFormat('yyyy년 M월', 'ko_KR').format(d);
        } catch (_) {}

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 월 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(monthLabel,
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.gray600)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${items.length}건',
                      style: const TextStyle(fontSize: 10, color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            ...items.map((ins) => _buildListCard(ins)),
          ],
        );
      },
    );
  }

  Widget _buildListCard(Inspection ins) {
    final resultColor = _resultColor(ins.result);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetail(ins),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 날짜 박스
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dayStr(ins.inspectionDate),
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: resultColor),
                    ),
                    Text(
                      _monthStr(ins.inspectionDate),
                      style: TextStyle(fontSize: 9, color: resultColor.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(ins.siteName ?? '현장 미지정',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13,
                            color: AppTheme.gray800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: resultColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ins.result == '예정') ...[
                              Icon(Icons.schedule, size: 9, color: resultColor),
                              const SizedBox(width: 2),
                            ],
                            Text(ins.result,
                              style: TextStyle(
                                fontSize: 10, color: resultColor,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      _infoChip(Icons.category_outlined, ins.inspectionType,
                        AppTheme.info),
                      if (ins.inspectorName != null) ...[
                        const SizedBox(width: 8),
                        _infoChip(Icons.person_outline, ins.inspectorName!,
                          AppTheme.gray400),
                      ],
                    ]),
                  ],
                ),
              ),
              // 버튼
              Column(
                children: [
                  _actionBtn(Icons.edit_outlined, AppTheme.gray400, () => _openForm(ins)),
                  const SizedBox(height: 4),
                  _actionBtn(Icons.delete_outline, AppTheme.danger, () => _delete(ins)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayStr(String dateStr) {
    try { return DateFormat('d').format(DateTime.parse(dateStr)); } catch (_) { return '--'; }
  }

  String _monthStr(String dateStr) {
    try { return DateFormat('MMM', 'ko_KR').format(DateTime.parse(dateStr)); } catch (_) { return ''; }
  }

  // ── 상세 보기 ────────────────────────────────────────────────
  void _showDetail(Inspection ins) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InspectionDetailSheet(ins: ins, onEdit: () {
        Navigator.pop(context);
        _openForm(ins);
      }),
    );
  }

  // ── 폼 열기 ──────────────────────────────────────────────────
  void _openForm(Inspection? ins, {DateTime? presetDate}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InspectionFormSheet(inspection: ins, presetDate: presetDate),
    );
    if (result == true) _load();
  }

  // ── 문자 파서 열기 ────────────────────────────────────────────
  void _openSmsParser() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SmsParserSheet(),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Inspection ins) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '검사 삭제',
      content: '이 검사 기록을 삭제하시겠습니까?',
    );
    if (ok != true) return;
    try {
      await ApiService.deleteInspection(ins.id!);
      if (mounted) {
        showToast(context, '검사 기록이 삭제되었습니다.');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 검사 상세 시트
// ══════════════════════════════════════════════════════════════
class _InspectionDetailSheet extends StatelessWidget {
  final Inspection ins;
  final VoidCallback onEdit;
  const _InspectionDetailSheet({required this.ins, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final resultColor = ins.result == '합격' ? AppTheme.success
        : ins.result == '불합격' ? AppTheme.danger
        : ins.result == '조건부합격' ? AppTheme.warning
        : ins.result == '예정' ? AppTheme.info
        : AppTheme.gray400;

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 바
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.assignment_outlined, color: resultColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ins.siteName ?? '현장 미지정',
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: AppTheme.gray800)),
                  Text(ins.inspectionType,
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray400)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: resultColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ins.result == '예정') ...[
                    Icon(Icons.schedule, size: 13, color: resultColor),
                    const SizedBox(width: 4),
                  ],
                  Text(ins.result,
                    style: TextStyle(color: resultColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ]),
          const Divider(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _row(Icons.calendar_today, '검사일', ins.inspectionDate),
                  if (ins.nextInspectionDate != null && ins.nextInspectionDate!.isNotEmpty)
                    _row(Icons.event_repeat, '다음 검사 예정일', ins.nextInspectionDate!,
                      valueColor: AppTheme.warning),
                  if (ins.inspectorName != null)
                    _row(Icons.person_outline, '검사자', ins.inspectorName!),
                  if (ins.inspectionAgency != null)
                    _row(Icons.domain_outlined, '검사기관', ins.inspectionAgency!),
                  if (ins.reportNo != null)
                    _row(Icons.receipt_long_outlined, '보고서 번호', ins.reportNo!),
                  if (ins.notes != null && ins.notes!.isNotEmpty)
                    _row(Icons.notes_outlined, '비고', ins.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('닫기'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('수정'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.gray400),
          const SizedBox(width: 8),
          SizedBox(width: 100,
            child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.gray400))),
          Expanded(
            child: Text(value,
              style: TextStyle(
                fontSize: 13, color: valueColor ?? AppTheme.gray700,
                fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 문자 파서 시트
// ══════════════════════════════════════════════════════════════
class SmsParserSheet extends StatefulWidget {
  const SmsParserSheet({super.key});

  @override
  State<SmsParserSheet> createState() => _SmsParserSheetState();
}

class _SmsParserSheetState extends State<SmsParserSheet> {
  final _smsCtrl = TextEditingController();
  _ParsedData? _parsed;
  bool _saving = false;

  List<Site> _sites = [];
  Site? _selectedSite;
  List<Elevator> _elevators = [];
  Elevator? _selectedElevator;
  bool _loadingSites = false;

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

  Future<void> _loadElevators(int siteId) async {
    try {
      final elevs = await ApiService.getSiteElevators(siteId);
      if (mounted) setState(() {
        _elevators = elevs;
        _selectedElevator = elevs.isNotEmpty ? elevs.first : null;
      });
    } catch (_) {}
  }

  void _parseSms() {
    final text = _smsCtrl.text.trim();
    if (text.isEmpty) return;

    String? date;
    String? time;
    String? siteName;
    String? inspectionType;
    String? agency;

    final datePatterns = [
      RegExp(r'(\d{4})[.\-/년](\d{1,2})[.\-/월](\d{1,2})일?'),
      RegExp(r'(\d{1,2})[./월](\d{1,2})일?'),
    ];
    for (final p in datePatterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        if (m.groupCount >= 3) {
          date = '${m.group(1)}-${m.group(2)!.padLeft(2,'0')}-${m.group(3)!.padLeft(2,'0')}';
        } else if (m.groupCount == 2) {
          final now = DateTime.now();
          date = '${now.year}-${m.group(1)!.padLeft(2,'0')}-${m.group(2)!.padLeft(2,'0')}';
        }
        break;
      }
    }

    final timePatterns = [
      RegExp(r'(오전|오후)\s*(\d{1,2})시\s*(\d{0,2})분?'),
      RegExp(r'(\d{1,2}):(\d{2})'),
      RegExp(r'(\d{1,2})시\s*(\d{0,2})분?'),
    ];
    for (final p in timePatterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        if (m.group(0)!.contains('오전') || m.group(0)!.contains('오후')) {
          var h = int.parse(m.group(2)!);
          if (m.group(1) == '오후' && h < 12) h += 12;
          final min = m.groupCount >= 3 && m.group(3)!.isNotEmpty
              ? m.group(3)!.padLeft(2,'0') : '00';
          time = '${h.toString().padLeft(2,'0')}:$min';
        } else if (m.groupCount >= 2) {
          time = '${m.group(1)!.padLeft(2,'0')}:${(m.group(2) ?? '00').padLeft(2,'0')}';
        }
        break;
      }
    }

    for (final s in _sites) {
      if (text.contains(s.siteName)) {
        siteName = s.siteName;
        _selectedSite = s;
        _loadElevators(s.id!);
        break;
      }
    }
    siteName ??= _extractSiteName(text);

    if (text.contains('정기검사') || text.contains('정기 검사')) inspectionType = '정기검사';
    else if (text.contains('완성검사')) inspectionType = '완성검사';
    else if (text.contains('수시검사')) inspectionType = '수시검사';
    else if (text.contains('정밀안전') || text.contains('정밀')) inspectionType = '정밀안전검사';
    else inspectionType = '정기검사';

    if (text.contains('한국승강기안전공단') || text.contains('안전공단')) {
      agency = '한국승강기안전공단';
    } else if (text.contains('KAS') || text.contains('승강기안전')) {
      agency = '한국승강기안전공단';
    }

    setState(() {
      _parsed = _ParsedData(
        date: date, time: time, siteName: siteName,
        inspectionType: inspectionType ?? '정기검사',
        agency: agency, rawText: text,
      );
    });
  }

  String? _extractSiteName(String text) {
    final pattern = RegExp(r'([가-힣\s]+(?:아파트|빌딩|타워|플라자|센터|주택|상가|마트|병원|학교))');
    final m = pattern.firstMatch(text);
    return m?.group(1)?.trim();
  }

  Future<void> _save() async {
    if (_parsed == null) return;
    if (_selectedSite == null) {
      showToast(context, '현장을 선택해주세요', isError: true);
      return;
    }
    if (_parsed!.date == null) {
      showToast(context, '날짜를 인식하지 못했습니다. 직접 수정해주세요.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final elevId = _selectedElevator?.id ?? (_elevators.isNotEmpty ? _elevators.first.id! : 0);
      if (elevId == 0) {
        showToast(context, '승강기 정보가 없습니다. 먼저 승강기를 등록해주세요.', isError: true);
        setState(() => _saving = false);
        return;
      }

      final inspection = Inspection(
        elevatorId: elevId,
        siteId: _selectedSite!.id!,
        inspectionType: _parsed!.inspectionType,
        inspectionDate: _parsed!.date!,
        inspectorName: null,
        inspectionAgency: _parsed!.agency,
        result: '합격',
        notes: '문자 자동 등록${_parsed!.time != null ? ' | 시간: ${_parsed!.time}' : ''}\n원문: ${_parsed!.rawText}',
      );

      await ApiService.createInspection(inspection);
      if (mounted) {
        showToast(context, '캘린더에 등록되었습니다!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sms_outlined, color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('문자로 자동 등록',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: AppTheme.gray800)),
                  Text('검사 문자를 붙여넣으면 자동으로 캘린더에 등록됩니다',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray400)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('검사 문자 입력',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppTheme.gray600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _smsCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '예) 파주프리미엄아울렛 정기검사\n2024년 5월 20일 오전 10시\n한국승강기안전공단',
                        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.gray300),
                        filled: true,
                        fillColor: AppTheme.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.gray200),
                        ),
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
                        ),
                      ),
                    ),

                    if (_parsed != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.auto_awesome, size: 14, color: AppTheme.success),
                              SizedBox(width: 6),
                              Text('분석 결과',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: AppTheme.success)),
                            ]),
                            const SizedBox(height: 8),
                            _resultRow(Icons.calendar_today, '날짜',
                              _parsed!.date ?? '인식 실패 (직접 선택)', _parsed!.date == null),
                            if (_parsed!.time != null)
                              _resultRow(Icons.access_time, '시간', _parsed!.time!),
                            _resultRow(Icons.business, '현장명',
                              _parsed!.siteName ?? '자동 매칭 실패'),
                            _resultRow(Icons.category_outlined, '검사 유형',
                              _parsed!.inspectionType),
                            if (_parsed!.agency != null)
                              _resultRow(Icons.domain, '검사기관', _parsed!.agency!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('현장 선택 *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.gray600)),
                      const SizedBox(height: 6),
                      SiteSearchField(
                        sites: _sites,
                        selected: _selectedSite,
                        isLoading: _loadingSites,
                        onChanged: (s) {
                          setState(() {
                            _selectedSite = s;
                            _elevators = [];
                            _selectedElevator = null;
                          });
                          if (s?.id != null) _loadElevators(s!.id!);
                        },
                      ),

                      if (_elevators.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('승강기 선택',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.gray600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<Elevator>(
                          value: _selectedElevator,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.elevator_outlined, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          ),
                          items: _elevators.map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              '${e.elevatorName ?? e.elevatorNo} (${e.elevatorNo})',
                              overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (e) => setState(() => _selectedElevator = e),
                        ),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.calendar_month, size: 20),
                          label: const Text('캘린더에 등록',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],

                    if (_parsed == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.infoLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.info),
                              SizedBox(width: 6),
                              Text('인식 가능한 형식',
                                style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.bold, color: AppTheme.info)),
                            ]),
                            SizedBox(height: 10),
                            Text('• 날짜: 2024-05-20, 2024.05.20\n  2024년5월20일, 5월20일',
                              style: TextStyle(fontSize: 11, color: AppTheme.gray600)),
                            SizedBox(height: 4),
                            Text('• 시간: 오전 10시, 오후 2시 30분, 14:00',
                              style: TextStyle(fontSize: 11, color: AppTheme.gray600)),
                            SizedBox(height: 4),
                            Text('• 유형: 정기검사, 완성검사, 수시검사, 정밀안전검사',
                              style: TextStyle(fontSize: 11, color: AppTheme.gray600)),
                            SizedBox(height: 4),
                            Text('• 현장명은 등록된 현장과 자동 매칭됩니다',
                              style: TextStyle(fontSize: 11, color: AppTheme.gray600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value, [bool isError = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 12, color: isError ? AppTheme.danger : AppTheme.success),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
        Expanded(
          child: Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: isError ? AppTheme.danger : AppTheme.gray800)),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _smsCtrl.dispose();
    super.dispose();
  }
}

class _ParsedData {
  final String? date;
  final String? time;
  final String? siteName;
  final String inspectionType;
  final String? agency;
  final String rawText;
  _ParsedData({
    this.date, this.time, this.siteName,
    required this.inspectionType, this.agency, required this.rawText,
  });
}

// ══════════════════════════════════════════════════════════════
// 검사 등록/수정 폼
// ══════════════════════════════════════════════════════════════
class InspectionFormSheet extends StatefulWidget {
  final Inspection? inspection;
  final DateTime? presetDate;
  const InspectionFormSheet({super.key, this.inspection, this.presetDate});

  @override
  State<InspectionFormSheet> createState() => _InspectionFormSheetState();
}

class _InspectionFormSheetState extends State<InspectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _dateCtrl = TextEditingController(
    text: widget.inspection?.inspectionDate ??
        (widget.presetDate != null
            ? DateFormat('yyyy-MM-dd').format(widget.presetDate!)
            : ''));
  late final _nextDateCtrl = TextEditingController(
    text: widget.inspection?.nextInspectionDate);
  late final _inspectorCtrl = TextEditingController(
    text: widget.inspection?.inspectorName);
  late final _agencyCtrl = TextEditingController(
    text: widget.inspection?.inspectionAgency);
  late final _reportCtrl = TextEditingController(text: widget.inspection?.reportNo);
  late final _notesCtrl = TextEditingController(text: widget.inspection?.notes);
  late String _type = widget.inspection?.inspectionType ?? '정기검사';
  // result는 검사일 기준으로 자동 결정 (미래=예정, 과거=사용자 선택)
  // 기존 검사 수정 시: '예정'이 아니면 그 값 유지, '예정'이면 날짜 다시 체크
  late String _result = _initResult();

  String _initResult() {
    final existing = widget.inspection?.result;
    if (existing != null && existing != '예정') return existing; // 이미 결과 있으면 유지
    return '예정'; // 새 등록 or 기존 예정 → 날짜에 따라 _isPast()로 판단
  }

  /// 검사일이 오늘 이전(과거/오늘)이면 true → 결과 입력 가능
  bool _isPast() {
    final txt = _dateCtrl.text.trim();
    if (txt.isEmpty) return false;
    final d = DateTime.tryParse(txt);
    if (d == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(d.year, d.month, d.day);
    return !dateOnly.isAfter(todayOnly);
  }

  List<Site> _sites = [];
  Site? _selectedSite;
  List<Elevator> _elevators = [];
  Elevator? _selectedElevator;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final sites = await ApiService.getSites();
      if (mounted) {
        setState(() { _sites = sites; });
        if (widget.inspection != null) {
          _selectedSite = sites.firstWhere(
            (s) => s.id == widget.inspection!.siteId,
            orElse: () => sites.isNotEmpty
                ? sites.first
                : Site(siteCode: '', siteName: '', address: '', status: ''),
          );
          await _loadElevators(widget.inspection!.siteId);
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
          if (widget.inspection != null) {
            _selectedElevator = elevs.firstWhere(
              (e) => e.id == widget.inspection!.elevatorId,
              orElse: () => elevs.isNotEmpty
                  ? elevs.first
                  : Elevator(siteId: siteId, elevatorNo: ''),
            );
          } else {
            _selectedElevator = elevs.isNotEmpty ? elevs.first : null;
          }
        });
      }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Text(widget.inspection == null ? '검사 등록' : '검사 수정',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('현장 *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.gray600)),
                          const SizedBox(height: 6),
                          SiteSearchField(
                            sites: _sites,
                            selected: _selectedSite,
                            onChanged: (s) {
                              setState(() {
                                _selectedSite = s;
                                _elevators = [];
                                _selectedElevator = null;
                              });
                              if (s?.id != null) _loadElevators(s!.id!);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_elevators.isNotEmpty)
                        DropdownButtonFormField<Elevator>(
                          value: _selectedElevator,
                          decoration: const InputDecoration(
                            labelText: '승강기',
                            prefixIcon: Icon(Icons.elevator_outlined, size: 18)),
                          items: _elevators.map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              '${e.elevatorName ?? e.elevatorNo} (${e.elevatorNo})',
                              overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (e) => setState(() => _selectedElevator = e),
                        ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: '검사 유형 *'),
                        items: const [
                          DropdownMenuItem(value: '완성검사', child: Text('완성검사')),
                          DropdownMenuItem(value: '정기검사', child: Text('정기검사')),
                          DropdownMenuItem(value: '수시검사', child: Text('수시검사')),
                          DropdownMenuItem(value: '정밀안전검사', child: Text('정밀안전검사')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? '정기검사'),
                      ),
                      const SizedBox(height: 8),
                      // 검사일 선택 → 날짜에 따라 결과 자동 처리
                      _dateFieldWithAutoResult(_dateCtrl, '검사일 *', required: true),
                      _dateField(_nextDateCtrl, '다음 검사 예정일'),
                      // 검사일이 오늘 이전이면 결과 입력 UI 표시
                      if (_isPast()) ..._buildResultSection()
                      else _buildScheduledBadge(),
                      const SizedBox(height: 8),
                      _field(_inspectorCtrl, '검사자'),
                      _field(_agencyCtrl, '검사기관'),
                      _field(_reportCtrl, '보고서 번호'),
                      _field(_notesCtrl, '비고', maxLines: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : Text(widget.inspection == null ? '등록하기' : '수정하기',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
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
        validator: required
            ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null
            : null,
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        validator: required
            ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null
            : null,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: ctrl.text.isNotEmpty
                ? DateTime.tryParse(ctrl.text) ?? DateTime.now()
                : DateTime.now(),
            firstDate: DateTime(2010),
            lastDate: DateTime(2035),
          );
          if (picked != null) {
            ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
          }
        },
      ),
    );
  }

  // 날짜 선택 + 결과 상태 자동 갱신
  Widget _dateFieldWithAutoResult(TextEditingController ctrl, String label,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        validator: required
            ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null
            : null,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: ctrl.text.isNotEmpty
                ? DateTime.tryParse(ctrl.text) ?? DateTime.now()
                : DateTime.now(),
            firstDate: DateTime(2010),
            lastDate: DateTime(2035),
          );
          if (picked != null) {
            ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
            // 날짜 변경 시 result 초기화: 과거 → 기존값 유지 or '합격', 미래 → '예정'
            setState(() {
              final wasPast = _isPast();
              if (!wasPast) {
                _result = '예정';
              } else if (_result == '예정') {
                _result = '합격'; // 과거 날짜 선택 시 기본 결과
              }
            });
          }
        },
      ),
    );
  }

  // 결과 입력 섹션 (검사일이 오늘 이전일 때만 표시)
  List<Widget> _buildResultSection() {
    return [
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined,
                    size: 14, color: AppTheme.gray500),
                const SizedBox(width: 6),
                const Text(
                  '검사 결과',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _resultOption('합격', AppTheme.success),
                const SizedBox(width: 8),
                _resultOption('조건부합격', AppTheme.warning),
                const SizedBox(width: 8),
                _resultOption('불합격', AppTheme.danger),
                const SizedBox(width: 8),
                _resultOption('보류', AppTheme.gray500),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _resultOption(String value, Color color) {
    final selected = _result == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _result = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : AppTheme.gray200,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : AppTheme.gray500,
            ),
          ),
        ),
      ),
    );
  }

  // 예정 상태 배지 (미래 날짜일 때 표시)
  Widget _buildScheduledBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 16, color: AppTheme.info),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '검사일이 되면 결과를 입력할 수 있습니다',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.info,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.info,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '예정',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSite == null) {
      showToast(context, '현장을 선택해주세요', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final elevId = _selectedElevator?.id
          ?? (_elevators.isNotEmpty ? _elevators.first.id! : 0);
      // 검사일 기준으로 최종 result 결정
      final finalResult = _isPast() ? _result : '예정';
      final inspection = Inspection(
        id: widget.inspection?.id,
        elevatorId: elevId,
        siteId: _selectedSite!.id!,
        inspectionType: _type,
        inspectionDate: _dateCtrl.text,
        nextInspectionDate:
            _nextDateCtrl.text.isNotEmpty ? _nextDateCtrl.text : null,
        inspectorName:
            _inspectorCtrl.text.isNotEmpty ? _inspectorCtrl.text : null,
        inspectionAgency:
            _agencyCtrl.text.isNotEmpty ? _agencyCtrl.text : null,
        result: finalResult,
        reportNo: _reportCtrl.text.isNotEmpty ? _reportCtrl.text : null,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );
      int inspectionId;
      if (widget.inspection == null) {
        inspectionId = await ApiService.createInspection(inspection);
      } else {
        await ApiService.updateInspection(widget.inspection!.id!, inspection);
        inspectionId = widget.inspection!.id!;
      }

      // 조건부합격 또는 불합격 시 → 지적사항 자동 등록 다이얼로그
      if (mounted && (finalResult == '조건부합격' || finalResult == '불합격')) {
        setState(() => _saving = false);
        final shouldAddIssue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: finalResult == '불합격' ? AppTheme.dangerLight : AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: finalResult == '불합격' ? AppTheme.danger : AppTheme.warning,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '지적사항 등록',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              '검사 결과가 [$finalResult]입니다.\n지적사항 탭에 자동으로 등록하시겠습니까?',
              style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('건너뛰기'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('지적사항 등록', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldAddIssue == true && mounted) {
          // 지적사항 등록 폼 열기 (검사 정보 자동 연동)
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => IssueFormSheet(
              issue: null,
              presetInspectionId: inspectionId,
              presetSiteId: _selectedSite!.id!,
              presetElevatorId: elevId,
              presetInspectionDate: _dateCtrl.text,
              presetInspectorName: _inspectorCtrl.text.isNotEmpty ? _inspectorCtrl.text : null,
              presetInspectionType: _type,
              presetResult: finalResult,
            ),
          );
        }
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
    _dateCtrl.dispose(); _nextDateCtrl.dispose(); _inspectorCtrl.dispose();
    _agencyCtrl.dispose(); _reportCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }
}
