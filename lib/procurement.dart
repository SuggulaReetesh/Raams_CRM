class StudioProcurementApprovalPolicy {
  const StudioProcurementApprovalPolicy({
    required this.requisitionPermissions,
    required this.purchaseOrderPermissions,
  });

  static const supportedPermissions = [
    'procurement.approve',
    'manageFinancials',
  ];

  factory StudioProcurementApprovalPolicy.defaults() =>
      const StudioProcurementApprovalPolicy(
        requisitionPermissions: ['procurement.approve'],
        purchaseOrderPermissions: ['procurement.approve', 'manageFinancials'],
      );

  final List<String> requisitionPermissions;
  final List<String> purchaseOrderPermissions;

  Map<String, Object?> toJson() => {
    'requisitionPermissions': requisitionPermissions,
    'purchaseOrderPermissions': purchaseOrderPermissions,
  };

  factory StudioProcurementApprovalPolicy.fromJson(Object? value) {
    final map = _procurementMap(value, 'approval policy');
    List<String> readPermissions(String key) {
      final permissions = map[key];
      if (permissions is! List<dynamic> ||
          !permissions.every((permission) => permission is String)) {
        throw FormatException(
          'The saved procurement policy has invalid "$key".',
        );
      }
      return permissions.cast<String>();
    }

    return StudioProcurementApprovalPolicy(
      requisitionPermissions: readPermissions('requisitionPermissions'),
      purchaseOrderPermissions: readPermissions('purchaseOrderPermissions'),
    );
  }
}

class StudioProcurementApprovalStep {
  const StudioProcurementApprovalStep({
    required this.permission,
    required this.status,
    required this.decisionNote,
    required this.decidedAt,
  });

  static const statuses = ['Pending', 'Approved', 'Rejected'];

  final String permission;
  final String status;
  final String decisionNote;
  final DateTime? decidedAt;

  Map<String, Object?> toJson() => {
    'permission': permission,
    'status': status,
    'decisionNote': decisionNote,
    'decidedAt': decidedAt?.toIso8601String(),
  };

  factory StudioProcurementApprovalStep.fromJson(Object? value) {
    final map = _procurementMap(value, 'approval step');
    final decidedAt = map['decidedAt'];
    if (decidedAt != null && decidedAt is! String) {
      throw const FormatException(
        'The saved procurement approval step has an invalid decision date.',
      );
    }
    return StudioProcurementApprovalStep(
      permission: _procurementString(map, 'permission'),
      status: _procurementString(map, 'status'),
      decisionNote: _procurementString(map, 'decisionNote'),
      decidedAt: decidedAt == null
          ? null
          : DateTime.tryParse(decidedAt as String),
    );
  }
}

class StudioRequisitionLine {
  const StudioRequisitionLine({
    required this.id,
    required this.materialId,
    required this.name,
    required this.unit,
    required this.quantityMilli,
    required this.specification,
  });

  final String id;
  final String materialId;
  final String name;
  final String unit;
  final int quantityMilli;
  final String specification;

  double get quantity => quantityMilli / 1000;

  Map<String, Object?> toJson() => {
    'id': id,
    'materialId': materialId,
    'name': name,
    'unit': unit,
    'quantityMilli': quantityMilli,
    'specification': specification,
  };

  factory StudioRequisitionLine.fromJson(Object? value) {
    final map = _procurementMap(value, 'requisition line');
    final quantityMilli = map['quantityMilli'];
    if (quantityMilli is! int) {
      throw const FormatException(
        'The saved requisition line has an invalid quantity.',
      );
    }
    return StudioRequisitionLine(
      id: _procurementString(map, 'id'),
      materialId: _procurementString(map, 'materialId'),
      name: _procurementString(map, 'name'),
      unit: _procurementString(map, 'unit'),
      quantityMilli: quantityMilli,
      specification: _procurementString(map, 'specification'),
    );
  }
}

class StudioMaterialRequisition {
  const StudioMaterialRequisition({
    required this.id,
    required this.projectId,
    required this.title,
    required this.requiredBy,
    required this.notes,
    required this.status,
    required this.items,
    required this.approvalSteps,
    required this.createdAt,
  });

