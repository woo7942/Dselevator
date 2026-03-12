import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site.dart';
import '../models/inspection.dart';
import '../models/check.dart';

class ApiService {
  static String _baseUrl = '';
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultUrl = 'https://8787-itvxovwjc5r0tvfptlnxw-b32ec7bb.sandbox.novita.ai';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultUrl;
  }

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

  static Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    try {
      var uri = Uri.parse('$_baseUrl$path');
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: params);
      }
      final response = await http.get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      throw ApiException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('네트워크 오류: $e');
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 15));
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
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http.put(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 15));
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
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http.patch(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body))
          .timeout(const Duration(seconds: 15));
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
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http.delete(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));
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
  static Future<DashboardData> getDashboard() async {
    final res = await _get('/api/dashboard');
    return DashboardData.fromJson(res['data'] as Map<String, dynamic>? ?? {});
  }

  // ── 현장 ──────────────────────────────────────────────────
  static Future<List<Site>> getSites({String? search, String? status, String? region}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (region != null && region != '전체') params['region'] = region;
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateSite(int id, Site site) async {
    await _put('/api/sites/$id', site.toJson());
  }

  static Future<void> deleteSite(int id) async {
    await _delete('/api/sites/$id');
  }

  static Future<int> createElevator(int siteId, Elevator elevator) async {
    final body = elevator.toJson();
    body['site_id'] = siteId;
    final res = await _post('/api/elevators', body);
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateElevator(int id, Elevator elevator) async {
    await _put('/api/elevators/$id', elevator.toJson());
  }

  static Future<void> deleteElevator(int id) async {
    await _delete('/api/elevators/$id');
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateInspection(int id, Inspection inspection) async {
    await _put('/api/inspections/$id', inspection.toJson());
  }

  static Future<void> deleteInspection(int id) async {
    await _delete('/api/inspections/$id');
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateIssue(int id, InspectionIssue issue) async {
    await _put('/api/issues/$id', issue.toJson());
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
  }

  static Future<void> deleteIssue(int id) async {
    await _delete('/api/issues/$id');
  }

  static Future<Map<String, dynamic>> createIssuesBulk(
      List<Map<String, dynamic>> issues) async {
    return await _post('/api/issues/bulk', {'issues': issues});
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
      final url = await _uploadOneXhr(
        files[i],
        filenames[i],
        onProgress: onProgress == null ? null : (p) => onProgress(i, files.length, p),
      );
      urls.add(url);
    }
    return urls;
  }

  /// XHR 기반 단일 파일 업로드 (Web 전용, 실시간 진행률)
  /// - Flutter Web에서 http.MultipartRequest는 동작 안 함 → XHR 필수
  /// - 재시도 없음 (1회만 전송)
  static Future<String> _uploadOneXhr(
    Uint8List bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) {
    final completer = Completer<String>();
    final uri = '$_baseUrl/api/upload';

    // 파일 크기에 따른 타임아웃 (최소 120초, MB당 5초, 최대 600초)
    final fileMB = bytes.length / (1024 * 1024);
    final timeoutMs = ((120 + fileMB * 5).clamp(120, 600) * 1000).toInt();

    final xhr = web.XMLHttpRequest();
    xhr.open('POST', uri);
    xhr.timeout = timeoutMs;

    // ── 업로드 진행률 (전송 단계: 0% → 90%) ──
    xhr.upload.addEventListener('progress', ((web.Event e) {
      if (completer.isCompleted) return;
      final pe = e as web.ProgressEvent;
      if (pe.lengthComputable && pe.total > 0) {
        final p = (pe.loaded / pe.total) * 0.9;
        onProgress?.call(p);
      }
    }).toJS);

    // ── 서버 응답 완료 (100%) ──
    xhr.addEventListener('load', ((web.Event _) {
      if (completer.isCompleted) return;
      onProgress?.call(1.0);
      try {
        if (xhr.status == 200) {
          final text = xhr.responseText;
          final data = jsonDecode(text) as Map<String, dynamic>;
          if (data['success'] == true) {
            final list = data['urls'];
            if (list is List && list.isNotEmpty) {
              completer.complete(list.first.toString());
            } else {
              completer.completeError(Exception('서버에서 URL을 반환하지 않았습니다'));
            }
          } else {
            completer.completeError(Exception(data['error']?.toString() ?? '업로드 오류'));
          }
        } else {
          completer.completeError(Exception('업로드 실패 (HTTP ${xhr.status})'));
        }
      } catch (e) {
        completer.completeError(Exception('응답 파싱 오류: $e'));
      }
    }).toJS);

    // ── 네트워크 오류 ──
    xhr.addEventListener('error', ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('네트워크 오류 - 연결을 확인해주세요'));
      }
    }).toJS);

    // ── 타임아웃 ──
    xhr.addEventListener('timeout', ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(
          '업로드 타임아웃 (${fileMB.toStringAsFixed(1)}MB) - 네트워크가 느립니다'));
      }
    }).toJS);

    // ── 취소 ──
    xhr.addEventListener('abort', ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('업로드가 취소되었습니다'));
      }
    }).toJS);

    // ── FormData 전송 ──
    final formData = web.FormData();
    final mime = _mimeType(filename);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    formData.append('files', blob, filename);
    xhr.send(formData);

    return completer.future;
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateMonthlyCheck(int id, MonthlyCheck check) async {
    await _put('/api/monthly/$id', check.toJson());
  }

  static Future<void> deleteMonthlyCheck(int id) async {
    await _delete('/api/monthly/$id');
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
    return (res['id'] as num?)?.toInt() ?? (res['data']?['id'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateQuarterlyCheck(int id, QuarterlyCheck check) async {
    await _put('/api/quarterly/$id', check.toJson());
  }

  static Future<void> deleteQuarterlyCheck(int id) async {
    await _delete('/api/quarterly/$id');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
