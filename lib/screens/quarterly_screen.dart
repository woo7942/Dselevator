import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import '../models/check.dart';
import '../models/site.dart';

class QuarterlyScreen extends StatefulWidget {
  const QuarterlyScreen({super.key});

  @override
  State<QuarterlyScreen> createState() => _QuarterlyScreenState();
}

class _QuarterlyScreenState extends State<QuarterlyScreen> {
  List<QuarterlyCheck> _checks = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  int _quarter = ((DateTime.now().month + 2) ~/ 3);
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final checks = await ApiService.getQuarterlyChecks(
        year: _year,
        quarter: _quarter,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
      );
      if (mounted) setState(() { _checks = checks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스마트 분기점검'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildYearQuarterSelector(),
          _buildSummaryBar(),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? ErrorWidget2(message: _error!, onRetry: _load)
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearQuarterSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                if (_quarter == 1) { _quarter = 4; _year--; } else _quarter--;
              });
              _load();
            },
          ),
          Expanded(
            child: Center(
              child: Text('$_year년 $_quarter분기',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                if (_quarter == 4) { _quarter = 1; _year++; } else _quarter++;
              });
              _load();
            },
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _year = DateTime.now().year;
                _quarter = ((DateTime.now().month + 2) ~/ 3);
              });
              _load();
            },
            child: const Text('이번 분기', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final total = _checks.length;
    final done = _checks.where((c) => c.status == '완료').length;
    final avgScore = _checks.where((c) => c.overallScore != null).isNotEmpty
        ? _checks.where((c) => c.overallScore != null)
            .map((c) => c.overallScore!)
            .reduce((a, b) => a + b) / _checks.where((c) => c.overallScore != null).length
        : null;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (total > 0) ...[
                  Text('완료: $done/$total',
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        backgroundColor: AppTheme.gray200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (avgScore != null)
                  Text('평균 ${avgScore.round()}점',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          DropdownButton<String>(
            value: _statusFilter.isEmpty ? '' : _statusFilter,
            underline: const SizedBox(),
            isDense: true,
            items: const [
              DropdownMenuItem(value: '', child: Text('전체', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '예정', child: Text('예정', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '완료', child: Text('완료', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '불가', child: Text('불가', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) { _statusFilter = v ?? ''; _load(); },
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_checks.isEmpty) {
      return const EmptyWidget(message: '이번 분기 점검 데이터가 없습니다', icon: Icons.memory_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _checks.length,
        itemBuilder: (_, i) => _buildCheckCard(_checks[i]),
      ),
    );
  }

  Widget _buildCheckCard(QuarterlyCheck check) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.memory, color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(check.siteName ?? '현장 미상',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.gray800)),
                      Text(check.elevatorName ?? '승강기 미상',
                        style: const TextStyle(fontSize: 11, color: AppTheme.gray400)),
                    ],
                  ),
                ),
                if (check.overallScore != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _scoreColor(check.overallScore!).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${check.overallScore}점',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: _scoreColor(check.overallScore!))),
                  ),
                  const SizedBox(width: 6),
                ],
                StatusBadge(status: check.status),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _openForm(check);
                    if (v == 'delete') _delete(check);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: AppTheme.danger))),
                  ],
                  child: const Icon(Icons.more_vert, size: 18, color: AppTheme.gray400),
                ),
              ],
            ),
            if (check.checkDate != null || check.checkerName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (check.checkDate != null) ...[
                    const Icon(Icons.calendar_today, size: 11, color: AppTheme.gray400),
                    const SizedBox(width: 3),
                    Text(fmtDate(check.checkDate), style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                    const SizedBox(width: 8),
                  ],
                  if (check.checkerName != null) ...[
                    const Icon(Icons.person_outline, size: 11, color: AppTheme.gray400),
                    const SizedBox(width: 3),
                    Text(check.checkerName!, style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
                  ],
                ],
              ),
            ],
            if (check.smartDiagnosis != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, size: 12, color: AppTheme.info),
                    const SizedBox(width: 4),
                    const Text('AI 진단: ', style: TextStyle(fontSize: 11, color: AppTheme.info, fontWeight: FontWeight.w500)),
                    Expanded(child: Text(check.smartDiagnosis!,
                      style: const TextStyle(fontSize: 11, color: AppTheme.info),
                      overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
            if (check.issuesFound != null) ...[
              const SizedBox(height: 4),
              Text('발견사항: ${check.issuesFound}',
                style: const TextStyle(fontSize: 11, color: AppTheme.gray500)),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return AppTheme.success;
    if (score >= 70) return AppTheme.warning;
    return AppTheme.danger;
  }

  void _openForm(QuarterlyCheck? check) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuarterlyCheckFormSheet(
        check: check,
        defaultYear: _year,
        defaultQuarter: _quarter,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(QuarterlyCheck check) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '분기점검 삭제',
      content: '이 분기점검 기록을 삭제하시겠습니까?',
    );
    if (ok != true) return;
    try {
      await ApiService.deleteQuarterlyCheck(check.id!);
      if (mounted) {
        showToast(context, '점검 기록이 삭제되었습니다.');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ── 분기 점검 폼 시트 ──────────────────────────────────────
class QuarterlyCheckFormSheet extends StatefulWidget {
  final QuarterlyCheck? check;
  final int defaultYear;
  final int defaultQuarter;
  const QuarterlyCheckFormSheet({
    super.key, this.check, required this.defaultYear, required this.defaultQuarter
  });

  @override
  State<QuarterlyCheckFormSheet> createState() => _QuarterlyCheckFormSheetState();
}

class _QuarterlyCheckFormSheetState extends State<QuarterlyCheckFormSheet> {
  final _formKey = GlobalKey<FormState>();
  List<Site> _sites = [];
  List<Elevator> _elevators = [];
  int? _selectedSiteId;
  int? _selectedElevatorId;
  late int _year = widget.check?.checkYear ?? widget.defaultYear;
  late int _quarter = widget.check?.quarter ?? widget.defaultQuarter;
  late String _status = widget.check?.status ?? '예정';
  late String _overallResult = widget.check?.overallResult ?? '양호';
  late final _dateCtrl = TextEditingController(text: widget.check?.checkDate);
  late final _checkerCtrl = TextEditingController(text: widget.check?.checkerName);
  late final _scoreCtrl = TextEditingController(text: widget.check?.overallScore?.toString());
  late final _diagCtrl = TextEditingController(text: widget.check?.smartDiagnosis);
  late final _issuesCtrl = TextEditingController(text: widget.check?.issuesFound);
  late final _actionsCtrl = TextEditingController(text: widget.check?.actionsTaken);
  late final _noiseLvlCtrl = TextEditingController(text: widget.check?.noiseLevel?.toString());
  late final _speedCtrl = TextEditingController(text: widget.check?.speedTest?.toString());
  bool _saving = false;

  final _inspItems = {
    'mechanical_room': '기계실',
    'hoistway': '승강로',
    'car_interior': '카 내부',
    'pit': '피트',
    'landing_doors': '각층 도어',
    'safety_gear': '안전장치',
    'ropes_chains': '로프/체인',
    'buffers': '완충기',
    'electrical': '전기설비',
  };
  late final Map<String, String> _inspValues = {
    'mechanical_room': widget.check?.mechanicalRoom ?? '양호',
    'hoistway': widget.check?.hoistway ?? '양호',
    'car_interior': widget.check?.carInterior ?? '양호',
    'pit': widget.check?.pit ?? '양호',
    'landing_doors': widget.check?.landingDoors ?? '양호',
    'safety_gear': widget.check?.safetyGear ?? '양호',
    'ropes_chains': widget.check?.ropesChains ?? '양호',
    'buffers': widget.check?.buffers ?? '양호',
    'electrical': widget.check?.electrical ?? '양호',
  };

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.check?.siteId;
    _selectedElevatorId = widget.check?.elevatorId;
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
              Row(
                children: [
                  Text(widget.check == null ? '분기점검 등록' : '분기점검 수정',
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
                      DropdownButtonFormField<int>(
                        value: _selectedSiteId,
                        decoration: const InputDecoration(labelText: '현장 *'),
                        items: _sites.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.siteName, style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        validator: (v) => v == null ? '현장을 선택하세요' : null,
                        onChanged: (v) {
                          setState(() {
                            _selectedSiteId = v;
                            _selectedElevatorId = null;
                            _elevators = [];
                          });
                          if (v != null) _loadElevators(v);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedElevatorId,
                        decoration: const InputDecoration(labelText: '승강기 *'),
                        items: _elevators.map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.displayName, style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        validator: (v) => v == null ? '승강기를 선택하세요' : null,
                        onChanged: (v) => setState(() => _selectedElevatorId = v),
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
                            items: ['예정', '완료', '불가', '이월']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _status = v ?? '예정'),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _overallResult,
                            decoration: const InputDecoration(labelText: '종합 결과'),
                            items: ['양호', '주의', '불량', '긴급조치필요']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _overallResult = v ?? '양호'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _scoreCtrl,
                            decoration: const InputDecoration(labelText: '종합 점수 (100점)'),
                            keyboardType: TextInputType.number,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            controller: _noiseLvlCtrl,
                            decoration: const InputDecoration(labelText: '소음 레벨 (dB)'),
                            keyboardType: TextInputType.number,
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _speedCtrl,
                            decoration: const InputDecoration(labelText: '속도 측정값 (m/s)'),
                            keyboardType: TextInputType.number,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('점검 항목',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.gray700)),
                      const SizedBox(height: 8),
                      ..._inspItems.entries.map((e) => _buildInspItemRow(e.key, e.value)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _diagCtrl,
                        decoration: const InputDecoration(
                          labelText: 'AI/스마트 진단 결과',
                          prefixIcon: Icon(Icons.psychology, size: 16),
                        ),
                        maxLines: 2,
                      ),
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

  Widget _buildInspItemRow(String key, String label) {
    final val = _inspValues[key] ?? '양호';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.gray600))),
          ...['양호', '주의', '불량'].map((opt) {
            final selected = val == opt;
            Color selColor;
            if (opt == '양호') selColor = AppTheme.success;
            else if (opt == '주의') selColor = AppTheme.warning;
            else selColor = AppTheme.danger;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _inspValues[key] = opt),
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
    setState(() => _saving = true);
    try {
      final check = QuarterlyCheck(
        id: widget.check?.id,
        elevatorId: _selectedElevatorId!,
        siteId: _selectedSiteId!,
        checkYear: _year,
        quarter: _quarter,
        checkDate: _dateCtrl.text.isNotEmpty ? _dateCtrl.text : null,
        checkerName: _checkerCtrl.text.isNotEmpty ? _checkerCtrl.text : null,
        status: _status,
        overallResult: _overallResult,
        overallScore: int.tryParse(_scoreCtrl.text),
        noiseLevel: double.tryParse(_noiseLvlCtrl.text),
        speedTest: double.tryParse(_speedCtrl.text),
        mechanicalRoom: _inspValues['mechanical_room'] ?? '양호',
        hoistway: _inspValues['hoistway'] ?? '양호',
        carInterior: _inspValues['car_interior'] ?? '양호',
        pit: _inspValues['pit'] ?? '양호',
        landingDoors: _inspValues['landing_doors'] ?? '양호',
        safetyGear: _inspValues['safety_gear'] ?? '양호',
        ropesChains: _inspValues['ropes_chains'] ?? '양호',
        buffers: _inspValues['buffers'] ?? '양호',
        electrical: _inspValues['electrical'] ?? '양호',
        smartDiagnosis: _diagCtrl.text.isNotEmpty ? _diagCtrl.text : null,
        issuesFound: _issuesCtrl.text.isNotEmpty ? _issuesCtrl.text : null,
        actionsTaken: _actionsCtrl.text.isNotEmpty ? _actionsCtrl.text : null,
      );
      if (widget.check == null) {
        await ApiService.createQuarterlyCheck(check);
      } else {
        await ApiService.updateQuarterlyCheck(widget.check!.id!, check);
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
    _dateCtrl.dispose(); _checkerCtrl.dispose(); _scoreCtrl.dispose();
    _diagCtrl.dispose(); _issuesCtrl.dispose(); _actionsCtrl.dispose();
    _noiseLvlCtrl.dispose(); _speedCtrl.dispose();
    super.dispose();
  }
}
