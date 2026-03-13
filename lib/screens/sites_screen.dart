import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/site.dart';

const _kRegions = ['전체', '교하동', '서패동', '회동', '탄현면', '고양시', '문발동', '기타'];

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  List<Site> _sites = [];
  bool _loading = true;
  String? _error;
  String _selectedRegion = '전체';
  String _selectedTeam = '전체';
  String _searchText = '';
  String _statusFilter = '';
  final _searchCtrl = TextEditingController();

  // ── 다중선택 모드 ──
  bool _selectMode = false;
  final Set<int> _selectedIds = {};
  List<String> _teamOptions = ['파주1팀', '파주2팀'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadTeams();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sites = await ApiService.getSites(
        search: _searchText.isNotEmpty ? _searchText : null,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        region: _selectedRegion != '전체' ? _selectedRegion : null,
        team: _selectedTeam != '전체' ? _selectedTeam : null,
      );
      if (mounted) setState(() { _sites = sites; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.getTeams();
      if (mounted && teams.isNotEmpty) setState(() => _teamOptions = teams);
    } catch (_) {}
  }

  // ── 다중선택 진입/해제 ──
  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_sites.map((s) => s.id!));
    });
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
  }

  // ── 선택된 현장 팀 일괄 변경 ──
  Future<void> _bulkChangeTeam() async {
    if (_selectedIds.isEmpty) {
      showToast(context, '현장을 선택해주세요', isError: true);
      return;
    }

    // 팀 선택 다이얼로그
    String? chosenTeam = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selected;
        return StatefulBuilder(
          builder: (ctx2, setS) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.group, size: 20, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('팀 일괄 변경', style: TextStyle(fontSize: 16)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('선택된 현장 ${_selectedIds.length}개의 팀을 변경합니다.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.gray500)),
                const SizedBox(height: 16),
                // 팀 없음
                _teamChoiceTile(ctx2, setS, null, selected, (v) => selected = v),
                ..._teamOptions.map((t) =>
                    _teamChoiceTile(ctx2, setS, t, selected, (v) => selected = v)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: selected != null || selected == null
                    ? () => Navigator.pop(ctx, selected ?? '__none__')
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text('변경', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (chosenTeam == null) return;
    final teamValue = chosenTeam == '__none__' ? null : chosenTeam;

    // 일괄 업데이트 실행
    int success = 0;
    int fail = 0;
    setState(() => _loading = true);
    for (final id in _selectedIds) {
      try {
        final site = _sites.firstWhere((s) => s.id == id);
        final updated = Site(
          id: site.id,
          siteCode: site.siteCode,
          siteName: site.siteName,
          address: site.address,
          ownerName: site.ownerName,
          ownerPhone: site.ownerPhone,
          managerName: site.managerName,
          totalElevators: site.totalElevators,
          status: site.status,
          contractStart: site.contractStart,
          contractEnd: site.contractEnd,
          notes: site.notes,
          team: teamValue,
        );
        await ApiService.updateSite(site.id!, updated);
        success++;
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      setState(() { _selectMode = false; _selectedIds.clear(); });
      showToast(context, '${success}개 변경 완료${fail > 0 ? " (실패: $fail개)" : ""}');
      _load();
    }
  }

  Widget _teamChoiceTile(
    BuildContext ctx,
    StateSetter setS,
    String? value,
    String? selected,
    void Function(String?) onSelect,
  ) {
    final label = value ?? '팀 없음';
    final Color bg = value == null
        ? AppTheme.gray100
        : _teamColor(value).withValues(alpha: 0.12);
    final Color fg = value == null ? AppTheme.gray600 : _teamColor(value);
    final bool isSelected = selected == value ||
        (selected == null && value == null);
    return GestureDetector(
      onTap: () => setS(() => onSelect(value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? fg.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: isSelected ? fg : AppTheme.gray200,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected ? fg : AppTheme.gray700)),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  Color _teamColor(String team) {
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

  @override
  Widget build(BuildContext context) {
    final selCount = _selectedIds.length;
    return Scaffold(
      appBar: AppBar(
        title: _selectMode
            ? Text('$selCount개 선택됨',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            : const Text('현장 관리'),
        backgroundColor: _selectMode ? const Color(0xFFE8F0FE) : null,
        foregroundColor: _selectMode ? AppTheme.primary : null,
        elevation: _selectMode ? 0 : null,
        actions: _selectMode
            ? [
                // 전체선택/해제
                TextButton(
                  onPressed: selCount == _sites.length ? _deselectAll : _selectAll,
                  child: Text(
                    selCount == _sites.length ? '전체해제' : '전체선택',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                // 팀 변경
                TextButton.icon(
                  onPressed: _bulkChangeTeam,
                  icon: const Icon(Icons.group, size: 16),
                  label: const Text('팀 변경', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                // 취소
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSelectMode,
                ),
                const SizedBox(width: 4),
              ]
            : [
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('새로고침', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gray600),
                ),
                const SizedBox(width: 2),
                // 다중선택 모드 버튼
                TextButton.icon(
                  onPressed: _toggleSelectMode,
                  icon: const Icon(Icons.checklist, size: 15),
                  label: const Text('선택', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray700,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openSiteForm(null),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('현장 등록', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          TeamTabBar(
            selected: _selectedTeam,
            onChanged: (t) {
              setState(() => _selectedTeam = t);
              _load();
            },
          ),
          _buildRegionTabs(),
          // 선택 모드 안내 바
          if (_selectMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFE8F0FE),
              child: Text(
                selCount == 0
                    ? '현장을 탭하여 선택하세요 (롱탭으로도 선택 가능)'
                    : '$selCount개의 현장이 선택됨 · 팀 변경 버튼으로 일괄 변경',
                style: TextStyle(
                  fontSize: 12,
                  color: selCount == 0 ? AppTheme.gray500 : AppTheme.primary,
                  fontWeight: selCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? ErrorWidget2(message: _error!, onRetry: _load)
                    : _buildSiteList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '현장명/주소/코드 검색...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onSubmitted: (v) {
                _searchText = v;
                _load();
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _statusFilter.isEmpty ? '' : _statusFilter,
            underline: const SizedBox(),
            isDense: true,
            items: const [
              DropdownMenuItem(value: '', child: Text('전체', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'active', child: Text('운영중', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'inactive', child: Text('비운영', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'suspended', child: Text('중지', style: TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              _statusFilter = v ?? '';
              _load();
            },
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              _searchText = _searchCtrl.text;
              _load();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Icon(Icons.search, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionTabs() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.gray100),
          top: BorderSide(color: AppTheme.gray100),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _kRegions.length,
        itemBuilder: (_, i) {
          final region = _kRegions[i];
          final isSelected = region == _selectedRegion;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedRegion = region);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: isSelected
                      ? const BorderSide(color: AppTheme.primary, width: 2)
                      : BorderSide.none,
                ),
              ),
              child: Center(
                child: Text(
                  region,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppTheme.primary : AppTheme.gray500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSiteList() {
    if (_sites.isEmpty) {
      return const EmptyWidget(message: '등록된 현장이 없습니다', icon: Icons.business_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _sites.length,
        itemBuilder: (_, i) => _buildSiteCard(_sites[i]),
      ),
    );
  }

  Widget _buildSiteCard(Site site) {
    // elevator_count=0이면 total_elevators 사용 (실제 등록 승강기 없을 때 계약대수 표시)
    final elevCnt = (site.elevatorCount != null && site.elevatorCount! > 0)
        ? site.elevatorCount!
        : site.totalElevators;
    final isSelected = _selectedIds.contains(site.id);
    final teamColor = site.team != null ? _teamColor(site.team!) : null;
    final teamBg = site.team != null ? _teamBgColor(site.team!) : null;

    return GestureDetector(
      onLongPress: () {
        if (!_selectMode) {
          setState(() {
            _selectMode = true;
            _selectedIds.add(site.id!);
          });
        }
      },
      onTap: _selectMode
          ? () => _toggleSelect(site.id!)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (site.team != null ? teamColor!.withValues(alpha: 0.25) : AppTheme.gray200),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            // ── 팀 색상 상단 바 ──
            if (site.team != null)
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 선택 체크박스 or 아이콘
                      if (_selectMode)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.gray100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.gray300,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            isSelected ? Icons.check : Icons.check,
                            color: isSelected ? Colors.white : AppTheme.gray300,
                            size: 20,
                          ),
                        )
                      else
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: site.team != null
                                ? teamBg
                                : AppTheme.infoLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business,
                            color: site.team != null ? teamColor : AppTheme.info,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 현장명 + 배지들
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    site.siteName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.gray800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (site.team != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: teamBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: teamColor!.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      site.team!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: teamColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                StatusBadge(status: site.status),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // 주소
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 12, color: AppTheme.gray400),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    site.address,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.gray500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── 하단 구분선 + 정보 행 ──
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.gray200,
                          AppTheme.gray200,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInfoChip(Icons.elevator, '승강기 $elevCnt대', AppTheme.primary),
                      const SizedBox(width: 8),
                      if (site.managerName != null)
                        _buildInfoChip(
                            Icons.person_outline, site.managerName!, AppTheme.gray500),
                      const Spacer(),
                      if (!_selectMode) ...[
                        TextButton(
                          onPressed: () => _openSiteDetail(site),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('상세보기',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openSiteForm(site),
                          color: AppTheme.gray400,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => _deleteSite(site),
                          color: AppTheme.danger,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  void _openSiteDetail(Site site) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SiteDetailScreen(site: site),
    ));
  }

  void _openSiteForm(Site? site) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SiteFormSheet(site: site),
    );
    if (result == true) _load();
  }

  Future<void> _deleteSite(Site site) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '현장 삭제',
      content: '${site.siteName} 현장을 삭제하시겠습니까?\n관련된 승강기, 검사 기록이 모두 삭제됩니다.',
    );
    if (ok != true) return;
    try {
      await ApiService.deleteSite(site.id!);
      if (mounted) {
        showToast(context, '현장이 삭제되었습니다.');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ── 현장 상세 화면 ──────────────────────────────────────────
class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  List<Elevator> _elevators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadElevators();
  }

  Future<void> _loadElevators() async {
    try {
      final elevs = await ApiService.getSiteElevators(widget.site.id!);
      if (mounted) setState(() { _elevators = elevs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    return Scaffold(
      appBar: AppBar(
        title: Text(site.siteName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => SiteFormSheet(site: site),
              );
              if (result == true && mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addElevator(),
        icon: const Icon(Icons.add),
        label: const Text('승강기 추가'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSiteInfo(site),
            const SizedBox(height: 16),
            _buildElevatorList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteInfo(Site site) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: AppTheme.info, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(site.siteName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.gray800))),
              StatusBadge(status: site.status),
            ],
          ),
          const Divider(height: 20),
          _infoRow('현장 코드', site.siteCode),
          _infoRow('주소', site.address),
          if (site.ownerName != null) _infoRow('건물주', site.ownerName!),
          if (site.ownerPhone != null) _infoRow('연락처', site.ownerPhone!),
          if (site.managerName != null) _infoRow('담당자', site.managerName!),
          if (site.contractStart != null)
            _infoRow('계약기간', '${fmtDate(site.contractStart)} ~ ${fmtDate(site.contractEnd)}'),
          if (site.notes != null) _infoRow('비고', site.notes!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray400)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.gray700)),
          ),
        ],
      ),
    );
  }

  Widget _buildElevatorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '승강기 목록',
          icon: Icons.elevator,
          iconColor: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_elevators.isEmpty)
          const EmptyWidget(message: '등록된 승강기가 없습니다', icon: Icons.elevator_outlined)
        else
          ...(_elevators.map((e) => _buildElevatorCard(e))),
      ],
    );
  }

  Widget _buildElevatorCard(Elevator elevator) {
    final statusColor = statusColors[elevator.status] ?? AppTheme.gray500;
    final statusBgColor = statusBgColors[elevator.status] ?? AppTheme.gray100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.elevator, color: statusColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(elevator.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.gray800)),
                      const SizedBox(width: 6),
                      StatusBadge(status: elevator.status),
                    ],
                  ),
                  Text('${elevator.elevatorType} · ${elevator.elevatorNo}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                  if (elevator.manufacturer != null)
                    Text('${elevator.manufacturer} · ${elevator.floorsServed ?? ""}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editElevator(elevator);
                if (v == 'delete') _deleteElevator(elevator);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: AppTheme.danger))),
              ],
              child: const Icon(Icons.more_vert, size: 18, color: AppTheme.gray400),
            ),
          ],
        ),
      ),
    );
  }

  void _addElevator() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ElevatorFormSheet(siteId: widget.site.id!),
    );
    if (result == true) _loadElevators();
  }

  void _editElevator(Elevator elevator) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ElevatorFormSheet(siteId: widget.site.id!, elevator: elevator),
    );
    if (result == true) _loadElevators();
  }

  Future<void> _deleteElevator(Elevator elevator) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '승강기 삭제',
      content: '${elevator.displayName}을 삭제하시겠습니까?',
    );
    if (ok != true) return;
    try {
      await ApiService.deleteElevator(elevator.id!);
      if (mounted) {
        showToast(context, '승강기가 삭제되었습니다.');
        _loadElevators();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ── 현장 폼 시트 ───────────────────────────────────────────
// ── 현장 + 호기 통합 등록 폼 ─────────────────────────────────────────
class SiteFormSheet extends StatefulWidget {
  final Site? site;
  const SiteFormSheet({super.key, this.site});

  @override
  State<SiteFormSheet> createState() => _SiteFormSheetState();
}

// 호기 입력 데이터 모델
class _ElevatorEntry {
  final TextEditingController noCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController mfrCtrl;
  final TextEditingController floorsCtrl;
  final TextEditingController capCtrl;
  String type;
  String status;

  _ElevatorEntry({
    String no = '',
    String name = '',
    String type = '승객용',
    String status = 'normal',
  })  : noCtrl = TextEditingController(text: no),
        nameCtrl = TextEditingController(text: name),
        mfrCtrl = TextEditingController(),
        floorsCtrl = TextEditingController(),
        capCtrl = TextEditingController(),
        type = type,
        status = status;

  void dispose() {
    noCtrl.dispose();
    nameCtrl.dispose();
    mfrCtrl.dispose();
    floorsCtrl.dispose();
    capCtrl.dispose();
  }
}

class _SiteFormSheetState extends State<SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  // 현장 정보
  late final _nameCtrl = TextEditingController(text: widget.site?.siteName);
  late final _addrCtrl = TextEditingController(text: widget.site?.address);
  late final _ownerCtrl = TextEditingController(text: widget.site?.ownerName);
  late final _phoneCtrl = TextEditingController(text: widget.site?.ownerPhone);
  late final _mgCtrl = TextEditingController(text: widget.site?.managerName);
  late final _notesCtrl = TextEditingController(text: widget.site?.notes);
  late String _status = widget.site?.status ?? 'active';
  late String? _team = widget.site?.team;
  List<String> _teamOptions = ['파주1팀', '파주2팀'];

  // 호기 목록 (신규 등록 시만 표시)
  final List<_ElevatorEntry> _elevators = [];
  bool _showElevators = true; // 호기 섹션 접기/펼치기

  bool _saving = false;

  final _elevTypes = ['승객용', '화물용', '비상용', '장애인용', '소형화물용', '에스컬레이터', '무빙워크'];
  final _elevStatuses = ['normal', 'warning', 'fault', 'stopped'];
  final _elevStatusLabels = {'normal': '정상', 'warning': '주의', 'fault': '고장', 'stopped': '정지'};

  bool get _isNew => widget.site == null;

  @override
  void initState() {
    super.initState();
    // 신규 등록 시 기본 호기 1개 자동 추가
    if (_isNew) {
      _elevators.add(_ElevatorEntry(no: '1', name: '1호기'));
    }
    // 팀 목록 로드
    _loadTeams();
  }

  Future<void> _addTeam() async {
    final ctrl = TextEditingController();
    final newTeam = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.group_add, size: 20),
          SizedBox(width: 8),
          Text('팀 추가', style: TextStyle(fontSize: 16)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '팀 이름',
            hintText: '예) 파주3팀',
            prefixIcon: Icon(Icons.group_outlined, size: 18),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (newTeam == null || newTeam.isEmpty) return;
    try {
      await ApiService.addTeam(newTeam);
      setState(() {
        if (!_teamOptions.contains(newTeam)) {
          _teamOptions = [..._teamOptions, newTeam];
        }
        _team = newTeam;
      });
      if (mounted) showToast(context, "'$newTeam' 팀이 추가되었습니다.");
    } catch (e) {
      if (mounted) showToast(context, '팀 추가 실패: $e', isError: true);
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.getTeams();
      if (mounted && teams.isNotEmpty) {
        setState(() => _teamOptions = teams);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _mgCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _elevators) {
      e.dispose();
    }
    super.dispose();
  }

  void _addElevator() {
    setState(() {
      final idx = _elevators.length + 1;
      _elevators.add(_ElevatorEntry(no: '$idx', name: '${idx}호기'));
    });
  }

  void _removeElevator(int index) {
    setState(() {
      _elevators[index].dispose();
      _elevators.removeAt(index);
    });
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 헤더 ──
              Row(
                children: [
                  Icon(Icons.business, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isNew ? '현장 등록' : '현장 수정',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 현장 정보 섹션 ──
                      _sectionHeader(Icons.location_on_outlined, '현장 정보', theme),
                      const SizedBox(height: 8),
                      _field(_nameCtrl, '현장명 *', required: true),
                      _field(_addrCtrl, '주소 *', required: true),
                      Row(
                        children: [
                          Expanded(child: _field(_ownerCtrl, '건물주')),
                          const SizedBox(width: 8),
                          Expanded(child: _field(_phoneCtrl, '연락처')),
                        ],
                      ),
                      _field(_mgCtrl, '담당자'),
                      // ── 팀 선택 + 팀 추가 버튼 ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _teamOptions.contains(_team) ? _team : null,
                              decoration: const InputDecoration(
                                labelText: '팀',
                                prefixIcon: Icon(Icons.group_outlined, size: 18),
                              ),
                              hint: const Text('팀 선택'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('팀 없음')),
                                ..._teamOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                              ],
                              onChanged: (v) => setState(() => _team = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 팀 추가 버튼
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _addTeam,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('팀 추가', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '상태'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('운영중')),
                          DropdownMenuItem(value: 'inactive', child: Text('비운영')),
                          DropdownMenuItem(value: 'suspended', child: Text('중지')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'active'),
                      ),
                      const SizedBox(height: 8),
                      _field(_notesCtrl, '비고', maxLines: 2),

                      // ── 호기 섹션 (신규 등록 시만) ──
                      if (_isNew) ...[
                        const SizedBox(height: 16),
                        // 호기 섹션 헤더 (접기/펼치기)
                        InkWell(
                          onTap: () => setState(() => _showElevators = !_showElevators),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.elevator, color: theme.colorScheme.primary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '호기 등록',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_elevators.length}대',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '현장 등록 후 함께 등록됩니다',
                                  style: TextStyle(fontSize: 10, color: AppTheme.gray500),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showElevators ? Icons.expand_less : Icons.expand_more,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_showElevators) ...[
                          const SizedBox(height: 8),
                          // 호기 카드 목록
                          ...List.generate(_elevators.length, (i) => _buildElevatorCard(i, theme)),
                          // 호기 추가 버튼
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _addElevator,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('호기 추가', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isNew ? Icons.check : Icons.save, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _isNew
                                  ? (_elevators.isNotEmpty
                                      ? '현장 + 호기 ${_elevators.length}대 등록'
                                      : '현장 등록')
                                  : '수정 저장',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
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

  Widget _sectionHeader(IconData icon, String title, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.gray500),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildElevatorCard(int i, ThemeData theme) {
    final e = _elevators[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 헤더
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${i + 1}호기',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // 삭제 버튼
              if (_elevators.isNotEmpty)
                InkWell(
                  onTap: () => _removeElevator(i),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: AppTheme.gray400),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 호기번호 + 명칭
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _elevField(e.noCtrl, '호기번호 *', required: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _elevField(e.nameCtrl, '명칭 (예: A동 1호기)'),
              ),
            ],
          ),
          // 종류 + 상태
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: e.type,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: '종류',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: _elevTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => e.type = v ?? '승객용'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: e.status,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: '상태',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  items: _elevStatuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_elevStatusLabels[s] ?? s, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => e.status = v ?? 'normal'),
                ),
              ),
            ],
          ),
          // 제조사 + 운행층 (선택)
          Row(
            children: [
              Expanded(child: _elevField(e.mfrCtrl, '제조사')),
              const SizedBox(width: 8),
              Expanded(child: _elevField(e.floorsCtrl, '운행층')),
            ],
          ),
        ],
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
        validator:
            required ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null : null,
      ),
    );
  }

  Widget _elevField(TextEditingController ctrl, String label,
      {bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator:
            required ? (v) => (v?.isEmpty ?? true) ? '필수' : null : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final site = Site(
        id: widget.site?.id,
        siteCode: widget.site?.siteCode ??
            'S-${DateTime.now().millisecondsSinceEpoch}',
        siteName: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim(),
        ownerName:
            _ownerCtrl.text.isNotEmpty ? _ownerCtrl.text.trim() : null,
        ownerPhone:
            _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text.trim() : null,
        managerName: _mgCtrl.text.isNotEmpty ? _mgCtrl.text.trim() : null,
        status: _status,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text.trim() : null,
        team: _team,
      );

      if (_isNew) {
        // 현장 생성
        final newSiteId = await ApiService.createSite(site);
        // 호기 일괄 등록
        int successCount = 0;
        for (final e in _elevators) {
          if (e.noCtrl.text.trim().isEmpty) continue;
          try {
            final elevator = Elevator(
              siteId: newSiteId,
              elevatorNo: e.noCtrl.text.trim(),
              elevatorName:
                  e.nameCtrl.text.isNotEmpty ? e.nameCtrl.text.trim() : null,
              elevatorType: e.type,
              manufacturer:
                  e.mfrCtrl.text.isNotEmpty ? e.mfrCtrl.text.trim() : null,
              floorsServed: e.floorsCtrl.text.isNotEmpty
                  ? e.floorsCtrl.text.trim()
                  : null,
              capacity: int.tryParse(e.capCtrl.text),
              status: e.status,
            );
            await ApiService.createElevator(newSiteId, elevator);
            successCount++;
          } catch (_) {
            // 개별 호기 실패는 무시하고 계속 진행
          }
        }
        if (mounted) {
          if (successCount > 0) {
            showToast(context,
                '현장 등록 완료! 호기 ${successCount}대가 함께 등록되었습니다.');
          } else if (_elevators.isNotEmpty) {
            showToast(context, '현장은 등록되었으나 호기 등록에 실패했습니다.',
                isError: true);
          }
          Navigator.pop(context, true);
        }
      } else {
        // 현장 수정만
        await ApiService.updateSite(widget.site!.id!, site);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}


// ── 승강기 폼 시트 ─────────────────────────────────────────
class ElevatorFormSheet extends StatefulWidget {
  final int siteId;
  final Elevator? elevator;
  const ElevatorFormSheet({super.key, required this.siteId, this.elevator});

  @override
  State<ElevatorFormSheet> createState() => _ElevatorFormSheetState();
}

class _ElevatorFormSheetState extends State<ElevatorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _noCtrl = TextEditingController(text: widget.elevator?.elevatorNo);
  late final _nameCtrl = TextEditingController(text: widget.elevator?.elevatorName);
  late final _mfrCtrl = TextEditingController(text: widget.elevator?.manufacturer);
  late final _floorsCtrl = TextEditingController(text: widget.elevator?.floorsServed);
  late final _capCtrl = TextEditingController(text: widget.elevator?.capacity?.toString());
  late final _notesCtrl = TextEditingController(text: widget.elevator?.notes);
  late String _type = widget.elevator?.elevatorType ?? '승객용';
  late String _status = widget.elevator?.status ?? 'normal';
  bool _saving = false;

  final _types = ['승객용', '화물용', '비상용', '장애인용', '소형화물용', '에스컬레이터', '무빙워크'];
  final _statuses = ['normal', 'warning', 'fault', 'stopped'];
  final _statusLabels = {'normal': '정상', 'warning': '주의', 'fault': '고장', 'stopped': '정지'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.elevator == null ? '승강기 등록' : '승강기 수정',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _field(_noCtrl, '승강기 번호 *', required: true),
                      _field(_nameCtrl, '승강기 명칭 (예: A동 1호기)'),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: '종류'),
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _type = v ?? '승객용'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _field(_mfrCtrl, '제조사')),
                          const SizedBox(width: 8),
                          Expanded(child: _field(_floorsCtrl, '운행층')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _field(_capCtrl, '정원(명)', number: true)),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: '상태'),
                            items: _statuses.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_statusLabels[s] ?? s),
                            )).toList(),
                            onChanged: (v) => setState(() => _status = v ?? 'normal'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _field(_notesCtrl, '비고', maxLines: 2),
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
                      : Text(widget.elevator == null ? '등록' : '수정'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, bool number = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: required ? (v) => (v?.isEmpty ?? true) ? '필수 항목입니다' : null : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final elevator = Elevator(
        id: widget.elevator?.id,
        siteId: widget.siteId,
        elevatorNo: _noCtrl.text,
        elevatorName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : null,
        elevatorType: _type,
        manufacturer: _mfrCtrl.text.isNotEmpty ? _mfrCtrl.text : null,
        floorsServed: _floorsCtrl.text.isNotEmpty ? _floorsCtrl.text : null,
        capacity: int.tryParse(_capCtrl.text),
        status: _status,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );
      if (widget.elevator == null) {
        await ApiService.createElevator(widget.siteId, elevator);
      } else {
        await ApiService.updateElevator(widget.elevator!.id!, elevator);
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
    _noCtrl.dispose(); _nameCtrl.dispose(); _mfrCtrl.dispose();
    _floorsCtrl.dispose(); _capCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }
}
