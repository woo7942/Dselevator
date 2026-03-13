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

class ApiService {
  static String _baseUrl = '';
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
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  static String get baseUrl => _baseUrl;

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
    notifyDataChanged('site'); // 데이터 변경 알림
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateSite(int id, Site site) async {
    await _put('/api/sites/$id', site.toJson());
    notifyDataChanged('site'); // 데이터 변경 알림
  }

  static Future<void> deleteSite(int id) async {
    await _delete('/api/sites/$id');
    notifyDataChanged('site'); // 데이터 변경 알림
  }

  static Future<int> createElevator(int siteId, Elevator elevator) async {
    final body = elevator.toJson();
    body['site_id'] = siteId;
    final res = await _post('/api/elevators', body);
    notifyDataChanged('elevator'); // 데이터 변경 알림
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateElevator(int id, Elevator elevator) async {
    await _put('/api/elevators/$id', elevator.toJson());
    notifyDataChanged('elevator'); // 데이터 변경 알림
  }

  static Future<void> deleteElevator(int id) async {
    await _delete('/api/elevators/$id');
    notifyDataChanged('elevator'); // 데이터 변경 알림
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateInspection(int id, Inspection inspection) async {
    await _put('/api/inspections/$id', inspection.toJson());
    notifyDataChanged('inspection');
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateIssue(int id, InspectionIssue issue) async {
    await _put('/api/issues/$id', issue.toJson());
    notifyDataChanged('issue');
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
  }

  static Future<Map<String, dynamic>> createIssuesBulk(
      List<Map<String, dynamic>> issues) async {
    final result = await _post('/api/issues/bulk', {'issues': issues});
    notifyDataChanged('issue');
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
  static Future<List<String>> getTeams() async {
    final res = await _get('/api/teams');
    final list = _extractList(res);
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> addTeam(String name) async {
    await _post('/api/teams', {'name': name});
  }

  // ── 사용자 관리 ─────────────────────────────────────────────
  static Future<List<dynamic>> getUsers() async {
    final res = await _get('/api/users');
    return _extractList(res);
  }

  static Future<void> createUser(String name, String pin, String role) async {
    await _post('/api/users', {'name': name, 'pin': pin, 'role': role});
  }

  static Future<void> updateUser(int id, {String? name, String? pin, String? role, int? isActive, String? tabPermissions}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (pin != null) body['pin'] = pin;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    if (tabPermissions != null) body['tab_permissions'] = tabPermissions;
    await _put('/api/users/$id', body);
  }

  static Future<void> deleteUser(int id) async {
    await _delete('/api/users/$id');
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
