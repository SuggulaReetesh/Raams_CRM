import 'dart:convert';

class StudioProject {
  const StudioProject({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.customerId,
    required this.targetDate,
  });

  static const statuses = ['Planning', 'In progress', 'On hold', 'Complete'];

  final String id;
  final String name;
  final String location;
  final String status;
  final String? customerId;
  final DateTime? targetDate;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'status': status,
        'customerId': customerId,
        'targetDate': targetDate?.toIso8601String(),
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
  });

  static const priorities = ['Low', 'Normal', 'High'];

  final String id;
  final String projectId;
  final String title;
  final String assignee;
  final DateTime? dueDate;
  final bool isComplete;
  final String priority;

  StudioTaskRecord copyWith({bool? isComplete}) => StudioTaskRecord(
        id: id,
        projectId: projectId,
        title: title,
        assignee: assignee,
        dueDate: dueDate,
        isComplete: isComplete ?? this.isComplete,
        priority: priority,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'assignee': assignee,
        'dueDate': dueDate?.toIso8601String(),
        'isComplete': isComplete,
        'priority': priority,
      };

  factory StudioTaskRecord.fromJson(Object? value) {
    final map = _readMap(value, 'task');
    final isComplete = map['isComplete'];
    if (isComplete is! bool) {
      throw const FormatException('A saved task has an invalid completion state.');
    }
    return StudioTaskRecord(
      id: _readString(map, 'id'),
      projectId: _readString(map, 'projectId'),
      title: _readString(map, 'title'),
      assignee: _readString(map, 'assignee'),
      dueDate: _readNullableDate(map, 'dueDate'),
      isComplete: isComplete,
      priority: _readString(map, 'priority'),
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
  });

  static const statuses = ['Not started', 'In progress', 'Complete'];

  final String id;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final String status;
  final String update;
  final DateTime updatedAt;

  StudioMilestone copyWith({
    String? status,
    String? update,
    DateTime? updatedAt,
  }) =>
      StudioMilestone(
        id: id,
        projectId: projectId,
        title: title,
        dueDate: dueDate,
        status: status ?? this.status,
        update: update ?? this.update,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'status': status,
        'update': update,
        'updatedAt': updatedAt.toIso8601String(),
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
  }) =>
      StudioProjectAsset(
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
        (byteLength != null &&
            (byteLength is! int || byteLength < 0)) ||
        (storagePath == null && (storedData == null || storedData.isEmpty))) {
      throw const FormatException('A saved project file has no valid data source.');
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
      throw const FormatException('A saved project file exceeds the local size limit.');
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

class StudioDeliveryWorkspace {
  const StudioDeliveryWorkspace({
    this.projects = const [],
    this.tasks = const [],
    this.milestones = const [],
    this.punchItems = const [],
    this.assets = const [],
    this.workLogs = const [],
    this.attendance = const [],
    this.approvals = const [],
  });

  final List<StudioProject> projects;
  final List<StudioTaskRecord> tasks;
  final List<StudioMilestone> milestones;
  final List<StudioPunchItem> punchItems;
  final List<StudioProjectAsset> assets;
  final List<StudioWorkLog> workLogs;
  final List<StudioAttendance> attendance;
  final List<StudioApproval> approvals;

  int get totalAssetBytes =>
      assets.fold(0, (total, asset) => total + asset.sizeBytes);

  StudioDeliveryWorkspace copyWith({
    List<StudioProject>? projects,
    List<StudioTaskRecord>? tasks,
    List<StudioMilestone>? milestones,
    List<StudioPunchItem>? punchItems,
    List<StudioProjectAsset>? assets,
    List<StudioWorkLog>? workLogs,
    List<StudioAttendance>? attendance,
    List<StudioApproval>? approvals,
  }) =>
      StudioDeliveryWorkspace(
        projects: projects ?? this.projects,
        tasks: tasks ?? this.tasks,
        milestones: milestones ?? this.milestones,
        punchItems: punchItems ?? this.punchItems,
        assets: assets ?? this.assets,
        workLogs: workLogs ?? this.workLogs,
        attendance: attendance ?? this.attendance,
        approvals: approvals ?? this.approvals,
      );

  Map<String, Object?> toJson() => {
        'projects': projects.map((item) => item.toJson()).toList(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'milestones': milestones.map((item) => item.toJson()).toList(),
        'punchItems': punchItems.map((item) => item.toJson()).toList(),
        'assets': assets.map((item) => item.toJson()).toList(),
        'workLogs': workLogs.map((item) => item.toJson()).toList(),
        'attendance': attendance.map((item) => item.toJson()).toList(),
        'approvals': approvals.map((item) => item.toJson()).toList(),
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
      projects.add(StudioProject(
        id: id,
        name: name,
        location: '',
        status: 'In progress',
        customerId: customer.id,
        targetDate: null,
      ));
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
      tasks: _readList(map, 'tasks', StudioTaskRecord.fromJson),
      milestones: _readList(map, 'milestones', StudioMilestone.fromJson),
      punchItems: _readList(map, 'punchItems', StudioPunchItem.fromJson),
      assets: _readList(map, 'assets', StudioProjectAsset.fromJson),
      workLogs: _readList(map, 'workLogs', StudioWorkLog.fromJson),
      attendance: _readList(map, 'attendance', StudioAttendance.fromJson),
      approvals: _readList(map, 'approvals', StudioApproval.fromJson),
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
