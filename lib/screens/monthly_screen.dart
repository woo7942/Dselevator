import 'package:flutter/material.dart';
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

class _MonthlyScreenState extends State<MonthlyScreen> {
  List<MonthlyCheck> _checks = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('월 점검 관리'),
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
          _buildYearMonthSelector(),
          _buildFilters(),
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

  Widget _buildYearMonthSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.gray800)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                if (_month == 12) { _month = 1; _year++; } else _month++;
              });
              _load();
            },
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _year = DateTime.now().year;
                _month = DateTime.now().month;
              });
              _load();
            },
            child: const Text('이번달', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final total = _checks.length;
    final done = _checks.where((c) => c.status == '완료').length;
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (total > 0) ...[
            Text('완료: $done / 전체: $total',
              style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  backgroundColor: AppTheme.gray200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          DropdownButton<String>(
            value: _statusFilter.isEmpty ? '' : _statusFilter,
            underline: const SizedBox(),
            isDense: true,
            items: const [
              DropdownMenuItem(value: '', child: Text('전체', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '예정', child: Text('예정', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '완료', child: Text('완료', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '불가', child: Text('불가', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: '이월', child: Text('이월', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) { _statusFilter = v ?? ''; _load(); },
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_checks.isEmpty) {
      return const EmptyWidget(message: '이번달 점검 데이터가 없습니다', icon: Icons.calendar_month_outlined);
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

  Widget _buildCheckCard(MonthlyCheck check) {
    final hasIssue = check.overallResult != '양호';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  check.status == '완료' ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: check.status == '완료' ? AppTheme.success : const Color(0xFFD1D5DB),
                ),
                const SizedBox(width: 8),
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
            if (hasIssue || check.issuesFound != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: check.overallResult == '긴급조치필요' ? AppTheme.dangerLight : AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 12,
                      color: check.overallResult == '긴급조치필요' ? AppTheme.danger : AppTheme.warning),
                    const SizedBox(width: 4),
                    Text('종합: ${check.overallResult}',
                      style: TextStyle(fontSize: 11,
                        color: check.overallResult == '긴급조치필요' ? AppTheme.danger : AppTheme.warning)),
                    if (check.issuesFound != null) ...[
                      const Text(' - ', style: TextStyle(fontSize: 11, color: AppTheme.gray500)),
                      Expanded(child: Text(check.issuesFound!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.gray600),
                        overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openForm(MonthlyCheck? check) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MonthlyCheckFormSheet(
        check: check,
        defaultYear: _year,
        defaultMonth: _month,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(MonthlyCheck check) async {
    final ok = await ConfirmDialog.show(
      context,
      title: '월 점검 삭제',
      content: '이 월 점검 기록을 삭제하시겠습니까?',
    );
    if (ok != true) return;
    try {
      await ApiService.deleteMonthlyCheck(check.id!);
      if (mounted) {
        showToast(context, '점검 기록이 삭제되었습니다.');
        _load();
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }
}

// ── 월 점검 폼 시트 ────────────────────────────────────────
class MonthlyCheckFormSheet extends StatefulWidget {
  final MonthlyCheck? check;
  final int defaultYear;
  final int defaultMonth;
  const MonthlyCheckFormSheet({
    super.key, this.check, required this.defaultYear, required this.defaultMonth
  });

  @override
  State<MonthlyCheckFormSheet> createState() => _MonthlyCheckFormSheetState();
}

class _MonthlyCheckFormSheetState extends State<MonthlyCheckFormSheet> {
  final _formKey = GlobalKey<FormState>();
  List<Site> _sites = [];
  List<Elevator> _elevators = [];
  int? _selectedSiteId;
  int? _selectedElevatorId;
  late int _year = widget.check?.checkYear ?? widget.defaultYear;
  late int _month = widget.check?.checkMonth ?? widget.defaultMonth;
  late String _status = widget.check?.status ?? '예정';
  late String _overallResult = widget.check?.overallResult ?? '양호';
  late final _dateCtrl = TextEditingController(text: widget.check?.checkDate);
  late final _checkerCtrl = TextEditingController(text: widget.check?.checkerName);
  late final _issuesCtrl = TextEditingController(text: widget.check?.issuesFound);
  late final _actionsCtrl = TextEditingController(text: widget.check?.actionsTaken);
  late final _nextCtrl = TextEditingController(text: widget.check?.nextAction);
  bool _saving = false;

  // 점검 항목
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
                        controller: _nextCtrl,
                        decoration: const InputDecoration(labelText: '후속 조치 필요 사항'),
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
    setState(() => _saving = true);
    try {
      final check = MonthlyCheck(
        id: widget.check?.id,
        elevatorId: _selectedElevatorId!,
        siteId: _selectedSiteId!,
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
        nextAction: _nextCtrl.text.isNotEmpty ? _nextCtrl.text : null,
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
    _issuesCtrl.dispose(); _actionsCtrl.dispose(); _nextCtrl.dispose();
    super.dispose();
  }
}


