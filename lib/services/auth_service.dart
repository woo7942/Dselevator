import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserInfo {
  final int id;
  final String name;
  final String role; // 'admin' | 'user'
  final String? lastLogin;

  const UserInfo({
    required this.id,
    required this.name,
    required this.role,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
    id: j['id'] as int,
    name: j['name'] as String,
    role: j['role'] as String? ?? 'user',
    lastLogin: j['last_login'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'role': role, 'last_login': lastLogin,
  };
}

class AuthService extends ChangeNotifier {
  static const _userKey = 'logged_in_user';

  UserInfo? _currentUser;
  bool _initialized = false;

  UserInfo? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get initialized => _initialized;

  // 앱 시작 시 저장된 로그인 정보 복원
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = UserInfo.fromJson(data);
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  // 로그인
  Future<String?> login(String name, String pin) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/auth/login');
      final resp = await ApiService.postRaw(uri, {'name': name.trim(), 'pin': pin.trim()});
      if (resp['success'] == true) {
        final user = UserInfo.fromJson(resp['user'] as Map<String, dynamic>);
        _currentUser = user;
        // 로컬 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
        notifyListeners();
        return null; // 성공 = null
      }
      return resp['error']?.toString() ?? '로그인 실패';
    } catch (e) {
      return '서버 연결 오류: $e';
    }
  }

  // 로그아웃
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }

  // PIN 변경
  Future<String?> changePin(String currentPin, String newPin) async {
    if (_currentUser == null) return '로그인이 필요합니다';
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/auth/change-pin');
      final resp = await ApiService.postRaw(uri, {
        'name': _currentUser!.name,
        'current_pin': currentPin,
        'new_pin': newPin,
      });
      if (resp['success'] == true) return null;
      return resp['error']?.toString() ?? 'PIN 변경 실패';
    } catch (e) {
      return '서버 오류: $e';
    }
  }

  // 사용자 목록 (관리자)
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/users');
      final resp = await ApiService.getRaw(uri);
      return List<Map<String, dynamic>>.from(resp['results'] ?? []);
    } catch (_) {
      return [];
    }
  }

  // 사용자 추가 (관리자)
  Future<String?> addUser(String name, String pin, {bool isAdmin = false}) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/users');
      final resp = await ApiService.postRaw(uri, {
        'name': name.trim(),
        'pin': pin.trim(),
        'role': isAdmin ? 'admin' : 'user',
      });
      if (resp['success'] == true) return null;
      return resp['error']?.toString() ?? '추가 실패';
    } catch (e) {
      return '서버 오류: $e';
    }
  }

  // 사용자 삭제 (관리자)
  Future<String?> deleteUser(int userId) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/users/$userId');
      await ApiService.deleteRaw(uri);
      return null; // 성공
    } catch (e) {
      return '서버 오류: $e';
    }
  }

  // 관리자가 사용자 PIN 초기화
  Future<String?> resetUserPin(int userId, String newPin) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/users/$userId');
      final resp = await ApiService.putRaw(uri, {'pin': newPin});
      if (resp['success'] == true) return null;
      return resp['error']?.toString() ?? '초기화 실패';
    } catch (e) {
      return '서버 오류: $e';
    }
  }
}
