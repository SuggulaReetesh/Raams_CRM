import 'dart:convert';

import 'package:raams_crm/procurement.dart';
import 'package:raams_crm/site_execution.dart';
import 'package:raams_crm/workforce.dart';

class StudioProject {
  const StudioProject({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.customerId,
    required this.targetDate,
    this.budget,
    this.startDate,
  });

  static const statuses = ['Planning', 'In progress', 'On hold', 'Complete'];

  final String id;
  final String name;
  final String location;
  final String status;
  final String? customerId;
  final DateTime? targetDate;
  final double? budget;
  final DateTime? startDate;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'status': status,
    'customerId': customerId,
    'targetDate': targetDate?.toIso8601String(),
    'budget': budget,
    'startDate': startDate?.toIso8601String(),
  };

  factory StudioProject.fromJson(Object? value) {
    final map = _readMap(value, 'project');
    return StudioProject(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      location: _readString(map, 'location'),
      status: _readString(map, 'status'),
      customerId: _readNullableString(map, 'customerId'),
      targetDate: _readNullableDate(map, 'targetDate'),
      budget: _readNullableNumber(map, 'budget'),
      startDate: _readNullableDate(map, 'startDate'),
    );
  }
}

class StudioProjectPhase {
  const StudioProjectPhase({
    required this.id,
    required this.projectId,
    required this.name,
    required this.position,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  static const statuses = ['Not started', 'In progress', 'Complete'];

  final String id;
  final String projectId;
  final String name;
  final int position;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'position': position,
    'status': status,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory StudioProjectPhase.fromJson(Object? value) {
    final map = _readMap(value, 'project phase');
    final position = map['position'];
    if (position is! int) {
      throw const FormatException(
        'A saved project phase has an invalid order.',
      );
    }
    return StudioProjectPhase(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      name: _readString(map, 'name'),
      position: position,
      status: _readString(map, 'status'),
      startDate: _readNullableDate(map, 'startDate'),
      endDate: _readNullableDate(map, 'endDate'),
    );
  }
}

class StudioMaterial {
  const StudioMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.specification,
    required this.description,
    required this.isActive,
  });

  static const categories = [
    'Cement & concrete',
    'Steel',
    'Electrical',
    'Plumbing',
    'HVAC',
    'Finishes',
    'Fixtures',
    'Safety',
    'Other',
  ];
  static const units = ['each', 'm', 'm2', 'm3', 'kg', 'L', 'set', 'bag'];

  final String id;
  final String name;
  final String category;
  final String unit;
  final String specification;
  final String description;
  final bool isActive;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'unit': unit,
    'specification': specification,
    'description': description,
    'isActive': isActive,
  };

  factory StudioMaterial.fromJson(Object? value) {
    final map = _readMap(value, 'material');
    final isActive = map['isActive'];
    if (isActive is! bool) {
      throw const FormatException(
        'A saved material has an invalid active state.',
      );
    }
    return StudioMaterial(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      category: _readString(map, 'category'),
      unit: _readString(map, 'unit'),
      specification: _readString(map, 'specification'),
      description: _readString(map, 'description'),
      isActive: isActive,
    );
  }
}

class StudioVendorDocument {
  const StudioVendorDocument({
    required this.id,
    required this.name,
    required this.documentType,
    required this.reference,
    required this.expiresAt,
  });

  final String id;
  final String name;
  final String documentType;
  final String reference;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'documentType': documentType,
    'reference': reference,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory StudioVendorDocument.fromJson(Object? value) {
    final map = _readMap(value, 'vendor document');
    return StudioVendorDocument(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      documentType: _readString(map, 'documentType'),
      reference: _readString(map, 'reference'),
      expiresAt: _readNullableDate(map, 'expiresAt'),
    );
  }
}

class StudioVendor {
  const StudioVendor({
    required this.id,
    required this.name,
    required this.kind,
    required this.email,
    required this.phone,
    required this.address,
    required this.taxId,
    required this.paymentTerms,
    required this.notes,
    required this.isActive,
    this.documents = const [],
  });

  static const kinds = ['Supplier', 'Contractor'];

