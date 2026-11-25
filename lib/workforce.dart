class StudioWorker {
  const StudioWorker({
    required this.id,
    required this.name,
    required this.kind,
    required this.role,
    required this.phone,
    required this.email,
    required this.status,
  });

  final String id;
  final String name;
  final String kind;
  final String role;
  final String phone;
  final String email;
  final String status;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'role': role,
    'phone': phone,
    'email': email,
    'status': status,
  };

  factory StudioWorker.fromJson(Object? value) {
    final map = _map(value);
    return StudioWorker(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      kind: _string(map, 'kind'),
      role: _string(map, 'role'),
      phone: _string(map, 'phone'),
      email: _string(map, 'email'),
      status: _string(map, 'status'),
    );
  }
}

class StudioWorkforceAllocation {
  const StudioWorkforceAllocation({
    required this.id,
    required this.workerId,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.notes,
  });

  final String id;
  final String workerId;
  final String projectId;
  final DateTime startDate;
  final DateTime? endDate;
  final String notes;

  Map<String, Object?> toJson() => {
    'id': id,
    'workerId': workerId,
    'projectId': projectId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'notes': notes,
  };

  factory StudioWorkforceAllocation.fromJson(Object? value) {
    final map = _map(value);
    final end = map['endDate'];
    return StudioWorkforceAllocation(
      id: _string(map, 'id'),
      workerId: _string(map, 'workerId'),
      projectId: _string(map, 'projectId'),
      startDate: _date(map, 'startDate'),
      endDate: end == null ? null : DateTime.tryParse(end as String),
      notes: _string(map, 'notes'),
    );
  }
}

class StudioSiteAttendance {
  const StudioSiteAttendance({
    required this.id,
    required this.workerId,
    required this.projectId,
    required this.date,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.note,
  });

  final String id;
  final String workerId;
  final String projectId;
  final DateTime date;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'workerId': workerId,
    'projectId': projectId,
    'date': date.toIso8601String(),
    'status': status,
    'checkIn': checkIn?.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'note': note,
  };

  factory StudioSiteAttendance.fromJson(Object? value) {
    final map = _map(value);
    final checkIn = map['checkIn'];
    final checkOut = map['checkOut'];
    return StudioSiteAttendance(
      id: _string(map, 'id'),
      workerId: _string(map, 'workerId'),
      projectId: _string(map, 'projectId'),
      date: _date(map, 'date'),
      status: _string(map, 'status'),
      checkIn: checkIn == null ? null : DateTime.tryParse(checkIn as String),
      checkOut: checkOut == null ? null : DateTime.tryParse(checkOut as String),
      note: _string(map, 'note'),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('A saved workforce record is invalid.');
  }
  return value;
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved workforce record is missing "$key".');
  }
  return value;
}

DateTime _date(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved workforce record has invalid "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('A saved workforce record has invalid "$key".');
  }
  return date;
}
