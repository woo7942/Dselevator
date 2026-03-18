class ErrorCode {
  final int id;
  final String errorCode;
  final String manufacturer;
  final String elevatorType;
  final String errorTitle;
  final String? errorDescription;
  final String? cause;
  final String? solution;
  final String severity; // '긴급' | '주의' | '일반'
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;
  final List<ErrorComment> comments;

  const ErrorCode({
    required this.id,
    required this.errorCode,
    required this.manufacturer,
    required this.elevatorType,
    required this.errorTitle,
    this.errorDescription,
    this.cause,
    this.solution,
    required this.severity,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.comments = const [],
  });

  factory ErrorCode.fromJson(Map<String, dynamic> json) {
    final commentList = (json['comments'] as List<dynamic>? ?? [])
        .map((c) => ErrorComment.fromJson(c as Map<String, dynamic>))
        .toList();
    return ErrorCode(
      id: json['id'] as int,
      errorCode: json['error_code'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      elevatorType: json['elevator_type'] as String? ?? '전체',
      errorTitle: json['error_title'] as String? ?? '',
      errorDescription: json['error_description'] as String?,
      cause: json['cause'] as String?,
      solution: json['solution'] as String?,
      severity: json['severity'] as String? ?? '일반',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      comments: commentList,
    );
  }

  Map<String, dynamic> toJson() => {
    'error_code': errorCode,
    'manufacturer': manufacturer,
    'elevator_type': elevatorType,
    'error_title': errorTitle,
    'error_description': errorDescription,
    'cause': cause,
    'solution': solution,
    'severity': severity,
    'created_by': createdBy,
  };

  ErrorCode copyWith({List<ErrorComment>? comments}) {
    return ErrorCode(
      id: id,
      errorCode: errorCode,
      manufacturer: manufacturer,
      elevatorType: elevatorType,
      errorTitle: errorTitle,
      errorDescription: errorDescription,
      cause: cause,
      solution: solution,
      severity: severity,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      comments: comments ?? this.comments,
    );
  }
}

class ErrorComment {
  final int id;
  final int errorId;
  final String author;
  final String content;
  final String? createdAt;

  const ErrorComment({
    required this.id,
    required this.errorId,
    required this.author,
    required this.content,
    this.createdAt,
  });

  factory ErrorComment.fromJson(Map<String, dynamic> json) {
    return ErrorComment(
      id: json['id'] as int,
      errorId: json['error_id'] as int? ?? 0,
      author: json['author'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}
