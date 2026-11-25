class StudioStockBalance {
  const StudioStockBalance({
    required this.id,
    required this.projectId,
    required this.materialId,
    required this.location,
    required this.quantityMilli,
  });

  final String id;
  final String projectId;
  final String materialId;
  final String location;
  final int quantityMilli;

  double get quantity => quantityMilli / 1000;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'materialId': materialId,
    'location': location,
    'quantityMilli': quantityMilli,
  };

  factory StudioStockBalance.fromJson(Object? value) => StudioStockBalance(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    materialId: _string(value, 'materialId'),
    location: _string(value, 'location'),
    quantityMilli: _int(value, 'quantityMilli'),
  );
}

class StudioGoodsReceiptLine {
  const StudioGoodsReceiptLine({
    required this.purchaseOrderLineId,
    required this.quantityMilli,
    required this.acceptedQuantityMilli,
  });

  final String purchaseOrderLineId;
  final int quantityMilli;
  final int acceptedQuantityMilli;

  Map<String, Object?> toJson() => {
    'purchaseOrderLineId': purchaseOrderLineId,
    'quantityMilli': quantityMilli,
    'acceptedQuantityMilli': acceptedQuantityMilli,
  };

  factory StudioGoodsReceiptLine.fromJson(Object? value) =>
      StudioGoodsReceiptLine(
        purchaseOrderLineId: _string(value, 'purchaseOrderLineId'),
        quantityMilli: _int(value, 'quantityMilli'),
        acceptedQuantityMilli: _int(value, 'acceptedQuantityMilli'),
      );
}

class StudioGoodsReceipt {
  const StudioGoodsReceipt({
    required this.id,
    required this.projectId,
    required this.purchaseOrderId,
    required this.location,
    required this.notes,
    required this.status,
    required this.lines,
    required this.receivedAt,
  });

  final String id;
  final String projectId;
  final String purchaseOrderId;
  final String location;
  final String notes;
  final String status;
  final List<StudioGoodsReceiptLine> lines;
  final DateTime receivedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'purchaseOrderId': purchaseOrderId,
    'location': location,
    'notes': notes,
    'status': status,
    'lines': lines.map((line) => line.toJson()).toList(),
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory StudioGoodsReceipt.fromJson(Object? value) => StudioGoodsReceipt(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    purchaseOrderId: _string(value, 'purchaseOrderId'),
    location: _string(value, 'location'),
    notes: _string(value, 'notes'),
    status: _string(value, 'status'),
    lines: _list(value, 'lines', StudioGoodsReceiptLine.fromJson),
    receivedAt: _date(value, 'receivedAt'),
  );
}

class StudioStockMovement {
  const StudioStockMovement({
    required this.id,
    required this.projectId,
    required this.materialId,
    required this.kind,
    required this.fromLocation,
    required this.toLocation,
    required this.quantityMilli,
    required this.reference,
    required this.notes,
    required this.occurredAt,
  });

  final String id;
  final String projectId;
  final String materialId;
  final String kind;
  final String? fromLocation;
  final String? toLocation;
  final int quantityMilli;
  final String reference;
  final String notes;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'materialId': materialId,
    'kind': kind,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
    'quantityMilli': quantityMilli,
    'reference': reference,
    'notes': notes,
    'occurredAt': occurredAt.toIso8601String(),
  };

  factory StudioStockMovement.fromJson(Object? value) => StudioStockMovement(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    materialId: _string(value, 'materialId'),
    kind: _string(value, 'kind'),
    fromLocation: _nullableString(value, 'fromLocation'),
    toLocation: _nullableString(value, 'toLocation'),
    quantityMilli: _int(value, 'quantityMilli'),
    reference: _string(value, 'reference'),
    notes: _string(value, 'notes'),
    occurredAt: _date(value, 'occurredAt'),
  );
}

class StudioWorkOrder {
  const StudioWorkOrder({
    required this.id,
    required this.projectId,
    required this.title,
    required this.contractor,
    required this.scope,
    required this.status,
    required this.priority,
    required this.startDate,
    required this.dueDate,
  });

  final String id;
  final String projectId;
  final String title;
  final String contractor;
  final String scope;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? dueDate;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'contractor': contractor,
    'scope': scope,
    'status': status,
    'priority': priority,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
  };

  factory StudioWorkOrder.fromJson(Object? value) => StudioWorkOrder(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    title: _string(value, 'title'),
    contractor: _string(value, 'contractor'),
    scope: _string(value, 'scope'),
    status: _string(value, 'status'),
    priority: _string(value, 'priority'),
    startDate: _nullableDate(value, 'startDate'),
    dueDate: _nullableDate(value, 'dueDate'),
  );
}

class StudioDailyReport {
  const StudioDailyReport({
    required this.id,
    required this.projectId,
    required this.reportDate,
    required this.summary,
    required this.weather,
    required this.workforceCount,
    required this.delays,
  });

  final String id;
  final String projectId;
  final DateTime reportDate;
  final String summary;
  final String weather;
  final int workforceCount;
  final String delays;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'reportDate': reportDate.toIso8601String(),
    'summary': summary,
    'weather': weather,
    'workforceCount': workforceCount,
    'delays': delays,
  };

  factory StudioDailyReport.fromJson(Object? value) => StudioDailyReport(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    reportDate: _date(value, 'reportDate'),
    summary: _string(value, 'summary'),
    weather: _string(value, 'weather'),
    workforceCount: _int(value, 'workforceCount'),
    delays: _string(value, 'delays'),
  );
}

class StudioSiteInspection {
  const StudioSiteInspection({
    required this.id,
    required this.projectId,
    required this.title,
    required this.kind,
    required this.status,
    required this.inspector,
    required this.findings,
    required this.inspectedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String kind;
  final String status;
  final String inspector;
  final String findings;
  final DateTime inspectedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'kind': kind,
    'status': status,
    'inspector': inspector,
    'findings': findings,
    'inspectedAt': inspectedAt.toIso8601String(),
  };

  factory StudioSiteInspection.fromJson(Object? value) => StudioSiteInspection(
    id: _string(value, 'id'),
    projectId: _string(value, 'projectId'),
    title: _string(value, 'title'),
    kind: _string(value, 'kind'),
    status: _string(value, 'status'),
    inspector: _string(value, 'inspector'),
    findings: _string(value, 'findings'),
    inspectedAt: _date(value, 'inspectedAt'),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('A saved site execution record is invalid.');
  }
  return value;
}

String _string(Object? value, String key) {
  final map = _map(value);
  final field = map[key];
  if (field is! String) {
    throw FormatException('Saved site execution record missing "$key".');
  }
  return field;
}

String? _nullableString(Object? value, String key) {
  final field = _map(value)[key];
  return field == null
      ? null
      : field is String
      ? field
      : throw const FormatException();
}

int _int(Object? value, String key) {
  final field = _map(value)[key];
  if (field is! int) throw const FormatException();
  return field;
}

DateTime _date(Object? value, String key) {
  final field = _map(value)[key];
  if (field is! String) throw const FormatException();
  final date = DateTime.tryParse(field);
  if (date == null) throw const FormatException();
  return date;
}

DateTime? _nullableDate(Object? value, String key) {
  final field = _map(value)[key];
  if (field == null) return null;
  if (field is! String) throw const FormatException();
  return DateTime.tryParse(field);
}

List<T> _list<T>(Object? value, String key, T Function(Object?) parser) {
  final field = _map(value)[key];
  if (field is! List<dynamic>) throw const FormatException();
  return field.map(parser).toList();
}
