import 'dart:convert';

import 'package:raams_crm/communication.dart';
import 'package:raams_crm/delivery.dart';
import 'package:raams_crm/finance.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.project,
    required this.stage,
    required this.value,
    required this.email,
    required this.phone,
    required this.notes,
    required this.initials,
    required this.tint,
    this.requirement,
  });

  final String id;
  final String name;
  final String project;
  final String stage;
  final String value;
  final String email;
  final String phone;
  final String notes;
  final String initials;
  final Color tint;
  final ProjectRequirement? requirement;

  Customer copyWith({String? stage, ProjectRequirement? requirement}) =>
      Customer(
        id: id,
        name: name,
        project: project,
        stage: stage ?? this.stage,
        value: value,
        email: email,
        phone: phone,
        notes: notes,
        initials: initials,
        tint: tint,
        requirement: requirement ?? this.requirement,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'project': project,
    'stage': stage,
    'value': value,
    'email': email,
    'phone': phone,
    'notes': notes,
    'initials': initials,
    'tint': tint.toARGB32(),
    'requirement': requirement?.toJson(),
  };

  factory Customer.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved customer record is invalid.');
    }

    String readString(String key) {
      final field = value[key];
      if (field is! String) {
        throw FormatException('A saved customer is missing "$key".');
      }
      return field;
    }

    final tint = value['tint'];
    if (tint is! int) {
      throw const FormatException('A saved customer has an invalid color.');
    }
    final requirementJson = value['requirement'];

    return Customer(
      id: readString('id'),
      name: readString('name'),
      project: readString('project'),
      stage: readString('stage'),
      value: readString('value'),
      email: readString('email'),
      phone: readString('phone'),
      notes: readString('notes'),
      initials: readString('initials'),
      tint: Color(tint),
      requirement: requirementJson == null
          ? null
          : ProjectRequirement.fromJson(requirementJson),
    );
  }
}

class ProjectRequirement {
  const ProjectRequirement({
    required this.rooms,
    required this.style,
    required this.budgetMin,
    required this.budgetMax,
    required this.startDate,
    required this.targetDate,
    required this.brief,
  });

  final List<String> rooms;
  final String style;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startDate;
  final DateTime? targetDate;
  final String brief;

  Map<String, Object?> toJson() => {
    'rooms': rooms,
    'style': style,
    'budgetMin': budgetMin,
    'budgetMax': budgetMax,
    'startDate': startDate?.toIso8601String(),
    'targetDate': targetDate?.toIso8601String(),
    'brief': brief,
  };

  factory ProjectRequirement.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved project brief is invalid.');
    }

    final roomsJson = value['rooms'];
    if (roomsJson is! List<dynamic> ||
        roomsJson.isEmpty ||
        !roomsJson.every((room) => room is String)) {
      throw const FormatException('Saved project rooms are invalid.');
    }

    String readString(String key) {
      final field = value[key];
      if (field is! String) {
        throw FormatException('A saved project brief is missing "$key".');
      }
      return field;
    }

    double? readAmount(String key) {
      final field = value[key];
      if (field == null) return null;
      if (field is! num || !field.toDouble().isFinite || field < 0) {
        throw FormatException('A saved project budget "$key" is invalid.');
      }
      return field.toDouble();
    }

    DateTime? readDate(String key) {
      final field = value[key];
      if (field == null) return null;
      if (field is! String) {
        throw FormatException('A saved project date "$key" is invalid.');
      }
      final date = DateTime.tryParse(field);
      if (date == null) {
        throw FormatException('A saved project date "$key" is invalid.');
      }
      return date;
    }

    final budgetMin = readAmount('budgetMin');
    final budgetMax = readAmount('budgetMax');
    final startDate = readDate('startDate');
    final targetDate = readDate('targetDate');
    if (budgetMin != null && budgetMax != null && budgetMin > budgetMax) {
      throw const FormatException('The saved project budget range is invalid.');
    }
    if (startDate != null &&
        targetDate != null &&
        targetDate.isBefore(startDate)) {
      throw const FormatException('The saved project timeline is invalid.');
    }

    final style = readString('style');
    if (style.trim().isEmpty) {
      throw const FormatException('A saved project brief has no design style.');
    }

    return ProjectRequirement(
      rooms: roomsJson.cast<String>(),
      style: style,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      startDate: startDate,
      targetDate: targetDate,
      brief: readString('brief'),
    );
  }
}

class StudioActivity {
  const StudioActivity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.kind,
    required this.title,
    required this.details,
    required this.actor,
    required this.occurredAt,
  });

  final String id;
  final String? customerId;
  final String customerName;
  final String kind;
  final String title;
  final String details;
  final String actor;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'customerId': customerId,
    'customerName': customerName,
    'kind': kind,
    'title': title,
    'details': details,
    'actor': actor,
    'occurredAt': occurredAt.toIso8601String(),
  };

  factory StudioActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved activity record is invalid.');
    }

    String readString(String key) {
      final field = value[key];
      if (field is! String) {
        throw FormatException('A saved activity is missing "$key".');
      }
      return field;
    }

    final customerId = value['customerId'];
    if (customerId != null && customerId is! String) {
      throw const FormatException('A saved activity has an invalid client ID.');
    }
    final occurredAtText = readString('occurredAt');
    final occurredAt = DateTime.tryParse(occurredAtText);
    if (occurredAt == null) {
      throw const FormatException('A saved activity has an invalid date.');
    }
    final savedCustomerId = customerId is String ? customerId : null;
    return StudioActivity(
      id: readString('id'),
      customerId: savedCustomerId,
      customerName: readString('customerName'),
      kind: readString('kind'),
      title: readString('title'),
      details: readString('details'),
      actor: readString('actor'),
      occurredAt: occurredAt,
    );
  }
}

