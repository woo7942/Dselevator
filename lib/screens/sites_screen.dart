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
  String _searchText = '';
  String _statusFilter = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
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
      );
      if (mounted) setState(() { _sites = sites; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('현장 관리'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openSiteForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildRegionTabs(),
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
        padding: const EdgeInsets.all(12),
        itemCount: _sites.length,
        itemBuilder: (_, i) => _buildSiteCard(_sites[i]),
      ),
    );
  }

  Widget _buildSiteCard(Site site) {
    final elevCnt = site.elevatorCount ?? site.totalElevators;
    return InfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business, color: AppTheme.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(site.siteName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.gray800)),
                        ),
                        StatusBadge(status: site.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.gray400),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(site.address,
                            style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildInfoChip(Icons.elevator, '승강기 $elevCnt대', AppTheme.primary),
              const SizedBox(width: 8),
              if (site.managerName != null)
                _buildInfoChip(Icons.person_outline, site.managerName!, AppTheme.gray500),
              const Spacer(),
              TextButton(
                onPressed: () => _openSiteDetail(site),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('상세보기', style: TextStyle(fontSize: 12)),
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
          ),
        ],
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
class SiteFormSheet extends StatefulWidget {
  final Site? site;
  const SiteFormSheet({super.key, this.site});

  @override
  State<SiteFormSheet> createState() => _SiteFormSheetState();
}

class _SiteFormSheetState extends State<SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _codeCtrl = TextEditingController(text: widget.site?.siteCode);
  late final _nameCtrl = TextEditingController(text: widget.site?.siteName);
  late final _addrCtrl = TextEditingController(text: widget.site?.address);
  late final _ownerCtrl = TextEditingController(text: widget.site?.ownerName);
  late final _phoneCtrl = TextEditingController(text: widget.site?.ownerPhone);
  late final _mgCtrl = TextEditingController(text: widget.site?.managerName);
  late final _notesCtrl = TextEditingController(text: widget.site?.notes);
  late String _status = widget.site?.status ?? 'active';
  bool _saving = false;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(widget.site == null ? '현장 등록' : '현장 수정',
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
                      DropdownButtonFormField<String>(
                        value: _status,
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
                      : Text(widget.site == null ? '등록' : '수정'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1}) {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final site = Site(
        id: widget.site?.id,
        siteCode: widget.site?.siteCode ?? 'S-${DateTime.now().millisecondsSinceEpoch}',
        siteName: _nameCtrl.text,
        address: _addrCtrl.text,
        ownerName: _ownerCtrl.text.isNotEmpty ? _ownerCtrl.text : null,
        ownerPhone: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : null,
        managerName: _mgCtrl.text.isNotEmpty ? _mgCtrl.text : null,
        status: _status,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );
      if (widget.site == null) {
        await ApiService.createSite(site);
      } else {
        await ApiService.updateSite(widget.site!.id!, site);
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
    _codeCtrl.dispose(); _nameCtrl.dispose(); _addrCtrl.dispose();
    _ownerCtrl.dispose(); _phoneCtrl.dispose(); _mgCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
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
                            value: _status,
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
