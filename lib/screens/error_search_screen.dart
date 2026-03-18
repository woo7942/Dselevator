import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/error_code.dart';
import '../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
// 에러코드 검색 메인 화면 – 제조사별 탭 구조
// ═══════════════════════════════════════════════════════════════
class ErrorSearchScreen extends StatefulWidget {
  const ErrorSearchScreen({super.key});

  @override
  State<ErrorSearchScreen> createState() => _ErrorSearchScreenState();
}

class _ErrorSearchScreenState extends State<ErrorSearchScreen> {
  // 제조사 탭 정보 (아이콘, 색상, 표시명)
  static const _tabs = [
    _MfgTab(key: 'ALL',          label: '전체',         color: Color(0xFF6366F1), icon: Icons.search),
    _MfgTab(key: 'TAC (TK50G)', label: 'TAC\n(TK50G)', color: Color(0xFF0891B2), icon: Icons.settings_input_component),
    _MfgTab(key: 'MHC2',        label: 'MHC2',         color: Color(0xFF059669), icon: Icons.memory),
    _MfgTab(key: 'MC2-Be',      label: 'MC2-Be',       color: Color(0xFFD97706), icon: Icons.electrical_services),
    _MfgTab(key: 'CPIK',        label: 'CPIK\nInverter', color: Color(0xFFDC2626), icon: Icons.bolt),
  ];