class StudioPersona {
  const StudioPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
  });

  static const viewClients = 'viewClients';
  static const manageClients = 'manageClients';
  static const managePipeline = 'managePipeline';
  static const manageRequirements = 'manageRequirements';
  static const viewFinancials = 'viewFinancials';
  static const configureWorkspace = 'configureWorkspace';
  static const viewProjects = 'viewProjects';
  static const manageProjects = 'manageProjects';
  static const manageTasks = 'manageTasks';
  static const manageFiles = 'manageFiles';
  static const viewFiles = 'viewFiles';
  static const manageMilestones = 'manageMilestones';
  static const managePunchList = 'managePunchList';
  static const viewWorkLogs = 'viewWorkLogs';
  static const manageWorkLogs = 'manageWorkLogs';
  static const manageAttendance = 'manageAttendance';
  static const manageApprovals = 'manageApprovals';
  static const approveApprovals = 'approveApprovals';
  static const manageFinancials = 'manageFinancials';
  static const viewCommunications = 'viewCommunications';
  static const manageCommunications = 'manageCommunications';

  static const deliveryPermissionKeys = {
    viewProjects,
    manageProjects,
    manageTasks,
    manageFiles,
    viewFiles,
    manageMilestones,
    managePunchList,
    viewWorkLogs,
    manageWorkLogs,
    manageAttendance,
    manageApprovals,
    approveApprovals,
  };

  static const financePermissionKeys = {manageFinancials};
  static const communicationPermissionKeys = {
    viewCommunications,
    manageCommunications,
  };

  static const permissionKeys = {
    viewClients,
    manageClients,
    managePipeline,
    manageRequirements,
    viewFinancials,
    configureWorkspace,
    viewProjects,
    manageProjects,
    manageTasks,
    manageFiles,
    viewFiles,
    manageMilestones,
    managePunchList,
    viewWorkLogs,
    manageWorkLogs,
    manageAttendance,
    manageApprovals,
    approveApprovals,
    manageFinancials,
    viewCommunications,
    manageCommunications,
  };

  static const clientManagementPermissions = {
    manageClients,
    managePipeline,
    manageRequirements,
  };

  static List<StudioPersona> defaults() => const [
    StudioPersona(
      id: 'owner',
      name: 'Studio owner',
      description: 'Full studio and workspace access.',
      permissions: [
        viewClients,
        manageClients,
        managePipeline,
        manageRequirements,
        viewFinancials,
        configureWorkspace,
        viewProjects,
        manageProjects,
        manageTasks,
        manageFiles,
        viewFiles,
        manageMilestones,
        managePunchList,
        viewWorkLogs,
        manageWorkLogs,
        manageAttendance,
        manageApprovals,
        approveApprovals,
        manageFinancials,
        viewCommunications,
        manageCommunications,
      ],
    ),
    StudioPersona(
      id: 'designer',
      name: 'Designer',
      description: 'Client and project brief access without budgets.',
      permissions: [
        viewClients,
        viewCommunications,
        manageCommunications,
        manageClients,
        manageRequirements,
        viewProjects,
        manageProjects,
        manageTasks,
        manageFiles,
        viewFiles,
        manageMilestones,
        managePunchList,
        viewWorkLogs,
        manageWorkLogs,
      ],
    ),
    StudioPersona(
      id: 'project-manager',
      name: 'Project manager',
      description: 'Manage client records, pipeline, and project briefs.',
      permissions: [
        viewClients,
        viewCommunications,
        manageCommunications,
        manageClients,
        managePipeline,
        manageRequirements,
        viewProjects,
        manageProjects,
        manageTasks,
        manageFiles,
        viewFiles,
        manageMilestones,
        managePunchList,
        viewWorkLogs,
        manageWorkLogs,
        manageAttendance,
        manageApprovals,
        approveApprovals,
      ],
    ),
    StudioPersona(
      id: 'finance',
      name: 'Finance',
      description: 'View client and financial information.',
      permissions: [
        viewClients,
        viewFinancials,
        viewProjects,
        viewFiles,
        viewWorkLogs,
        manageApprovals,
        approveApprovals,
        manageFinancials,
        viewCommunications,
      ],
    ),
    StudioPersona(
      id: 'read-only',
      name: 'Read only',
      description: 'View client records without editing.',
      permissions: [
        viewClients,
        viewCommunications,
        viewProjects,
        viewFiles,
        viewWorkLogs,
      ],
    ),
  ];

  final String id;
  final String name;
  final String description;
  final List<String> permissions;

  bool allows(String permission) => permissions.contains(permission);

  StudioPersona copyWith({
    String? name,
    String? description,
    List<String>? permissions,
  }) => StudioPersona(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    permissions: permissions ?? this.permissions,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'permissions': permissions,
  };

  factory StudioPersona.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved studio role is invalid.');
    }
    final id = value['id'];
    final name = value['name'];
    final description = value['description'];
    final permissions = value['permissions'];
    if (id is! String ||
        name is! String ||
        description is! String ||
        permissions is! List<dynamic> ||
        !permissions.every((permission) => permission is String)) {
      throw const FormatException('A saved studio role is incomplete.');
    }
    return StudioPersona(
      id: id,
      name: name,
      description: description,
      permissions: permissions.cast<String>(),
    );
  }
}

