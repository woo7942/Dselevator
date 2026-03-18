import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../utils/platform_stub.dart'
    if (dart.library.js_interop) '../utils/platform_web.dart' as platform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site.dart';
import '../models/inspection.dart';
import '../models/check.dart';
import '../models/error_code.dart';

class ApiService {
  static String _baseUrl = 'https://elevator-api-4lac.onrender.com'; // 초기값을 기본 URL로 설정
  static const String _baseUrlKey = 'api_base_url';

  // 기본 서버 주소 (Render 배포 서버)
  static const String _defaultUrl = 'https://elevator-api-4lac.onrender.com';

  // ── 데이터 변경 이벤트 스트림 (대시보드 실시간 새로고침용) ──────
  static final StreamController<String> _dataChangeController =
      StreamController<String>.broadcast();
  static Stream<String> get onDataChanged => _dataChangeController.stream;

  /// 데이터 변경 사실을 브로드캐스트 (저장/수정/삭제 후 호출)
  static void notifyDataChanged(String type) {
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(type);
    }
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey) ?? '';
    // 저장된 URL이 비어있거나 유효하지 않으면 기본 URL 사용
    if (saved.isEmpty || !saved.startsWith('http')) {
      _baseUrl = _defaultUrl;
    } else {
      _baseUrl = saved;
    }
  }

  /// 저장된 서버 주소가 없으면 true → 설정 화면 표시 필요
  static bool get needsSetup => false; // 기본 주소가 있으므로 항상 false

  static Future<void> setBaseUrl(String url) async {
    final trimmed = url.trimRight().replaceAll(RegExp(r'/$'), '');
    // 빈 문자열이거나 http로 시작 안하면 기본값 사용
    _baseUrl = (trimmed.isEmpty || !trimmed.startsWith('http')) ? _defaultUrl : trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  static String get baseUrl => _baseUrl.isEmpty ? _defaultUrl : _baseUrl;

  // 서버 응답에서 리스트 추출 (results 또는 data 키 모두 처리)
  static List<dynamic> _extractList(Map<String, dynamic> res) {
    return (res['results'] as List<dynamic>?)
        ?? (res['data'] as List<dynamic>?)
        ?? [];
  }

  // 서버 응답에서 단일 객체 추출 (result 또는 data 키 모두 처리)
  static Map<String, dynamic> _extractMap(Map<String, dynamic> res) {
    return (res['result'] as Map<String, dynamic>?)
        ?? (res['data'] as Map<String, dynamic>?)
        ?? {};
  }

  static Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params, int retries = 2}) async {
    // URL이 비어있으면 기본값 사용
    final url = _baseUrl.isEmpty ? _defaultUrl : _baseUrl;
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        var uri = Uri.parse('$url$path');
        if (params != null && params.isNotEmpty) {
          uri = uri.replace(queryParameters: params);
        }
        // 첫 번째 시도는 30초 (콜드 스타트 대비), 이후 15초
        final timeout = attempt == 0 ? const Duration(seconds: 30) : const Duration(seconds: 15);
        final response = await http.get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        }
        throw ApiException('HTTP \${response.statusCode}: \${response.body}');
      } catch (e) {
        if (e is ApiException) rethrow;
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: attempt + 1)); // 재시도 전 대기
          continue;
        }
        throw ApiException('네트워크 오류: \$e');
      }
    }
    throw ApiException('요청 실패');
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final url = _baseUrl.isEmpty ? _defaultUrl : _baseUrl;
    try {
      final uri = Uri.parse('$url$path');
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('네트워크 오류: $e');
    }
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final url = _baseUrl.isEmpty ? _defaultUrl : _baseUrl;
    try {
      final uri = Uri.parse('$url$path');
      final response = await http.put(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('네트워크 오류: $e');
    }
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final url = _baseUrl.isEmpty ? _defaultUrl : _baseUrl;
    try {
      final uri = Uri.parse('$url$path');
      final response = await http.patch(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('네트워크 오류: $e');
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    final url = _baseUrl.isEmpty ? _defaultUrl : _baseUrl;
    try {
      final uri = Uri.parse('$url$path');
      final response = await http.delete(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('네트워크 오류: $e');
    }
  }

  // ── 대시보드 ──────────────────────────────────────────────
  static Future<DashboardData> getDashboard({String? team}) async {
    final params = team != null && team != '전체' ? {'team': team} : <String, String>{};
    final res = await _get('/api/dashboard', params: params.isNotEmpty ? params : null);
    return DashboardData.fromJson(res['data'] as Map<String, dynamic>? ?? {});
  }

  // ── 현장 ──────────────────────────────────────────────────
  static Future<List<Site>> getSites({String? search, String? status, String? region, String? team}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (region != null && region != '전체') params['region'] = region;
    if (team != null && team.isNotEmpty && team != '전체') params['team'] = team;
    final res = await _get('/api/sites', params: params);
    final data = _extractList(res);
    return data.map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Site> getSite(int id) async {
    final res = await _get('/api/sites/$id');
    return Site.fromJson(_extractMap(res));
  }

  static Future<List<Elevator>> getSiteElevators(int siteId) async {
    final res = await _get('/api/elevators', params: {'site_id': siteId.toString()});
    final data = _extractList(res);
    return data.map((e) => Elevator.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> createSite(Site site) async {
    final res = await _post('/api/sites', site.toJson());
    notifyDataChanged('site');
    _autoBackup(); // 로컬 백업
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateSite(int id, Site site) async {
    await _put('/api/sites/$id', site.toJson());
    notifyDataChanged('site');
    _autoBackup();
  }

  static Future<void> deleteSite(int id) async {
    await _delete('/api/sites/$id');
    notifyDataChanged('site');
    _autoBackup();
  }

  static Future<int> createElevator(int siteId, Elevator elevator) async {
    final body = elevator.toJson();
    body['site_id'] = siteId;
    final res = await _post('/api/elevators', body);
    notifyDataChanged('elevator');
    _autoBackup();
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateElevator(int id, Elevator elevator) async {
    await _put('/api/elevators/$id', elevator.toJson());
    notifyDataChanged('elevator');
    _autoBackup();
  }

  static Future<void> deleteElevator(int id) async {
    await _delete('/api/elevators/$id');
    notifyDataChanged('elevator');
    _autoBackup();
  }

  // ── 검사 ──────────────────────────────────────────────────
  static Future<List<Inspection>> getInspections({
    int? siteId, int? elevatorId, String? type, String? result, String? year, String? month
  }) async {
    final params = <String, String>{};
    if (siteId != null) params['site_id'] = siteId.toString();
    if (elevatorId != null) params['elevator_id'] = elevatorId.toString();
    if (type != null && type.isNotEmpty) params['inspection_type'] = type;
    if (result != null && result.isNotEmpty) params['result'] = result;
    final res = await _get('/api/inspections', params: params);
    final data = _extractList(res);
    return data.map((e) => Inspection.fromJson(e as Map<String, dynamic>)).toList();
  }

  // upcoming: next_inspection_date가 30일 이내인 검사 목록 (로컬 필터링)
  static Future<List<Inspection>> getUpcomingInspections() async {
    final res = await _get('/api/inspections');
    final data = _extractList(res);
    final all = data.map((e) => Inspection.fromJson(e as Map<String, dynamic>)).toList();
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    return all.where((ins) {
      if (ins.nextInspectionDate == null || ins.nextInspectionDate!.isEmpty) return false;
      try {
        final d = DateTime.parse(ins.nextInspectionDate!);
        return d.isAfter(now) && d.isBefore(limit);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  static Future<int> createInspection(Inspection inspection) async {
    final res = await _post('/api/inspections', inspection.toJson());
    notifyDataChanged('inspection');
    _autoBackup();
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateInspection(int id, Inspection inspection) async {
    await _put('/api/inspections/$id', inspection.toJson());
    notifyDataChanged('inspection');
    _autoBackup();
  }

  static Future<void> deleteInspection(int id) async {
    await _delete('/api/inspections/$id');
    notifyDataChanged('inspection');
  }

  // ── 지적사항 ───────────────────────────────────────────────
  static Future<List<InspectionIssue>> getIssues({
    int? siteId, int? elevatorId, String? status, String? severity, int? inspectionId
  }) async {
    final params = <String, String>{};
    if (siteId != null) params['site_id'] = siteId.toString();
    if (elevatorId != null) params['elevator_id'] = elevatorId.toString();
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (severity != null && severity.isNotEmpty) params['severity'] = severity;
    if (inspectionId != null) params['inspection_id'] = inspectionId.toString();
    final res = await _get('/api/issues', params: params);
    final data = _extractList(res);
    return data.map((e) => InspectionIssue.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> createIssue(InspectionIssue issue) async {
    final res = await _post('/api/issues', issue.toJson());
    notifyDataChanged('issue');
    _autoBackup();
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateIssue(int id, InspectionIssue issue) async {
    await _put('/api/issues/$id', issue.toJson());
    notifyDataChanged('issue');
    _autoBackup();
  }

  static Future<void> updateIssueAction(int id, {
    required String status,
    String? actionTaken,
    String? actionDate,
    String? actionBy,
    String? photoBefore,
    String? photoAfter,
  }) async {
    await _patch('/api/issues/$id/action', {
      'status': status,
      if (actionTaken != null) 'action_taken': actionTaken,
      if (actionDate != null) 'action_date': actionDate,
      if (actionBy != null) 'action_by': actionBy,
      if (photoBefore != null) 'photo_before': photoBefore,
      if (photoAfter != null) 'photo_after': photoAfter,
    });
    notifyDataChanged('issue');
  }

  static Future<void> deleteIssue(int id) async {
    await _delete('/api/issues/$id');
    notifyDataChanged('issue');
    _autoBackup();
  }

  static Future<Map<String, dynamic>> createIssuesBulk(
      List<Map<String, dynamic>> issues) async {
    final result = await _post('/api/issues/bulk', {'issues': issues});
    notifyDataChanged('issue');
    _autoBackup();
    return result;
  }

  /// 파일 업로드 (이미지/동영상) - 파일 1개씩 순차 업로드
  /// [onProgress]: (현재파일인덱스, 전체파일수, 0.0~1.0진행률) 콜백
  static Future<List<String>> uploadFiles(
    List<Uint8List> files,
    List<String> filenames, {
    void Function(int fileIndex, int total, double progress)? onProgress,
  }) async {
    final List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      final url = await _uploadOneFile(
        files[i],
        filenames[i],
        onProgress: onProgress == null ? null : (p) => onProgress(i, files.length, p),
      );
      urls.add(url);
    }
    return urls;
  }

  /// 단일 파일 업로드 (Web: XHR, 네이티브: http.MultipartRequest)
  static Future<String> _uploadOneFile(
    Uint8List bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      // Web: XHR로 진행률 지원 업로드
      return platform.uploadFileXhr(
        _baseUrl,
        bytes,
        filename,
        mimeType: _mimeType,
        onProgress: onProgress,
      );
    } else {
      // 네이티브(Android/iOS): http.MultipartRequest 사용
      final uri = Uri.parse('$_baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: filename,
      ));
      onProgress?.call(0.5);
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      onProgress?.call(1.0);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['urls'];
          if (list is List && list.isNotEmpty) {
            return list.first.toString();
          }
        }
        throw Exception(data['error']?.toString() ?? '업로드 오류');
      } else {
        throw Exception('업로드 실패 (HTTP ${res.statusCode})');
      }
    }
  }

  static String _mimeType(String name) {
    switch (name.toLowerCase().split('.').last) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'avi':  return 'video/x-msvideo';
      case 'webm': return 'video/webm';
      case '3gp':  return 'video/3gpp';
      default:     return 'application/octet-stream';
    }
  }

  // ── PDF 파싱 ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> parsePdf(
      Uint8List bytes, String filename) async {
    final uri = Uri.parse('$_baseUrl/api/pdf/parse');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'pdf',
      bytes,
      filename: filename,
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('PDF 파싱 실패 (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'PDF 파싱 오류');
    }
    return data;
  }

  // ── 이미지(캡처) 파싱 ────────────────────────────────────────
  static Future<Map<String, dynamic>> parseImages(
      List<({Uint8List bytes, String filename})> images) async {
    final uri = Uri.parse('$_baseUrl/api/image/parse');
    final request = http.MultipartRequest('POST', uri);
    for (final img in images) {
      request.files.add(http.MultipartFile.fromBytes(
        'images',
        img.bytes,
        filename: img.filename,
      ));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('이미지 파싱 실패 (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data;
  }

  // ── 월 점검 ───────────────────────────────────────────────
  static Future<List<MonthlyCheck>> getMonthlyChecks({
    int? siteId, int? elevatorId, int? year, int? month, String? status
  }) async {
    final params = <String, String>{};
    if (siteId != null) params['site_id'] = siteId.toString();
    if (elevatorId != null) params['elevator_id'] = elevatorId.toString();
    if (year != null) params['check_year'] = year.toString();
    if (month != null) params['check_month'] = month.toString();
    if (status != null && status.isNotEmpty) params['status'] = status;
    final res = await _get('/api/monthly', params: params);
    final data = _extractList(res);
    return data.map((e) => MonthlyCheck.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> createMonthlyCheck(MonthlyCheck check) async {
    final res = await _post('/api/monthly', check.toJson());
    notifyDataChanged('monthly');
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateMonthlyCheck(int id, MonthlyCheck check) async {
    await _put('/api/monthly/$id', check.toJson());
    notifyDataChanged('monthly');
  }

  static Future<void> deleteMonthlyCheck(int id) async {
    await _delete('/api/monthly/$id');
    notifyDataChanged('monthly');
  }

  // ── 분기 점검 ─────────────────────────────────────────────
  static Future<List<QuarterlyCheck>> getQuarterlyChecks({
    int? siteId, int? elevatorId, int? year, int? quarter, String? status
  }) async {
    final params = <String, String>{};
    if (siteId != null) params['site_id'] = siteId.toString();
    if (elevatorId != null) params['elevator_id'] = elevatorId.toString();
    if (year != null) params['year'] = year.toString();
    if (quarter != null) params['quarter'] = quarter.toString();
    if (status != null && status.isNotEmpty) params['status'] = status;
    final res = await _get('/api/quarterly', params: params);
    final data = _extractList(res);
    return data.map((e) => QuarterlyCheck.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> createQuarterlyCheck(QuarterlyCheck check) async {
    final res = await _post('/api/quarterly', check.toJson());
    notifyDataChanged('quarterly');
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateQuarterlyCheck(int id, QuarterlyCheck check) async {
    await _put('/api/quarterly/$id', check.toJson());
    notifyDataChanged('quarterly');
  }

  static Future<void> deleteQuarterlyCheck(int id) async {
    await _delete('/api/quarterly/$id');
  }

  // ── 팀 관련 ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getVersion() async {
    return await _get('/api/version');
  }

  static Future<List<String>> getTeams() async {
    final res = await _get('/api/teams');
    final list = _extractList(res);
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> addTeam(String name) async {
    await _post('/api/teams', {'name': name});
  }

  // ── 로컬 DB 백업/복원 (영구 데이터 보호) ──────────────────────
  static const String _backupCacheKey = 'db_backup_v1';
  static const String _backupTimestampKey = 'db_backup_timestamp';

  /// 서버 전체 데이터를 로컬에 백업
  static Future<void> backupToLocal() async {
    try {
      final res = await _get('/api/backup');
      if (res['success'] == true && res['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_backupCacheKey, jsonEncode(res['data']));
        await prefs.setString(_backupTimestampKey, DateTime.now().toIso8601String());
      }
    } catch (_) {}
  }

  /// 로컬 백업에서 서버로 복원 (서버 재시작 후 데이터 손실 시)
  static Future<Map<String, dynamic>?> restoreFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_backupCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final res = await _post('/api/restore', {'data': data});
      return res;
    } catch (_) {
      return null;
    }
  }

  /// 마지막 백업 시각 반환
  static Future<String?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupTimestampKey);
  }

  /// 데이터 추가/수정/삭제 후 자동 백업 트리거
  static Future<void> _autoBackup() async {
    // 비동기로 실행 - 백업 실패해도 메인 동작에 영향 없음
    Future.delayed(const Duration(milliseconds: 500), () async {
      await backupToLocal();
    });
  }

  // ── 관리자: 영구저장 / 영구삭제 ──────────────────────────────
  static const String _adminSecret = 'DS2024';

  /// 현재 DB 전체를 seed_data.json에 영구저장 (재배포 후 복원용)
  /// GitHub에도 자동 push (서버에 GITHUB_TOKEN 설정 시)
  static Future<Map<String, dynamic>> saveSeed() async {
    return await _post('/api/admin/save-seed', {'secret': _adminSecret});
  }

  /// 중복 현장 정리 (site_name 기준)
  static Future<Map<String, dynamic>> dedupSites() async {
    return await _post('/api/admin/dedup', {'secret': _adminSecret});
  }

  /// DB 초기화 후 seed_data.json으로 재구성
  static Future<Map<String, dynamic>> resetFromSeed() async {
    return await _post('/api/admin/reset-from-seed', {'secret': _adminSecret});
  }

  // ── 사용자 관리 (로컬 캐시 + 서버 동기화) ──────────────────
  static const String _userCacheKey = 'cached_users_v2';

  /// 로컬에 사용자 목록 저장
  static Future<void> _saveUsersToCache(List<dynamic> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userCacheKey, jsonEncode(users));
    } catch (_) {}
  }

  /// 로컬 캐시에서 사용자 목록 불러오기
  static Future<List<dynamic>> _loadUsersFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userCacheKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  /// 캐시에 있는 사용자를 서버에 복원 (서버 재시작 후 동기화)
  static Future<void> _syncCacheToServer(List<dynamic> cached) async {
    for (final u in cached) {
      final m = u as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      if (name.isEmpty) continue;
      try {
        // 서버에 없으면 추가 (있으면 409 conflict → 무시)
        await _post('/api/users/restore', {
          'name': name,
          'role': m['role'] ?? 'user',
          'tab_permissions': m['tab_permissions'] ?? '',
          'is_active': m['is_active'] ?? 1,
        });
      } catch (_) {}
    }
  }

  static Future<List<dynamic>> getUsers() async {
    try {
      final res = await _get('/api/users');
      final list = _extractList(res);
      // 서버 데이터가 1명(기본관리자만)이고 캐시에 더 많으면 → 서버 재시작된 것
      final cached = await _loadUsersFromCache();
      if (list.length <= 1 && cached.length > 1) {
        // 캐시를 서버에 복원
        await _syncCacheToServer(cached);
        // 복원 후 다시 조회
        final res2 = await _get('/api/users');
        final list2 = _extractList(res2);
        await _saveUsersToCache(list2);
        return list2;
      }
      await _saveUsersToCache(list);
      return list;
    } catch (e) {
      // 서버 오류 시 캐시 반환
      return await _loadUsersFromCache();
    }
  }

  static Future<void> createUser(String name, String pin, String role) async {
    await _post('/api/users', {'name': name, 'pin': pin, 'role': role});
    // 캐시 업데이트
    final list = await _loadUsersFromCache();
    list.add({'name': name, 'role': role, 'is_active': 1, 'tab_permissions': ''});
    await _saveUsersToCache(list);
  }

  static Future<void> updateUser(int id, {String? name, String? pin, String? role, int? isActive, String? tabPermissions}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (pin != null) body['pin'] = pin;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    if (tabPermissions != null) body['tab_permissions'] = tabPermissions;
    await _put('/api/users/$id', body);
    // 캐시 새로고침
    try {
      final res = await _get('/api/users');
      await _saveUsersToCache(_extractList(res));
    } catch (_) {}
  }

  static Future<void> deleteUser(int id) async {
    await _delete('/api/users/$id');
    // 캐시 새로고침
    try {
      final res = await _get('/api/users');
      await _saveUsersToCache(_extractList(res));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  // 에러코드 검색 API
  // ══════════════════════════════════════════════════════════════

  /// 에러코드 목록 검색 (q=검색어, manufacturer=제조사, severity=심각도)
  static Future<List<ErrorCode>> getErrorCodes({
    String? q,
    String? manufacturer,
    String? severity,
    String? elevatorType,
  }) async {
    final params = <String, String>{};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (manufacturer != null && manufacturer.isNotEmpty) params['manufacturer'] = manufacturer;
    if (severity != null && severity.isNotEmpty) params['severity'] = severity;
    if (elevatorType != null && elevatorType.isNotEmpty && elevatorType != '전체') params['elevator_type'] = elevatorType;
    final res = await _get('/api/error-codes', params: params);
    final list = _extractList(res);
    return list.map((e) => ErrorCode.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 에러코드 단일 조회 (댓글 포함)
  static Future<ErrorCode> getErrorCode(int id) async {
    final res = await _get('/api/error-codes/$id');
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    return ErrorCode.fromJson(data);
  }

  /// 에러코드 등록 (관리자 전용)
  static Future<ErrorCode> createErrorCode(Map<String, dynamic> body) async {
    final res = await _post('/api/error-codes', body);
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    return ErrorCode.fromJson(data);
  }

  /// 에러코드 수정 (관리자 전용)
  static Future<ErrorCode> updateErrorCode(int id, Map<String, dynamic> body) async {
    final res = await _put('/api/error-codes/$id', body);
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    return ErrorCode.fromJson(data);
  }

  /// 에러코드 삭제 (관리자 전용)
  static Future<void> deleteErrorCode(int id) async {
    await _delete('/api/error-codes/$id');
  }

  /// 제조사 목록 조회
  static Future<List<String>> getErrorManufacturers() async {
    final res = await _get('/api/error-manufacturers');
    final list = _extractList(res);
    return list.map((e) => e.toString()).toList();
  }

  /// 댓글 목록 조회
  static Future<List<ErrorComment>> getErrorComments(int errorId) async {
    final res = await _get('/api/error-codes/$errorId/comments');
    final list = _extractList(res);
    return list.map((e) => ErrorComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 댓글 등록 (관리자 전용)
  static Future<ErrorComment> addErrorComment(int errorId, String author, String content) async {
    final res = await _post('/api/error-codes/$errorId/comments', {
      'author': author,
      'content': content,
    });
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    return ErrorComment.fromJson(data);
  }

  /// 댓글 삭제 (관리자 전용)
  static Future<void> deleteErrorComment(int errorId, int commentId) async {
    await _delete('/api/error-codes/$errorId/comments/$commentId');
  }

  // ── 외부 URI 헬퍼 ───────────────────────────────────────────
  static Future<Map<String, dynamic>> postRaw(Uri uri, Map<String, dynamic> body) async {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(decoded['error']?.toString() ?? 'HTTP ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> getRaw(Uri uri) async {
    final response = await http.get(uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(decoded['error']?.toString() ?? 'HTTP ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> putRaw(Uri uri, Map<String, dynamic> body) async {
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw ApiException(decoded['error']?.toString() ?? 'HTTP ${response.statusCode}');
  }

  static Future<void> deleteRaw(Uri uri) async {
    final response = await http.delete(uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      throw ApiException(decoded['error']?.toString() ?? 'HTTP ${response.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
