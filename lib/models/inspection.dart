class Inspection {
  final int? id;
  final int elevatorId;
  final int siteId;
  final String inspectionType;
  final String inspectionDate;
  final String? scheduledDate;
  final String? nextInspectionDate;
  final String? inspectorName;
  final String? inspectionAgency;
  final String result; // '예정', '합격', '조건부합격', '불합격', '보류'
  final String? reportNo;
  final String? notes;
  final String? createdAt;
  final String? siteName;
  final double? daysRemaining;
  final String? teamName;

  Inspection({
    this.id,
    required this.elevatorId,
    required this.siteId,
    required this.inspectionType,
    required this.inspectionDate,
    this.scheduledDate,
    this.nextInspectionDate,
    this.inspectorName,
    this.inspectionAgency,
    this.result = '예정',
    this.reportNo,
    this.notes,
    this.createdAt,
    this.siteName,
    this.daysRemaining,
    this.teamName,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as int?,
      elevatorId: (json['elevator_id'] as num?)?.toInt() ?? 0,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      inspectionType: json['inspection_type'] as String? ?? '',
      inspectionDate: json['inspection_date'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String?,
      nextInspectionDate: json['next_inspection_date'] as String?,
      inspectorName: json['inspector_name'] as String?,
      inspectionAgency: json['inspection_agency'] as String?,
      result: json['result'] as String? ?? '합격',
      reportNo: json['report_no'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      siteName: json['site_name'] as String?,
      daysRemaining: (json['days_remaining'] as num?)?.toDouble(),
      teamName: json['team'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'elevator_id': elevatorId,
      'site_id': siteId,
      'inspection_type': inspectionType,
      'inspection_date': inspectionDate,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (nextInspectionDate != null) 'next_inspection_date': nextInspectionDate,
      if (inspectorName != null) 'inspector_name': inspectorName,
      if (inspectionAgency != null) 'inspection_agency': inspectionAgency,
      'result': result,
      if (reportNo != null) 'report_no': reportNo,
      if (notes != null) 'notes': notes,
    };
  }

  String get effectiveDate => scheduledDate ?? inspectionDate;
}

class InspectionIssue {
  final int? id;
  final int? inspectionId;
  final int elevatorId;
  final int siteId;
  final int issueNo;
  final String? issueCategory;
  final String issueDescription;
  final String? legalBasis;
  final String severity; // 중결함, 경결함, 권고사항
  final String status; // 미조치, 조치중, 조치완료, 재검사필요
  final String? actionRequired;
  final String? actionTaken;
  final String? actionDate;
  final String? actionBy;
  final String? photoBefore;
  final String? photoAfter;
  final String? deadline;
  final String? inspectionDate;
  final String? inspectorName;
  final String? createdAt;
  final String? comment;       // 코멘트
  final String? mediaUrls;     // JSON 배열 문자열로 저장된 파일 URL 목록
  final String? elevatorNo;    // 호기번호 (join용)
  // Join fields
  final String? siteName;
  final String? elevatorName;
  final String? inspectionType;
  final String? inspDate;
  final String? teamName;

  InspectionIssue({
    this.id,
    this.inspectionId,
    required this.elevatorId,
    required this.siteId,
    this.issueNo = 1,
    this.issueCategory,
    required this.issueDescription,
    this.legalBasis,
    this.severity = '경결함',
    this.status = '미조치',
    this.actionRequired,
    this.actionTaken,
    this.actionDate,
    this.actionBy,
    this.photoBefore,
    this.photoAfter,
    this.deadline,
    this.inspectionDate,
    this.inspectorName,
    this.createdAt,
    this.comment,
    this.mediaUrls,
    this.elevatorNo,
    this.siteName,
    this.elevatorName,
    this.inspectionType,
    this.inspDate,
    this.teamName,
  });

  /// mediaUrls JSON 문자열을 List<String>으로 파싱
  List<String> get mediaList {
    if (mediaUrls == null || mediaUrls!.isEmpty) return [];
    try {
      final decoded = (mediaUrls!.startsWith('['))
          ? (mediaUrls!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(','))
              .map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      return decoded;
    } catch (_) {
      return [];
    }
  }

  factory InspectionIssue.fromJson(Map<String, dynamic> json) {
    return InspectionIssue(
      id: json['id'] as int?,
      inspectionId: (json['inspection_id'] as num?)?.toInt(),
      elevatorId: (json['elevator_id'] as num?)?.toInt() ?? 0,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      issueNo: (json['issue_no'] as num?)?.toInt() ?? 1,
      issueCategory: json['issue_category'] as String?,
      issueDescription: json['issue_description'] as String? ?? '',
      legalBasis: json['legal_basis'] as String?,
      severity: json['severity'] as String? ?? '경결함',
      status: json['status'] as String? ?? '미조치',
      actionRequired: json['action_required'] as String?,
      actionTaken: json['action_taken'] as String?,
      actionDate: json['action_date'] as String?,
      actionBy: json['action_by'] as String?,
      photoBefore: json['photo_before'] as String?,
      photoAfter: json['photo_after'] as String?,
      deadline: json['deadline'] as String?,
      inspectionDate: json['inspection_date'] as String?,
      inspectorName: json['inspector_name'] as String?,
      createdAt: json['created_at'] as String?,
      comment: json['comment'] as String?,
      mediaUrls: json['media_urls'] as String?,
      elevatorNo: json['elevator_no'] as String?,
      siteName: json['site_name'] as String?,
      elevatorName: json['elevator_name'] as String?,
      inspectionType: json['inspection_type'] as String?,
      inspDate: json['insp_date'] as String?,
      teamName: json['team'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (inspectionId != null) 'inspection_id': inspectionId,
      'elevator_id': elevatorId,
      'site_id': siteId,
      'issue_no': issueNo,
      if (issueCategory != null) 'issue_category': issueCategory,
      'issue_description': issueDescription,
      if (legalBasis != null) 'legal_basis': legalBasis,
      'severity': severity,
      'status': status,
      if (actionRequired != null) 'action_required': actionRequired,
      if (actionTaken != null) 'action_taken': actionTaken,
      if (actionDate != null) 'action_date': actionDate,
      if (actionBy != null) 'action_by': actionBy,
      if (deadline != null) 'deadline': deadline,
      if (inspectionDate != null) 'inspection_date': inspectionDate,
      if (inspectorName != null) 'inspector_name': inspectorName,
      if (comment != null) 'comment': comment,
      if (mediaUrls != null) 'media_urls': mediaUrls,
      if (elevatorNo != null) 'elevator_no': elevatorNo,
    };
  }
}