class WorkspacePreferences {
  const WorkspacePreferences({
    required this.studioName,
    required this.defaultPipelineStage,
    required this.activePersonaId,
  });

  factory WorkspacePreferences.defaults({
    required String defaultPipelineStage,
  }) => WorkspacePreferences(
    studioName: 'Sravya Studio',
    defaultPipelineStage: defaultPipelineStage,
    activePersonaId: 'owner',
  );

  final String studioName;
  final String defaultPipelineStage;
  final String activePersonaId;

  WorkspacePreferences copyWith({
    String? studioName,
    String? defaultPipelineStage,
    String? activePersonaId,
  }) => WorkspacePreferences(
    studioName: studioName ?? this.studioName,
    defaultPipelineStage: defaultPipelineStage ?? this.defaultPipelineStage,
    activePersonaId: activePersonaId ?? this.activePersonaId,
  );

  Map<String, Object?> toJson() => {
    'studioName': studioName,
    'defaultPipelineStage': defaultPipelineStage,
    'activePersonaId': activePersonaId,
  };

  factory WorkspacePreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Saved workspace preferences are invalid.');
    }
    final studioName = value['studioName'];
    final defaultPipelineStage = value['defaultPipelineStage'];
    final activePersonaId = value['activePersonaId'];
    if (studioName is! String ||
        defaultPipelineStage is! String ||
        activePersonaId is! String) {
      throw const FormatException(
        'Saved workspace preferences are incomplete.',
      );
    }
    return WorkspacePreferences(
      studioName: studioName,
      defaultPipelineStage: defaultPipelineStage,
      activePersonaId: activePersonaId,
    );
  }
}

class CustomerWorkspace {
  const CustomerWorkspace({
    required this.customers,
    required this.pipelineStages,
    required this.activities,
    required this.personas,
    required this.preferences,
    required this.delivery,
    required this.financials,
    required this.communications,
  });

  final List<Customer> customers;
  final List<String> pipelineStages;
  final List<StudioActivity> activities;
  final List<StudioPersona> personas;
  final WorkspacePreferences preferences;
  final StudioDeliveryWorkspace delivery;
  final StudioFinancialWorkspace financials;
  final List<StudioCommunication> communications;
}

abstract interface class CustomerWorkspaceRepository {
  Future<CustomerWorkspace> loadWorkspace({
    required List<Customer> initialCustomers,
    required List<String> initialStages,
  });

  Future<void> saveWorkspace({
    required List<Customer> customers,
    required List<String> pipelineStages,
    required List<StudioActivity> activities,
    required List<StudioPersona> personas,
    required WorkspacePreferences preferences,
    required StudioDeliveryWorkspace delivery,
    required StudioFinancialWorkspace financials,
    required List<StudioCommunication> communications,
  });
}