  final String id;
  final String name;
  final String kind;
  final String email;
  final String phone;
  final String address;
  final String taxId;
  final String paymentTerms;
  final String notes;
  final bool isActive;
  final List<StudioVendorDocument> documents;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'email': email,
    'phone': phone,
    'address': address,
    'taxId': taxId,
    'paymentTerms': paymentTerms,
    'notes': notes,
    'isActive': isActive,
    'documents': documents.map((document) => document.toJson()).toList(),
  };

  factory StudioVendor.fromJson(Object? value) {
    final map = _readMap(value, 'vendor');
    final isActive = map['isActive'];
    if (isActive is! bool) {
      throw const FormatException(
        'A saved vendor has an invalid active state.',
      );
    }
    return StudioVendor(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      kind: _readString(map, 'kind'),
      email: _readString(map, 'email'),
      phone: _readString(map, 'phone'),
      address: _readString(map, 'address'),
      taxId: _readString(map, 'taxId'),
      paymentTerms: _readString(map, 'paymentTerms'),
      notes: _readString(map, 'notes'),
      isActive: isActive,
      documents: _readOptionalList(
        map,
        'documents',
        StudioVendorDocument.fromJson,
      ),
    );
  }
}

class StudioTaskRecord {
  const StudioTaskRecord({
    required this.id,
    required this.projectId,
    required this.title,
    required this.assignee,
    required this.dueDate,
    required this.isComplete,
    required this.priority,
    this.dependsOnTaskIds = const [],
  });

  static const priorities = ['Low', 'Normal', 'High'];

  final String id;
  final String projectId;
  final String title;
  final String assignee;
  final DateTime? dueDate;
  final bool isComplete;
  final String priority;
  final List<String> dependsOnTaskIds;

  StudioTaskRecord copyWith({
    bool? isComplete,
    List<String>? dependsOnTaskIds,
  }) => StudioTaskRecord(
    id: id,
    projectId: projectId,
    title: title,
    assignee: assignee,
    dueDate: dueDate,
    isComplete: isComplete ?? this.isComplete,
    priority: priority,
    dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'assignee': assignee,
    'dueDate': dueDate?.toIso8601String(),
    'isComplete': isComplete,
    'priority': priority,
    'dependsOnTaskIds': dependsOnTaskIds,
  };

  factory StudioTaskRecord.fromJson(Object? value) {
    final map = _readMap(value, 'task');
    final isComplete = map['isComplete'];
    if (isComplete is! bool) {
      throw const FormatException(
        'A saved task has an invalid completion state.',
      );
    }
    return StudioTaskRecord(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      title: _readString(map, 'title'),
      assignee: _readString(map, 'assignee'),
      dueDate: _readNullableDate(map, 'dueDate'),
      isComplete: isComplete,
      priority: _readString(map, 'priority'),
      dependsOnTaskIds: _readOptionalStringList(map, 'dependsOnTaskIds'),
    );
  }
}

class StudioMilestone {
  const StudioMilestone({
    required this.id,
    required this.projectId,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.update,
    required this.updatedAt,
    this.phaseId,
  });

  static const statuses = ['Not started', 'In progress', 'Complete'];

  final String id;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final String status;
  final String update;
  final DateTime updatedAt;
  final String? phaseId;

  StudioMilestone copyWith({
    String? status,
    String? update,
    DateTime? updatedAt,
  }) => StudioMilestone(
    id: id,
    projectId: projectId,
    title: title,
    dueDate: dueDate,
    status: status ?? this.status,
    update: update ?? this.update,
    updatedAt: updatedAt ?? this.updatedAt,
    phaseId: phaseId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'dueDate': dueDate?.toIso8601String(),
    'status': status,
    'update': update,
    'updatedAt': updatedAt.toIso8601String(),
    'phaseId': phaseId,
  };

  factory StudioMilestone.fromJson(Object? value) {
    final map = _readMap(value, 'milestone');
    return StudioMilestone(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      title: _readString(map, 'title'),
      dueDate: _readNullableDate(map, 'dueDate'),
      status: _readString(map, 'status'),
      update: _readString(map, 'update'),
      updatedAt: _readDate(map, 'updatedAt'),
      phaseId: _readNullableString(map, 'phaseId'),
    );
  }
}

