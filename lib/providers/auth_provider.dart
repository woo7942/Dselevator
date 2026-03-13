import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

// ────────────────────────────────────────────────────────────
//  앱 전체 탭 정의 (키 = API 저장값, label = 화면 표시)
// ────────────────────────────────────────────────────────────
class AppTab {
  final String key;
  final String label;
  const AppTab({required this.key, required this.label});
}

const kAppTabs = [
  AppTab(key: 'dashboard',   label: '대시보드'),
  AppTab(key: 'sites',       label: '현장관리'),
  AppTab(key: 'inspections', label: '검사관리'),
  AppTab(key: 'issues',      label: '지적사항'),
  AppTab(key: 'monthly',     label: '월점검'),
  AppTab(key: 'quarterly',   label: '분기점검'),
];

// ────────────────────────────────────────────────────────────
//  UserInfo
// ────────────────────────────────────────────────────────────
class UserInfo {
  final int id;
  final String name;
  final String role;
  // null = 모든 탭 허용 (관리자 또는 미설정), 비어있으면 모두 허용
  final List<String>? tabPermissions;

  const UserInfo({
    required this.id,
    required this.name,
    required this.role,
    this.tabPermissions,
  });

  bool get isAdmin => role == 'admin';

  /// 탭 key가 허용되어 있는지 확인
  /// - 관리자는 항상 true
  /// - tabPermissions == null 이면 모두 허용
  /// - tabPermissions가 비어 있으면 모두 허용
  bool canAccessTab(String tabKey) {
    if (isAdmin) return true;
    if (tabPermissions == null || tabPermissions!.isEmpty) return true;
    return tabPermissions!.contains(tabKey);
  }

  /// 허용된 탭 목록 반환 (순서 유지)
  List<AppTab> get allowedTabs {
    if (isAdmin) return kAppTabs;
    if (tabPermissions == null || tabPermissions!.isEmpty) return kAppTabs;
    return kAppTabs.where((t) => tabPermissions!.contains(t.key)).toList();
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    // tab_permissions: JSON 문자열 "dashboard,sites,monthly" 파싱
    List<String>? perms;
    final raw = json['tab_permissions'];
    if (raw != null && raw.toString().isNotEmpty) {
      perms = raw.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return UserInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      tabPermissions: perms,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  AuthProvider
// ────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  UserInfo? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserInfo? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<bool> login(String name, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.login(name, pin);
      _currentUser = UserInfo.fromJson(result['user'] as Map<String, dynamic>);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