  int _tabIndex = 0;
  final _searchCtrl = TextEditingController();
  String _selectedSeverity = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.currentUser?.isAdmin ?? false;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isWide
          ? _buildWideLayout(isAdmin)
          : _buildNarrowLayout(isAdmin),
    );
  }

  // ── 태블릿 / 데스크탑: 왼쪽 탭 사이드바 ──────────────────────
  Widget _buildWideLayout(bool isAdmin) {
    return Row(
      children: [
        _buildTabSidebar(),
        const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
        Expanded(child: _buildContent(isAdmin)),
      ],
    );
  }

  // ── 모바일: 상단 스크롤 탭 ──────────────────────────────────
  Widget _buildNarrowLayout(bool isAdmin) {
    return Column(
      children: [
        _buildTopTabBar(),
        Expanded(child: _buildContent(isAdmin)),
      ],
    );
  }

  // ── 왼쪽 제조사 탭 사이드바 ────────────────────────────────
  Widget _buildTabSidebar() {
    return Container(
      width: 88,
      color: Colors.white,
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              border: Border(bottom: BorderSide(color: Color(0xFFF59E0B), width: 2)),
            ),
            child: const Column(
              children: [
                Icon(Icons.search, color: Color(0xFFD97706), size: 22),
                SizedBox(height: 4),
                Text('에러\n검색', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 탭 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              itemCount: _tabs.length,
              itemBuilder: (_, i) => _buildSideTab(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideTab(int i) {
    final tab = _tabs[i];
    final selected = _tabIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? tab.color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: tab.color, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: selected ? tab.color : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(tab.icon, size: 17, color: selected ? Colors.white : AppTheme.gray500),
            ),
            const SizedBox(height: 5),
            Text(tab.label, textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? tab.color : AppTheme.gray600,
                  height: 1.2,
                )),
          ],
        ),
      ),
    );
  }

  // ── 모바일 상단 탭바 ─────────────────────────────────────────
  Widget _buildTopTabBar() {
    return Container(
      color: Colors.white,
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _tabs.length,
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          final selected = _tabIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? tab.color : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 14, color: selected ? Colors.white : AppTheme.gray500),
                  const SizedBox(width: 5),
                  Text(tab.label.replaceAll('\n', ' '),
                      style: TextStyle(
                        fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? Colors.white : AppTheme.gray600,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 메인 컨텐츠 영역 ─────────────────────────────────────────
  Widget _buildContent(bool isAdmin) {
    final tab = _tabs[_tabIndex];
    final mfg = tab.key == 'ALL' ? null : tab.key;
    return _ErrorListPane(
      key: ValueKey('${tab.key}_${_selectedSeverity}_${_searchCtrl.text}'),
      manufacturer: mfg,
      severity: _selectedSeverity.isEmpty ? null : _selectedSeverity,
      searchQuery: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      tabColor: tab.color,
      tabLabel: tab.label,
      isAdmin: isAdmin,
      onSearchChanged: (q) => setState(() {}),
      searchCtrl: _searchCtrl,
      selectedSeverity: _selectedSeverity,
      onSeverityChanged: (s) => setState(() => _selectedSeverity = s),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 탭별 에러 목록 패널
// ═══════════════════════════════════════════════════════════════
class _ErrorListPane extends StatefulWidget {
  final String? manufacturer;
  final String? severity;
  final String? searchQuery;
  final Color tabColor;
  final String tabLabel;
  final bool isAdmin;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController searchCtrl;
  final String selectedSeverity;
  final ValueChanged<String> onSeverityChanged;

  const _ErrorListPane({
    super.key,
    this.manufacturer,
    this.severity,
    this.searchQuery,
    required this.tabColor,
    required this.tabLabel,
    required this.isAdmin,
    required this.onSearchChanged,
    required this.searchCtrl,
    required this.selectedSeverity,
    required this.onSeverityChanged,
  });

  @override
  State<_ErrorListPane> createState() => _ErrorListPaneState();
}

class _ErrorListPaneState extends State<_ErrorListPane> {
  List<ErrorCode> _items = [];
  bool _loading = true;
  String? _error;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.getErrorCodes(
        q: widget.searchQuery,
        manufacturer: widget.manufacturer,
        severity: widget.severity,
      );
      if (mounted) setState(() { _items = list; _loading = false; _searched = true; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _triggerSearch() {
    widget.onSearchChanged(widget.searchCtrl.text);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        _buildStats(),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: widget.tabColor))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
                  : _items.isEmpty && _searched
                      ? _buildEmpty()
                      : _buildList(),
        ),
      ],
    );
  }

  // ── 검색바 ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // 제목 + 관리자 뱃지
          Row(
            children: [
              Container(
                width: 6, height: 20,
                decoration: BoxDecoration(color: widget.tabColor, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.manufacturer ?? '전체 에러코드',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.tabColor),
                ),
              ),
              if (widget.isAdmin)
                GestureDetector(
                  onTap: () => _showAddDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.tabColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 13, color: Colors.white),
                        SizedBox(width: 3),
                        Text('등록', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 검색창
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '에러코드 번호, 키워드 검색...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.gray400),
                    prefixIcon: const Icon(Icons.search, size: 17, color: AppTheme.gray400),
                    suffixIcon: widget.searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () { widget.searchCtrl.clear(); _triggerSearch(); },
                          )
                        : null,
                    filled: true, fillColor: AppTheme.gray50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _triggerSearch(),
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 6),
              // 심각도 필터
              _SeverityDropdown(
                value: widget.selectedSeverity,
                onChanged: (v) { widget.onSeverityChanged(v); _load(); },
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _triggerSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.tabColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(50, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('검색', style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 통계 바 ───────────────────────────────────────────────────
  Widget _buildStats() {
    if (_loading || _items.isEmpty) return const SizedBox.shrink();
    final emergency = _items.where((e) => e.severity == '긴급').length;
    final warning = _items.where((e) => e.severity == '주의').length;
    final normal = _items.where((e) => e.severity == '일반').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Text('총 ${_items.length}건', style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
          const Spacer(),
          if (emergency > 0) _statChip('긴급 $emergency', AppTheme.danger, AppTheme.dangerLight),
          if (warning > 0) _statChip('주의 $warning', AppTheme.warning, AppTheme.warningLight),
          if (normal > 0) _statChip('일반 $normal', AppTheme.info, AppTheme.infoLight),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color fg, Color bg) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  // ── 빈 상태 ───────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 52, color: widget.tabColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('검색 결과가 없습니다', style: TextStyle(fontSize: 15, color: AppTheme.gray500)),
          const SizedBox(height: 6),
          Text(widget.manufacturer != null
              ? '${widget.manufacturer} 에러코드를 찾을 수 없습니다'
              : '다른 검색어로 시도해보세요',
              style: const TextStyle(fontSize: 12, color: AppTheme.gray400)),
        ],
      ),
    );
  }

  // ── 목록 ─────────────────────────────────────────────────────
  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 80),
      itemCount: _items.length,
      itemBuilder: (_, i) => _buildCard(_items[i]),
    );
  }

  Widget _buildCard(ErrorCode ec) {
    final (fg, bg) = _severityColors(ec.severity);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: ec.severity == '긴급' ? AppTheme.dangerLight : AppTheme.gray200),
      ),
      child: InkWell(
        onTap: () => _showDetail(context, ec),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 에러코드 박스
              Container(
                width: 64, height: 40,
                decoration: BoxDecoration(
                  color: widget.tabColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.tabColor.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(ec.errorCode,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: widget.tabColor, fontFamily: 'monospace',
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ec.errorTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (ec.errorDescription != null && ec.errorDescription!.isNotEmpty)
                      Text(ec.errorDescription!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                    child: Text(ec.severity, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _showEditDialog(context, ec),
                          child: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.gray400),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _confirmDelete(context, ec),
                          child: const Icon(Icons.delete_outline, size: 14, color: AppTheme.danger),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _severityColors(String s) {
    return switch (s) {
      '긴급' => (AppTheme.danger, AppTheme.dangerLight),
      '주의' => (AppTheme.warning, AppTheme.warningLight),
      _ => (AppTheme.info, AppTheme.infoLight),
    };
  }

  // ════════════════════════════════════════════════════════════
  // 상세 바텀시트
  // ════════════════════════════════════════════════════════════
  void _showDetail(BuildContext context, ErrorCode ec) async {
    ErrorCode detail = ec;
    try {
      detail = await ApiService.getErrorCode(ec.id);
    } catch (_) {}
    if (!mounted) return;
    final ctx = context;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        errorCode: detail,
        isAdmin: widget.isAdmin,
        tabColor: widget.tabColor,
        onRefresh: _load,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 등록 / 수정 다이얼로그
  // ════════════════════════════════════════════════════════════
  void _showAddDialog(BuildContext context) => _showFormDialog(context, null);
  void _showEditDialog(BuildContext context, ErrorCode ec) => _showFormDialog(context, ec);

  void _showFormDialog(BuildContext context, ErrorCode? ec) {
    final isEdit = ec != null;
    final codeCtrl = TextEditingController(text: ec?.errorCode ?? '');
    final mfgCtrl = TextEditingController(text: ec?.manufacturer ?? (widget.manufacturer ?? ''));
    final titleCtrl = TextEditingController(text: ec?.errorTitle ?? '');
    final descCtrl = TextEditingController(text: ec?.errorDescription ?? '');
    final causeCtrl = TextEditingController(text: ec?.cause ?? '');
    final solCtrl = TextEditingController(text: ec?.solution ?? '');
    String severity = ec?.severity ?? '일반';
    final auth = context.read<AuthProvider>();
    final createdBy = auth.currentUser?.name ?? '관리자';

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx2, setS) => AlertDialog(
          title: Text(isEdit ? '에러코드 수정' : '에러코드 등록',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: _field(codeCtrl, '에러코드 *', '예: 1007, ERR-01...')),
                    const SizedBox(width: 8),
                    Expanded(child: _field(mfgCtrl, '제조사 *', '예: MHC2, TAC...')),
                  ]),
                  const SizedBox(height: 8),
                  _field(titleCtrl, '에러 제목 *', '에러 제목'),
                  const SizedBox(height: 8),
                  _field(descCtrl, '에러 설명', '에러 내용 설명', lines: 2),
                  const SizedBox(height: 8),
                  _field(causeCtrl, '원인', '발생 원인', lines: 2),
                  const SizedBox(height: 8),
                  _field(solCtrl, '해결방법', '조치 방법', lines: 3),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('심각도', style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
                    const SizedBox(width: 12),
                    ...['일반', '주의', '긴급'].map((s) {
                      final (fg, bg) = _severityColors(s);
                      return GestureDetector(
                        onTap: () => setS(() => severity = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: severity == s ? bg : AppTheme.gray100,
                            borderRadius: BorderRadius.circular(6),
                            border: severity == s ? Border.all(color: fg) : null,
                          ),
                          child: Text(s, style: TextStyle(fontSize: 12, color: severity == s ? fg : AppTheme.gray500, fontWeight: severity == s ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    }),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx2), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.tabColor),
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || mfgCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) {
                  showToast(context, '에러코드, 제조사, 제목은 필수입니다.', isError: true);
                  return;
                }
                final body = {
                  'error_code': codeCtrl.text.trim(),
                  'manufacturer': mfgCtrl.text.trim(),
                  'elevator_type': '전체',
                  'error_title': titleCtrl.text.trim(),
                  'error_description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'cause': causeCtrl.text.trim().isEmpty ? null : causeCtrl.text.trim(),
                  'solution': solCtrl.text.trim().isEmpty ? null : solCtrl.text.trim(),
                  'severity': severity,
                  'created_by': createdBy,
                };
                try {
                  if (isEdit) {
                    await ApiService.updateErrorCode(ec!.id, body);
                  } else {
                    await ApiService.createErrorCode(body);
                  }
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(dCtx2);
                    // ignore: use_build_context_synchronously
                    showToast(context, isEdit ? '수정되었습니다.' : '등록되었습니다.');
                    _load();
                  }
                } catch (e) {
                  // ignore: use_build_context_synchronously
                  if (mounted) showToast(context, '오류: $e', isError: true);
                }
              },
              child: Text(isEdit ? '수정' : '등록', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, {int lines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.gray600)),
        const SizedBox(height: 3),
        TextField(
          controller: ctrl, maxLines: lines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(fontSize: 12, color: AppTheme.gray400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppTheme.gray200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppTheme.gray200)),
            isDense: true,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ErrorCode ec) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('에러코드 삭제', style: TextStyle(fontSize: 15)),
        content: Text('[${ec.errorCode}] ${ec.errorTitle}\n삭제하면 댓글도 모두 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              try {
                await ApiService.deleteErrorCode(ec.id);
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(dCtx);
                  // ignore: use_build_context_synchronously
                  showToast(context, '삭제되었습니다.');
                  _load();
                }
              } catch (e) {
                // ignore: use_build_context_synchronously
                if (mounted) showToast(context, '오류: $e', isError: true);
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 심각도 드롭다운
// ═══════════════════════════════════════════════════════════════
class _SeverityDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SeverityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? '전체' : value,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray700),
          items: ['전체', '긴급', '주의', '일반'].map((e) =>
            DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => onChanged(v == '전체' ? '' : (v ?? '')),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 상세보기 바텀시트
// ═══════════════════════════════════════════════════════════════
class _DetailSheet extends StatefulWidget {
  final ErrorCode errorCode;
  final bool isAdmin;
  final Color tabColor;
  final VoidCallback onRefresh;
  const _DetailSheet({required this.errorCode, required this.isAdmin, required this.tabColor, required this.onRefresh});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late ErrorCode _ec;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _ec = widget.errorCode;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final author = context.read<AuthProvider>().currentUser?.name ?? '관리자';
    setState(() => _posting = true);
    try {
      final c = await ApiService.addErrorComment(_ec.id, author, text);
      setState(() {
        _ec = _ec.copyWith(comments: [..._ec.comments, c]);
        _commentCtrl.clear();
        _posting = false;
      });
      widget.onRefresh();
    } catch (e) {
      setState(() => _posting = false);
      if (mounted) showToast(context, '댓글 오류: $e', isError: true);
    }
  }

  Future<void> _deleteComment(ErrorComment c) async {
    try {
      await ApiService.deleteErrorComment(_ec.id, c.id);
      setState(() => _ec = _ec.copyWith(comments: _ec.comments.where((x) => x.id != c.id).toList()));
      widget.onRefresh();
    } catch (e) {
      if (mounted) showToast(context, '삭제 오류: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (_ec.severity) {
      '긴급' => (AppTheme.danger, AppTheme.dangerLight),
      '주의' => (AppTheme.warning, AppTheme.warningLight),
      _ => (AppTheme.info, AppTheme.infoLight),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.gray300, borderRadius: BorderRadius.circular(2)),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.tabColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.tabColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(_ec.errorCode,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.tabColor, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                    child: Text(_ec.severity, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(_ec.manufacturer, style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
                ],
              ),
            ),
            const Divider(height: 1),
            // 내용
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_ec.errorTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
                  if (_ec.errorDescription != null && _ec.errorDescription!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_ec.errorDescription!, style: const TextStyle(fontSize: 13, color: AppTheme.gray600, height: 1.6)),
                  ],
                  if (_ec.cause != null && _ec.cause!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section(Icons.help_outline, '원인', _ec.cause!, AppTheme.warningLight, AppTheme.warning),
                  ],
                  if (_ec.solution != null && _ec.solution!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _section(Icons.build_outlined, '해결방법', _ec.solution!, AppTheme.successLight, AppTheme.success),
                  ],
                  // 댓글
                  const SizedBox(height: 20),
                  Row(children: [
                    const Icon(Icons.comment_outlined, size: 15, color: AppTheme.gray500),
                    const SizedBox(width: 6),
                    Text('관리자 코멘트 (${_ec.comments.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
                  ]),
                  const SizedBox(height: 6),
                  const Divider(),
                  if (_ec.comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('등록된 코멘트가 없습니다', style: TextStyle(fontSize: 12, color: AppTheme.gray400), textAlign: TextAlign.center),
                    )
                  else
                    ..._ec.comments.map((c) => _commentTile(c)),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 12),
                    _commentInput(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title, String content, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
          ]),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.gray700, height: 1.6)),
        ],
      ),
    );
  }

  Widget _commentTile(ErrorComment c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 11, backgroundColor: widget.tabColor.withValues(alpha: 0.15),
              child: Text(c.author.isNotEmpty ? c.author[0] : 'A',
                  style: TextStyle(fontSize: 10, color: widget.tabColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 7),
            Text(c.author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
            const Spacer(),
            Text(_fmt(c.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.gray400)),
            if (widget.isAdmin) ...[
              const SizedBox(width: 4),
              InkWell(onTap: () => _deleteComment(c), child: const Icon(Icons.close, size: 13, color: AppTheme.gray400)),
            ],
          ]),
          const SizedBox(height: 5),
          Text(c.content, style: const TextStyle(fontSize: 12, color: AppTheme.gray600, height: 1.5)),
        ],
      ),
    );
  }

  Widget _commentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            maxLines: 3, minLines: 2,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '현장 경험, 주의사항 등 코멘트 작성...',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.gray400),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.gray200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.gray200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _posting ? null : _addComment,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.tabColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _posting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white, size: 16),
                      SizedBox(height: 2),
                      Text('등록', style: TextStyle(fontSize: 10, color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.month}/${d.day}';
    } catch (_) {
      return raw.length > 5 ? raw.substring(0, 5) : raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 데이터 클래스
// ═══════════════════════════════════════════════════════════════
class _MfgTab {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _MfgTab({required this.key, required this.label, required this.color, required this.icon});
}