class StudioPunchItem {
  const StudioPunchItem({
    required this.id,
    required this.projectId,
    required this.description,
    required this.assignee,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  static const statuses = ['Open', 'In progress', 'Resolved'];

  final String id;
  final String projectId;
  final String description;
  final String assignee;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;

  StudioPunchItem copyWith({String? status}) => StudioPunchItem(
    id: id,
    projectId: projectId,
    description: description,
    assignee: assignee,
    dueDate: dueDate,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'description': description,
    'assignee': assignee,
    'dueDate': dueDate?.toIso8601String(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudioPunchItem.fromJson(Object? value) {
    final map = _readMap(value, 'punch-list item');
    return StudioPunchItem(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      description: _readString(map, 'description'),
      assignee: _readString(map, 'assignee'),
      dueDate: _readNullableDate(map, 'dueDate'),
      status: _readString(map, 'status'),
      createdAt: _readDate(map, 'createdAt'),
    );
  }
}

class StudioProjectAsset {
  const StudioProjectAsset({
    required this.id,
    required this.projectId,
    required this.name,
    required this.mimeType,
    required this.kind,
    required this.caption,
    required this.dataBase64,
    required this.addedBy,
    required this.addedAt,
    this.storagePath,
    this.byteLength,
  });

  static const maxFileBytes = 1024 * 1024;
  static const maxTotalBytes = 2 * 1024 * 1024;
  static const kinds = ['document', 'photo'];
  static const allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
    'text/plain',
    'text/csv',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  final String id;
  final String projectId;
  final String name;
  final String mimeType;
  final String kind;
  final String caption;
  final String dataBase64;
  final String? storagePath;
  final int? byteLength;
  final String addedBy;
  final DateTime addedAt;

  List<int> get bytes => base64Decode(dataBase64);
  int get sizeBytes => byteLength ?? bytes.length;

  StudioProjectAsset copyWith({
    String? dataBase64,
    String? storagePath,
    int? byteLength,
  }) => StudioProjectAsset(
    id: id,
    projectId: projectId,
    name: name,
    mimeType: mimeType,
    kind: kind,
    caption: caption,
    dataBase64: dataBase64 ?? this.dataBase64,
    addedBy: addedBy,
    addedAt: addedAt,
    storagePath: storagePath ?? this.storagePath,
    byteLength: byteLength ?? this.byteLength,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'mimeType': mimeType,
    'kind': kind,
    'caption': caption,
    'dataBase64': dataBase64,
    if (storagePath != null) 'storagePath': storagePath,
    if (byteLength != null) 'byteLength': byteLength,
    'addedBy': addedBy,
    'addedAt': addedAt.toIso8601String(),
  };

  factory StudioProjectAsset.fromJson(Object? value) {
    final map = _readMap(value, 'project file');
    final storedData = map['dataBase64'];
    final storagePath = _readNullableString(map, 'storagePath');
    final byteLength = map['byteLength'];
    if ((storedData != null && storedData is! String) ||
        (byteLength != null && (byteLength is! int || byteLength < 0)) ||
        (storagePath == null && (storedData == null || storedData.isEmpty))) {
      throw const FormatException(
        'A saved project file has no valid data source.',
      );
    }
    final asset = StudioProjectAsset(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      name: _readString(map, 'name'),
      mimeType: _readString(map, 'mimeType'),
      kind: _readString(map, 'kind'),
      caption: _readString(map, 'caption'),
      dataBase64: storedData as String? ?? '',
      addedBy: _readString(map, 'addedBy'),
      addedAt: _readDate(map, 'addedAt'),
      storagePath: storagePath,
      byteLength: byteLength as int?,
    );
    if (asset.sizeBytes > maxFileBytes) {
      throw const FormatException(
        'A saved project file exceeds the local size limit.',
      );
    }
    return asset;
  }
}

class StudioWorkLog {
  const StudioWorkLog({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.author,
    required this.minutes,
    required this.description,
    required this.loggedAt,
  });

  final String id;
  final String projectId;
  final String? taskId;
  final String author;
  final int minutes;
  final String description;
  final DateTime loggedAt;

  StudioWorkLog copyWith({String? projectId}) => StudioWorkLog(
    id: id,
    projectId: projectId ?? this.projectId,
    taskId: taskId,
    author: author,
    minutes: minutes,
    description: description,
    loggedAt: loggedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'taskId': taskId,
    'author': author,
    'minutes': minutes,
    'description': description,
    'loggedAt': loggedAt.toIso8601String(),
  };

  factory StudioWorkLog.fromJson(Object? value) {
    final map = _readMap(value, 'work log');
    final minutes = map['minutes'];
    if (minutes is! int) {
      throw const FormatException('A saved work log has an invalid duration.');
    }
    return StudioWorkLog(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      taskId: _readNullableString(map, 'taskId'),
      author: _readString(map, 'author'),
      minutes: minutes,
      description: _readString(map, 'description'),
      loggedAt: _readDate(map, 'loggedAt'),
    );
  }
}

class StudioAttendance {
  const StudioAttendance({
    required this.id,
    required this.personaId,
    required this.personaName,
    required this.date,
    required this.status,
    required this.note,
  });

  static const statuses = ['Present', 'Remote', 'Late', 'Away'];

  final String id;
  final String personaId;
  final String personaName;
  final DateTime date;
  final String status;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'personaId': personaId,
    'personaName': personaName,
    'date': date.toIso8601String(),
    'status': status,
    'note': note,
  };

  factory StudioAttendance.fromJson(Object? value) {
    final map = _readMap(value, 'attendance');
    return StudioAttendance(
      id: _readString(map, 'id'),
      personaId: _readString(map, 'personaId'),
      personaName: _readString(map, 'personaName'),
      date: _readDate(map, 'date'),
      status: _readString(map, 'status'),
      note: _readString(map, 'note'),
    );
  }
}

class StudioApproval {
  const StudioApproval({
    required this.id,
    required this.projectId,
    required this.title,
    required this.details,
    required this.requestedBy,
    required this.approverPersonaId,
    required this.approverName,
    this.relatedProposalId,
    required this.status,
    required this.decisionNote,
    required this.requestedAt,
    required this.decidedAt,
  });

  static const statuses = ['Pending', 'Approved', 'Rejected'];

  final String id;
  final String projectId;
  final String title;
  final String details;
  final String requestedBy;
  final String approverPersonaId;
  final String approverName;
  final String? relatedProposalId;
  final String status;
  final String decisionNote;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  StudioApproval decide({required String status, required String note}) =>
      StudioApproval(
        id: id,
        projectId: projectId,
        title: title,
        details: details,
        requestedBy: requestedBy,
        approverPersonaId: approverPersonaId,
        approverName: approverName,
        relatedProposalId: relatedProposalId,
        status: status,
        decisionNote: note,
        requestedAt: requestedAt,
        decidedAt: DateTime.now(),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'details': details,
    'requestedBy': requestedBy,
    'approverPersonaId': approverPersonaId,
    'approverName': approverName,
    'relatedProposalId': relatedProposalId,
    'status': status,
    'decisionNote': decisionNote,
    'requestedAt': requestedAt.toIso8601String(),
    'decidedAt': decidedAt?.toIso8601String(),
  };

  factory StudioApproval.fromJson(Object? value) {
    final map = _readMap(value, 'approval');
    return StudioApproval(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      title: _readString(map, 'title'),
      details: _readString(map, 'details'),
      requestedBy: _readString(map, 'requestedBy'),
      approverPersonaId: _readString(map, 'approverPersonaId'),
      approverName: _readString(map, 'approverName'),
      relatedProposalId: _readNullableString(map, 'relatedProposalId'),
      status: _readString(map, 'status'),
      decisionNote: _readString(map, 'decisionNote'),
      requestedAt: _readDate(map, 'requestedAt'),
      decidedAt: _readNullableDate(map, 'decidedAt'),
    );
  }
}

class StudioImportRecord {
  const StudioImportRecord({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.status,
    required this.importedCount,
    required this.failedCount,
    required this.errors,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String fileName;
  final String status;
  final int importedCount;
  final int failedCount;
  final List<String> errors;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'fileName': fileName,
    'status': status,
    'importedCount': importedCount,
    'failedCount': failedCount,
    'errors': errors,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudioImportRecord.fromJson(Object? value) {
    final map = _readMap(value, 'import record');
    final importedCount = map['importedCount'];
    final failedCount = map['failedCount'];
    final errors = map['errors'];
    if (importedCount is! int ||
        failedCount is! int ||
        errors is! List<dynamic> ||
        !errors.every((error) => error is String)) {
      throw const FormatException('A saved import record is invalid.');
    }
    return StudioImportRecord(
      id: _readString(map, 'id'),
      kind: _readString(map, 'kind'),
      fileName: _readString(map, 'fileName'),
      status: _readString(map, 'status'),
      importedCount: importedCount,
      failedCount: failedCount,
      errors: errors.cast<String>(),
      createdAt: _readDate(map, 'createdAt'),
    );
  }
}

class StudioReportSnapshot {
  const StudioReportSnapshot({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String kind;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String summary;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'projectId': projectId,
    'kind': kind,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudioReportSnapshot.fromJson(Object? value) {
    final map = _readMap(value, 'report snapshot');
    return StudioReportSnapshot(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      kind: _readString(map, 'kind'),
      periodStart: _readDate(map, 'periodStart'),
      periodEnd: _readDate(map, 'periodEnd'),
      summary: _readString(map, 'summary'),
      createdAt: _readDate(map, 'createdAt'),
    );
  }
}

class StudioDeliveryWorkspace {
  const StudioDeliveryWorkspace({
    this.projects = const [],
    this.phases = const [],
    this.tasks = const [],
    this.milestones = const [],
    this.materials = const [],
    this.vendors = const [],
    this.punchItems = const [],
    this.assets = const [],
    this.workLogs = const [],
    this.attendance = const [],
    this.approvals = const [],
    this.requisitions = const [],
    this.rfqs = const [],
    this.vendorQuotes = const [],
    this.purchaseOrders = const [],
    this.stockBalances = const [],
    this.goodsReceipts = const [],
    this.stockMovements = const [],
    this.workOrders = const [],
    this.dailyReports = const [],
    this.siteInspections = const [],
    this.workers = const [],
    this.workforceAllocations = const [],
    this.siteAttendance = const [],
    this.importRecords = const [],
    this.reportSnapshots = const [],
  });

  final List<StudioProject> projects;
  final List<StudioProjectPhase> phases;
  final List<StudioTaskRecord> tasks;
  final List<StudioMilestone> milestones;
  final List<StudioMaterial> materials;
  final List<StudioVendor> vendors;
  final List<StudioPunchItem> punchItems;
  final List<StudioProjectAsset> assets;
  final List<StudioWorkLog> workLogs;
  final List<StudioAttendance> attendance;
  final List<StudioApproval> approvals;
  final List<StudioMaterialRequisition> requisitions;
  final List<StudioRequestForQuotation> rfqs;
  final List<StudioVendorQuote> vendorQuotes;
  final List<StudioPurchaseOrder> purchaseOrders;
  final List<StudioStockBalance> stockBalances;
  final List<StudioGoodsReceipt> goodsReceipts;
  final List<StudioStockMovement> stockMovements;
  final List<StudioWorkOrder> workOrders;
  final List<StudioDailyReport> dailyReports;
  final List<StudioSiteInspection> siteInspections;
  final List<StudioWorker> workers;
  final List<StudioWorkforceAllocation> workforceAllocations;
  final List<StudioSiteAttendance> siteAttendance;
  final List<StudioImportRecord> importRecords;
  final List<StudioReportSnapshot> reportSnapshots;

  int get totalAssetBytes =>
      assets.fold(0, (total, asset) => total + asset.sizeBytes);

  StudioDeliveryWorkspace copyWith({
    List<StudioProject>? projects,
    List<StudioProjectPhase>? phases,
    List<StudioTaskRecord>? tasks,
    List<StudioMilestone>? milestones,
    List<StudioMaterial>? materials,
    List<StudioVendor>? vendors,
    List<StudioPunchItem>? punchItems,
    List<StudioProjectAsset>? assets,
    List<StudioWorkLog>? workLogs,
    List<StudioAttendance>? attendance,
    List<StudioApproval>? approvals,
    List<StudioMaterialRequisition>? requisitions,
    List<StudioRequestForQuotation>? rfqs,
    List<StudioVendorQuote>? vendorQuotes,
    List<StudioPurchaseOrder>? purchaseOrders,
    List<StudioStockBalance>? stockBalances,
    List<StudioGoodsReceipt>? goodsReceipts,
    List<StudioStockMovement>? stockMovements,
    List<StudioWorkOrder>? workOrders,
    List<StudioDailyReport>? dailyReports,
    List<StudioSiteInspection>? siteInspections,
    List<StudioWorker>? workers,
    List<StudioWorkforceAllocation>? workforceAllocations,
    List<StudioSiteAttendance>? siteAttendance,
    List<StudioImportRecord>? importRecords,
    List<StudioReportSnapshot>? reportSnapshots,
  }) => StudioDeliveryWorkspace(
    projects: projects ?? this.projects,
    phases: phases ?? this.phases,
    tasks: tasks ?? this.tasks,
    milestones: milestones ?? this.milestones,
    materials: materials ?? this.materials,
    vendors: vendors ?? this.vendors,
    punchItems: punchItems ?? this.punchItems,
    assets: assets ?? this.assets,
    workLogs: workLogs ?? this.workLogs,
    attendance: attendance ?? this.attendance,
    approvals: approvals ?? this.approvals,
    requisitions: requisitions ?? this.requisitions,
    rfqs: rfqs ?? this.rfqs,
    vendorQuotes: vendorQuotes ?? this.vendorQuotes,
    purchaseOrders: purchaseOrders ?? this.purchaseOrders,
    stockBalances: stockBalances ?? this.stockBalances,
    goodsReceipts: goodsReceipts ?? this.goodsReceipts,
    stockMovements: stockMovements ?? this.stockMovements,
    workOrders: workOrders ?? this.workOrders,
    dailyReports: dailyReports ?? this.dailyReports,
    siteInspections: siteInspections ?? this.siteInspections,
    workers: workers ?? this.workers,
    workforceAllocations: workforceAllocations ?? this.workforceAllocations,
    siteAttendance: siteAttendance ?? this.siteAttendance,
    importRecords: importRecords ?? this.importRecords,
    reportSnapshots: reportSnapshots ?? this.reportSnapshots,
  );

  Map<String, Object?> toJson() => {
    'projects': projects.map((item) => item.toJson()).toList(),
    'phases': phases.map((item) => item.toJson()).toList(),
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'milestones': milestones.map((item) => item.toJson()).toList(),
    'materials': materials.map((item) => item.toJson()).toList(),
    'vendors': vendors.map((item) => item.toJson()).toList(),
    'punchItems': punchItems.map((item) => item.toJson()).toList(),
    'assets': assets.map((item) => item.toJson()).toList(),
    'workLogs': workLogs.map((item) => item.toJson()).toList(),
    'attendance': attendance.map((item) => item.toJson()).toList(),
    'approvals': approvals.map((item) => item.toJson()).toList(),
    'requisitions': requisitions.map((item) => item.toJson()).toList(),
    'rfqs': rfqs.map((item) => item.toJson()).toList(),
    'vendorQuotes': vendorQuotes.map((item) => item.toJson()).toList(),
    'purchaseOrders': purchaseOrders.map((item) => item.toJson()).toList(),
    'stockBalances': stockBalances.map((item) => item.toJson()).toList(),
    'goodsReceipts': goodsReceipts.map((item) => item.toJson()).toList(),
    'stockMovements': stockMovements.map((item) => item.toJson()).toList(),
    'workOrders': workOrders.map((item) => item.toJson()).toList(),
    'dailyReports': dailyReports.map((item) => item.toJson()).toList(),
    'siteInspections': siteInspections.map((item) => item.toJson()).toList(),
    'workers': workers.map((item) => item.toJson()).toList(),
    'workforceAllocations': workforceAllocations
        .map((item) => item.toJson())
        .toList(),
    'siteAttendance': siteAttendance.map((item) => item.toJson()).toList(),
    'importRecords': importRecords.map((item) => item.toJson()).toList(),
    'reportSnapshots': reportSnapshots.map((item) => item.toJson()).toList(),
  };

  factory StudioDeliveryWorkspace.forCustomers(
    Iterable<({String id, String project})> customers,
  ) {
    final projects = <StudioProject>[];
    final projectIdsByName = <String, String>{};
    for (final customer in customers) {
      final name = customer.project;
      if (name.trim().isEmpty || projectIdsByName.containsKey(name)) continue;
      final id = 'project-${customer.id}';
      projectIdsByName[name] = id;
      projects.add(
        StudioProject(
          id: id,
          name: name,
          location: '',
          status: 'In progress',
          customerId: customer.id,
          targetDate: null,
        ),
      );
    }
    final now = DateTime.now();
    final tasks = <StudioTaskRecord>[
      for (var index = 0; index < projects.length && index < 4; index++)
        StudioTaskRecord(
          id: 'demo-task-$index',
          projectId: projects[index].id,
          title: [
            'Review design selections',
            'Prepare concept presentation',
            'Confirm supplier lead times',
            'Schedule the next client review',
          ][index],
          assignee: 'Studio owner',
          dueDate: DateTime(now.year, now.month, now.day + index + 1),
          isComplete: index == 2,
          priority: index == 0 ? 'High' : 'Normal',
        ),
    ];
    return StudioDeliveryWorkspace(projects: projects, tasks: tasks);
  }

  factory StudioDeliveryWorkspace.fromJson(Object? value) {
    final map = _readMap(value, 'delivery workspace');
    return StudioDeliveryWorkspace(
      projects: _readList(map, 'projects', StudioProject.fromJson),
      phases: _readOptionalList(map, 'phases', StudioProjectPhase.fromJson),
      tasks: _readList(map, 'tasks', StudioTaskRecord.fromJson),
      milestones: _readList(map, 'milestones', StudioMilestone.fromJson),
      materials: _readOptionalList(map, 'materials', StudioMaterial.fromJson),
      vendors: _readOptionalList(map, 'vendors', StudioVendor.fromJson),
      punchItems: _readList(map, 'punchItems', StudioPunchItem.fromJson),
      assets: _readList(map, 'assets', StudioProjectAsset.fromJson),
      workLogs: _readList(map, 'workLogs', StudioWorkLog.fromJson),
      attendance: _readList(map, 'attendance', StudioAttendance.fromJson),
      approvals: _readList(map, 'approvals', StudioApproval.fromJson),
      requisitions: _readOptionalList(
        map,
        'requisitions',
        StudioMaterialRequisition.fromJson,
      ),
      rfqs: _readOptionalList(map, 'rfqs', StudioRequestForQuotation.fromJson),
      vendorQuotes: _readOptionalList(
        map,
        'vendorQuotes',
        StudioVendorQuote.fromJson,
      ),
      purchaseOrders: _readOptionalList(
        map,
        'purchaseOrders',
        StudioPurchaseOrder.fromJson,
      ),
      stockBalances: _readOptionalList(
        map,
        'stockBalances',
        StudioStockBalance.fromJson,
      ),
      goodsReceipts: _readOptionalList(
        map,
        'goodsReceipts',
        StudioGoodsReceipt.fromJson,
      ),
      stockMovements: _readOptionalList(
        map,
        'stockMovements',
        StudioStockMovement.fromJson,
      ),
      workOrders: _readOptionalList(
        map,
        'workOrders',
        StudioWorkOrder.fromJson,
      ),
      dailyReports: _readOptionalList(
        map,
        'dailyReports',
        StudioDailyReport.fromJson,
      ),
      siteInspections: _readOptionalList(
        map,
        'siteInspections',
        StudioSiteInspection.fromJson,
      ),
      workers: _readOptionalList(map, 'workers', StudioWorker.fromJson),
      workforceAllocations: _readOptionalList(
        map,
        'workforceAllocations',
        StudioWorkforceAllocation.fromJson,
      ),
      siteAttendance: _readOptionalList(
        map,
        'siteAttendance',
        StudioSiteAttendance.fromJson,
      ),
      importRecords: _readOptionalList(
        map,
        'importRecords',
        StudioImportRecord.fromJson,
      ),
      reportSnapshots: _readOptionalList(
        map,
        'reportSnapshots',
        StudioReportSnapshot.fromJson,
      ),
    );
  }
}

Map<String, dynamic> _readMap(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Saved $label data is invalid.');
  }
  return value;
}

String _readString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved record is missing "$key".');
  }
  return value;
}

String? _readNullableString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('A saved record has an invalid "$key".');
  }
  return value;
}

double? _readNullableNumber(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0 || value > 1000000000000) {
    throw FormatException('A saved record has an invalid "$key".');
  }
  return value.toDouble();
}

List<String> _readOptionalStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List<dynamic> || !value.every((item) => item is String)) {
    throw FormatException('Saved "$key" data is invalid.');
  }
  return value.cast<String>();
}

DateTime _readDate(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved record is missing "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('A saved record has an invalid "$key".');
  }
  return date;
}

DateTime? _readNullableDate(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('A saved record has an invalid "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('A saved record has an invalid "$key".');
  }
  return date;
}

List<T> _readList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(Object?) decode,
) {
  final value = map[key];
  if (value is! List<dynamic>) {
    throw FormatException('Saved "$key" data is not a list.');
  }
  return value.map(decode).toList();
}

List<T> _readOptionalList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(Object?) decode,
) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List<dynamic>) {
    throw FormatException('Saved "$key" data is not a list.');
  }
  return value.map(decode).toList();
}
