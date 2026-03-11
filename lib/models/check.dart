class MonthlyCheck {
  final int? id;
  final int elevatorId;
  final int siteId;
  final int checkYear;
  final int checkMonth;
  final String? checkDate;
  final String? checkerName;
  final String status; // 예정, 완료, 불가, 이월
  final String doorCheck;
  final String motorCheck;
  final String brakeCheck;
  final String ropeCheck;
  final String safetyDeviceCheck;
  final String lightingCheck;
  final String emergencyCheck;
  final String overallResult;
  final String? issuesFound;
  final String? actionsTaken;
  final String? nextAction;
  final String? notes;
  // Join fields
  final String? siteName;
  final String? elevatorName;

  MonthlyCheck({
    this.id,
    required this.elevatorId,
    required this.siteId,
    required this.checkYear,
    required this.checkMonth,
    this.checkDate,
    this.checkerName,
    this.status = '예정',
    this.doorCheck = '양호',
    this.motorCheck = '양호',
    this.brakeCheck = '양호',
    this.ropeCheck = '양호',
    this.safetyDeviceCheck = '양호',
    this.lightingCheck = '양호',
    this.emergencyCheck = '양호',
    this.overallResult = '양호',
    this.issuesFound,
    this.actionsTaken,
    this.nextAction,
    this.notes,
    this.siteName,
    this.elevatorName,
  });

  factory MonthlyCheck.fromJson(Map<String, dynamic> json) {
    return MonthlyCheck(
      id: json['id'] as int?,
      elevatorId: (json['elevator_id'] as num?)?.toInt() ?? 0,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      checkYear: (json['check_year'] as num?)?.toInt() ?? DateTime.now().year,
      checkMonth: (json['check_month'] as num?)?.toInt() ?? DateTime.now().month,
      checkDate: json['check_date'] as String?,
      checkerName: json['checker_name'] as String?,
      status: json['status'] as String? ?? '예정',
      doorCheck: json['door_check'] as String? ?? '양호',
      motorCheck: json['motor_check'] as String? ?? '양호',
      brakeCheck: json['brake_check'] as String? ?? '양호',
      ropeCheck: json['rope_check'] as String? ?? '양호',
      safetyDeviceCheck: json['safety_device_check'] as String? ?? '양호',
      lightingCheck: json['lighting_check'] as String? ?? '양호',
      emergencyCheck: json['emergency_check'] as String? ?? '양호',
      overallResult: json['overall_result'] as String? ?? '양호',
      issuesFound: json['issues_found'] as String?,
      actionsTaken: json['actions_taken'] as String?,
      nextAction: json['next_action'] as String?,
      notes: json['notes'] as String?,
      siteName: json['site_name'] as String?,
      elevatorName: json['elevator_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'elevator_id': elevatorId,
      'site_id': siteId,
      'check_year': checkYear,
      'check_month': checkMonth,
      if (checkDate != null) 'check_date': checkDate,
      if (checkerName != null) 'checker_name': checkerName,
      'status': status,
      'door_check': doorCheck,
      'motor_check': motorCheck,
      'brake_check': brakeCheck,
      'rope_check': ropeCheck,
      'safety_device_check': safetyDeviceCheck,
      'lighting_check': lightingCheck,
      'emergency_check': emergencyCheck,
      'overall_result': overallResult,
      if (issuesFound != null) 'issues_found': issuesFound,
      if (actionsTaken != null) 'actions_taken': actionsTaken,
      if (nextAction != null) 'next_action': nextAction,
      if (notes != null) 'notes': notes,
    };
  }
}

class QuarterlyCheck {
  final int? id;
  final int elevatorId;
  final int siteId;
  final int checkYear;
  final int quarter;
  final String? checkDate;
  final String? checkerName;
  final String status;
  final String mechanicalRoom;
  final String hoistway;
  final String carInterior;
  final String pit;
  final String landingDoors;
  final String safetyGear;
  final String ropesChains;
  final String buffers;
  final String electrical;
  final int? overallScore;
  final String overallResult;
  final String? smartDiagnosis;
  final String? vibrationData;
  final double? noiseLevel;
  final double? speedTest;
  final String? issuesFound;
  final String? actionsTaken;
  final String? nextAction;
  final String? reportUrl;
  final String? notes;
  // Join fields
  final String? siteName;
  final String? elevatorName;

  QuarterlyCheck({
    this.id,
    required this.elevatorId,
    required this.siteId,
    required this.checkYear,
    required this.quarter,
    this.checkDate,
    this.checkerName,
    this.status = '예정',
    this.mechanicalRoom = '양호',
    this.hoistway = '양호',
    this.carInterior = '양호',
    this.pit = '양호',
    this.landingDoors = '양호',
    this.safetyGear = '양호',
    this.ropesChains = '양호',
    this.buffers = '양호',
    this.electrical = '양호',
    this.overallScore,
    this.overallResult = '양호',
    this.smartDiagnosis,
    this.vibrationData,
    this.noiseLevel,
    this.speedTest,
    this.issuesFound,
    this.actionsTaken,
    this.nextAction,
    this.reportUrl,
    this.notes,
    this.siteName,
    this.elevatorName,
  });

  factory QuarterlyCheck.fromJson(Map<String, dynamic> json) {
    return QuarterlyCheck(
      id: json['id'] as int?,
      elevatorId: (json['elevator_id'] as num?)?.toInt() ?? 0,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      checkYear: (json['check_year'] as num?)?.toInt() ?? DateTime.now().year,
      quarter: (json['quarter'] as num?)?.toInt() ?? 1,
      checkDate: json['check_date'] as String?,
      checkerName: json['checker_name'] as String?,
      status: json['status'] as String? ?? '예정',
      mechanicalRoom: json['mechanical_room'] as String? ?? '양호',
      hoistway: json['hoistway'] as String? ?? '양호',
      carInterior: json['car_interior'] as String? ?? '양호',
      pit: json['pit'] as String? ?? '양호',
      landingDoors: json['landing_doors'] as String? ?? '양호',
      safetyGear: json['safety_gear'] as String? ?? '양호',
      ropesChains: json['ropes_chains'] as String? ?? '양호',
      buffers: json['buffers'] as String? ?? '양호',
      electrical: json['electrical'] as String? ?? '양호',
      overallScore: (json['overall_score'] as num?)?.toInt(),
      overallResult: json['overall_result'] as String? ?? '양호',
      smartDiagnosis: json['smart_diagnosis'] as String?,
      vibrationData: json['vibration_data'] as String?,
      noiseLevel: (json['noise_level'] as num?)?.toDouble(),
      speedTest: (json['speed_test'] as num?)?.toDouble(),
      issuesFound: json['issues_found'] as String?,
      actionsTaken: json['actions_taken'] as String?,
      nextAction: json['next_action'] as String?,
      reportUrl: json['report_url'] as String?,
      notes: json['notes'] as String?,
      siteName: json['site_name'] as String?,
      elevatorName: json['elevator_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'elevator_id': elevatorId,
      'site_id': siteId,
      'check_year': checkYear,
      'quarter': quarter,
      if (checkDate != null) 'check_date': checkDate,
      if (checkerName != null) 'checker_name': checkerName,
      'status': status,
      'mechanical_room': mechanicalRoom,
      'hoistway': hoistway,
      'car_interior': carInterior,
      'pit': pit,
      'landing_doors': landingDoors,
      'safety_gear': safetyGear,
      'ropes_chains': ropesChains,
      'buffers': buffers,
      'electrical': electrical,
      if (overallScore != null) 'overall_score': overallScore,
      'overall_result': overallResult,
      if (smartDiagnosis != null) 'smart_diagnosis': smartDiagnosis,
      if (noiseLevel != null) 'noise_level': noiseLevel,
      if (speedTest != null) 'speed_test': speedTest,
      if (issuesFound != null) 'issues_found': issuesFound,
      if (actionsTaken != null) 'actions_taken': actionsTaken,
      if (nextAction != null) 'next_action': nextAction,
      if (notes != null) 'notes': notes,
    };
  }
}

class DashboardData {
  final int sites;
  final Map<String, dynamic>? elevators;
  final Map<String, dynamic>? pendingIssues;
  final int upcomingInspections;
  final Map<String, dynamic>? monthlyStats;
  final Map<String, dynamic>? quarterlyStats;
  final List<dynamic> recentIssues;

  DashboardData({
    this.sites = 0,
    this.elevators,
    this.pendingIssues,
    this.upcomingInspections = 0,
    this.monthlyStats,
    this.quarterlyStats,
    this.recentIssues = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      sites: (json['sites'] as num?)?.toInt() ?? 0,
      elevators: json['elevators'] as Map<String, dynamic>?,
      pendingIssues: json['pendingIssues'] as Map<String, dynamic>?,
      upcomingInspections: (json['upcomingInspections'] as num?)?.toInt() ?? 0,
      monthlyStats: json['monthlyStats'] as Map<String, dynamic>?,
      quarterlyStats: json['quarterlyStats'] as Map<String, dynamic>?,
      recentIssues: json['recentIssues'] as List<dynamic>? ?? [],
    );
  }
}