class SharedPreferencesCustomerWorkspaceRepository
    implements CustomerWorkspaceRepository {
  const SharedPreferencesCustomerWorkspaceRepository();

  static const _workspaceKey = 'atelier.workspace.v1';
  static const _legacyCustomersKey = 'atelier.customers.v1';
  static const _legacyStagesKey = 'atelier.pipeline.stages.v1';

  Future<bool> hasSavedWorkspaceData() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey(_workspaceKey) ||
        preferences.containsKey(_legacyCustomersKey) ||
        preferences.containsKey(_legacyStagesKey);
  }

  @override
  Future<CustomerWorkspace> loadWorkspace({
    required List<Customer> initialCustomers,
    required List<String> initialStages,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final workspaceJson = preferences.getString(_workspaceKey);
    if (workspaceJson == null) {
      final customersJson = preferences.getString(_legacyCustomersKey);
      final customers = customersJson == null
          ? List<Customer>.of(initialCustomers)
          : _decodeCustomers(jsonDecode(customersJson));
      final stages =
          preferences.getStringList(_legacyStagesKey) ?? initialStages;
      final activities = <StudioActivity>[];
      final personas = StudioPersona.defaults();
      final workspacePreferences = WorkspacePreferences.defaults(
        defaultPipelineStage: stages.isEmpty ? '' : stages.first,
      );
      final delivery = StudioDeliveryWorkspace.forCustomers(
        customers.map(
          (customer) => (id: customer.id, project: customer.project),
        ),
      );
      final financials = StudioFinancialWorkspace.defaults();
      const communications = <StudioCommunication>[];
      _validateWorkspace(
        customers,
        stages,
        activities: activities,
        personas: personas,
        preferences: workspacePreferences,
        delivery: delivery,
        financials: financials,
        communications: communications,
      );
      return CustomerWorkspace(
        customers: customers,
        pipelineStages: stages,
        activities: activities,
        personas: personas,
        preferences: workspacePreferences,
        delivery: delivery,
        financials: financials,
        communications: communications,
      );
    }

    return decodeWorkspaceData(
      jsonDecode(workspaceJson),
      initialCustomers: initialCustomers,
      initialStages: initialStages,
    );
  }

  CustomerWorkspace decodeWorkspaceData(
    Object? decoded, {
    required List<Customer> initialCustomers,
    required List<String> initialStages,
  }) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved workspace data is invalid.');
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != null && schemaVersion is! int) {
      throw const FormatException('Saved workspace version is invalid.');
    }
    final customers = _decodeCustomers(decoded['customers']);
    final stages = decoded['pipelineStages'];
    if (stages is! List<dynamic> || !stages.every((stage) => stage is String)) {
      throw const FormatException('Saved pipeline stages are invalid.');
    }
    final pipelineStages = stages.cast<String>();
    final activitiesJson = decoded['activities'];
    final activities = activitiesJson == null
        ? <StudioActivity>[]
        : _decodeActivities(activitiesJson);
    final personasJson = decoded['personas'];
    final decodedPersonas = personasJson == null
        ? StudioPersona.defaults()
        : _decodePersonas(personasJson);
    var personas = schemaVersion == null || schemaVersion < 2
        ? _migrateDeliveryPermissions(decodedPersonas)
        : decodedPersonas;
    if (schemaVersion == null || schemaVersion < 3) {
      personas = _migrateFinancialPermissions(personas);
    }
    if (schemaVersion == null || schemaVersion < 4) {
      personas = _migrateCommunicationPermissions(personas);
    }
    final preferencesJson = decoded['preferences'];
    final workspacePreferences = preferencesJson == null
        ? WorkspacePreferences.defaults(
            defaultPipelineStage: pipelineStages.isEmpty
                ? ''
                : pipelineStages.first,
          )
        : WorkspacePreferences.fromJson(preferencesJson);
    final deliveryJson = decoded['delivery'];
    final delivery = deliveryJson == null
        ? StudioDeliveryWorkspace.forCustomers(
            customers.map(
              (customer) => (id: customer.id, project: customer.project),
            ),
          )
        : StudioDeliveryWorkspace.fromJson(deliveryJson);
    final financialsJson = decoded['financials'];
    final financials = financialsJson == null
        ? StudioFinancialWorkspace.defaults()
        : StudioFinancialWorkspace.fromJson(financialsJson);
    final communicationsJson = decoded['communications'];
    final savedCommunications = communicationsJson == null
        ? <StudioCommunication>[]
        : _decodeCommunications(communicationsJson);
    final communications = schemaVersion == null || schemaVersion < 4
        ? [
            ..._migrateLegacyInteractions(
              activities,
              customers,
              personas,
              workspacePreferences.activePersonaId,
            ),
            ...savedCommunications,
          ]
        : savedCommunications;
    _validateWorkspace(
      customers,
      pipelineStages,
      activities: activities,
      personas: personas,
      preferences: workspacePreferences,
      delivery: delivery,
      financials: financials,
      communications: communications,
    );
    return CustomerWorkspace(
      customers: customers,
      pipelineStages: pipelineStages,
      activities: activities,
      personas: personas,
      preferences: workspacePreferences,
      delivery: delivery,
      financials: financials,
      communications: communications,
    );
  }

  @override
  Future<void> saveWorkspace({
    required List<Customer> customers,
    required List<String> pipelineStages,
    required List<StudioActivity> activities,
    required List<StudioPersona> personas,
    required WorkspacePreferences preferences,
    required StudioDeliveryWorkspace delivery,
    required StudioFinancialWorkspace financials,
    required List<StudioCommunication> communications,
  }) async {
    _validateWorkspace(
      customers,
      pipelineStages,
      activities: activities,
      personas: personas,
      preferences: preferences,
      delivery: delivery,
      financials: financials,
      communications: communications,
    );
    final storage = await SharedPreferences.getInstance();
    final saved = await storage.setString(
      _workspaceKey,
      jsonEncode(
        encodeWorkspaceData(
          customers: customers,
          pipelineStages: pipelineStages,
          activities: activities,
          personas: personas,
          preferences: preferences,
          delivery: delivery,
          financials: financials,
          communications: communications,
        ),
      ),
    );
    if (!saved) {
      throw Exception(
        'The studio workspace could not be saved on this device.',
      );
    }
  }

  Map<String, Object?> encodeWorkspaceData({
    required List<Customer> customers,
    required List<String> pipelineStages,
    required List<StudioActivity> activities,
    required List<StudioPersona> personas,
    required WorkspacePreferences preferences,
    required StudioDeliveryWorkspace delivery,
    required StudioFinancialWorkspace financials,
    required List<StudioCommunication> communications,
  }) {
    _validateWorkspace(
      customers,
      pipelineStages,
      activities: activities,
      personas: personas,
      preferences: preferences,
      delivery: delivery,
      financials: financials,
      communications: communications,
    );
    return {
      'schemaVersion': 4,
      'customers': customers.map((customer) => customer.toJson()).toList(),
      'pipelineStages': pipelineStages,
      'activities': activities.map((activity) => activity.toJson()).toList(),
      'personas': personas.map((persona) => persona.toJson()).toList(),
      'preferences': preferences.toJson(),
      'delivery': delivery.toJson(),
      'financials': financials.toJson(),
      'communications': communications.map((entry) => entry.toJson()).toList(),
    };
  }

  List<StudioPersona> _migrateDeliveryPermissions(
    List<StudioPersona> personas,
  ) {
    final defaults = {
      for (final persona in StudioPersona.defaults()) persona.id: persona,
    };
    return personas.map((persona) {
      final defaultPersona = defaults[persona.id];
      if (defaultPersona == null ||
          persona.permissions.any(
            StudioPersona.deliveryPermissionKeys.contains,
          )) {
        return persona;
      }
      final deliveryPermissions = defaultPersona.permissions.where(
        StudioPersona.deliveryPermissionKeys.contains,
      );
      return persona.copyWith(
        permissions: [...persona.permissions, ...deliveryPermissions],
      );
    }).toList();
  }

  List<StudioPersona> _migrateFinancialPermissions(
    List<StudioPersona> personas,
  ) {
    final defaults = {
      for (final persona in StudioPersona.defaults()) persona.id: persona,
    };
    return personas.map((persona) {
      final defaultPersona = defaults[persona.id];
      if (defaultPersona == null) return persona;
      final financePermissions = defaultPersona.permissions.where(
        StudioPersona.financePermissionKeys.contains,
      );
      return persona.copyWith(
        permissions: [
          ...persona.permissions,
          ...financePermissions.where(
            (permission) => !persona.permissions.contains(permission),
          ),
        ],
      );
    }).toList();
  }

  List<StudioPersona> _migrateCommunicationPermissions(
    List<StudioPersona> personas,
  ) {
    final defaults = {
      for (final persona in StudioPersona.defaults()) persona.id: persona,
    };
    return personas.map((persona) {
      final defaultPersona = defaults[persona.id];
      if (defaultPersona == null) return persona;
      final communicationPermissions = defaultPersona.permissions.where(
        StudioPersona.communicationPermissionKeys.contains,
      );
      return persona.copyWith(
        permissions: [
          ...persona.permissions,
          ...communicationPermissions.where(
            (permission) => !persona.permissions.contains(permission),
          ),
        ],
      );
    }).toList();
  }

  List<Customer> _decodeCustomers(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Saved customer data is not a list.');
    }
    return value.map((customer) => Customer.fromJson(customer)).toList();
  }

  List<StudioActivity> _decodeActivities(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Saved activity data is not a list.');
    }
    return value.map((activity) => StudioActivity.fromJson(activity)).toList();
  }

  List<StudioPersona> _decodePersonas(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Saved studio roles are not a list.');
    }
    return value.map((persona) => StudioPersona.fromJson(persona)).toList();
  }

  List<StudioCommunication> _decodeCommunications(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Saved communication history is not a list.');
    }
    return value.map(StudioCommunication.fromJson).toList();
  }

  List<StudioCommunication> _migrateLegacyInteractions(
    List<StudioActivity> activities,
    List<Customer> customers,
    List<StudioPersona> personas,
    String fallbackPersonaId,
  ) {
    final migrated = <StudioCommunication>[];
    for (final activity in activities.where(
      (item) => item.kind == 'interaction',
    )) {
      final persona = personas.where((item) => item.name == activity.actor);
      final title = activity.title.toLowerCase();
      final originalChannel = title.endsWith(' logged')
          ? activity.title.substring(0, activity.title.length - 7)
          : 'Other';
      final channel = originalChannel == 'Note'
          ? 'Internal note'
          : StudioCommunication.channels.contains(originalChannel)
          ? originalChannel
          : 'Other';
      final clientExists =
          activity.customerId != null &&
          customers.any((customer) => customer.id == activity.customerId);
      migrated.add(
        StudioCommunication(
          id: 'legacy-${activity.id}',
          clientId: clientExists ? activity.customerId : null,
          clientName: activity.customerName,
          projectId: null,
          projectName: '',
          channel: channel,
          subject: '',
          body: activity.details.trim().isEmpty
              ? 'Interaction logged without additional details.'
              : activity.details,
          recipient: '',
          status: 'Logged',
          createdByPersonaId: persona.isEmpty
              ? fallbackPersonaId
              : persona.first.id,
          createdByName: activity.actor,
          createdAt: activity.occurredAt,
          updatedAt: activity.occurredAt,
        ),
      );
    }
    return migrated;
  }

  static bool _hasInvalidPersona(List<StudioPersona> personas) {
    if (personas.isEmpty) return true;
    for (final persona in personas) {
      if (persona.id.trim().isEmpty ||
          persona.name.trim().isEmpty ||
          persona.name.length > 50 ||
          persona.description.length > 160) {
        return true;
      }
      if (persona.permissions.any(
        (permission) => !StudioPersona.permissionKeys.contains(permission),
      )) {
        return true;
      }
      if (persona.permissions.any(
            (permission) =>
                StudioPersona.clientManagementPermissions.contains(permission),
          ) &&
          !persona.allows(StudioPersona.viewClients)) {
        return true;
      }
      if (persona.allows(StudioPersona.manageCommunications) &&
          !persona.allows(StudioPersona.viewCommunications)) {
        return true;
      }
      if (persona.allows(StudioPersona.viewCommunications) &&
          (!persona.allows(StudioPersona.viewClients) ||
              !persona.allows(StudioPersona.viewProjects))) {
        return true;
      }
      if (persona.allows(StudioPersona.manageFinancials) &&
          !persona.allows(StudioPersona.viewFinancials)) {
        return true;
      }
    }
    return false;
  }

  void _validateWorkspace(
    List<Customer> customers,
    List<String> stages, {
    required List<StudioActivity> activities,
    required List<StudioPersona> personas,
    required WorkspacePreferences preferences,
    required StudioDeliveryWorkspace delivery,
    required StudioFinancialWorkspace financials,
    required List<StudioCommunication> communications,
  }) {
    if (stages.length < 2) {
      throw const FormatException('A pipeline must have at least two stages.');
    }
    final normalizedStages = stages.map((stage) => stage.trim()).toList();
    if (normalizedStages.any((stage) => stage.isEmpty || stage.length > 40)) {
      throw const FormatException(
        'Pipeline stage names must be 1–40 characters.',
      );
    }
    if (normalizedStages.toSet().length != normalizedStages.length ||
        normalizedStages.map((stage) => stage.toLowerCase()).toSet().length !=
            normalizedStages.length) {
      throw const FormatException('Pipeline stage names must be unique.');
    }
    if (customers.any((customer) => !stages.contains(customer.stage))) {
      throw const FormatException(
        'A customer is assigned to a stage that no longer exists.',
      );
    }
    if (_hasInvalidPersona(personas)) {
      throw const FormatException(
        'Studio roles must have valid names and access.',
      );
    }
    if (personas.map((persona) => persona.id).toSet().length !=
            personas.length ||
        personas
                .map((persona) => persona.name.trim().toLowerCase())
                .toSet()
                .length !=
            personas.length) {
      throw const FormatException('Studio role names must be unique.');
    }
    if (activities.any(
      (activity) =>
          activity.id.trim().isEmpty ||
          activity.title.trim().isEmpty ||
          activity.actor.trim().isEmpty,
    )) {
      throw const FormatException(
        'Activity entries must include a title and actor.',
      );
    }
    if (activities.map((activity) => activity.id).toSet().length !=
        activities.length) {
      throw const FormatException('Activity entry IDs must be unique.');
    }
    final personaIds = personas.map((persona) => persona.id).toSet();
    final communicationIds = communications.map((entry) => entry.id).toSet();
    if (communicationIds.length != communications.length ||
        communications.any(
          (entry) =>
              entry.id.trim().isEmpty ||
              entry.clientName.length > 120 ||
              (entry.clientId != null &&
                  !customers.any(
                    (customer) => customer.id == entry.clientId,
                  )) ||
              entry.projectName.length > 120 ||
              (entry.projectId != null &&
                  !delivery.projects.any(
                    (project) => project.id == entry.projectId,
                  )) ||
              (entry.projectId != null &&
                  delivery.projects.any(
                    (project) =>
                        project.id == entry.projectId &&
                        project.customerId != null &&
                        entry.clientId != project.customerId,
                  )) ||
              entry.channel.length > 30 ||
              !StudioCommunication.channels.contains(entry.channel) ||
              entry.subject.length > 200 ||
              entry.subject.contains('\n') ||
              entry.subject.contains('\r') ||
              entry.body.trim().isEmpty ||
              entry.body.length > 5000 ||
              entry.recipient.length > 254 ||
              !StudioCommunication.statuses.contains(entry.status) ||
              ((entry.channel == 'Email' &&
                      [
                        'Draft',
                        'Ready to send',
                        'Queued',
                        'Sending',
                        'Sent',
                        'Delivered',
                        'Read',
                        'Failed',
                        'Received',
                      ].contains(entry.status)) &&
                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(entry.recipient)) ||
              ((entry.channel == 'WhatsApp' &&
                      [
                        'Draft',
                        'Ready to send',
                        'Queued',
                        'Sending',
                        'Sent',
                        'Delivered',
                        'Read',
                        'Failed',
                        'Received',
                      ].contains(entry.status)) &&
                  (entry.recipient.replaceAll(RegExp(r'\D'), '').length < 8 ||
                      entry.recipient.replaceAll(RegExp(r'\D'), '').length >
                          15)) ||
              entry.createdByPersonaId.trim().isEmpty ||
              !personaIds.contains(entry.createdByPersonaId) ||
              entry.createdByName.trim().isEmpty ||
              entry.mentionedPersonaIds.toSet().length !=
                  entry.mentionedPersonaIds.length ||
              entry.mentionedPersonaIds.any(
                (personaId) => !personaIds.contains(personaId),
              ) ||
              entry.readByPersonaIds.toSet().length !=
                  entry.readByPersonaIds.length ||
              entry.readByPersonaIds.any(
                (personaId) => !personaIds.contains(personaId),
              ),
        )) {
      throw const FormatException('Communication history is invalid.');
    }
    if (preferences.studioName.trim().isEmpty ||
        preferences.studioName.length > 80 ||
        !stages.contains(preferences.defaultPipelineStage) ||
        !personas.any((persona) => persona.id == preferences.activePersonaId)) {
      throw const FormatException('Workspace preferences are invalid.');
    }
    if (delivery.totalAssetBytes > StudioProjectAsset.maxTotalBytes) {
      throw const FormatException(
        'Project files exceed the local storage limit.',
      );
    }
    final projectIds = delivery.projects.map((project) => project.id).toSet();
    if (projectIds.length != delivery.projects.length ||
        delivery.projects.any(
          (project) =>
              project.id.trim().isEmpty ||
              project.name.trim().isEmpty ||
              project.name.length > 120 ||
              !StudioProject.statuses.contains(project.status) ||
              (project.customerId != null &&
                  !customers.any(
                    (customer) => customer.id == project.customerId,
                  )),
        )) {
      throw const FormatException('Project records are invalid.');
    }
    if (delivery.tasks.any(
      (task) =>
          !projectIds.contains(task.projectId) ||
          task.id.trim().isEmpty ||
          task.title.trim().isEmpty ||
          task.assignee.trim().isEmpty ||
          !StudioTaskRecord.priorities.contains(task.priority),
    )) {
      throw const FormatException('Project tasks are invalid.');
    }
    final taskIds = delivery.tasks.map((task) => task.id).toSet();
    if (taskIds.length != delivery.tasks.length) {
      throw const FormatException('Project task IDs must be unique.');
    }
    if (delivery.milestones.any(
      (item) =>
          !projectIds.contains(item.projectId) ||
          item.id.trim().isEmpty ||
          item.title.trim().isEmpty ||
          !StudioMilestone.statuses.contains(item.status),
    )) {
      throw const FormatException('Project milestones are invalid.');
    }
    if (delivery.milestones.map((item) => item.id).toSet().length !=
        delivery.milestones.length) {
      throw const FormatException('Project milestone IDs must be unique.');
    }
    if (delivery.punchItems.any(
      (item) =>
          !projectIds.contains(item.projectId) ||
          item.id.trim().isEmpty ||
          item.description.trim().isEmpty ||
          item.assignee.trim().isEmpty ||
          !StudioPunchItem.statuses.contains(item.status),
    )) {
      throw const FormatException('Project punch-list records are invalid.');
    }
    if (delivery.punchItems.map((item) => item.id).toSet().length !=
        delivery.punchItems.length) {
      throw const FormatException('Punch-list IDs must be unique.');
    }
    if (delivery.assets.any(
      (asset) =>
          !projectIds.contains(asset.projectId) ||
          asset.id.trim().isEmpty ||
          asset.name.trim().isEmpty ||
          asset.addedBy.trim().isEmpty ||
          asset.sizeBytes > StudioProjectAsset.maxFileBytes ||
          !StudioProjectAsset.kinds.contains(asset.kind),
    )) {
      throw const FormatException('Project files are invalid.');
    }
    if (delivery.assets.map((asset) => asset.id).toSet().length !=
        delivery.assets.length) {
      throw const FormatException('Project file IDs must be unique.');
    }
    if (delivery.workLogs.any(
      (log) =>
          !projectIds.contains(log.projectId) ||
          (log.taskId != null &&
              (!taskIds.contains(log.taskId) ||
                  !delivery.tasks.any(
                    (task) =>
                        task.id == log.taskId &&
                        task.projectId == log.projectId,
                  ))) ||
          log.id.trim().isEmpty ||
          log.author.trim().isEmpty ||
          log.minutes < 1 ||
          log.minutes > 1440 ||
          log.description.trim().isEmpty,
    )) {
      throw const FormatException('Project work logs are invalid.');
    }
    if (delivery.attendance.any(
      (record) =>
          record.id.trim().isEmpty ||
          record.personaId.trim().isEmpty ||
          record.personaName.trim().isEmpty ||
          !StudioAttendance.statuses.contains(record.status),
    )) {
      throw const FormatException('Attendance records are invalid.');
    }
    if (delivery.attendance.map((record) => record.id).toSet().length !=
        delivery.attendance.length) {
      throw const FormatException('Attendance IDs must be unique.');
    }
    if (delivery.approvals.any(
      (approval) =>
          !projectIds.contains(approval.projectId) ||
          approval.id.trim().isEmpty ||
          approval.title.trim().isEmpty ||
          approval.requestedBy.trim().isEmpty ||
          approval.approverPersonaId.trim().isEmpty ||
          approval.approverName.trim().isEmpty ||
          !StudioApproval.statuses.contains(approval.status) ||
          (approval.status == 'Pending' && approval.decidedAt != null) ||
          (approval.status != 'Pending' && approval.decidedAt == null),
    )) {
      throw const FormatException('Approval records are invalid.');
    }
    if (delivery.approvals.map((approval) => approval.id).toSet().length !=
        delivery.approvals.length) {
      throw const FormatException('Approval IDs must be unique.');
    }
    bool validItems(List<StudioQuoteLine> items) {
      final ids = items.map((item) => item.id).toSet();
      return items.isNotEmpty &&
          ids.length == items.length &&
          items.every(
            (item) =>
                item.id.trim().isNotEmpty &&
                item.description.trim().isNotEmpty &&
                item.description.length <= 180 &&
                item.quantity.isFinite &&
                item.quantity > 0 &&
                item.unit.trim().isNotEmpty &&
                item.unit.length <= 20 &&
                item.unitRate.isFinite &&
                item.unitRate >= 0 &&
                item.amount.isFinite,
          ) &&
          items.fold<double>(0, (total, item) => total + item.amount) > 0;
    }

    bool validTaxRate(double rate) => rate.isFinite && rate >= 0 && rate <= 100;
    bool validCurrency(String currency) =>
        currency.trim().isNotEmpty && currency.length <= 4;
    final settings = financials.settings;
    if (settings.quotationPrefix.trim().isEmpty ||
        settings.quotationPrefix.length > 12 ||
        settings.proposalPrefix.trim().isEmpty ||
        settings.proposalPrefix.length > 12 ||
        settings.invoicePrefix.trim().isEmpty ||
        settings.invoicePrefix.length > 12 ||
        settings.nextQuotationNumber < 1 ||
        settings.nextProposalNumber < 1 ||
        settings.nextInvoiceNumber < 1 ||
        !validCurrency(settings.currencySymbol) ||
        !validTaxRate(settings.defaultTaxRate) ||
        settings.defaultTerms.length > 3000) {
      throw const FormatException('Financial settings are invalid.');
    }
    final templates = financials.templates;
    if (templates.isEmpty ||
        templates.any(
          (template) =>
              template.id.trim().isEmpty ||
              template.name.trim().isEmpty ||
              template.name.length > 80 ||
              template.brandName.length > 120 ||
              template.introduction.length > 1500 ||
              template.terms.length > 3000 ||
              template.footer.length > 400 ||
              template.sectionOrder.length !=
                  StudioDocumentTemplate.sectionLabels.length ||
              template.sectionOrder.toSet().length !=
                  StudioDocumentTemplate.sectionLabels.length ||
              template.sectionOrder.any(
                (section) =>
                    !StudioDocumentTemplate.sectionLabels.containsKey(section),
              ),
        )) {
      throw const FormatException('Document templates are invalid.');
    }
    if (templates.map((template) => template.id).toSet().length !=
            templates.length ||
        templates
                .map((template) => template.name.trim().toLowerCase())
                .toSet()
                .length !=
            templates.length) {
      throw const FormatException('Document template names must be unique.');
    }
    final quotationIds = financials.quotations
        .map((quotation) => quotation.id)
        .toSet();
    if (quotationIds.length != financials.quotations.length ||
        financials.quotations.any(
          (quotation) =>
              quotation.id.trim().isEmpty ||
              quotation.number.trim().isEmpty ||
              quotation.projectId.trim().isEmpty ||
              !projectIds.contains(quotation.projectId) ||
              quotation.projectName.trim().isEmpty ||
              quotation.clientId.trim().isEmpty ||
              quotation.clientName.trim().isEmpty ||
              quotation.title.trim().isEmpty ||
              quotation.title.length > 120 ||
              !validItems(quotation.items) ||
              !validTaxRate(quotation.taxRate) ||
              !validCurrency(quotation.currencySymbol),
        )) {
      throw const FormatException('Quotations are invalid.');
    }
    if (financials.quotations
            .map((quotation) => quotation.number)
            .toSet()
            .length !=
        financials.quotations.length) {
      throw const FormatException('Quotation numbers must be unique.');
    }
    final proposalIds = financials.proposals
        .map((proposal) => proposal.id)
        .toSet();
    if (proposalIds.length != financials.proposals.length ||
        financials.proposals.any(
          (proposal) =>
              proposal.id.trim().isEmpty ||
              proposal.number.trim().isEmpty ||
              !quotationIds.contains(proposal.quotationId) ||
              !projectIds.contains(proposal.projectId) ||
              proposal.projectName.trim().isEmpty ||
              proposal.clientId.trim().isEmpty ||
              proposal.clientName.trim().isEmpty ||
              proposal.title.trim().isEmpty ||
              proposal.brandName.trim().isEmpty ||
              proposal.title.length > 120 ||
              proposal.brandName.length > 120 ||
              proposal.introduction.length > 1500 ||
              proposal.terms.length > 3000 ||
              proposal.footer.length > 400 ||
              proposal.requirementRooms.any((room) => room.trim().isEmpty) ||
              proposal.requirementRooms.toSet().length !=
                  proposal.requirementRooms.length ||
              (proposal.budgetMin != null &&
                  (!proposal.budgetMin!.isFinite || proposal.budgetMin! < 0)) ||
              (proposal.budgetMax != null &&
                  (!proposal.budgetMax!.isFinite ||
                      proposal.budgetMax! < 0 ||
                      (proposal.budgetMin != null &&
                          proposal.budgetMax! < proposal.budgetMin!))) ||
              !StudioProposal.statuses.contains(proposal.status) ||
              !validItems(proposal.items) ||
              !validTaxRate(proposal.taxRate) ||
              !validCurrency(proposal.currencySymbol) ||
              proposal.sectionOrder.length !=
                  StudioDocumentTemplate.sectionLabels.length ||
              proposal.sectionOrder.toSet().length !=
                  StudioDocumentTemplate.sectionLabels.length ||
              proposal.sectionOrder.any(
                (section) =>
                    !StudioDocumentTemplate.sectionLabels.containsKey(section),
              ),
        )) {
      throw const FormatException('Proposals are invalid.');
    }
    if (financials.proposals
            .map((proposal) => proposal.number)
            .toSet()
            .length !=
        financials.proposals.length) {
      throw const FormatException('Proposal numbers must be unique.');
    }
    if (delivery.approvals.any(
      (approval) =>
          approval.relatedProposalId != null &&
          !proposalIds.contains(approval.relatedProposalId),
    )) {
      throw const FormatException('Proposal approval links are invalid.');
    }
    final invoiceIds = financials.invoices.map((invoice) => invoice.id).toSet();
    final invoicedProposalIds = financials.invoices
        .map((invoice) => invoice.proposalId)
        .toSet();
    if (invoiceIds.length != financials.invoices.length ||
        invoicedProposalIds.length != financials.invoices.length ||
        financials.invoices.any(
          (invoice) =>
              invoice.id.trim().isEmpty ||
              invoice.number.trim().isEmpty ||
              !financials.proposals.any(
                (proposal) =>
                    proposal.id == invoice.proposalId &&
                    proposal.status == 'Approved',
              ) ||
              !projectIds.contains(invoice.projectId) ||
              invoice.projectName.trim().isEmpty ||
              invoice.clientId.trim().isEmpty ||
              invoice.clientName.trim().isEmpty ||
              invoice.title.trim().isEmpty ||
              !validItems(invoice.items) ||
              !validTaxRate(invoice.taxRate) ||
              !validCurrency(invoice.currencySymbol) ||
              !StudioInvoice.statuses.contains(invoice.status) ||
              !invoice.paidAmount.isFinite ||
              invoice.paidAmount < 0 ||
              invoice.paidAmount > invoice.total ||
              (invoice.status == 'Paid' &&
                  invoice.paidAmount != invoice.total) ||
              (invoice.status == 'Partially paid' &&
                  (invoice.paidAmount <= 0 ||
                      invoice.paidAmount >= invoice.total)) ||
              ((invoice.status == 'Draft' || invoice.status == 'Sent') &&
                  invoice.paidAmount != 0),
        )) {
      throw const FormatException('Invoices are invalid.');
    }
    if (financials.invoices.map((invoice) => invoice.number).toSet().length !=
        financials.invoices.length) {
      throw const FormatException('Invoice numbers must be unique.');
    }
  }
}
