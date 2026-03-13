import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../models/site.dart';
import '../services/api_service.dart';

// ── 공통 팀 탭바 ──────────────────────────────────────────────
// 사용법: TeamTabBar(selected: _selectedTeam, onChanged: (t) { setState(()=>_selectedTeam=t); _load(); })
class TeamTabBar extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const TeamTabBar({super.key, required this.selected, required this.onChanged});

  @override
  State<TeamTabBar> createState() => _TeamTabBarState();
}

class _TeamTabBarState extends State<TeamTabBar> {
  List<String> _teams = ['전체', '파주1팀', '파주2팀'];

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.getTeams();
      if (mounted && teams.isNotEmpty) {
        setState(() => _teams = ['전체', ...teams]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: AppTheme.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 14, color: AppTheme.gray500),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _teams.map((t) {
                final selected = t == widget.selected;
                return GestureDetector(
                  onTap: () => widget.onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.gray300,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : AppTheme.gray600,
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
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColors[status] ?? AppTheme.gray500;
    final bgColor = statusBgColors[status] ?? AppTheme.gray100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? _getStatusLabel(status),
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _getStatusLabel(String s) {
    const labels = {
      'active': '운영중', 'inactive': '비운영', 'suspended': '중지',
      'normal': '정상', 'warning': '주의', 'fault': '고장', 'stopped': '정지',
    };
    return labels[s] ?? s;
  }
}

class SeverityBadge extends StatelessWidget {
  final String severity;
  final double fontSize;

  const SeverityBadge({super.key, required this.severity, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = severityColors[severity] ?? AppTheme.gray500;
    final bgColor = severityBgColors[severity] ?? AppTheme.gray100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const InfoCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
      ),
    );
  }
}

class ErrorWidget2 extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorWidget2({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.gray600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.gray400),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.gray400, fontSize: 14)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;
  final Color? iconColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? AppTheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = '삭제',
    this.confirmColor,
  });

  static Future<bool?> show(BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '삭제',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Text(content, style: const TextStyle(color: AppTheme.gray600)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppTheme.danger,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

void showToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}

String fmtDate(String? d) => d != null && d.length >= 10 ? d.substring(0, 10) : '-';

// ══════════════════════════════════════════════════════
// 검색 가능한 현장 선택 위젯
// ══════════════════════════════════════════════════════

/// 검색 가능한 현장 선택 다이얼로그 + 필드
/// 사용법:
///   SiteSearchField(
///     sites: _sites,
///     selected: _selectedSite,
///     onChanged: (s) => setState(() => _selectedSite = s),
///   )
class SiteSearchField extends StatelessWidget {
  final List<Site> sites;
  final Site? selected;
  final void Function(Site?) onChanged;
  final String label;
  final bool required;
  final bool isLoading;

  const SiteSearchField({
    super.key,
    required this.sites,
    required this.selected,
    required this.onChanged,
    this.label = '현장 선택',
    this.required = false,
    this.isLoading = false,
  });

  Future<void> _showSearchDialog(BuildContext context) async {
    final result = await showDialog<_SiteSearchResult?>(
      context: context,
      builder: (ctx) => _SiteSearchDialog(sites: sites, selected: selected),
    );
    if (result != null) {
      onChanged(result.site);
    }
    // result == null이면 다이얼로그 X 버튼으로 닫은 것 → 변경 없음
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: () => _showSearchDialog(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected != null ? AppTheme.primary : AppTheme.gray300,
            width: selected != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.business_outlined,
              size: 18,
              color: selected != null ? AppTheme.primary : AppTheme.gray400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.siteName ?? label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected != null ? AppTheme.gray800 : AppTheme.gray400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search,
              size: 18,
              color: AppTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

/// 다이얼로그 반환 래퍼 (null과 취소를 구분)
class _SiteSearchResult {
  final Site? site;
  _SiteSearchResult(this.site);
}

class _SiteSearchDialog extends StatefulWidget {
  final List<Site> sites;
  final Site? selected;
  const _SiteSearchDialog({required this.sites, this.selected});

  @override
  State<_SiteSearchDialog> createState() => _SiteSearchDialogState();
}

class _SiteSearchDialogState extends State<_SiteSearchDialog> {
  late List<Site> _filtered;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filtered = widget.sites;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.sites
          : widget.sites
              .where((s) =>
                  s.siteName.toLowerCase().contains(q) ||
                  s.address.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('현장 선택',
                      style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: '현장명 또는 주소로 검색...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.gray400),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.gray400),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.gray50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // 결과 수
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('${_filtered.length}개 현장',
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray500)),
                ],
              ),
            ),

            const Divider(height: 1),

            // 목록
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: AppTheme.gray300),
                          SizedBox(height: 8),
                          Text('검색 결과가 없습니다',
                            style: TextStyle(fontSize: 13, color: AppTheme.gray400)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final site = _filtered[i];
                        final isSelected = site.id == widget.selected?.id;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryLight,
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : AppTheme.gray100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.business_outlined,
                              size: 18,
                              color: isSelected ? Colors.white : AppTheme.gray500,
                            ),
                          ),
                          title: Text(
                            site.siteName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : AppTheme.gray800,
                            ),
                          ),
                          subtitle: site.address.isNotEmpty
                              ? Text(
                                  site.address,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.gray400),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, _SiteSearchResult(site)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