  static const statuses = ['Draft', 'Pending approval', 'Approved', 'Rejected'];

  final String id;
  final String projectId;
  final String title;
  final DateTime? requiredBy;
  final String notes;
  final String status;
  final List<StudioRequisitionLine> items;
  final List<StudioProcurementApprovalStep> approvalSteps;
  final DateTime createdAt;

  StudioMaterialRequisition copyWith({
    String? status,
    List<StudioProcurementApprovalStep>? approvalSteps,
  }) => StudioMaterialRequisition(
    id: id,
    projectId: projectId,
    title: title,
    requiredBy: requiredBy,
    notes: notes,
    status: status ?? this.status,
    items: items,
    approvalSteps: approvalSteps ?? this.approvalSteps,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'requiredBy': requiredBy?.toIso8601String(),
    'notes': notes,
    'status': status,
    'items': items.map((item) => item.toJson()).toList(),
    'approvalSteps': approvalSteps.map((step) => step.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudioMaterialRequisition.fromJson(Object? value) {
    final map = _procurementMap(value, 'requisition');
    return StudioMaterialRequisition(
      id: _procurementString(map, 'id'),
      projectId: _procurementString(map, 'projectId'),
      title: _procurementString(map, 'title'),
      requiredBy: _procurementDate(map, 'requiredBy', nullable: true),
      notes: _procurementString(map, 'notes'),
      status: _procurementString(map, 'status'),
      items: _procurementList(map, 'items', StudioRequisitionLine.fromJson),
      approvalSteps: _procurementList(
        map,
        'approvalSteps',
        StudioProcurementApprovalStep.fromJson,
      ),
      createdAt: _procurementDate(map, 'createdAt')!,
    );
  }
}

class StudioRequestForQuotation {
  const StudioRequestForQuotation({
    required this.id,
    required this.projectId,
    required this.requisitionId,
    required this.vendorIds,
    required this.quoteDueAt,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  static const statuses = ['Draft', 'Issued', 'Closed'];

  final String id;
  final String projectId;
  final String requisitionId;
  final List<String> vendorIds;
  final DateTime? quoteDueAt;
  final String notes;
  final String status;
  final DateTime createdAt;

  StudioRequestForQuotation copyWith({String? status}) =>
      StudioRequestForQuotation(
        id: id,
        projectId: projectId,
        requisitionId: requisitionId,
        vendorIds: vendorIds,
        quoteDueAt: quoteDueAt,
        notes: notes,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'requisitionId': requisitionId,
    'vendorIds': vendorIds,
    'quoteDueAt': quoteDueAt?.toIso8601String(),
    'notes': notes,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudioRequestForQuotation.fromJson(Object? value) {
    final map = _procurementMap(value, 'request for quotation');
    final vendorIds = map['vendorIds'];
    if (vendorIds is! List<dynamic> ||
        !vendorIds.every((vendorId) => vendorId is String)) {
      throw const FormatException(
        'The saved request for quotation has invalid vendors.',
      );
    }
    return StudioRequestForQuotation(
      id: _procurementString(map, 'id'),
      projectId: _procurementString(map, 'projectId'),
      requisitionId: _procurementString(map, 'requisitionId'),
      vendorIds: vendorIds.cast<String>(),
      quoteDueAt: _procurementDate(map, 'quoteDueAt', nullable: true),
      notes: _procurementString(map, 'notes'),
      status: _procurementString(map, 'status'),
      createdAt: _procurementDate(map, 'createdAt')!,
    );
  }
}

class StudioVendorQuoteLine {
  const StudioVendorQuoteLine({
    required this.requisitionLineId,
    required this.unitPriceMinor,
  });

  final String requisitionLineId;
  final int unitPriceMinor;

  Map<String, Object?> toJson() => {
    'requisitionLineId': requisitionLineId,
    'unitPriceMinor': unitPriceMinor,
  };

  factory StudioVendorQuoteLine.fromJson(Object? value) {
    final map = _procurementMap(value, 'vendor quote line');
    final unitPriceMinor = map['unitPriceMinor'];
    if (unitPriceMinor is! int) {
      throw const FormatException(
        'The saved vendor quote has an invalid unit price.',
      );
    }
    return StudioVendorQuoteLine(
      requisitionLineId: _procurementString(map, 'requisitionLineId'),
      unitPriceMinor: unitPriceMinor,
    );
  }
}

class StudioVendorQuote {
  const StudioVendorQuote({
    required this.id,
    required this.projectId,
    required this.rfqId,
    required this.vendorId,
    required this.currency,
    required this.items,
    required this.totalMinor,
    required this.validUntil,
    required this.deliveryDays,
    required this.terms,
    required this.status,
    required this.submittedAt,
  });

  static const statuses = ['Submitted', 'Selected', 'Not selected'];

  final String id;
  final String projectId;
  final String rfqId;
  final String vendorId;
  final String currency;
  final List<StudioVendorQuoteLine> items;
  final int totalMinor;
  final DateTime? validUntil;
  final int? deliveryDays;
  final String terms;
  final String status;
  final DateTime submittedAt;

  StudioVendorQuote copyWith({String? status}) => StudioVendorQuote(
    id: id,
    projectId: projectId,
    rfqId: rfqId,
    vendorId: vendorId,
    currency: currency,
    items: items,
    totalMinor: totalMinor,
    validUntil: validUntil,
    deliveryDays: deliveryDays,
    terms: terms,
    status: status ?? this.status,
    submittedAt: submittedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'rfqId': rfqId,
    'vendorId': vendorId,
    'currency': currency,
    'items': items.map((item) => item.toJson()).toList(),
    'totalMinor': totalMinor,
    'validUntil': validUntil?.toIso8601String(),
    'deliveryDays': deliveryDays,
    'terms': terms,
    'status': status,
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory StudioVendorQuote.fromJson(Object? value) {
    final map = _procurementMap(value, 'vendor quote');
    final totalMinor = map['totalMinor'];
    final deliveryDays = map['deliveryDays'];
    if (totalMinor is! int || deliveryDays != null && deliveryDays is! int) {
      throw const FormatException(
        'The saved vendor quote has invalid totals or delivery time.',
      );
    }
    return StudioVendorQuote(
      id: _procurementString(map, 'id'),
      projectId: _procurementString(map, 'projectId'),
      rfqId: _procurementString(map, 'rfqId'),
      vendorId: _procurementString(map, 'vendorId'),
      currency: _procurementString(map, 'currency'),
      items: _procurementList(map, 'items', StudioVendorQuoteLine.fromJson),
      totalMinor: totalMinor,
      validUntil: _procurementDate(map, 'validUntil', nullable: true),
      deliveryDays: deliveryDays as int?,
      terms: _procurementString(map, 'terms'),
      status: _procurementString(map, 'status'),
      submittedAt: _procurementDate(map, 'submittedAt')!,
    );
  }
}

class StudioPurchaseOrderLine {
  const StudioPurchaseOrderLine({
    required this.requisitionLineId,
    required this.description,
    required this.unit,
    required this.quantityMilli,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });

  final String requisitionLineId;
  final String description;
  final String unit;
  final int quantityMilli;
  final int unitPriceMinor;
  final int lineTotalMinor;

  Map<String, Object?> toJson() => {
    'requisitionLineId': requisitionLineId,
    'description': description,
    'unit': unit,
    'quantityMilli': quantityMilli,
    'unitPriceMinor': unitPriceMinor,
    'lineTotalMinor': lineTotalMinor,
  };

  factory StudioPurchaseOrderLine.fromJson(Object? value) {
    final map = _procurementMap(value, 'purchase order line');
    final quantityMilli = map['quantityMilli'];
    final unitPriceMinor = map['unitPriceMinor'];
    final lineTotalMinor = map['lineTotalMinor'];
    if (quantityMilli is! int ||
        unitPriceMinor is! int ||
        lineTotalMinor is! int) {
      throw const FormatException(
        'The saved purchase order has invalid line totals.',
      );
    }
    return StudioPurchaseOrderLine(
      requisitionLineId: _procurementString(map, 'requisitionLineId'),
      description: _procurementString(map, 'description'),
      unit: _procurementString(map, 'unit'),
      quantityMilli: quantityMilli,
      unitPriceMinor: unitPriceMinor,
      lineTotalMinor: lineTotalMinor,
    );
  }
}

class StudioPurchaseOrder {
  const StudioPurchaseOrder({
    required this.id,
    required this.projectId,
    required this.requisitionId,
    required this.rfqId,
    required this.quoteId,
    required this.vendorId,
    required this.currency,
    required this.items,
    required this.totalMinor,
    required this.notes,
    required this.status,
    required this.approvalSteps,
    required this.createdAt,
    required this.issuedAt,
  });

  static const statuses = [
    'Draft',
    'Pending approval',
    'Approved',
    'Rejected',
    'Issued',
    'Cancelled',
  ];

  final String id;
  final String projectId;
  final String requisitionId;
  final String rfqId;
  final String quoteId;
  final String vendorId;
  final String currency;
  final List<StudioPurchaseOrderLine> items;
  final int totalMinor;
  final String notes;
  final String status;
  final List<StudioProcurementApprovalStep> approvalSteps;
  final DateTime createdAt;
  final DateTime? issuedAt;

  StudioPurchaseOrder copyWith({
    String? status,
    List<StudioProcurementApprovalStep>? approvalSteps,
    DateTime? issuedAt,
  }) => StudioPurchaseOrder(
    id: id,
    projectId: projectId,
    requisitionId: requisitionId,
    rfqId: rfqId,
    quoteId: quoteId,
    vendorId: vendorId,
    currency: currency,
    items: items,
    totalMinor: totalMinor,
    notes: notes,
    status: status ?? this.status,
    approvalSteps: approvalSteps ?? this.approvalSteps,
    createdAt: createdAt,
    issuedAt: issuedAt ?? this.issuedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'requisitionId': requisitionId,
    'rfqId': rfqId,
    'quoteId': quoteId,
    'vendorId': vendorId,
    'currency': currency,
    'items': items.map((item) => item.toJson()).toList(),
    'totalMinor': totalMinor,
    'notes': notes,
    'status': status,
    'approvalSteps': approvalSteps.map((step) => step.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'issuedAt': issuedAt?.toIso8601String(),
  };

  factory StudioPurchaseOrder.fromJson(Object? value) {
    final map = _procurementMap(value, 'purchase order');
    final totalMinor = map['totalMinor'];
    if (totalMinor is! int) {
      throw const FormatException(
        'The saved purchase order has an invalid total.',
      );
    }
    return StudioPurchaseOrder(
      id: _procurementString(map, 'id'),
      projectId: _procurementString(map, 'projectId'),
      requisitionId: _procurementString(map, 'requisitionId'),
      rfqId: _procurementString(map, 'rfqId'),
      quoteId: _procurementString(map, 'quoteId'),
      vendorId: _procurementString(map, 'vendorId'),
      currency: _procurementString(map, 'currency'),
      items: _procurementList(map, 'items', StudioPurchaseOrderLine.fromJson),
      totalMinor: totalMinor,
      notes: _procurementString(map, 'notes'),
      status: _procurementString(map, 'status'),
      approvalSteps: _procurementList(
        map,
        'approvalSteps',
        StudioProcurementApprovalStep.fromJson,
      ),
      createdAt: _procurementDate(map, 'createdAt')!,
      issuedAt: _procurementDate(map, 'issuedAt', nullable: true),
    );
  }
}

Map<String, dynamic> _procurementMap(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('The saved $label is invalid.');
  }
  return value;
}

String _procurementString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('The saved procurement record is missing "$key".');
  }
  return value;
}

DateTime? _procurementDate(
  Map<String, dynamic> map,
  String key, {
  bool nullable = false,
}) {
  final value = map[key];
  if (value == null && nullable) return null;
  if (value is! String) {
    throw FormatException('The saved procurement record has invalid "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('The saved procurement record has invalid "$key".');
  }
  return date;
}

List<T> _procurementList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(Object?) parse,
) {
  final value = map[key];
  if (value is! List<dynamic>) {
    throw FormatException('The saved procurement record has invalid "$key".');
  }
  return value.map(parse).toList();
}
