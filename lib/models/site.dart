class Site {
  final int? id;
  final String siteCode;
  final String siteName;
  final String address;
  final String? ownerName;
  final String? ownerPhone;
  final String? managerName;
  final int totalElevators;
  final String status; // active, inactive, suspended
  final String? contractStart;
  final String? contractEnd;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final int? elevatorCount;

  Site({
    this.id,
    required this.siteCode,
    required this.siteName,
    required this.address,
    this.ownerName,
    this.ownerPhone,
    this.managerName,
    this.totalElevators = 0,
    this.status = 'active',
    this.contractStart,
    this.contractEnd,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.elevatorCount,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as int?,
      siteCode: json['site_code'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      ownerName: json['owner_name'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      managerName: json['manager_name'] as String?,
      totalElevators: (json['total_elevators'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      contractStart: json['contract_start'] as String?,
      contractEnd: json['contract_end'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      elevatorCount: (json['elevator_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'site_code': siteCode,
      'site_name': siteName,
      'address': address,
      if (ownerName != null) 'owner_name': ownerName,
      if (ownerPhone != null) 'owner_phone': ownerPhone,
      if (managerName != null) 'manager_name': managerName,
      'total_elevators': totalElevators,
      'status': status,
      if (contractStart != null) 'contract_start': contractStart,
      if (contractEnd != null) 'contract_end': contractEnd,
      if (notes != null) 'notes': notes,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'active': return '운영중';
      case 'inactive': return '비운영';
      case 'suspended': return '중지';
      default: return status;
    }
  }
}

class Elevator {
  final int? id;
  final int siteId;
  final String elevatorNo;
  final String? elevatorName;
  final String elevatorType;
  final String? manufacturer;
  final int? manufactureYear;
  final String? installDate;
  final String? floorsServed;
  final int? capacity;
  final int? loadCapacity;
  final double? speed;
  final String status; // normal, warning, fault, stopped
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  Elevator({
    this.id,
    required this.siteId,
    required this.elevatorNo,
    this.elevatorName,
    this.elevatorType = '승객용',
    this.manufacturer,
    this.manufactureYear,
    this.installDate,
    this.floorsServed,
    this.capacity,
    this.loadCapacity,
    this.speed,
    this.status = 'normal',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Elevator.fromJson(Map<String, dynamic> json) {
    return Elevator(
      id: json['id'] as int?,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      elevatorNo: json['elevator_no'] as String? ?? '',
      elevatorName: json['elevator_name'] as String?,
      elevatorType: json['elevator_type'] as String? ?? '승객용',
      manufacturer: json['manufacturer'] as String?,
      manufactureYear: (json['manufacture_year'] as num?)?.toInt(),
      installDate: json['install_date'] as String?,
      floorsServed: json['floors_served'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      loadCapacity: (json['load_capacity'] as num?)?.toInt(),
      speed: (json['speed'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'normal',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'site_id': siteId,
      'elevator_no': elevatorNo,
      if (elevatorName != null) 'elevator_name': elevatorName,
      'elevator_type': elevatorType,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (manufactureYear != null) 'manufacture_year': manufactureYear,
      if (installDate != null) 'install_date': installDate,
      if (floorsServed != null) 'floors_served': floorsServed,
      if (capacity != null) 'capacity': capacity,
      if (loadCapacity != null) 'load_capacity': loadCapacity,
      if (speed != null) 'speed': speed,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'normal': return '정상';
      case 'warning': return '주의';
      case 'fault': return '고장';
      case 'stopped': return '정지';
      default: return status;
    }
  }

  String get displayName => elevatorName ?? elevatorNo;
}
