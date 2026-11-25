import 'dart:convert';

import 'package:raams_crm/app_config.dart';
import 'package:raams_crm/backend/auth_gate.dart';
import 'package:raams_crm/backend/backend_api_client.dart';
import 'package:raams_crm/backend/remote_customer_workspace_repository.dart';
import 'package:raams_crm/backend/workspace_access.dart';
import 'package:raams_crm/backend/workspace_access_dialog.dart';
import 'package:raams_crm/backend/workspace_selection_gate.dart';
import 'package:raams_crm/communication.dart';
import 'package:raams_crm/customer.dart';
import 'package:raams_crm/delivery.dart';
import 'package:raams_crm/finance.dart';
import 'package:raams_crm/procurement.dart';
import 'package:raams_crm/site_execution.dart';
import 'package:raams_crm/workforce.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

part 'finance_dialogs.dart';
part 'communication_dialogs.dart';
part 'project_planning_dialogs.dart';
part 'procurement_dialogs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromBuildEnvironment();
  if (config.environment != AppEnvironment.development) {
    await Supabase.initialize(
      url: config.requiredSupabaseUrl.toString(),
      publishableKey: config.requiredSupabasePublishableKey,
    );
  }
  runApp(AtelierApp(config: config));
}

const ink = Color(0xFF24332D);
const canvas = Color(0xFFF7F5F0);
const paper = Color(0xFFFFFEFB);
const muted = Color(0xFF87877E);
const line = Color(0xFFE9E6DE);
const accent = Color(0xFFB77C56);
const sage = Color(0xFF758A78);

String _formatCurrencyAmount(double amount, String symbol) {
  final parts = amount.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '$symbol$whole.${parts.last}';
}

const _studioPermissionLabels = <String, String>{
  StudioPersona.viewClients: 'View client records',
  StudioPersona.manageClients:
      'Add, edit, import, log interactions, and remove clients',
  StudioPersona.managePipeline: 'Move clients and configure pipeline stages',
  StudioPersona.manageRequirements: 'Edit project requirements',
  StudioPersona.viewFinancials: 'View client budgets and proposals',
  StudioPersona.configureWorkspace: 'Configure studio workspace',
  StudioPersona.viewProjects: 'View projects',
  StudioPersona.manageProjects: 'Create and edit projects',
  StudioPersona.manageTasks: 'Create, assign, and complete tasks',
  StudioPersona.viewFiles: 'View and download project files',
  StudioPersona.manageFiles: 'Upload and organize project files',
  StudioPersona.manageMilestones: 'Manage milestones and updates',
  StudioPersona.managePunchList: 'Create and resolve punch-list items',
  StudioPersona.viewWorkLogs: 'View work logs',
  StudioPersona.manageWorkLogs: 'Record project work logs',
  StudioPersona.manageAttendance: 'Record and review attendance',
  StudioPersona.manageApprovals: 'Submit and route approval requests',
  StudioPersona.approveApprovals: 'Decide routed approvals',
  StudioPersona.manageFinancials:
      'Manage quotations, proposals, templates, settings, and invoices',
  StudioPersona.viewCommunications: 'View client and project conversations',
  StudioPersona.manageCommunications:
      'Compose messages, log interactions, and notify teammates',
  StudioPersona.viewMaterials: 'View the material catalogue',
  StudioPersona.manageMaterials: 'Manage materials and specifications',
  StudioPersona.viewVendors: 'View suppliers and contractors',
  StudioPersona.manageVendors: 'Manage supplier and contractor records',
  StudioPersona.approveProcurement: 'Approve requisitions and purchase orders',
};

String _studioPermissionForRole(String permission) => switch (permission) {
  'projects.view' => StudioPersona.viewProjects,
  'projects.manage' => StudioPersona.manageProjects,
  'finance.view' => StudioPersona.viewFinancials,
  'finance.manage' => StudioPersona.manageFinancials,
  'workspace.read' => StudioPersona.viewClients,
  'workspace.write' => StudioPersona.manageClients,
  _ => permission,
};

class AtelierApp extends StatelessWidget {
  const AtelierApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: config.appTitle,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      fontFamily: 'Georgia',
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        hintStyle: const TextStyle(
          color: muted,
          fontFamily: 'Arial',
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    home: config.environment == AppEnvironment.development
        ? const StudioHome()
        : BackendEnvironmentNotice(
            environment: config.environment,
            apiBaseUri: config.requiredApiBaseUri,
            child: SupabaseAuthGate(
              authRedirectUrl: config.authRedirectUri?.toString(),
              authenticatedBuilder: (context, session) {
                final auth = Supabase.instance.client.auth;
                return WorkspaceSelectionGate(
                  baseUri: config.requiredApiBaseUri,
                  accessTokenProvider: () async =>
                      auth.currentSession?.accessToken,
                  onSignOut: () => auth.signOut(),
                  organizationBuilder: (organization, onSwitchWorkspace) =>
                      StudioHome(
                        key: ValueKey('${session.user.id}:${organization.id}'),
                        repository: RemoteCustomerWorkspaceRepository(
                          baseUri: config.requiredApiBaseUri,
                          workspaceId: organization.id,
                          accessTokenProvider: () async =>
                              auth.currentSession?.accessToken,
                        ),
                        workspaceAccessClient: WorkspaceAccessClient(
                          baseUri: config.requiredApiBaseUri,
                          workspaceId: organization.id,
                          accessTokenProvider: () async =>
                              auth.currentSession?.accessToken,
                        ),
                        accessPersona: StudioPersona(
                          id: organization.userId,
                          name: organization.roleName,
                          description: 'Organization access role',
                          permissions: {
                            ...organization.permissions,
                            ...organization.projectPermissions,
                          }.map(_studioPermissionForRole).toList(),
                        ),
                        organizationPermissions: organization.permissions,
                        onSignOut: () => auth.signOut(),
                        onSwitchWorkspace: onSwitchWorkspace,
                      ),
                );
              },
            ),
          ),
  );
}

class BackendEnvironmentNotice extends StatefulWidget {
  const BackendEnvironmentNotice({
    required this.environment,
    required this.apiBaseUri,
    required this.child,
    super.key,
  });

  final AppEnvironment environment;
  final Uri apiBaseUri;
  final Widget child;

  @override
  State<BackendEnvironmentNotice> createState() =>
      _BackendEnvironmentNoticeState();
}

class _BackendEnvironmentNoticeState extends State<BackendEnvironmentNotice> {
  late final BackendApiClient _apiClient;
  late Future<BackendStatus> _status;

  @override
  void initState() {
    super.initState();
    _apiClient = BackendApiClient(baseUri: widget.apiBaseUri);
    _status = _apiClient.checkStatus(
      expectedEnvironment: widget.environment.name,
    );
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  void _retry() {
    setState(
      () => _status = _apiClient.checkStatus(
        expectedEnvironment: widget.environment.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BackendStatus>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.requireData.databaseConnected) {
        return widget.child;
      }
      final message = snapshot.connectionState == ConnectionState.waiting
          ? 'Checking API and database readiness…'
          : snapshot.hasError
          ? 'Backend check failed: ${snapshot.error}'
          : 'The API is reachable, but the database is not ready.';
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    snapshot.connectionState == ConnectionState.waiting
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_off_outlined,
                    size: 40,
                    color: ink,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.environment.name[0].toUpperCase()}${widget.environment.name.substring(1)} service status',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: accent, fontFamily: 'Arial'),
                  ),
                  if (snapshot.connectionState != ConnectionState.waiting) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check again'),
                    ),
                  ],
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class StudioHome extends StatefulWidget {
  const StudioHome({
    this.repository = const SharedPreferencesCustomerWorkspaceRepository(),
    this.workspaceAccessClient,
    this.accessPersona,
    this.organizationPermissions,
    this.onSignOut,
    this.onSwitchWorkspace,
    super.key,
  });

  final CustomerWorkspaceRepository repository;
  final WorkspaceAccessClient? workspaceAccessClient;
  final StudioPersona? accessPersona;
  final List<String>? organizationPermissions;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onSwitchWorkspace;

  @override
  State<StudioHome> createState() => _StudioHomeState();
}

class _StudioHomeState extends State<StudioHome> {
  int _section = 0;
  String _query = '';
  late final CustomerWorkspaceRepository _customerRepository;
  List<Customer> _customers = [
    const Customer(
      id: 'demo-olivia',
      name: 'Olivia Bennett',
      project: 'West Village Residence',
      stage: 'Qualified',
      value: '\$185,000',
      email: 'olivia@example.test',
      phone: '',
      notes: 'Prefers natural stone and warm, layered lighting.',
      initials: 'OB',
      tint: Color(0xFFE9DDD0),
    ),
    const Customer(
      id: 'demo-alexander',
      name: 'Alexander Chen',
      project: 'Park Avenue Penthouse',
      stage: 'Proposal',
      value: '\$320,000',
      email: 'alexander@example.test',
      phone: '',
      notes: '',
      initials: 'AC',
      tint: Color(0xFFDCE3DA),
    ),
    const Customer(
      id: 'demo-sofia',
      name: 'Sofia Laurent',
      project: 'Hamptons Summer House',
      stage: 'New inquiry',
      value: '\$92,000',
      email: 'sofia@example.test',
      phone: '',
      notes: '',
      initials: 'SL',
      tint: Color(0xFFE9D9D5),
    ),
    const Customer(
      id: 'demo-reed',
      name: 'James & Emma Reed',
      project: 'Brooklyn Townhouse',
      stage: 'Discovery',
      value: '\$146,000',
      email: 'reed@example.test',
      phone: '',
      notes: '',
      initials: 'ER',
      tint: Color(0xFFE9E5D9),
    ),
  ];
  List<String> _pipelineStages = [
    'New inquiry',
    'Discovery',
    'Qualified',
    'Proposal',
    'Client',
    'On hold',
  ];
  List<StudioActivity> _activities = [];
  List<StudioPersona> _personas = StudioPersona.defaults();
  StudioDeliveryWorkspace _delivery = const StudioDeliveryWorkspace();
  StudioFinancialWorkspace _financials = StudioFinancialWorkspace.defaults();
  List<StudioLineItemCatalogEntry> _lineItemCatalog = const [];
  bool _lineItemCatalogLoaded = false;
  bool _lineItemCatalogLoading = false;
  String? _lineItemCatalogError;
  List<StudioCommunication> _communications = [];
  String? _communicationClientFilter;
  String? _communicationProjectFilter;
  String _communicationFilter = 'All';
  late WorkspacePreferences _workspacePreferences =
      WorkspacePreferences.defaults(
        defaultPipelineStage: _pipelineStages.first,
      );
  bool _showPipelineBoard = false;
  bool _customersLoading = true;
  bool _savingCustomers = false;
  String? _customerStorageError;
  String? _selectedProjectId;
  String _projectTab = 'Projects';
  String _proposalTab = 'Quotations';
  String _taskFilter = 'All';
  String _documentQuery = '';

  static const _sections = [
    ('Overview', Icons.grid_view_rounded),
    ('Clients & leads', Icons.people_outline_rounded),
    ('Projects', Icons.home_work_outlined),
    ('Proposals', Icons.description_outlined),
    ('Tasks', Icons.check_circle_outline_rounded),
    ('Project delivery', Icons.work_outline),
    ('Studio features', Icons.auto_awesome_outlined),
    ('Reports', Icons.bar_chart_rounded),
    ('Communications', Icons.forum_outlined),
  ];
  static const _implementedFeatures = <String>{
    'Customer Management',
    'Requirement intake',
    'Communication history',
    'Email sending',
    'WhatsApp messaging',
    '@mentions',
    'Lead pipeline configuration',
    'Bulk import (CSV)',
    'Persona configuration',
    'Project documents',
    'Milestone Updates',
    'Progress photos',
    'Punch list',
    'Project Task Creation',
    'Tasks',
    'Task suggestions',
    'Work logs',
    'Attendance Tracking',
    'File storage',
    'Approval routing',
    'Activity timeline',
    'BOQ / Quotation Creation',
    'Document templates',
    'Proposal layout designer',
    'Proposal settings',
    'Proposal Generation',
    'Invoice Preparation',
    'Report Generation',
  };

  List<Customer> get _filteredCustomers => _customers
      .where(
        (lead) =>
            '${lead.name} ${lead.project} ${lead.stage} ${lead.email} ${lead.phone}'
                .toLowerCase()
                .contains(_query.toLowerCase()),
      )
      .toList();

  StudioPersona get _activePersona =>
      widget.accessPersona ??
      _personas.firstWhere(
        (persona) => persona.id == _workspacePreferences.activePersonaId,
        orElse: () => StudioPersona.defaults().first,
      );

  bool _can(String permission) =>
      _activePersona.permissions.contains('*') ||
      _activePersona.allows(permission);

  List<StudioTaskRecord> get _filteredTasks {
    final query = _query.toLowerCase();
    return _delivery.tasks.where((task) {
      final matchesFilter = switch (_taskFilter) {
        'Open' => !task.isComplete,
        'Complete' => task.isComplete,
        _ => true,
      };
      final project = _projectFor(task.projectId);
      final matchesQuery =
          '${task.title} ${task.assignee} ${project?.name ?? ''}'
              .toLowerCase()
              .contains(query);
      return matchesFilter && matchesQuery;
    }).toList()..sort((first, second) {
      if (first.isComplete != second.isComplete) {
        return first.isComplete ? 1 : -1;
      }
      final firstDue = first.dueDate ?? DateTime(9999);
      final secondDue = second.dueDate ?? DateTime(9999);
      return firstDue.compareTo(secondDue);
    });
  }

  StudioProject? _projectFor(String projectId) {
    for (final project in _delivery.projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  Customer? _customerFor(String? customerId) {
    if (customerId == null) return null;
    for (final customer in _customers) {
      if (customer.id == customerId) return customer;
    }
    return null;
  }

  StudioProject? get _selectedProject {
    if (_selectedProjectId == null) {
      return _delivery.projects.isEmpty ? null : _delivery.projects.first;
    }
    return _projectFor(_selectedProjectId!);
  }

  List<StudioActivity> get _recentActivities => List<StudioActivity>.of(
    _activities,
  )..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

  @override
  void initState() {
    super.initState();
    _customerRepository = widget.repository;
    _restoreCustomers();
  }

  @override
  void dispose() {
    final repository = _customerRepository;
    if (repository is RemoteCustomerWorkspaceRepository) {
      repository.close();
    }
    widget.workspaceAccessClient?.close();
    super.dispose();
  }

  Future<void> _restoreCustomers() async {
    try {
      final remoteRepository = _customerRepository;
      var workspace = remoteRepository is RemoteCustomerWorkspaceRepository
          ? await remoteRepository.loadWorkspacePaged(
              initialCustomers: _customers,
              initialStages: _pipelineStages,
            )
          : await remoteRepository.loadWorkspace(
              initialCustomers: _customers,
              initialStages: _pipelineStages,
            );
      if (remoteRepository is RemoteCustomerWorkspaceRepository &&
          remoteRepository.isNewWorkspace) {
        const localRepository = SharedPreferencesCustomerWorkspaceRepository();
        if (await localRepository.hasSavedWorkspaceData() && mounted) {
          final shouldImport = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Import this device’s saved workspace?'),
              content: const Text(
                'A remote workspace does not exist yet. Import your saved local records now? Your local copy will remain on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep local copy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Import workspace'),
                ),
              ],
            ),
          );
          if (shouldImport == true) {
            final localWorkspace = await localRepository.loadWorkspace(
              initialCustomers: const [],
              initialStages: _pipelineStages,
            );
            await remoteRepository.saveWorkspace(
              customers: localWorkspace.customers,
              pipelineStages: localWorkspace.pipelineStages,
              activities: localWorkspace.activities,
              personas: localWorkspace.personas,
              preferences: localWorkspace.preferences,
              delivery: localWorkspace.delivery,
              financials: localWorkspace.financials,
              communications: localWorkspace.communications,
            );
            final importPersona =
                widget.accessPersona ??
                localWorkspace.personas.firstWhere(
                  (item) =>
                      item.id == localWorkspace.preferences.activePersonaId,
                  orElse: () => StudioPersona.defaults().first,
                );
            if (importPersona.permissions.contains('*') ||
                importPersona.allows(StudioPersona.manageFinancials)) {
              for (final entry in await localRepository.loadLineItemCatalog()) {
                await remoteRepository.saveLineItemCatalogEntry(entry);
              }
            }
            workspace = localWorkspace;
          }
        }
      }
      var lineItemCatalog = const <StudioLineItemCatalogEntry>[];
      var lineItemCatalogLoaded = false;
      String? lineItemCatalogError;
      final persona =
          widget.accessPersona ??
          workspace.personas.firstWhere(
            (item) => item.id == workspace.preferences.activePersonaId,
            orElse: () => StudioPersona.defaults().first,
          );
      final canViewFinancials =
          persona.permissions.contains('*') ||
          persona.allows(StudioPersona.viewFinancials);
      if (canViewFinancials) {
        try {
          lineItemCatalog = await _customerRepository.loadLineItemCatalog();
          lineItemCatalogLoaded = true;
        } on Exception catch (error) {
          lineItemCatalogError =
              'Could not load the workspace line-item catalog: $error';
        }
      }
      if (!mounted) return;
      setState(() {
        _customers = workspace.customers;
        _pipelineStages = workspace.pipelineStages;
        _activities = workspace.activities;
        _personas = workspace.personas;
        _workspacePreferences = workspace.preferences;
        _delivery = workspace.delivery;
        _financials = workspace.financials;
        _lineItemCatalog = lineItemCatalog;
        _lineItemCatalogLoaded = lineItemCatalogLoaded;
        _lineItemCatalogError = lineItemCatalogError;
        _lineItemCatalogLoading = false;
        _communications = workspace.communications;
        _customersLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _customersLoading = false;
        _customerStorageError = 'Could not load saved clients: $error';
      });
    }
  }

  Future<bool> _loadLineItemCatalog({bool announce = true}) async {
    if (!_can(StudioPersona.viewFinancials)) return false;
    if (_lineItemCatalogLoaded) return true;
    if (_lineItemCatalogLoading) return false;
    setState(() {
      _lineItemCatalogLoading = true;
      _lineItemCatalogError = null;
    });
    try {
      final catalog = await _customerRepository.loadLineItemCatalog();
      if (!mounted) return false;
      setState(() {
        _lineItemCatalog = catalog;
        _lineItemCatalogLoaded = true;
        _lineItemCatalogLoading = false;
        _lineItemCatalogError = null;
      });
      return true;
    } on Exception catch (error) {
      if (!mounted) return false;
      final message = 'Could not load the workspace line-item catalog: $error';
      setState(() {
        _lineItemCatalogLoading = false;
        _lineItemCatalogError = message;
      });
      if (announce) _toast(message);
      return false;
    }
  }

  Future<bool> _saveLineItemCatalogEntry(
    StudioLineItemCatalogEntry entry,
  ) async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot manage the line-item catalog.');
      return false;
    }
    setState(() {
      _lineItemCatalogLoading = true;
      _lineItemCatalogError = null;
    });
    try {
      await _customerRepository.saveLineItemCatalogEntry(entry);
      final catalog = await _customerRepository.loadLineItemCatalog();
      if (!mounted) return false;
      setState(() {
        _lineItemCatalog = catalog;
        _lineItemCatalogLoaded = true;
        _lineItemCatalogLoading = false;
        _lineItemCatalogError = null;
      });
      _toast('${entry.name} saved to the workspace catalog.');
      return true;
    } on Exception catch (error) {
      if (!mounted) return false;
      final message = 'Could not save ${entry.name}: $error';
      setState(() {
        _lineItemCatalogLoading = false;
        _lineItemCatalogError = message;
      });
      _toast(message);
      return false;
    }
  }

  Future<bool> _refreshRemoteWorkspace({bool announce = true}) async {
    final repository = _customerRepository;
    if (repository is! RemoteCustomerWorkspaceRepository) return true;
    if (_customersLoading || _savingCustomers) {
      if (announce) {
        _toast('Workspace data is already loading or saving.');
      }
      return false;
    }
    setState(() => _customersLoading = true);
    try {
      final workspace = await repository.loadWorkspacePaged(
        initialCustomers: _customers,
        initialStages: _pipelineStages,
      );
      if (!mounted) return false;
      if (repository.isNewWorkspace && _customers.isNotEmpty) {
        throw const FormatException(
          'The remote workspace is no longer available.',
        );
      }
      setState(() {
        _customers = workspace.customers;
        _pipelineStages = workspace.pipelineStages;
        _activities = workspace.activities;
        _personas = workspace.personas;
        _workspacePreferences = workspace.preferences;
        _delivery = workspace.delivery;
        _financials = workspace.financials;
        _communications = workspace.communications;
        _customerStorageError = null;
      });
      if (announce) _toast('Workspace refreshed from the server.');
      return true;
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () =>
              _customerStorageError = 'Could not refresh the workspace: $error',
        );
        if (announce) _toast('Workspace refresh failed: $error');
      }
      return false;
    } finally {
      if (mounted) setState(() => _customersLoading = false);
    }
  }

  StudioActivity _activity({
    required String kind,
    required String title,
    required String details,
    Customer? customer,
  }) => StudioActivity(
    id: 'activity-${DateTime.now().microsecondsSinceEpoch}-${_activities.length}',
    customerId: customer?.id,
    customerName: customer?.name ?? _workspacePreferences.studioName,
    kind: kind,
    title: title,
    details: details,
    actor: _activePersona.name,
    occurredAt: DateTime.now(),
  );

  Future<void> _saveCustomers(
    List<Customer> customers, {
    required String confirmation,
    StudioActivity? activity,
    StudioDeliveryWorkspace? delivery,
    List<StudioCommunication>? communications,
  }) => _saveWorkspace(
    customers: customers,
    activities: activity == null ? _activities : [..._activities, activity],
    delivery: delivery,
    communications: communications,
    confirmation: confirmation,
  );

  Future<void> _saveDelivery(
    StudioDeliveryWorkspace delivery, {
    required String confirmation,
    required String activityTitle,
    required String activityDetails,
    StudioFinancialWorkspace? financials,
  }) => _saveWorkspace(
    delivery: delivery,
    financials: financials,
    activities: [
      ..._activities,
      _activity(
        kind: 'project_delivery',
        title: activityTitle,
        details: activityDetails,
      ),
    ],
    confirmation: confirmation,
  );

  Future<void> _saveFinancials(
    StudioFinancialWorkspace financials, {
    StudioDeliveryWorkspace? delivery,
    required String confirmation,
    required String activityTitle,
    required String activityDetails,
  }) => _saveWorkspace(
    delivery: delivery,
    financials: financials,
    activities: [
      ..._activities,
      _activity(
        kind: 'finance',
        title: activityTitle,
        details: activityDetails,
      ),
    ],
    confirmation: confirmation,
  );

  Future<void> _saveCommunications(
    List<StudioCommunication> communications, {
    required String confirmation,
    required String activityTitle,
    required String activityDetails,
    String? clientId,
  }) {
    final client = clientId == null ? null : _customerFor(clientId);
    final activity = _activity(
      kind: 'communication',
      title: activityTitle,
      details: activityDetails,
      customer: client,
    );
    return _saveWorkspace(
      communications: communications,
      activities: [..._activities, activity],
      confirmation: confirmation,
    );
  }

  Future<void> _saveWorkspace({
    List<Customer>? customers,
    List<String>? pipelineStages,
    List<StudioActivity>? activities,
    List<StudioPersona>? personas,
    WorkspacePreferences? preferences,
    StudioDeliveryWorkspace? delivery,
    StudioFinancialWorkspace? financials,
    List<StudioCommunication>? communications,
    required String confirmation,
  }) async {
    if (_savingCustomers) {
      _toast('A workspace change is already being saved. Please try again.');
      return;
    }
    final savedCustomers = customers ?? _customers;
    final savedStages = pipelineStages ?? _pipelineStages;
    final savedActivities = activities ?? _activities;
    final savedPersonas = personas ?? _personas;
    final savedPreferences = preferences ?? _workspacePreferences;
    final savedDelivery = delivery ?? _delivery;
    final savedFinancials = financials ?? _financials;
    final savedCommunications = communications ?? _communications;
    setState(() => _savingCustomers = true);
    try {
      await _customerRepository.saveWorkspace(
        customers: savedCustomers,
        pipelineStages: savedStages,
        activities: savedActivities,
        personas: savedPersonas,
        preferences: savedPreferences,
        delivery: savedDelivery,
        financials: savedFinancials,
        communications: savedCommunications,
      );
      if (!mounted) return;
      setState(() {
        _customers = savedCustomers;
        _pipelineStages = savedStages;
        _activities = savedActivities;
        _personas = savedPersonas;
        _workspacePreferences = savedPreferences;
        _delivery = savedDelivery;
        _financials = savedFinancials;
        _communications = savedCommunications;
        _customerStorageError = null;
      });
      _toast(confirmation);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _customerStorageError = 'Could not save workspace changes: $error',
      );
      _toast('Workspace changes could not be saved.');
    } finally {
      if (mounted) setState(() => _savingCustomers = false);
    }
  }

  Future<void> _configurePipeline() async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.managePipeline)) {
      _toast('This studio role cannot configure the lead pipeline.');
      return;
    }
    final configuration = await showDialog<PipelineConfiguration>(
      context: context,
      builder: (context) => PipelineEditorDialog(
        stages: _pipelineStages,
        occupiedStages: {
          for (final stage in _pipelineStages)
            stage: _customers
                .where((customer) => customer.stage == stage)
                .length,
        },
      ),
    );
    if (configuration == null || !mounted) return;

    final updatedCustomers = _customers
        .map(
          (customer) => customer.copyWith(
            stage:
                configuration.renamedStages[customer.stage] ?? customer.stage,
          ),
        )
        .toList();
    final currentDefault = _workspacePreferences.defaultPipelineStage;
    final defaultStage =
        configuration.renamedStages[currentDefault] ??
        (configuration.stages.contains(currentDefault)
            ? currentDefault
            : configuration.stages.first);
    await _saveWorkspace(
      customers: updatedCustomers,
      pipelineStages: configuration.stages,
      preferences: _workspacePreferences.copyWith(
        defaultPipelineStage: defaultStage,
      ),
      activities: [
        ..._activities,
        _activity(
          kind: 'pipeline_updated',
          title: 'Lead pipeline updated',
          details: '${configuration.stages.length} stages configured.',
        ),
      ],
      confirmation: 'Lead pipeline updated.',
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut?.call();
    } on Exception catch (error) {
      if (mounted) _toast('Could not sign out: $error');
    }
  }

  Future<void> _openOrganizationAccess() async {
    if (_customersLoading || _savingCustomers) {
      _toast('Workspace data is still loading or saving. Please try again.');
      return;
    }
    final client = widget.workspaceAccessClient;
    if (client == null) {
      await _configurePersonas();
      return;
    }
    final accessPermissions =
        widget.organizationPermissions ??
        widget.accessPersona?.permissions ??
        const <String>[];
    final canViewAccess = accessPermissions.any(
      (permission) => {
        '*',
        'members.view',
        'members.manage',
        'roles.view',
        'roles.manage',
      }.contains(permission),
    );
    if (!canViewAccess) {
      _toast('Your organization role cannot view access settings.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => WorkspaceAccessDialog(
        client: client,
        projects: _delivery.projects,
        permissions: accessPermissions,
      ),
    );
  }

  Future<void> _configurePersonas() async {
    if (widget.accessPersona != null) {
      _toast('Production access is managed through organization roles.');
      return;
    }
    if (_customersLoading || _savingCustomers) {
      _toast('Workspace data is still loading or saving. Please try again.');
      return;
    }
    final configuration = await showDialog<PersonaConfiguration>(
      context: context,
      builder: (context) => PersonaConfigurationDialog(
        personas: _personas,
        preferences: _workspacePreferences,
        stages: _pipelineStages,
        protectedPersonaIds:
            _delivery.approvals
                .where((approval) => approval.status == 'Pending')
                .map((approval) => approval.approverPersonaId)
                .toSet()
              ..addAll(
                _communications.expand(
                  (entry) => [
                    entry.createdByPersonaId,
                    ...entry.mentionedPersonaIds,
                    ...entry.readByPersonaIds,
                  ],
                ),
              ),
        allowConfigure: _can(StudioPersona.configureWorkspace),
      ),
    );
    if (configuration == null || !mounted) return;
    await _saveWorkspace(
      personas: configuration.personas,
      preferences: configuration.preferences,
      activities: [
        ..._activities,
        _activity(
          kind: 'persona_configuration',
          title: 'Workspace settings updated',
          details: 'Studio roles and preferences were changed.',
        ),
      ],
      confirmation: 'Studio roles and preferences saved.',
    );
  }

  Future<void> _configureCommunicationIntegrations() async {
    if (_customersLoading || _savingCustomers) {
      _toast('Workspace data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.configureWorkspace)) {
      _toast('This studio role cannot configure sender accounts.');
      return;
    }
    final repository = _customerRepository;
    if (repository is! RemoteCustomerWorkspaceRepository) {
      _toast('Sender accounts are available when connected to the backend.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => CommunicationIntegrationDialog(
        repository: repository,
        workspaceName: _workspacePreferences.studioName,
      ),
    );
  }

  Future<void> _moveCustomerToStage(
    Customer customer,
    String destination,
  ) async {
    if (customer.stage == destination) return;
    if (!_can(StudioPersona.managePipeline)) {
      _toast('This studio role cannot move clients between stages.');
      return;
    }
    await _saveCustomers(
      _customers
          .map(
            (item) => item.id == customer.id
                ? item.copyWith(stage: destination)
                : item,
          )
          .toList(),
      confirmation: '${customer.name} moved to $destination.',
      activity: _activity(
        kind: 'stage_changed',
        title: 'Lead stage changed',
        details: '${customer.stage} → $destination',
        customer: customer,
      ),
    );
  }

  Future<void> _captureRequirements(Customer customer) async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageRequirements)) {
      _toast('This studio role cannot edit project requirements.');
      return;
    }
    final requirements = await showDialog<ProjectRequirement>(
      context: context,
      builder: (context) =>
          ProjectRequirementDialog(initial: customer.requirement),
    );
    if (requirements == null || !mounted) return;
    await _saveCustomers(
      _customers
          .map(
            (item) => item.id == customer.id
                ? item.copyWith(requirement: requirements)
                : item,
          )
          .toList(),
      confirmation: 'Project requirements saved for ${customer.name}.',
      activity: _activity(
        kind: 'requirements_updated',
        title: 'Project requirements updated',
        details: '${requirements.rooms.join(', ')} · ${requirements.style}',
        customer: customer,
      ),
    );
  }

  Future<void> _importCustomers() async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageClients)) {
      _toast('This studio role cannot import client records.');
      return;
    }

    try {
      if (_customerRepository is RemoteCustomerWorkspaceRepository &&
          !await _refreshRemoteWorkspace(announce: false)) {
        return;
      }
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty || !mounted) return;

      final file = selection.files.single;
      if (file.size > 5 * 1024 * 1024) {
        throw const FormatException('CSV files must be 5 MB or smaller.');
      }
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('The selected CSV file could not be read.');
      }
      final contents = utf8.decode(bytes).replaceFirst('\uFEFF', '');
      final preview = _parseCustomerCsv(contents);
      if (preview.entries.isEmpty) {
        throw const FormatException('The CSV contains no client rows.');
      }

      final customers = await showDialog<List<Customer>>(
        context: context,
        builder: (context) => CsvImportPreviewDialog(preview: preview),
      );
      if (customers == null || customers.isEmpty || !mounted) return;
      await _saveCustomers(
        [...customers, ..._customers],
        confirmation:
            '${customers.length} client${customers.length == 1 ? '' : 's'} imported.',
        delivery: _delivery.copyWith(
          importRecords: [
            ..._delivery.importRecords,
            StudioImportRecord(
              id: 'import-${DateTime.now().microsecondsSinceEpoch}',
              kind: 'Client CSV',
              fileName: file.name,
              status: 'Completed',
              importedCount: customers.length,
              failedCount: preview.entries
                  .where((entry) => entry.issue != null)
                  .length,
              errors: preview.entries
                  .where((entry) => entry.issue != null)
                  .map((entry) => entry.issue!)
                  .toList(),
              createdAt: DateTime.now().toUtc(),
            ),
          ],
        ),
        activity: _activity(
          kind: 'csv_import',
          title: 'Clients imported from CSV',
          details:
              '${customers.length} client${customers.length == 1 ? '' : 's'} added.',
        ),
      );
    } on FormatException catch (error) {
      if (mounted) _toast(error.message);
    } on Exception catch (error) {
      if (mounted) _toast('Could not import the CSV file: $error');
    }
  }

  CsvImportPreview _parseCustomerCsv(String contents) {
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(contents);
    if (rows.isEmpty) {
      throw const FormatException('The CSV file is empty.');
    }
    if (rows.length > 5001) {
      throw const FormatException('A CSV may contain up to 5,000 client rows.');
    }

    String normalizeHeader(Object? value) {
      final header = value?.toString().trim().toLowerCase() ?? '';
      return switch (header) {
        'client' ||
        'client_name' ||
        'customer' ||
        'customer_name' ||
        'full_name' => 'name',
        'email_address' => 'email',
        'phone_number' => 'phone',
        'project_name' || 'residence' => 'project',
        'lead_stage' => 'stage',
        'estimated_budget' => 'budget',
        _ => header.replaceAll(RegExp(r'[\s-]+'), '_'),
      };
    }

    final columns = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      final header = normalizeHeader(rows.first[index]);
      if (header.isEmpty) continue;
      if (columns.containsKey(header)) {
        throw FormatException('The CSV contains a duplicate "$header" column.');
      }
      columns[header] = index;
    }
    if (!columns.containsKey('name')) {
      throw const FormatException('The CSV must include a "name" column.');
    }

    String cell(List<dynamic> row, String column) {
      final index = columns[column];
      if (index == null || index >= row.length) return '';
      return row[index]?.toString().trim() ?? '';
    }

    final entries = <CsvImportEntry>[];
    final seenCustomers = List<Customer>.of(_customers);
    final colors = [
      const Color(0xFFE9DDD0),
      const Color(0xFFDCE3DA),
      const Color(0xFFE9D9D5),
      const Color(0xFFE9E5D9),
    ];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every(
        (value) => value == null || value.toString().trim().isEmpty,
      )) {
        continue;
      }
      final rowNumber = rowIndex + 1;
      final name = cell(row, 'name');
      final email = cell(row, 'email');
      final phone = cell(row, 'phone');
      final project = cell(row, 'project');
      final stageText = cell(row, 'stage');
      final budgetText = cell(row, 'budget');
      final notes = cell(row, 'notes');

      String? issue;
      if (name.isEmpty) {
        issue = 'Client name is required.';
      } else if (email.isNotEmpty &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        issue = 'Email address is invalid.';
      }

      String? stage;
      if (stageText.isEmpty) {
        stage = _workspacePreferences.defaultPipelineStage;
      } else {
        for (final configuredStage in _pipelineStages) {
          if (configuredStage.toLowerCase() == stageText.toLowerCase()) {
            stage = configuredStage;
            break;
          }
        }
      }
      if (issue == null && stage == null) {
        issue = 'Unknown pipeline stage "$stageText".';
      }

      double? budget;
      if (issue == null && budgetText.isNotEmpty) {
        budget = double.tryParse(budgetText.replaceAll(RegExp(r'[$,\s]'), ''));
        if (budget == null || !budget.isFinite || budget < 0) {
          issue = 'Budget must be a non-negative number.';
        }
      }
      if (issue != null) {
        entries.add(
          CsvImportEntry(rowNumber: rowNumber, name: name, issue: issue),
        );
        continue;
      }

      final initials = name
          .split(RegExp(r'\s+'))
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
      final customer = Customer(
        id: 'csv-${DateTime.now().microsecondsSinceEpoch}-$rowNumber',
        name: name,
        project: project,
        stage: stage!,
        value: budget == null ? '—' : '\$${_formatAmount(budget)}',
        email: email,
        phone: phone,
        notes: notes,
        initials: initials,
        tint: colors[(rowIndex - 1) % colors.length],
      );
      final duplicate = _findDuplicateCustomer(customer, seenCustomers);
      if (duplicate != null) {
        entries.add(
          CsvImportEntry(
            rowNumber: rowNumber,
            name: name,
            duplicateReason: 'Matches ${duplicate.name}.',
          ),
        );
        continue;
      }
      seenCustomers.add(customer);
      entries.add(
        CsvImportEntry(
          rowNumber: rowNumber,
          name: name,
          customer: customer,
          defaultedStage: stageText.isEmpty,
        ),
      );
    }
    return CsvImportPreview(entries);
  }

  void _navigate(int index) {
    setState(() {
      _section = index;
      _query = '';
    });
  }

  List<StudioCommunication> get _unreadMentions =>
      _communications
          .where(
            (entry) =>
                _can(StudioPersona.viewCommunications) &&
                entry.mentionedPersonaIds.contains(_activePersona.id) &&
                !entry.readByPersonaIds.contains(_activePersona.id),
          )
          .toList()
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));

  void _openCommunications({
    String? clientId,
    String? projectId,
    String filter = 'All',
  }) {
    setState(() {
      _section = 8;
      _communicationClientFilter = clientId;
      _communicationProjectFilter = projectId;
      _communicationFilter = filter;
      _query = '';
    });
  }

  Future<void> _createCommunication({
    String channel = 'Internal note',
    String? clientId,
    String? projectId,
    String? vendorId,
    String? procurementRecordType,
    String? procurementRecordId,
    String? initialRecipient,
  }) async {
    if (_customersLoading || _savingCustomers) {
      _toast('Workspace data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageCommunications)) {
      _toast('This studio role cannot add to communication history.');
      return;
    }
    initialRecipient ??= vendorId == null
        ? null
        : _delivery.vendors
              .where((vendor) => vendor.id == vendorId)
              .firstOrNull
              ?.email;
    final draft = await showDialog<CommunicationDraft>(
      context: context,
      builder: (context) => CommunicationComposerDialog(
        customers: _customers,
        projects: _delivery.projects,
        personas: _personas,
        activePersonaId: _activePersona.id,
        initialChannel: channel,
        initialClientId: clientId,
        initialProjectId: projectId,
        initialRecipient: initialRecipient,
      ),
    );
    if (draft == null || !mounted) return;
    final client = draft.clientId == null ? null : _customerFor(draft.clientId);
    final project = projectId != null
        ? _projectFor(projectId)
        : draft.projectId == null
        ? null
        : _projectFor(draft.projectId!);
    final now = DateTime.now();
    final entry = StudioCommunication(
      id: _newId('communication'),
      clientId: client?.id,
      clientName: client?.name ?? '',
      vendorId: vendorId,
      procurementRecordType: procurementRecordType,
      procurementRecordId: procurementRecordId,
      projectId: project?.id,
      projectName: project?.name ?? '',
      channel: draft.channel,
      subject: draft.subject,
      body: draft.body,
      recipient: draft.recipient,
      status: draft.status,
      createdByPersonaId: _activePersona.id,
      createdByName: _activePersona.name,
      createdAt: now,
      updatedAt: now,
      mentionedPersonaIds: draft.mentionedPersonaIds,
    );
    if (entry.status == 'Draft') {
      final action = await _chooseCommunicationDelivery(entry);
      if (action == null || !mounted) return;
      if (action == 'connected') {
        await _sendConnectedCommunication(entry);
        return;
      }
      if (action == 'draft') {
        await _saveCommunications(
          [entry, ..._communications],
          confirmation: 'Message draft saved.',
          activityTitle: '${draft.channel} draft saved',
          activityDetails: '${entry.clientName} · ${entry.subject}',
          clientId: entry.clientId,
        );
        return;
      }
    }
    await _saveCommunications(
      [entry, ..._communications],
      confirmation: entry.status == 'Received'
          ? 'Received message logged.'
          : entry.status == 'Draft'
          ? 'Message draft saved.'
          : 'Communication added to history.',
      activityTitle: '${draft.channel} added to communication history',
      activityDetails: [
        if (client != null) client.name,
        if (project != null) project.name,
        if (draft.mentionedPersonaIds.isNotEmpty)
          '${draft.mentionedPersonaIds.length} teammate mention(s)',
      ].join(' · '),
      clientId: client?.id,
    );
    if (!mounted || !_communications.any((saved) => saved.id == entry.id)) {
      return;
    }
    if (entry.status == 'Draft') {
      await _openExternalComposer(entry);
    }
  }

  Future<String?> _chooseCommunicationDelivery(
    StudioCommunication entry,
  ) async {
    final repository = _customerRepository;
    if (repository is! RemoteCustomerWorkspaceRepository) return 'external';
    final provider = entry.channel == 'Email' ? 'postal' : 'whatsapp';
    Map<String, String> integrations;
    try {
      integrations = await repository.loadCommunicationIntegrations();
    } on Exception catch (error) {
      if (mounted) {
        _toast('Could not check connected sender accounts: $error');
      }
      return 'external';
    }
    final accountHint = integrations[provider];
    if (accountHint == null) return 'external';
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        title: Text('Send ${entry.channel.toLowerCase()}'),
        content: Text(
          'A connected sender is available ($accountHint). Choose how to '
          'send this message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'draft'),
            child: const Text('Save draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'external'),
            child: const Text('Open messaging app'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(context, 'connected'),
            child: const Text('Send from connected account'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendConnectedCommunication(StudioCommunication entry) async {
    final repository = _customerRepository;
    if (repository is! RemoteCustomerWorkspaceRepository) {
      _toast('Connected sending requires the backend.');
      return;
    }
    if (_savingCustomers) {
      _toast('A workspace change is already being saved. Please try again.');
      return;
    }
    setState(() => _savingCustomers = true);
    try {
      final sent = await repository.sendCommunication(entry);
      if (!mounted) return;
      setState(() {
        _communications = [
          sent,
          ..._communications.where((item) => item.id != sent.id),
        ];
        _savingCustomers = false;
      });
      final activityTitle = sent.status == 'Failed'
          ? '${entry.channel} delivery failed'
          : '${entry.channel} sent';
      final activityDetails = '${entry.clientName} · ${entry.subject}';
      await _saveWorkspace(
        activities: [
          ..._activities,
          _activity(
            kind: 'communication',
            title: activityTitle,
            details: activityDetails,
            customer: entry.clientId == null
                ? null
                : _customerFor(entry.clientId),
          ),
        ],
        confirmation: sent.status == 'Failed'
            ? 'Delivery failed. Review the sender account before composing a retry.'
            : 'Message sent through the connected account.',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _toast('Could not confirm message delivery: $error');
      if (error is WorkspaceApiException &&
          error.code == 'integration_not_configured') {
        setState(() => _savingCustomers = false);
        await _saveCommunications(
          [entry, ..._communications],
          confirmation: 'Sender account is unavailable. Message draft saved.',
          activityTitle: '${entry.channel} draft saved',
          activityDetails: '${entry.clientName} · ${entry.subject}',
          clientId: entry.clientId,
        );
      } else {
        try {
          await _restoreCustomers();
        } on Exception catch (reloadError) {
          if (mounted) {
            _toast('Could not reload communication history: $reloadError');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _savingCustomers = false);
    }
  }

  Future<void> _openExternalComposer(StudioCommunication entry) async {
    if (!_can(StudioPersona.manageCommunications)) {
      _toast('This studio role cannot open an outbound message.');
      return;
    }
    final Uri uri;
    if (entry.channel == 'Email') {
      uri = Uri(
        scheme: 'mailto',
        path: entry.recipient,
        queryParameters: {
          if (entry.subject.isNotEmpty) 'subject': entry.subject,
          'body': entry.body,
        },
      );
    } else {
      final digits = entry.recipient.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8 || digits.length > 15) {
        _toast(
          'Add a valid international phone number before opening WhatsApp.',
        );
        return;
      }
      uri = Uri.https('wa.me', '/$digits', {'text': entry.body});
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await Clipboard.setData(ClipboardData(text: entry.body));
        if (mounted) {
          _toast(
            'Could not open a message app; the message was copied. Draft saved.',
          );
        }
        return;
      }
      final updated = entry.copyWith(
        status: 'Ready to send',
        updatedAt: DateTime.now(),
      );
      await _saveWorkspace(
        communications: _communications
            .map((item) => item.id == entry.id ? updated : item)
            .toList(),
        confirmation: 'Composer opened. Confirm the message is sent to update its history.',
      );
    } on Exception catch (error) {
      if (mounted) _toast('Could not open the message composer: $error');
    }
  }

  Future<void> _callCustomer(Customer customer) async {
    final phone = customer.phone.trim();
    if (phone.isEmpty) {
      _toast('Add a phone number for ${customer.name} before calling.');
      return;
    }

    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _toast('Could not open the phone app for ${customer.name}.');
      }
    } on Exception catch (error) {
      if (mounted) _toast('Could not start a call to ${customer.name}: $error');
    }
  }

  Future<void> _markCommunicationSent(StudioCommunication entry) async {
    if (!_can(StudioPersona.manageCommunications) ||
        !['Email', 'WhatsApp'].contains(entry.channel) ||
        !['Draft', 'Ready to send'].contains(entry.status)) {
      _toast('This message is not available to mark as sent.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Confirm message was sent'),
        content: const Text(
          'The app cannot verify delivery in your email or WhatsApp client. Mark this message as sent only if you completed sending it there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, mark sent'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = entry.copyWith(status: 'Sent', updatedAt: DateTime.now());
    await _saveCommunications(
      _communications
          .map((item) => item.id == entry.id ? updated : item)
          .toList(),
      confirmation: 'Message marked as sent.',
      activityTitle: '${entry.channel} marked sent',
      activityDetails: '${entry.clientName} · ${entry.subject}',
      clientId: entry.clientId,
    );
  }

  Future<void> _markMentionRead(StudioCommunication entry) async {
    if (!_unreadMentions.any((item) => item.id == entry.id)) return;
    final updated = entry.copyWith(
      readByPersonaIds: [...entry.readByPersonaIds, _activePersona.id],
      updatedAt: DateTime.now(),
    );
    await _saveWorkspace(
      communications: _communications
          .map((item) => item.id == entry.id ? updated : item)
          .toList(),
      confirmation: 'Mention marked as read.',
    );
  }

  Widget _communicationsPage() {
    if (!_can(StudioPersona.viewCommunications)) return _accessNotice();
    var entries = _communications.toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    if (_communicationClientFilter != null) {
      entries = entries
          .where((entry) => entry.clientId == _communicationClientFilter)
          .toList();
    }
    if (_communicationProjectFilter != null) {
      entries = entries
          .where((entry) => entry.projectId == _communicationProjectFilter)
          .toList();
    }
    entries = entries.where((entry) {
      final queryMatch =
          '${entry.clientName} ${entry.projectName} ${entry.subject} ${entry.body}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final filterMatch = switch (_communicationFilter) {
        'Mentions' => entry.mentionedPersonaIds.contains(_activePersona.id),
        'Email' || 'WhatsApp' => entry.channel == _communicationFilter,
        'Notes' => entry.channel == 'Internal note',
        _ => true,
      };
      return queryMatch && filterMatch;
    }).toList();
    final hasContext =
        _communicationClientFilter != null ||
        _communicationProjectFilter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('RELATIONSHIPS, CONSIDERED'),
        const SizedBox(height: 8),
        Text('Communication history', style: _heading(30)),
        const SizedBox(height: 7),
        Text(
          hasContext
              ? 'A dated record of the conversation for this client or project.'
              : 'Conversations, client messages, and teammate mentions in one place.',
          style: const TextStyle(
            fontFamily: 'Arial',
            color: muted,
            fontSize: 13,
          ),
        ),
        if (_can(StudioPersona.manageCommunications)) ...[
          const SizedBox(height: 15),
          Wrap(
            spacing: 9,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ink),
                onPressed: () => _createCommunication(
                  clientId: _communicationClientFilter,
                  projectId: _communicationProjectFilter,
                ),
                icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                label: const Text('Add note'),
              ),
              OutlinedButton.icon(
                onPressed: () => _createCommunication(
                  channel: 'Email',
                  clientId: _communicationClientFilter,
                  projectId: _communicationProjectFilter,
                ),
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('Email'),
              ),
              OutlinedButton.icon(
                onPressed: () => _createCommunication(
                  channel: 'WhatsApp',
                  clientId: _communicationClientFilter,
                  projectId: _communicationProjectFilter,
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: () => _createCommunication(
                  channel: 'Call',
                  clientId: _communicationClientFilter,
                  projectId: _communicationProjectFilter,
                ),
                icon: const Icon(Icons.call_outlined, size: 16),
                label: const Text('Log a call'),
              ),
              if (_can(StudioPersona.configureWorkspace) &&
                  _customerRepository is RemoteCustomerWorkspaceRepository)
                OutlinedButton.icon(
                  onPressed: _configureCommunicationIntegrations,
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Sender accounts'),
                ),
            ],
          ),
        ],
        if (hasContext)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openCommunications(),
              icon: const Icon(Icons.close, size: 15),
              label: const Text('Clear context'),
            ),
          ),
        const SizedBox(height: 14),
        if (_unreadMentions.isNotEmpty && _communicationFilter != 'Mentions')
          _deliveryPanel(
            'Mentions for ${_activePersona.name}',
            '${_unreadMentions.length} unread teammate notification(s)',
            child: Column(
              children: _unreadMentions.take(3).map(_communicationRow).toList(),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ['All', 'Mentions', 'Email', 'WhatsApp', 'Notes']
              .map(
                (filter) => ChoiceChip(
                  label: Text(filter),
                  selected: _communicationFilter == filter,
                  onSelected: (_) =>
                      setState(() => _communicationFilter = filter),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: entries.isEmpty
              ? _emptyDeliveryCard(
                  _communications.isEmpty
                      ? 'Start a client conversation'
                      : 'No matching communication',
                  _communications.isEmpty
                      ? 'Log a note or prepare an email or WhatsApp message. Entries stay on this device.'
                      : 'Try another filter or search term.',
                )
              : Column(children: entries.map(_communicationRow).toList()),
        ),
        const SizedBox(height: 12),
        _featureNote(
          'Messages open in your own apps',
          'Email and WhatsApp drafts are handed off to the installed client. This prototype does not send messages or verify delivery; mark one sent only after you send it.',
        ),
      ],
    );
  }

  Widget _communicationRow(StudioCommunication entry) {
    final isUnread = _unreadMentions.any((item) => item.id == entry.id);
    final mentioned = entry.mentionedPersonaIds
        .map((id) => _personas.where((persona) => persona.id == id))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first.name)
        .toList();
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(entry.createdAt.toLocal());
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(entry.createdAt.toLocal()));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: isUnread
                ? const Color(0xFFE9DDD0)
                : const Color(0xFFECEAE3),
            child: Icon(
              switch (entry.channel) {
                'Email' => Icons.mail_outline,
                'WhatsApp' => Icons.chat_bubble_outline,
                'Call' => Icons.call_outlined,
                'Meeting' => Icons.calendar_today_outlined,
                _ => Icons.sticky_note_2_outlined,
              },
              size: 16,
              color: ink,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.subject.isEmpty ? entry.channel : entry.subject} · ${entry.clientName.isEmpty ? entry.projectName : entry.clientName}',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (entry.projectName.isNotEmpty)
                  Text(
                    entry.projectName,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  entry.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.channel} · ${entry.status} · $date · $time · ${entry.createdByName}'
                  '${mentioned.isEmpty ? '' : ' · @${mentioned.join(', @')}'}',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (isUnread)
            IconButton(
              tooltip: 'Mark mention as read',
              onPressed: () => _markMentionRead(entry),
              icon: const Icon(
                Icons.mark_email_read_outlined,
                size: 18,
                color: accent,
              ),
            )
          else if (_can(StudioPersona.manageCommunications) &&
              ['Email', 'WhatsApp'].contains(entry.channel) &&
              ['Draft', 'Ready to send'].contains(entry.status))
            PopupMenuButton<String>(
              tooltip: 'Message actions',
              onSelected: (action) {
                if (action == 'open') _openExternalComposer(entry);
                if (action == 'sent') _markCommunicationSent(entry);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'open',
                  child: Text('Open ${entry.channel}'),
                ),
                const PopupMenuItem(value: 'sent', child: Text('Mark as sent')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _addCustomer() async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageClients)) {
      _toast('This studio role cannot add client records.');
      return;
    }
    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerEditorDialog(
        stages: _pipelineStages,
        initialStage: _workspacePreferences.defaultPipelineStage,
        allowFinancials: _can(StudioPersona.viewFinancials),
      ),
    );
    if (customer == null || !mounted) return;
    if (_hasDuplicateCustomer(customer)) {
      _toast(
        'A client with that email address or phone number already exists.',
      );
      return;
    }
    await _saveCustomers(
      [customer, ..._customers],
      confirmation: '${customer.name} added to your clients.',
      activity: _activity(
        kind: 'client_created',
        title: 'Client added',
        details: customer.project.isEmpty
            ? 'Added to ${customer.stage}.'
            : '${customer.project} · ${customer.stage}',
        customer: customer,
      ),
    );
  }

  Future<void> _editCustomer(Customer customer) async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageClients)) {
      _toast('This studio role cannot edit client records.');
      return;
    }
    final updated = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerEditorDialog(
        customer: customer,
        stages: _pipelineStages,
        allowFinancials: _can(StudioPersona.viewFinancials),
      ),
    );
    if (updated == null || !mounted) return;
    if (_hasDuplicateCustomer(updated, exceptId: customer.id)) {
      _toast(
        'A client with that email address or phone number already exists.',
      );
      return;
    }
    await _saveCustomers(
      _customers
          .map((item) => item.id == customer.id ? updated : item)
          .toList(),
      confirmation: '${updated.name} updated.',
      activity: _activity(
        kind: 'client_updated',
        title: 'Client details updated',
        details: 'Client contact and project details were edited.',
        customer: updated,
      ),
    );
  }

  bool _hasDuplicateCustomer(Customer customer, {String? exceptId}) {
    return _findDuplicateCustomer(customer, _customers, exceptId: exceptId) !=
        null;
  }

  Customer? _findDuplicateCustomer(
    Customer customer,
    Iterable<Customer> candidates, {
    String? exceptId,
  }) {
    final email = customer.email.trim().toLowerCase();
    final phone = customer.phone.replaceAll(RegExp(r'\D'), '');
    for (final existing in candidates) {
      if (existing.id == exceptId) continue;
      final sameEmail =
          email.isNotEmpty && existing.email.trim().toLowerCase() == email;
      final existingPhone = existing.phone.replaceAll(RegExp(r'\D'), '');
      final samePhone = phone.isNotEmpty && existingPhone == phone;
      if (sameEmail || samePhone) return existing;
    }
    return null;
  }

  Future<void> _showCustomer(Customer customer) async {
    if (!_can(StudioPersona.viewClients)) {
      _toast('This studio role cannot view client records.');
      return;
    }
    final customerActivities = _recentActivities
        .where((activity) => activity.customerId == customer.id)
        .take(4)
        .toList();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        scrollable: true,
        title: Text(customer.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _customerDetail('Stage', customer.stage),
              _customerDetail('Project', customer.project),
              if (_can(StudioPersona.viewFinancials))
                _customerDetail('Estimated budget', customer.value),
              _customerDetail('Email', customer.email),
              _customerDetail('Phone', customer.phone),
              if (customer.notes.isNotEmpty)
                _customerDetail('Notes', customer.notes),
              if (customer.requirement != null) ...[
                const Divider(height: 22),
                const Text(
                  'PROJECT REQUIREMENTS',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                _customerDetail(
                  'Rooms',
                  customer.requirement!.rooms.join(', '),
                ),
                _customerDetail('Style', customer.requirement!.style),
                if (_can(StudioPersona.viewFinancials))
                  _customerDetail(
                    'Budget',
                    _formatRequirementBudget(customer.requirement!),
                  ),
                _customerDetail(
                  'Timeline',
                  _formatRequirementTimeline(customer.requirement!),
                ),
                if (customer.requirement!.brief.isNotEmpty)
                  _customerDetail('Brief', customer.requirement!.brief),
              ],
              const Divider(height: 22),
              const Text(
                'ACTIVITY',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              if (customerActivities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No client activity recorded yet.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                ...customerActivities.map(_activityLine),
              if (_can(StudioPersona.viewCommunications)) ...[
                const Divider(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, 'communication_history'),
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: const Text('Open communication history'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_can(StudioPersona.manageCommunications))
            TextButton(
              onPressed: () => Navigator.pop(context, 'log'),
              child: const Text('Log interaction'),
            ),
          if (_can(StudioPersona.manageCommunications) &&
              customer.email.trim().isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, 'email'),
              child: const Text('Email'),
            ),
          if (_can(StudioPersona.manageCommunications) &&
              customer.phone.trim().isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, 'whatsapp'),
              child: const Text('WhatsApp'),
            ),
          if (_can(StudioPersona.manageRequirements))
            TextButton(
              onPressed: () => Navigator.pop(context, 'requirements'),
              child: Text(
                customer.requirement == null ? 'Capture brief' : 'Edit brief',
              ),
            ),
          if (_can(StudioPersona.manageClients)) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Edit client'),
            ),
          ],
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _editCustomer(customer);
    } else if (action == 'delete') {
      await _deleteCustomer(customer);
    } else if (action == 'requirements') {
      await _captureRequirements(customer);
    } else if (action == 'log') {
      await _logCustomerInteraction(customer);
    } else if (action == 'communication_history') {
      _openCommunications(clientId: customer.id);
    } else if (action == 'email') {
      _createCommunication(channel: 'Email', clientId: customer.id);
    } else if (action == 'whatsapp') {
      _createCommunication(channel: 'WhatsApp', clientId: customer.id);
    }
  }

  Future<void> _logCustomerInteraction(Customer customer) async {
    if (!_can(StudioPersona.manageCommunications)) {
      _toast('This studio role cannot add to communication history.');
      return;
    }
    final interaction = await showDialog<InteractionDraft>(
      context: context,
      builder: (context) => const InteractionDialog(),
    );
    if (interaction == null || !mounted) return;
    final now = DateTime.now();
    final channel = interaction.type == 'Note'
        ? 'Internal note'
        : interaction.type;
    final entry = StudioCommunication(
      id: _newId('communication'),
      clientId: customer.id,
      clientName: customer.name,
      projectId: null,
      projectName: '',
      channel: StudioCommunication.channels.contains(channel)
          ? channel
          : 'Other',
      subject: '',
      body: interaction.details,
      recipient: '',
      status: 'Logged',
      createdByPersonaId: _activePersona.id,
      createdByName: _activePersona.name,
      createdAt: now,
      updatedAt: now,
    );
    await _saveCommunications(
      [entry, ..._communications],
      clientId: customer.id,
      confirmation: '${interaction.type} added to ${customer.name}’s timeline.',
      activityTitle: '${interaction.type} logged',
      activityDetails: interaction.details,
    );
  }

  Future<void> _showActivityTimeline() async {
    if (!_can(StudioPersona.viewClients)) {
      _toast('This studio role cannot view client activity.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) =>
          ActivityTimelineDialog(activities: _recentActivities),
    );
  }

  String _formatRequirementBudget(ProjectRequirement requirements) {
    final minimum = requirements.budgetMin;
    final maximum = requirements.budgetMax;
    if (minimum == null && maximum == null) return 'Not specified';
    if (minimum == null) return 'Up to \$${_formatAmount(maximum!)}';
    if (maximum == null) return 'From \$${_formatAmount(minimum)}';
    return '\$${_formatAmount(minimum)} – \$${_formatAmount(maximum)}';
  }

  String _formatRequirementTimeline(ProjectRequirement requirements) {
    final start = requirements.startDate;
    final target = requirements.targetDate;
    if (start == null && target == null) return 'Not specified';
    if (start == null) return 'By ${_formatDate(target!)}';
    if (target == null) return 'From ${_formatDate(start)}';
    return '${_formatDate(start)} – ${_formatDate(target)}';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Widget _customerDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: muted,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: ink,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _deleteCustomer(Customer customer) async {
    if (_customersLoading || _savingCustomers) {
      _toast('Client data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageClients)) {
      _toast('This studio role cannot remove client records.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Remove this client?'),
        content: Text(
          '${customer.name} will be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove client'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _saveCustomers(
      _customers.where((item) => item.id != customer.id).toList(),
      confirmation: '${customer.name} removed.',
      delivery: _delivery.copyWith(
        projects: _delivery.projects
            .map(
              (project) => project.customerId == customer.id
                  ? StudioProject(
                      id: project.id,
                      name: project.name,
                      location: project.location,
                      status: project.status,
                      customerId: null,
                      targetDate: project.targetDate,
                    )
                  : project,
            )
            .toList(),
      ),
      communications: _communications
          .map(
            (entry) => entry.clientId == customer.id
                ? entry.copyWith(clearClient: true)
                : entry,
          )
          .toList(),
      activity: _activity(
        kind: 'client_deleted',
        title: 'Client removed',
        details: 'Client record removed from the workspace.',
        customer: customer,
      ),
    );
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  String _dateLabel(DateTime? date) => date == null
      ? 'No date'
      : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());

  Future<void> _createProject() async {
    if (!_can(StudioPersona.manageProjects)) {
      _toast('This studio role cannot create projects.');
      return;
    }
    final project = await showDialog<StudioProject>(
      context: context,
      builder: (context) => ProjectEditorDialog(
        customers: _customers,
        canViewBudget:
            _can(StudioPersona.viewFinancials) ||
            _can(StudioPersona.manageFinancials),
        canManageBudget: _can(StudioPersona.manageFinancials),
        project: StudioProject(
          id: _newId('project'),
          name: '',
          location: '',
          status: StudioProject.statuses.first,
          customerId: null,
          targetDate: null,
        ),
      ),
    );
    if (project == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(projects: [..._delivery.projects, project]),
      confirmation: '${project.name} created.',
      activityTitle: 'Project created',
      activityDetails: project.name,
    );
  }

  Future<void> _editProject(StudioProject project) async {
    if (!_can(StudioPersona.manageProjects)) {
      _toast('This studio role cannot edit projects.');
      return;
    }
    final updated = await showDialog<StudioProject>(
      context: context,
      builder: (context) => ProjectEditorDialog(
        customers: _customers,
        canViewBudget:
            _can(StudioPersona.viewFinancials) ||
            _can(StudioPersona.manageFinancials),
        canManageBudget: _can(StudioPersona.manageFinancials),
        project: project,
      ),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        projects: _delivery.projects
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: '${updated.name} updated.',
      activityTitle: 'Project updated',
      activityDetails: updated.name,
    );
  }

  Future<void> _createProjectPhase(StudioProject project) async {
    if (!_can(StudioPersona.manageMilestones)) {
      _toast('This studio role cannot manage project phases.');
      return;
    }
    final phase = await showDialog<StudioProjectPhase>(
      context: context,
      builder: (context) => ProjectPhaseEditorDialog(
        phase: StudioProjectPhase(
          id: _newId('phase'),
          projectId: project.id,
          name: '',
          position:
              _delivery.phases
                  .where((item) => item.projectId == project.id)
                  .fold<int>(
                    -1,
                    (maximum, item) =>
                        item.position > maximum ? item.position : maximum,
                  ) +
              1,
          status: StudioProjectPhase.statuses.first,
          startDate: null,
          endDate: null,
        ),
      ),
    );
    if (phase == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(phases: [..._delivery.phases, phase]),
      confirmation: 'Project phase added.',
      activityTitle: 'Project phase added',
      activityDetails: '${project.name} · ${phase.name}',
    );
  }

  Future<void> _editProjectPhase(StudioProjectPhase phase) async {
    if (!_can(StudioPersona.manageMilestones)) return;
    final updated = await showDialog<StudioProjectPhase>(
      context: context,
      builder: (context) => ProjectPhaseEditorDialog(phase: phase),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        phases: _delivery.phases
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: 'Project phase updated.',
      activityTitle: 'Project phase updated',
      activityDetails: updated.name,
    );
  }

  Future<void> _createMaterial() async {
    if (!_can(StudioPersona.manageMaterials)) {
      _toast('This studio role cannot manage materials.');
      return;
    }
    final material = await showDialog<StudioMaterial>(
      context: context,
      builder: (context) => MaterialEditorDialog(
        material: StudioMaterial(
          id: _newId('material'),
          name: '',
          category: StudioMaterial.categories.first,
          unit: StudioMaterial.units.first,
          specification: '',
          description: '',
          isActive: true,
        ),
      ),
    );
    if (material == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(materials: [..._delivery.materials, material]),
      confirmation: 'Material added to the catalogue.',
      activityTitle: 'Material catalogue updated',
      activityDetails: material.name,
    );
  }

  Future<void> _editMaterial(StudioMaterial material) async {
    if (!_can(StudioPersona.manageMaterials)) return;
    final updated = await showDialog<StudioMaterial>(
      context: context,
      builder: (context) => MaterialEditorDialog(material: material),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        materials: _delivery.materials
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: 'Material record updated.',
      activityTitle: 'Material catalogue updated',
      activityDetails: updated.name,
    );
  }

  Future<void> _createVendor() async {
    if (!_can(StudioPersona.manageVendors)) {
      _toast('This studio role cannot manage suppliers or contractors.');
      return;
    }
    final vendor = await showDialog<StudioVendor>(
      context: context,
      builder: (context) => VendorEditorDialog(
        vendor: StudioVendor(
          id: _newId('vendor'),
          name: '',
          kind: StudioVendor.kinds.first,
          email: '',
          phone: '',
          address: '',
          taxId: '',
          paymentTerms: '',
          notes: '',
          isActive: true,
        ),
      ),
    );
    if (vendor == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(vendors: [..._delivery.vendors, vendor]),
      confirmation: 'Supplier or contractor added.',
      activityTitle: 'Vendor directory updated',
      activityDetails: vendor.name,
    );
  }

  Future<void> _editVendor(StudioVendor vendor) async {
    if (!_can(StudioPersona.manageVendors)) return;
    final updated = await showDialog<StudioVendor>(
      context: context,
      builder: (context) => VendorEditorDialog(vendor: vendor),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        vendors: _delivery.vendors
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: 'Vendor record updated.',
      activityTitle: 'Vendor directory updated',
      activityDetails: updated.name,
    );
  }

  void _openProject(StudioProject project) {
    setState(() => _selectedProjectId = project.id);
    _navigate(5);
  }

  Future<void> _addTask() => _createProjectTask();

  Future<void> _createProjectTask({String? projectId}) async {
    if (!_can(StudioPersona.manageTasks)) {
      _toast('This studio role cannot create tasks.');
      return;
    }
    if (_delivery.projects.isEmpty) {
      _toast('Create a project before adding a project task.');
      return;
    }
    final task = await showDialog<StudioTaskRecord>(
      context: context,
      builder: (context) => ProjectTaskEditorDialog(
        projects: _delivery.projects,
        personas: _personas,
        tasks: _delivery.tasks,
        task: StudioTaskRecord(
          id: _newId('task'),
          projectId: projectId ?? _delivery.projects.first.id,
          title: '',
          assignee: '',
          dueDate: null,
          isComplete: false,
          priority: 'Normal',
        ),
        loadProjectAssignees:
            widget.workspaceAccessClient?.loadProjectAssignees,
      ),
    );
    if (task == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(tasks: [task, ..._delivery.tasks]),
      confirmation: 'Task added to ${_projectFor(task.projectId)!.name}.',
      activityTitle: 'Project task created',
      activityDetails: task.title,
    );
  }

  Future<void> _editProjectTask(StudioTaskRecord task) async {
    if (!_can(StudioPersona.manageTasks)) {
      _toast('This studio role cannot edit project tasks.');
      return;
    }
    final updated = await showDialog<StudioTaskRecord>(
      context: context,
      builder: (context) => ProjectTaskEditorDialog(
        projects: _delivery.projects,
        personas: _personas,
        tasks: _delivery.tasks,
        task: task,
        loadProjectAssignees:
            widget.workspaceAccessClient?.loadProjectAssignees,
      ),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        tasks: _delivery.tasks
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
        workLogs: _delivery.workLogs
            .map(
              (log) => log.taskId == updated.id
                  ? log.copyWith(projectId: updated.projectId)
                  : log,
            )
            .toList(),
      ),
      confirmation: 'Task updated.',
      activityTitle: 'Project task updated',
      activityDetails: updated.title,
    );
  }

  Future<void> _toggleProjectTask(StudioTaskRecord task) async {
    if (!_can(StudioPersona.manageTasks)) {
      _toast('This studio role cannot update project tasks.');
      return;
    }
    await _saveDelivery(
      _delivery.copyWith(
        tasks: _delivery.tasks
            .map(
              (item) => item.id == task.id
                  ? item.copyWith(isComplete: !item.isComplete)
                  : item,
            )
            .toList(),
      ),
      confirmation: task.isComplete ? 'Task reopened.' : 'Task completed.',
      activityTitle: task.isComplete ? 'Task reopened' : 'Task completed',
      activityDetails: task.title,
    );
  }

  Future<void> _createMilestone(StudioProject project) async {
    if (!_can(StudioPersona.manageMilestones)) {
      _toast('This studio role cannot manage milestones.');
      return;
    }
    final milestone = await showDialog<StudioMilestone>(
      context: context,
      builder: (context) => MilestoneEditorDialog(
        projectId: project.id,
        phases: _delivery.phases
            .where((phase) => phase.projectId == project.id)
            .toList(),
        milestone: StudioMilestone(
          id: _newId('milestone'),
          projectId: project.id,
          title: '',
          dueDate: null,
          status: StudioMilestone.statuses.first,
          update: '',
          updatedAt: DateTime.now(),
        ),
      ),
    );
    if (milestone == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(milestones: [..._delivery.milestones, milestone]),
      confirmation: 'Milestone added.',
      activityTitle: 'Project milestone added',
      activityDetails: '${project.name} · ${milestone.title}',
    );
  }

  Future<void> _editMilestone(StudioMilestone milestone) async {
    if (!_can(StudioPersona.manageMilestones)) return;
    final updated = await showDialog<StudioMilestone>(
      context: context,
      builder: (context) => MilestoneEditorDialog(
        projectId: milestone.projectId,
        phases: _delivery.phases
            .where((phase) => phase.projectId == milestone.projectId)
            .toList(),
        milestone: milestone,
      ),
    );
    if (updated == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(
        milestones: _delivery.milestones
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: 'Milestone update saved.',
      activityTitle: 'Milestone updated',
      activityDetails:
          '${_projectFor(updated.projectId)?.name ?? ''} · ${updated.title} · ${updated.status}',
    );
  }

  Future<void> _createPunchItem(StudioProject project) async {
    if (!_can(StudioPersona.managePunchList)) {
      _toast('This studio role cannot manage punch-list items.');
      return;
    }
    final item = await showDialog<StudioPunchItem>(
      context: context,
      builder: (context) => PunchItemEditorDialog(
        projectId: project.id,
        personas: _personas,
        assignee: _activePersona.name,
      ),
    );
    if (item == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(punchItems: [..._delivery.punchItems, item]),
      confirmation: 'Punch-list item added.',
      activityTitle: 'Punch-list item added',
      activityDetails: '${project.name} · ${item.description}',
    );
  }

  Future<void> _updatePunchItem(StudioPunchItem item, String status) async {
    if (!_can(StudioPersona.managePunchList)) return;
    await _saveDelivery(
      _delivery.copyWith(
        punchItems: _delivery.punchItems
            .map(
              (record) => record.id == item.id
                  ? record.copyWith(status: status)
                  : record,
            )
            .toList(),
      ),
      confirmation: 'Punch-list status updated.',
      activityTitle: 'Punch-list item updated',
      activityDetails: '${_projectFor(item.projectId)?.name ?? ''} · $status',
    );
  }

  Future<void> _addProjectAsset(StudioProject project, String kind) async {
    if (_customersLoading || _savingCustomers) {
      _toast('Workspace data is still loading or saving. Please try again.');
      return;
    }
    if (!_can(StudioPersona.manageFiles)) {
      _toast('This studio role cannot upload project files.');
      return;
    }
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: kind == 'photo' ? FileType.image : FileType.any,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty || !mounted) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _toast('The selected file could not be read.');
        return;
      }
      if (bytes.length > StudioProjectAsset.maxFileBytes) {
        _toast('Each project file must be 1 MB or smaller.');
        return;
      }
      if (_delivery.totalAssetBytes + bytes.length >
          StudioProjectAsset.maxTotalBytes) {
        _toast('Project files are limited to 2 MB per device workspace.');
        return;
      }
      final caption = kind == 'photo'
          ? await showDialog<String>(
              context: context,
              builder: (context) => const PhotoCaptionDialog(),
            )
          : '';
      if (caption == null || !mounted) return;
      final extension = file.extension?.toLowerCase() ?? '';
      final mimeType = _mimeType(extension);
      if (!StudioProjectAsset.allowedMimeTypes.contains(mimeType)) {
        _toast('This file type is not supported for project storage.');
        return;
      }
      final assetId = _newId(kind);
      final repository = _customerRepository;
      String? storagePath;
      if (repository is RemoteCustomerWorkspaceRepository) {
        setState(() => _savingCustomers = true);
        try {
          storagePath = await repository.uploadProjectFile(
            projectId: project.id,
            assetId: assetId,
            mimeType: mimeType,
            bytes: Uint8List.fromList(bytes),
          );
        } finally {
          if (mounted) setState(() => _savingCustomers = false);
        }
      }
      final asset = StudioProjectAsset(
        id: assetId,
        projectId: project.id,
        name: file.name,
        mimeType: mimeType,
        kind: kind,
        caption: caption,
        dataBase64: storagePath == null ? base64Encode(bytes) : '',
        addedBy: _activePersona.name,
        addedAt: DateTime.now(),
        storagePath: storagePath,
        byteLength: bytes.length,
      );
      await _saveDelivery(
        _delivery.copyWith(assets: [..._delivery.assets, asset]),
        confirmation: kind == 'photo'
            ? 'Progress photo added.'
            : 'Project file uploaded.',
        activityTitle: kind == 'photo'
            ? 'Progress photo added'
            : 'Project file uploaded',
        activityDetails: '${project.name} · ${file.name}',
      );
    } on Exception catch (error) {
      if (mounted) _toast('Could not add the project file: $error');
    }
  }

  String _mimeType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };

  Future<void> _viewProjectAsset(StudioProjectAsset asset) async {
    if (!_can(StudioPersona.viewFiles)) {
      _toast('This studio role cannot view project files.');
      return;
    }
    var previewAsset = asset;
    final repository = _customerRepository;
    if (asset.bytes.isEmpty &&
        asset.storagePath != null &&
        repository is RemoteCustomerWorkspaceRepository) {
      try {
        final bytes = await repository.downloadProjectFile(asset);
        previewAsset = asset.copyWith(dataBase64: base64Encode(bytes));
      } on Exception catch (error) {
        if (mounted) _toast('Could not load ${asset.name}: $error');
        return;
      }
    }
    await showDialog<void>(
      context: context,
      builder: (context) => ProjectAssetPreviewDialog(
        asset: previewAsset,
        canManage: _can(StudioPersona.manageFiles),
        onDownload: () => _downloadProjectAsset(asset),
        onDelete: () => _deleteProjectAsset(asset),
      ),
    );
  }

  Future<void> _downloadProjectAsset(StudioProjectAsset asset) async {
    if (!_can(StudioPersona.viewFiles)) {
      _toast('This studio role cannot download project files.');
      return;
    }
    try {
      final repository = _customerRepository;
      final bytes = asset.bytes.isNotEmpty
          ? asset.bytes
          : repository is RemoteCustomerWorkspaceRepository
          ? await repository.downloadProjectFile(asset)
          : throw const FormatException('The project file data is missing.');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save project file',
        fileName: asset.name,
        bytes: Uint8List.fromList(bytes),
      );
      if (path != null && mounted) _toast('${asset.name} saved.');
    } on Exception catch (error) {
      if (mounted) _toast('Could not save ${asset.name}: $error');
    }
  }

  Future<void> _deleteProjectAsset(StudioProjectAsset asset) async {
    if (!_can(StudioPersona.manageFiles)) {
      _toast('This studio role cannot remove project files.');
      return;
    }
    await _saveDelivery(
      _delivery.copyWith(
        assets: _delivery.assets.where((item) => item.id != asset.id).toList(),
      ),
      confirmation: '${asset.name} removed.',
      activityTitle: 'Project file removed',
      activityDetails: asset.name,
    );
  }

  Future<void> _createWorkLog(StudioProject project) async {
    if (!_can(StudioPersona.manageWorkLogs)) {
      _toast('This studio role cannot record work logs.');
      return;
    }
    final log = await showDialog<StudioWorkLog>(
      context: context,
      builder: (context) => WorkLogEditorDialog(
        project: project,
        tasks: _delivery.tasks
            .where((task) => task.projectId == project.id)
            .toList(),
        author: _activePersona.name,
        id: _newId('worklog'),
      ),
    );
    if (log == null || !mounted) return;
    await _saveDelivery(
      _delivery.copyWith(workLogs: [log, ..._delivery.workLogs]),
      confirmation: 'Work log recorded.',
      activityTitle: 'Project work logged',
      activityDetails:
          '${project.name} · ${log.minutes} minutes · ${log.description}',
    );
  }

  Future<void> _recordAttendance() async {
    if (!_can(StudioPersona.manageAttendance)) {
      _toast('This studio role cannot record attendance.');
      return;
    }
    final record = await showDialog<StudioAttendance>(
      context: context,
      builder: (context) => AttendanceEditorDialog(
        personas: _personas,
        activePersona: _activePersona,
        id: _newId('attendance'),
      ),
    );
    if (record == null || !mounted) return;
    bool sameDay(DateTime first, DateTime second) =>
        first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
    final updatedRecords = _delivery.attendance
        .where(
          (item) =>
              item.personaId != record.personaId ||
              !sameDay(item.date, record.date),
        )
        .toList();
    await _saveDelivery(
      _delivery.copyWith(attendance: [record, ...updatedRecords]),
      confirmation: 'Attendance recorded for ${record.personaName}.',
      activityTitle: 'Attendance recorded',
      activityDetails: '${record.personaName} · ${record.status}',
    );
  }

  Future<void> _createApproval(
    StudioProject project, {
    StudioProposal? proposal,
  }) async {
    if (!_can(StudioPersona.manageApprovals)) {
      _toast('This studio role cannot submit approval requests.');
      return;
    }
    if (proposal != null &&
        _delivery.approvals.any(
          (approval) =>
              approval.relatedProposalId == proposal.id &&
              approval.status == 'Pending',
        )) {
      _toast('This proposal already has a pending approval request.');
      return;
    }
    if (proposal != null &&
        _financials.invoices.any(
          (invoice) => invoice.proposalId == proposal.id,
        )) {
      _toast('This proposal already has an invoice and cannot be re-routed.');
      return;
    }
    final approvers = _personas
        .where((persona) => persona.allows(StudioPersona.approveApprovals))
        .toList();
    if (approvers.isEmpty) {
      _toast('Configure a studio role with approval permission first.');
      return;
    }
    final approval = await showDialog<StudioApproval>(
      context: context,
      builder: (context) => ApprovalRequestDialog(
        project: project,
        approvers: approvers,
        requester: _activePersona.name,
        id: _newId('approval'),
        relatedProposalId: proposal?.id,
        initialTitle: proposal == null
            ? ''
            : 'Proposal ${proposal.number} approval',
      ),
    );
    if (approval == null || !mounted) return;
    final financials = proposal == null
        ? null
        : _financials.copyWith(
            proposals: _financials.proposals
                .map(
                  (item) => item.id == proposal.id
                      ? item.copyWith(
                          status: 'Pending approval',
                          updatedAt: DateTime.now(),
                        )
                      : item,
                )
                .toList(),
          );
    await _saveDelivery(
      _delivery.copyWith(approvals: [approval, ..._delivery.approvals]),
      confirmation: 'Approval request routed to ${approval.approverName}.',
      activityTitle: 'Approval request submitted',
      activityDetails: '${project.name} · ${approval.title}',
      financials: financials,
    );
  }

  Future<void> _decideApproval(StudioApproval approval, String status) async {
    final assignedApprover =
        approval.approverPersonaId == _activePersona.id ||
        _can(StudioPersona.configureWorkspace);
    if (!_can(StudioPersona.approveApprovals) || !assignedApprover) {
      _toast('This request is assigned to ${approval.approverName}.');
      return;
    }
    final decision = await showDialog<ApprovalDecision>(
      context: context,
      builder: (context) =>
          ApprovalDecisionDialog(title: approval.title, status: status),
    );
    if (decision == null || !mounted) return;
    final financials = approval.relatedProposalId == null
        ? null
        : _financials.copyWith(
            proposals: _financials.proposals
                .map(
                  (proposal) => proposal.id == approval.relatedProposalId
                      ? proposal.copyWith(
                          status: decision.status,
                          updatedAt: DateTime.now(),
                        )
                      : proposal,
                )
                .toList(),
          );
    await _saveDelivery(
      _delivery.copyWith(
        approvals: _delivery.approvals
            .map(
              (item) => item.id == approval.id
                  ? item.decide(status: decision.status, note: decision.note)
                  : item,
            )
            .toList(),
      ),
      confirmation: 'Approval ${decision.status.toLowerCase()}.',
      activityTitle: 'Approval ${decision.status.toLowerCase()}',
      activityDetails:
          '${approval.title} · ${approval.projectId} · ${decision.note}',
      financials: financials,
    );
  }

  String _documentNumber(String prefix, int sequence) =>
      '$prefix${sequence.toString().padLeft(4, '0')}';

  int _availableSequence(
    String prefix,
    int start,
    Iterable<String> existingNumbers,
  ) {
    final existing = existingNumbers.toSet();
    var sequence = start;
    while (existing.contains(_documentNumber(prefix, sequence))) {
      sequence++;
    }
    return sequence;
  }

  String _formatCurrency(double amount, String symbol) {
    return _formatCurrencyAmount(amount, symbol);
  }

  Future<void> _createQuotation() async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot create quotations.');
      return;
    }
    if (!await _loadLineItemCatalog() || !mounted) return;
    final eligibleProjects = _delivery.projects
        .where((project) => _customerFor(project.customerId) != null)
        .toList();
    if (eligibleProjects.isEmpty) {
      _toast('Link a client to a project before creating a quotation.');
      return;
    }
    final now = DateTime.now();
    final settings = _financials.settings;
    final sequence = _availableSequence(
      settings.quotationPrefix,
      settings.nextQuotationNumber,
      _financials.quotations.map((item) => item.number),
    );
    final project = eligibleProjects.first;
    final client = _customerFor(project.customerId)!;
    final quotation = await Navigator.of(context).push<StudioQuotation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => QuotationEditorPage(
          quotation: StudioQuotation(
            id: _newId('quotation'),
            number: _documentNumber(settings.quotationPrefix, sequence),
            projectId: project.id,
            projectName: project.name,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
            title: 'Interior design scope — ${project.name}',
            items: const [],
            taxRate: settings.defaultTaxRate,
            currencySymbol: settings.currencySymbol,
            createdAt: now,
            updatedAt: now,
          ),
          catalog: _lineItemCatalog,
        ),
      ),
    );
    if (quotation == null || !mounted) return;
    await _saveFinancials(
      _financials.copyWith(
        quotations: [quotation, ..._financials.quotations],
        settings: settings.copyWith(nextQuotationNumber: sequence + 1),
      ),
      confirmation: '${quotation.number} saved.',
      activityTitle: 'Quotation created',
      activityDetails: '${quotation.number} · ${quotation.projectName}',
    );
  }

  Future<void> _editQuotation(StudioQuotation quotation) async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot edit quotations.');
      return;
    }
    if (!await _loadLineItemCatalog() || !mounted) return;
    final updated = await Navigator.of(context).push<StudioQuotation>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => QuotationEditorPage(
          quotation: quotation,
          catalog: _lineItemCatalog,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    await _saveFinancials(
      _financials.copyWith(
        quotations: _financials.quotations
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
      confirmation: '${updated.number} updated.',
      activityTitle: 'Quotation updated',
      activityDetails: '${updated.number} · ${updated.projectName}',
    );
  }

  Future<void> _generateProposal(StudioQuotation quotation) async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot generate proposals.');
      return;
    }
    if (quotation.items.isEmpty) {
      _toast('Add at least one quotation item before generating a proposal.');
      return;
    }
    final draft = await showDialog<ProposalDraft>(
      context: context,
      builder: (context) => ProposalGenerationDialog(
        quotation: quotation,
        templates: _financials.templates,
        defaultTerms: _financials.settings.defaultTerms,
      ),
    );
    if (draft == null || !mounted) return;
    StudioDocumentTemplate? template;
    for (final item in _financials.templates) {
      if (item.id == draft.templateId) {
        template = item;
        break;
      }
    }
    if (template == null) {
      _toast('The selected document template is no longer available.');
      return;
    }
    final now = DateTime.now();
    final settings = _financials.settings;
    final sequence = _availableSequence(
      settings.proposalPrefix,
      settings.nextProposalNumber,
      _financials.proposals.map((item) => item.number),
    );
    final requirement = _customerFor(quotation.clientId)?.requirement;
    final proposal = StudioProposal(
      id: _newId('proposal'),
      number: _documentNumber(settings.proposalPrefix, sequence),
      quotationId: quotation.id,
      projectId: quotation.projectId,
      projectName: quotation.projectName,
      clientId: quotation.clientId,
      clientName: quotation.clientName,
      clientEmail: quotation.clientEmail,
      title: draft.title,
      requirementRooms: List.of(requirement?.rooms ?? const <String>[]),
      designStyle: requirement?.style ?? '',
      projectBrief: requirement?.brief ?? '',
      budgetMin: requirement?.budgetMin,
      budgetMax: requirement?.budgetMax,
      startDate: requirement?.startDate,
      targetDate: requirement?.targetDate,
      brandName: template.brandName.trim().isEmpty
          ? _workspacePreferences.studioName
          : template.brandName.trim(),
      introduction: draft.introduction,
      terms: draft.terms,
      footer: template.footer,
      accentColor: template.accentColor,
      sectionOrder: List.of(template.sectionOrder),
      items: List.of(quotation.items),
      taxRate: quotation.taxRate,
      currencySymbol: quotation.currencySymbol,
      status: 'Draft',
      createdAt: now,
      updatedAt: now,
    );
    await _saveFinancials(
      _financials.copyWith(
        proposals: [proposal, ..._financials.proposals],
        settings: settings.copyWith(nextProposalNumber: sequence + 1),
      ),
      confirmation: '${proposal.number} generated.',
      activityTitle: 'Proposal generated',
      activityDetails: '${proposal.number} · ${proposal.projectName}',
    );
  }

  Future<void> _previewProposal(StudioProposal proposal) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ProposalPreviewDialog(
        proposal: proposal,
        onExport: () => _exportProposal(proposal),
      ),
    );
  }

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  Future<void> _exportProposal(StudioProposal proposal) async {
    try {
      final accentColor = (proposal.accentColor & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0');
      final lineRows = proposal.items.map((item) {
        return '<tr><td>${_escapeHtml(item.description)}</td>'
            '<td>${item.quantity}</td><td>${_escapeHtml(item.unit)}</td>'
            '<td>${_escapeHtml(_formatCurrency(item.unitRate, proposal.currencySymbol))}</td>'
            '<td>${_escapeHtml(_formatCurrency(item.amount, proposal.currencySymbol))}</td></tr>';
      }).join();
      final briefDetails = <String>[];
      if (proposal.designStyle.isNotEmpty) {
        briefDetails.add(
          '<p><strong>Design direction:</strong> ${_escapeHtml(proposal.designStyle)}</p>',
        );
      }
      if (proposal.requirementRooms.isNotEmpty) {
        briefDetails.add(
          '<p><strong>Spaces:</strong> ${_escapeHtml(proposal.requirementRooms.join(', '))}</p>',
        );
      }
      if (proposal.startDate != null || proposal.targetDate != null) {
        final timeline = [
          if (proposal.startDate != null)
            'Starts ${_escapeHtml(_dateLabel(proposal.startDate))}',
          if (proposal.targetDate != null)
            'Target ${_escapeHtml(_dateLabel(proposal.targetDate))}',
        ].join(' · ');
        briefDetails.add('<p><strong>Timeline:</strong> $timeline</p>');
      }
      if (proposal.budgetMin != null || proposal.budgetMax != null) {
        final minimum = proposal.budgetMin == null
            ? '—'
            : _escapeHtml(
                _formatCurrency(proposal.budgetMin!, proposal.currencySymbol),
              );
        final maximum = proposal.budgetMax == null
            ? '—'
            : _escapeHtml(
                _formatCurrency(proposal.budgetMax!, proposal.currencySymbol),
              );
        briefDetails.add(
          '<p><strong>Client budget:</strong> $minimum – $maximum</p>',
        );
      }
      if (proposal.projectBrief.trim().isNotEmpty) {
        briefDetails.add(
          '<p><strong>Project brief:</strong> ${_escapeHtml(proposal.projectBrief)}</p>',
        );
      }
      final sections = <String, String>{
        'cover':
            '<header><p>${_escapeHtml(proposal.brandName)}</p>'
            '<h1>${_escapeHtml(proposal.title)}</h1>'
            '<p>${_escapeHtml(proposal.number)} · ${_escapeHtml(proposal.projectName)}</p>'
            '<p>Prepared for ${_escapeHtml(proposal.clientName)}</p></header>',
        'overview':
            '<section><h2>Project overview</h2>'
            '<p>${_escapeHtml(proposal.introduction)}</p>${briefDetails.join()}'
            '</section>',
        'scope':
            '<section><h2>Scope of work</h2><table><thead><tr>'
            '<th>Description</th><th>Qty</th><th>Unit</th><th>Rate</th><th>Amount</th>'
            '</tr></thead><tbody>$lineRows</tbody></table></section>',
        'investment':
            '<section><h2>Investment</h2>'
            '<p>Subtotal: ${_escapeHtml(_formatCurrency(proposal.subtotal, proposal.currencySymbol))}</p>'
            '<p>Tax (${proposal.taxRate.toStringAsFixed(2)}%): '
            '${_escapeHtml(_formatCurrency(proposal.taxAmount, proposal.currencySymbol))}</p>'
            '<h3>Total: ${_escapeHtml(_formatCurrency(proposal.total, proposal.currencySymbol))}</h3></section>',
        'terms':
            '<section><h2>Terms</h2><p>${_escapeHtml(proposal.terms)}</p></section>',
        'footer': '<footer>${_escapeHtml(proposal.footer)}</footer>',
      };
      final content = proposal.sectionOrder
          .map((section) => sections[section] ?? '')
          .join('\n');
      final html =
          '<!doctype html><html><head><meta charset="utf-8">'
          '<meta name="viewport" content="width=device-width, initial-scale=1">'
          '<title>${_escapeHtml(proposal.number)} · ${_escapeHtml(proposal.title)}</title>'
          '<style>body{font:16px Georgia,serif;color:#24332d;max-width:900px;margin:48px auto;padding:0 24px}'
          'header{border-bottom:3px solid #$accentColor;padding-bottom:24px;margin-bottom:32px}'
          'header p:first-child,h2{color:#$accentColor}h1{font-size:38px}section{margin:28px 0}'
          'table{width:100%;border-collapse:collapse;font:14px Arial,sans-serif}'
          'th,td{text-align:left;padding:10px;border-bottom:1px solid #e9e6de}'
          'footer{margin-top:48px;color:#777;font-size:13px}</style></head>'
          '<body>$content</body></html>';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export client proposal',
        fileName: '${proposal.number}.html',
        bytes: Uint8List.fromList(utf8.encode(html)),
      );
      if (path != null && mounted) {
        _toast('${proposal.number} exported.');
      }
    } on Exception catch (error) {
      if (mounted) _toast('Could not export proposal: $error');
    }
  }

  Future<void> _manageTemplates() async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot manage document templates.');
      return;
    }
    final templates = await showDialog<List<StudioDocumentTemplate>>(
      context: context,
      builder: (context) =>
          DocumentTemplateManagerDialog(templates: _financials.templates),
    );
    if (templates == null || !mounted) return;
    await _saveFinancials(
      _financials.copyWith(templates: templates),
      confirmation: 'Document templates saved.',
      activityTitle: 'Document templates updated',
      activityDetails: '${templates.length} studio templates',
    );
  }

  Future<void> _editFinancialSettings() async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot change proposal settings.');
      return;
    }
    final settings = await showDialog<StudioFinancialSettings>(
      context: context,
      builder: (context) =>
          ProposalSettingsDialog(settings: _financials.settings),
    );
    if (settings == null || !mounted) return;
    await _saveFinancials(
      _financials.copyWith(settings: settings),
      confirmation: 'Proposal and invoice settings saved.',
      activityTitle: 'Financial settings updated',
      activityDetails:
          'Document numbering, currency, tax, and default terms updated.',
    );
  }

  Future<void> _prepareInvoice(StudioProposal proposal) async {
    if (!_can(StudioPersona.manageFinancials)) {
      _toast('This studio role cannot prepare invoices.');
      return;
    }
    if (proposal.status != 'Approved') {
      _toast('Only approved proposals can be invoiced.');
      return;
    }
    if (_financials.invoices.any(
      (invoice) => invoice.proposalId == proposal.id,
    )) {
      _toast('An invoice has already been prepared for this proposal.');
      return;
    }
    final draft = await showDialog<InvoiceDraft>(
      context: context,
      builder: (context) => InvoiceEditorDialog(proposal: proposal),
    );
    if (draft == null || !mounted) return;
    final settings = _financials.settings;
    final sequence = _availableSequence(
      settings.invoicePrefix,
      settings.nextInvoiceNumber,
      _financials.invoices.map((item) => item.number),
    );
    final invoice = StudioInvoice(
      id: _newId('invoice'),
      number: _documentNumber(settings.invoicePrefix, sequence),
      proposalId: proposal.id,
      projectId: proposal.projectId,
      projectName: proposal.projectName,
      clientId: proposal.clientId,
      clientName: proposal.clientName,
      clientEmail: proposal.clientEmail,
      title: proposal.title,
      items: List.of(proposal.items),
      taxRate: proposal.taxRate,
      currencySymbol: proposal.currencySymbol,
      issuedAt: DateTime.now(),
      dueDate: draft.dueDate,
      memo: draft.memo,
      status: 'Draft',
      paidAmount: 0,
    );
    await _saveFinancials(
      _financials.copyWith(
        invoices: [invoice, ..._financials.invoices],
        settings: settings.copyWith(nextInvoiceNumber: sequence + 1),
      ),
      confirmation: '${invoice.number} prepared as a draft.',
      activityTitle: 'Invoice prepared',
      activityDetails: '${invoice.number} · ${invoice.clientName}',
    );
  }

  Future<void> _markInvoiceSent(StudioInvoice invoice) async {
    if (!_can(StudioPersona.manageFinancials) || invoice.status != 'Draft') {
      _toast('This studio role cannot send this invoice.');
      return;
    }
    await _saveFinancials(
      _financials.copyWith(
        invoices: _financials.invoices
            .map(
              (item) =>
                  item.id == invoice.id ? item.copyWith(status: 'Sent') : item,
            )
            .toList(),
      ),
      confirmation: '${invoice.number} marked as sent.',
      activityTitle: 'Invoice marked sent',
      activityDetails: '${invoice.number} · ${invoice.clientName}',
    );
  }

  Future<void> _recordInvoicePayment(StudioInvoice invoice) async {
    if (!_can(StudioPersona.manageFinancials) ||
        invoice.status == 'Draft' ||
        invoice.status == 'Paid') {
      _toast('This invoice is not available for payment updates.');
      return;
    }
    final payment = await showDialog<double>(
      context: context,
      builder: (context) => InvoicePaymentDialog(invoice: invoice),
    );
    if (payment == null || !mounted) return;
    final paidAmount = double.parse(
      (invoice.paidAmount + payment).toStringAsFixed(2),
    );
    final status = paidAmount >= invoice.total
        ? 'Paid'
        : paidAmount > 0
        ? 'Partially paid'
        : 'Sent';
    await _saveFinancials(
      _financials.copyWith(
        invoices: _financials.invoices
            .map(
              (item) => item.id == invoice.id
                  ? item.copyWith(status: status, paidAmount: paidAmount)
                  : item,
            )
            .toList(),
      ),
      confirmation: 'Payment recorded for ${invoice.number}.',
      activityTitle: 'Invoice payment recorded',
      activityDetails:
          '${invoice.number} · ${_formatCurrency(payment, invoice.currencySymbol)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _topbar(wide),
                  Expanded(child: _pageBody(wide)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide ? null : _mobileNavigation(),
    );
  }

  Widget _sidebar() => Container(
    width: 238,
    decoration: const BoxDecoration(
      color: paper,
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 28, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'S R A V Y A',
                style: TextStyle(
                  color: ink,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'STUDIO MANAGEMENT',
                style: TextStyle(
                  color: muted,
                  fontFamily: 'Arial',
                  letterSpacing: 1.25,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 0, 0, 12),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: muted,
              fontFamily: 'Arial',
              letterSpacing: 1.4,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...List.generate(_sections.length, (index) {
          final item = _sections[index];
          final selected = _section == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                selected: selected,
                selectedTileColor: const Color(0xFFF0EEE8),
                leading:
                    Icon(item.$2, size: 18, color: selected ? ink : muted),
                title: Text(
                  item.$1,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 12,
                    color: selected ? ink : const Color(0xFF62645E),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                onTap: () => _navigate(index),
              ),
            ),
          );
        }),
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFFF5F1E9),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: accent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thoughtful spaces.\nSeamless operations.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: line),
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE7DED2),
            child: Text(
              _activePersona.name
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join(),
              style: const TextStyle(
                color: ink,
                fontFamily: 'Arial',
                fontSize: 9,
              ),
            ),
          ),
          title: Text(
            _workspacePreferences.studioName,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            widget.accessPersona == null
                ? 'Previewing ${_activePersona.name}'
                : 'Organization role · ${_activePersona.name}',
            style: TextStyle(fontFamily: 'Arial', fontSize: 10, color: muted),
          ),
          trailing: widget.onSignOut == null
              ? const Icon(Icons.keyboard_arrow_down, size: 18, color: muted)
              : PopupMenuButton<String>(
                  tooltip: 'Account options',
                  onSelected: (action) {
                    if (action == 'sign_out') _signOut();
                    if (action == 'switch_workspace') {
                      widget.onSwitchWorkspace?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.onSwitchWorkspace != null)
                      const PopupMenuItem(
                        value: 'switch_workspace',
                        child: Text('Switch organization'),
                      ),
                    const PopupMenuItem(
                      value: 'sign_out',
                      child: Text('Sign out'),
                    ),
                  ],
                ),
            onTap: _openOrganizationAccess,
          ),
        ),
      ],
    ),
  );

  Widget _topbar(bool wide) => Container(
    height: 70,
    padding: EdgeInsets.symmetric(horizontal: wide ? 34 : 18),
    decoration: const BoxDecoration(
      color: canvas,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!wide) ...[
          Expanded(
            child: Text(
              _workspacePreferences.studioName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
                color: ink,
              ),
            ),
          ),
        ] else
          Expanded(
            child: Text(
              _section == 0 ? 'Monday, November 16, 2026' : 'Your studio',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontFamily: 'Arial',
              ),
            ),
          ),
        if (_section == 1 || _section == 4 || _section == 6 || _section == 8)
          SizedBox(
            width: wide
                ? 230
                : MediaQuery.sizeOf(context).width < 380
                ? 100
                : 132,
            height: 38,
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        if (!wide &&
            ((_section == 4 && _can(StudioPersona.manageTasks)) ||
                (_section == 8 && _can(StudioPersona.manageCommunications)) ||
                (_section != 4 &&
                    _section != 6 &&
                    _section != 8 &&
                    _can(StudioPersona.manageClients))))
          IconButton(
            tooltip: switch (_section) {
              4 => 'New task',
              8 => 'New communication',
              _ => 'New client',
            },
            onPressed: switch (_section) {
              4 => _addTask,
              8 => () => _createCommunication(),
              _ => _addCustomer,
            },
            icon: const Icon(Icons.add_circle_outline, size: 21, color: ink),
          ),
        const SizedBox(width: 12),
        if (_customerRepository is RemoteCustomerWorkspaceRepository)
          IconButton(
            tooltip: 'Refresh workspace from server',
            onPressed: _customersLoading || _savingCustomers
                ? null
                : () => _refreshRemoteWorkspace(),
            icon: _customersLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 19, color: ink),
          ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _unreadMentions.isEmpty
              ? () => _toast('You’re all caught up.')
              : () => _openCommunications(filter: 'Mentions'),
          icon: Badge(
            isLabelVisible: _unreadMentions.isNotEmpty,
            label: Text('${_unreadMentions.length}'),
            child: const Icon(Icons.notifications_none, size: 20, color: ink),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: widget.accessPersona == null
              ? 'Studio roles and preferences'
              : 'Organization and access',
          onPressed: _openOrganizationAccess,
          icon: const Icon(Icons.settings_outlined, size: 19, color: ink),
        ),
        const SizedBox(width: 8),
        if (wide)
          if ((_section == 4 && _can(StudioPersona.manageTasks)) ||
              (_section == 8 && _can(StudioPersona.manageCommunications)) ||
              (_section != 4 &&
                  _section != 6 &&
                  _section != 8 &&
                  _can(StudioPersona.manageClients)))
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: paper,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              onPressed: switch (_section) {
                4 => _addTask,
                8 => () => _createCommunication(),
                _ => _addCustomer,
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(switch (_section) {
                4 => 'New task',
                8 => 'New note',
                _ => 'New client',
              }),
            ),
      ],
    ),
  );

  Widget _mobileNavigation() => NavigationBar(
    selectedIndex: switch (_section) {
      0 => 0,
      1 => 1,
      2 => 2,
      3 => 3,
      _ => 4,
    },
    onDestinationSelected: (index) => _navigate(index == 4 ? 6 : index),
    backgroundColor: paper,
    indicatorColor: const Color(0xFFECEAE3),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.people_outline_rounded),
        label: 'Clients',
      ),
      NavigationDestination(
        icon: Icon(Icons.home_work_outlined),
        label: 'Projects',
      ),
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        label: 'Proposals',
      ),
      NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        label: 'More',
      ),
    ],
  );

  Widget _pageBody(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 27, wide ? 34 : 18, 36),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1220),
        child: switch (_section) {
          0 => _dashboard(wide),
          1 => _leadsPage(wide),
          2 => _projectsPage(wide),
          3 => _proposalsPage(wide),
          4 => _tasksPage(),
          5 => _deliveryPage(),
          6 => _featuresPage(),
          7 => _reportsPage(wide),
          _ => _communicationsPage(),
        },
      ),
    ),
  );

  Widget _dashboard(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _eyebrow('YOUR STUDIO AT A GLANCE'),
      const SizedBox(height: 8),
      Text(
        'Good morning, ${_activePersona.name}',
        style: _heading(wide ? 31 : 26),
      ),
      const SizedBox(height: 7),
      const Text(
        'A considered overview of what’s taking shape.',
        style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
      ),
      const SizedBox(height: 25),
      _metricGrid(wide),
      const SizedBox(height: 24),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _pipelineCard()),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: _tasksCard(compact: true)),
          ],
        )
      else ...[
        _pipelineCard(),
        const SizedBox(height: 18),
        _tasksCard(compact: false),
      ],
      const SizedBox(height: 18),
      _projectsPreview(),
      const SizedBox(height: 20),
      _activityPreview(),
    ],
  );

  Widget _metricGrid(bool wide, {bool finance = false}) {
    final visibleProjects = _can(StudioPersona.viewProjects);
    final activeProjectCount = _delivery.projects
        .where((project) => project.status != 'Complete')
        .length;
    final pendingApprovalCount = _delivery.approvals
        .where((approval) => approval.status == 'Pending')
        .length;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final invoicesThisMonth = _financials.invoices
        .where(
          (invoice) =>
              !invoice.issuedAt.isBefore(monthStart) &&
              !invoice.issuedAt.isAfter(now),
        )
        .toList();
    final invoicedThisMonth = invoicesThisMonth.fold<double>(
      0,
      (total, invoice) => total + invoice.total,
    );
    final totalInvoiced = _financials.invoices.fold<double>(
      0,
      (total, invoice) => total + invoice.total,
    );
    final totalCollected = _financials.invoices.fold<double>(
      0,
      (total, invoice) => total + invoice.paidAmount,
    );
    final collectionRate = totalInvoiced == 0
        ? 0
        : (totalCollected / totalInvoiced * 100).round();
    final metrics = finance
        ? [
            (
              'Proposals',
              '${_financials.proposals.length}',
              '${_financials.proposals.where((item) => item.status == 'Approved').length} approved',
              Icons.description_outlined,
            ),
            (
              'Awaiting approval',
              '${_financials.proposals.where((item) => item.status == 'Pending approval').length}',
              'Proposal decisions pending',
              Icons.pending_outlined,
            ),
            (
              'Invoiced this month',
              _formatCurrency(
                invoicedThisMonth,
                _financials.settings.currencySymbol,
              ),
              '${invoicesThisMonth.length} invoices issued',
              Icons.receipt_long_outlined,
            ),
            (
              'Collected',
              '$collectionRate%',
              '${_formatCurrency(totalCollected, _financials.settings.currencySymbol)} received',
              Icons.payments_outlined,
            ),
          ]
        : [
            (
              'Active projects',
              visibleProjects ? '$activeProjectCount' : 'Restricted',
              visibleProjects
                  ? '${_delivery.projects.length} total projects'
                  : 'Project access not included',
              Icons.home_work_outlined,
            ),
            (
              'Pipeline value',
              _can(StudioPersona.viewFinancials) ? '\$1.24M' : 'Restricted',
              _can(StudioPersona.viewFinancials)
                  ? '+12.8% vs. last month'
                  : 'Financial access not included',
              Icons.trending_up,
            ),
            (
              'Awaiting approval',
              visibleProjects ? '$pendingApprovalCount' : 'Restricted',
              visibleProjects
                  ? 'Open project decisions'
                  : 'Project access not included',
              Icons.pending_outlined,
            ),
            (
              'Client satisfaction',
              '98%',
              'Across 12 recent projects',
              Icons.favorite_border,
            ),
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = wide
            ? 4
            : constraints.maxWidth < 430
            ? 1
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 118,
          ),
          itemBuilder: (context, index) {
            final item = metrics[index];
            return Container(
              padding: const EdgeInsets.all(17),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Icon(item.$4, color: accent, size: 17),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: sage,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pipelineCard() {
    if (!_can(StudioPersona.viewClients)) return _accessNotice();
    final openCustomers = _customers
        .where((customer) => !['Client', 'On hold'].contains(customer.stage))
        .toList();
    final totalValue = openCustomers.fold<double>(
      0,
      (total, customer) =>
          total +
          (double.tryParse(customer.value.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0),
    );
    final progress = _customers.isEmpty
        ? 0.0
        : openCustomers.length / _customers.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Lead pipeline', 'View all', () => _navigate(1)),
          const SizedBox(height: 22),
          Text(
            _can(StudioPersona.viewFinancials)
                ? '\$${_formatAmount(totalValue)}'
                : 'Restricted',
            style: const TextStyle(
              color: ink,
              fontSize: 25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _can(StudioPersona.viewFinancials)
                ? 'Potential project value'
                : 'Financial access not included',
            style: const TextStyle(
              color: muted,
              fontFamily: 'Arial',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDEAE2),
              color: sage,
            ),
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 16,
            runSpacing: 9,
            children: [
              for (var index = 0; index < _pipelineStages.length; index++)
                _legend(
                  _pipelineStages[index],
                  '${_customers.where((customer) => customer.stage == _pipelineStages[index]).length}',
                  _stageColors[index % _stageColors.length],
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final rounded = amount.round().toString();
    return rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  static const _stageColors = [
    accent,
    Color(0xFFC9A883),
    sage,
    ink,
    Color(0xFF9A8B83),
    Color(0xFFB6A77D),
    Color(0xFF718B91),
  ];

  Widget _tasksCard({required bool compact}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeading('On your mind', 'All tasks', () => _navigate(4)),
        const SizedBox(height: 13),
        if (!_can(StudioPersona.viewProjects))
          const Text(
            'Task access is not included in this role.',
            style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 10),
          )
        else if (_delivery.tasks.isEmpty)
          const Text(
            'Project tasks will appear here.',
            style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 10),
          )
        else
          ..._delivery.tasks.take(compact ? 4 : 3).map(_taskRow),
      ],
    ),
  );

  Widget _taskRow(StudioTaskRecord task) {
    final project = _projectFor(task.projectId);
    final subtitle = [
      project?.name ?? 'Project removed',
      task.assignee.isEmpty ? 'Unassigned' : task.assignee,
      'Due ${_dateLabel(task.dueDate)}',
    ].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: task.isComplete,
        activeColor: sage,
        onChanged: _can(StudioPersona.manageTasks)
            ? (_) => _toggleProjectTask(task)
            : null,
      ),
      title: InkWell(
        onTap: _can(StudioPersona.manageTasks)
            ? () => _editProjectTask(task)
            : null,
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Arial',
            fontSize: 11,
            color: task.isComplete ? muted : ink,
            decoration: task.isComplete ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
      ),
      trailing: _pill(task.priority),
    );
  }

  Widget _projectsPreview() => !_can(StudioPersona.viewProjects)
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _cardHeading('In the making', 'All projects', () => _navigate(2)),
              const SizedBox(height: 10),
              if (_delivery.projects.isEmpty)
                const Text(
                  'Your projects will appear here.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 10,
                  ),
                )
              else
                ..._delivery.projects.take(3).map(_projectRow),
            ],
          ),
        );

  Widget _projectRow(StudioProject project) => InkWell(
    onTap: () => _openProject(project),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFECE5D9),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.home_work_outlined, color: ink, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w600,
                    color: ink,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  project.location.isEmpty
                      ? _customerFor(project.customerId)?.name ??
                            'No client linked'
                      : project.location,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 460) _pill(project.status),
          const SizedBox(width: 12),
        ],
      ),
    ),
  );

  Widget _activityPreview() {
    if (!_can(StudioPersona.viewClients)) return const SizedBox.shrink();
    final recent = _recentActivities.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading(
            'A little momentum',
            'Activity timeline',
            _showActivityTimeline,
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            const Text(
              'Client changes and conversations will appear here.',
              style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 11),
            )
          else
            ...recent.map(_activityLine),
        ],
      ),
    );
  }

  Widget _activityLine(StudioActivity activity) {
    final occurredAt = activity.occurredAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(occurredAt);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt));
    final initials = activity.actor
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return _ActivityLine(
      initials: initials,
      title: '${activity.title} · ${activity.customerName}',
      detail: [
        if (activity.details.isNotEmpty) activity.details,
        '$date · $time · ${activity.actor}',
      ].join(' · '),
      color: activity.kind == 'interaction'
          ? const Color(0xFFDCE3DA)
          : const Color(0xFFE9DDD0),
    );
  }

  Widget _leadsPage(bool wide) => !_can(StudioPersona.viewClients)
      ? _accessNotice()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('RELATIONSHIPS, CONSIDERED'),
            const SizedBox(height: 8),
            Text('Clients & leads', style: _heading(30)),
            const SizedBox(height: 7),
            const Text(
              'Every great space begins with a conversation.',
              style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 9,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _summaryChip(
                  '${_customers.length} clients',
                  Icons.people_outline,
                ),
                _summaryChip(
                  '${_customers.where((customer) => !['Client', 'On hold'].contains(customer.stage)).length} active inquiries',
                  Icons.south_west,
                ),
                _summaryChip(
                  '${_customers.where((customer) => customer.requirement != null).length} briefs',
                  Icons.assignment_outlined,
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showPipelineBoard = !_showPipelineBoard),
                  icon: Icon(
                    _showPipelineBoard
                        ? Icons.view_list_outlined
                        : Icons.view_kanban_outlined,
                    size: 16,
                  ),
                  label: Text(_showPipelineBoard ? 'List' : 'Pipeline'),
                ),
                if (_can(StudioPersona.managePipeline))
                  OutlinedButton.icon(
                    onPressed: _configurePipeline,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Configure stages'),
                  ),
                if (_can(StudioPersona.manageClients))
                  OutlinedButton.icon(
                    onPressed: _importCustomers,
                    icon: const Icon(Icons.upload_file_outlined, size: 16),
                    label: const Text('Import CSV'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'CSV columns: name (required), email, phone, project, stage, budget, notes.',
              style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 10),
            ),
            const SizedBox(height: 18),
            if (_customerStorageError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _customerStorageError!,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: Color(0xFF8A3528),
                    fontSize: 11,
                  ),
                ),
              ),
            if (_savingCustomers)
              const LinearProgressIndicator(
                color: sage,
                backgroundColor: line,
                minHeight: 2,
              ),
            if (_customersLoading)
              const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(color: sage),
              )
            else if (_showPipelineBoard)
              _pipelineBoard()
            else
              Container(
                padding: EdgeInsets.all(wide ? 21 : 13),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    if (_can(StudioPersona.manageClients))
                      _cardHeading('Your people', 'Add client', _addCustomer)
                    else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your people',
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 13),
                    ..._filteredCustomers.map(_customerRow),
                    if (_filteredCustomers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No clients match that search.',
                          style: TextStyle(fontFamily: 'Arial', color: muted),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _featureNote(
              'Thoughtful from first hello',
              'Capture project requirements, record every conversation, and keep each relationship in view.',
            ),
          ],
        );

  Widget _pipelineBoard() => SizedBox(
    height: 465,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _pipelineStages.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final stage = _pipelineStages[index];
        final customers = _filteredCustomers
            .where((customer) => customer.stage == stage)
            .toList();
        return Container(
          width: 265,
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _pill('${customers.length}'),
                ],
              ),
              const Divider(height: 20, color: line),
              if (customers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No clients in this stage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 9),
                    itemBuilder: (context, customerIndex) =>
                        _pipelineCustomerCard(customers[customerIndex]),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _pipelineCustomerCard(Customer customer) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            if (_can(StudioPersona.managePipeline))
              PopupMenuButton<String>(
                tooltip: 'Move client to another stage',
                icon: const Icon(Icons.more_horiz, size: 19, color: muted),
                padding: EdgeInsets.zero,
                onSelected: (stage) => _moveCustomerToStage(customer, stage),
                itemBuilder: (context) => _pipelineStages
                    .where((stage) => stage != customer.stage)
                    .map(
                      (stage) => PopupMenuItem(
                        value: stage,
                        child: Text(
                          'Move to $stage',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
        if (customer.project.isNotEmpty)
          Text(
            customer.project,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: muted,
              fontSize: 10,
            ),
          ),
        const SizedBox(height: 9),
        if (_can(StudioPersona.viewFinancials))
          Text(
            customer.value,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );

  Widget _customerRow(Customer customer) => InkWell(
    onTap: () => _showCustomer(customer),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: customer.tint,
            child: Text(
              customer.initials,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.project.isNotEmpty
                      ? customer.project
                      : customer.email.isNotEmpty
                      ? customer.email
                      : 'No project linked',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 530)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _pill(customer.stage),
            ),
          if (customer.requirement != null)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.assignment_turned_in_outlined,
                color: sage,
                size: 16,
              ),
            ),
          IconButton(
            tooltip: customer.phone.trim().isEmpty
                ? 'Phone number unavailable'
                : 'Call ${customer.name}',
            onPressed: customer.phone.trim().isEmpty
                ? null
                : () => _callCustomer(customer),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.call_outlined, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: accent,
              disabledForegroundColor: muted,
            ),
          ),
          if (_can(StudioPersona.viewFinancials))
            Text(
              customer.value,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: muted, size: 18),
        ],
      ),
    ),
  );

  Widget _projectsPage(bool wide) =>
      !_can(StudioPersona.viewProjects) &&
          !_can(StudioPersona.viewMaterials) &&
          !_can(StudioPersona.viewVendors) &&
          !_can(StudioPersona.approveProcurement)
      ? _accessNotice()
      : Builder(
          builder: (context) {
            final tabs = [
              if (_can(StudioPersona.viewProjects)) 'Projects',
              if (_can(StudioPersona.viewProjects)) 'Schedule',
              if (_can(StudioPersona.viewMaterials)) 'Materials',
              if (_can(StudioPersona.viewVendors)) 'Vendors',
              if (_can(StudioPersona.viewProcurement) ||
                  _can(StudioPersona.approveProcurement))
                'Procurement',
            ];
            final selectedTab = tabs.contains(_projectTab)
                ? _projectTab
                : tabs.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow('CONSTRUCTION WORKSPACE'),
                const SizedBox(height: 8),
                Text(
                  selectedTab == 'Procurement'
                      ? 'Procurement'
                      : selectedTab == 'Materials' || selectedTab == 'Vendors'
                      ? 'Master data'
                      : 'Projects',
                  style: _heading(30),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Plan project work and keep shared construction records in one place.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tabs
                      .map(
                        (tab) => ChoiceChip(
                          label: Text(tab),
                          selected: selectedTab == tab,
                          onSelected: (_) => setState(() => _projectTab = tab),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                switch (selectedTab) {
                  'Projects' => _projectList(wide),
                  'Schedule' => _schedulePage(),
                  'Materials' => _materialsPage(),
                  'Vendors' => _vendorsPage(),
                  _ => _procurementPage(),
                },
              ],
            );
          },
        );

  Widget _procurementPage() {
    final project = _selectedProject;
    if (project == null) {
      return _emptyDeliveryCard(
        'Create a project first',
        'Procurement records are organized by project.',
      );
    }
    final requisitions = _delivery.requisitions
        .where((item) => item.projectId == project.id)
        .toList();
    final rfqs = _delivery.rfqs
        .where((item) => item.projectId == project.id)
        .toList();
    final quotes = _delivery.vendorQuotes
        .where((item) => item.projectId == project.id)
        .toList();
    final purchaseOrders = _delivery.purchaseOrders
        .where((item) => item.projectId == project.id)
        .toList();
    final manageable = _can(StudioPersona.manageProcurement);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: project.id,
                decoration: const InputDecoration(labelText: 'Project'),
                items: _delivery.projects
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedProjectId = value),
              ),
            ),
            if (_can(StudioPersona.configureWorkspace)) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Approval policy',
                onPressed: _configureProcurementPolicy,
                icon: const Icon(Icons.tune),
              ),
            ],
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Procurement audit history',
              onPressed: () => _openProcurementAudit(project),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _procurementSection(
          title: 'Material requisitions',
          description: 'Request project materials and route decisions.',
          action: manageable
              ? OutlinedButton.icon(
                  onPressed: () => _createRequisition(project),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New requisition'),
                )
              : null,
          children: requisitions.isEmpty
              ? [_procurementEmpty('No requisitions for this project.')]
              : requisitions
                    .map(
                      (item) => _requisitionCard(item, canManage: manageable),
                    )
                    .toList(),
        ),
        const SizedBox(height: 18),
        _procurementSection(
          title: 'Vendor requests for quotation',
          description: 'Issue approved requirements to selected vendors.',
          action: manageable
              ? OutlinedButton.icon(
                  onPressed:
                      requisitions.any((item) => item.status == 'Approved')
                      ? () => _createRfq(project)
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New RFQ'),
                )
              : null,
          children: rfqs.isEmpty
              ? [_procurementEmpty('No vendor requests yet.')]
              : rfqs
                    .map((item) => _rfqCard(item, canManage: manageable))
                    .toList(),
        ),
        const SizedBox(height: 18),
        _procurementSection(
          title: 'Quote comparison',
          description: 'Compare submitted vendor quotes before selecting one.',
          action: manageable
              ? OutlinedButton.icon(
                  onPressed: rfqs.any((item) => item.status == 'Issued')
                      ? () => _createVendorQuote(project)
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Record quote'),
                )
              : null,
          children: quotes.isEmpty
              ? [_procurementEmpty('No vendor quotes have been recorded.')]
              : quotes.map(_vendorQuoteCard).toList(),
        ),
        const SizedBox(height: 18),
        _procurementSection(
          title: 'Purchase orders',
          description:
              'Create orders from selected quotes and approve before issue.',
          action: manageable
              ? OutlinedButton.icon(
                  onPressed: quotes.any((item) => item.status == 'Selected')
                      ? () => _createPurchaseOrder(project)
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New purchase order'),
                )
              : null,
          children: purchaseOrders.isEmpty
              ? [_procurementEmpty('No purchase orders have been created.')]
              : purchaseOrders
                    .map(
                      (item) => _purchaseOrderCard(item, canManage: manageable),
                    )
                    .toList(),
        ),
      ],
    );
  }

  Widget _procurementSection({
    required String title,
    required String description,
    required Widget? action,
    required List<Widget> children,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _heading(19)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _procurementEmpty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      message,
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 12),
    ),
  );

  Widget _requisitionCard(
    StudioMaterialRequisition item, {
    required bool canManage,
  }) {
    final project = _projectFor(item.projectId);
    final pendingStep = item.approvalSteps
        .where((step) => step.status == 'Pending')
        .firstOrNull;
    final canDecide =
        pendingStep != null &&
        _canProcurementPermission(pendingStep.permission);
    return _procurementRecordCard(
      title: item.title,
      subtitle:
          '${item.items.length} material line${item.items.length == 1 ? '' : 's'} · ${project?.name ?? ''}',
      status: item.status,
      detail: item.items
          .map(
            (line) =>
                '${line.name}: ${line.quantity.toStringAsFixed(3)} ${line.unit}',
          )
          .join('  ·  '),
      actions: [
        if (item.status == 'Draft' && canManage)
          _procurementButton('Submit', () => _submitRequisition(item)),
        if (_can(StudioPersona.manageCommunications))
          _procurementButton(
            'Add communication',
            () => _createCommunication(
              projectId: item.projectId,
              procurementRecordType: 'requisitions',
              procurementRecordId: item.id,
            ),
          ),
        if (canDecide) ...[
          _procurementButton('Approve', () => _decideRequisition(item, true)),
          _procurementButton('Reject', () => _decideRequisition(item, false)),
        ],
      ],
    );
  }

  Widget _rfqCard(StudioRequestForQuotation item, {required bool canManage}) {
    final requisition = _requisitionFor(item.requisitionId);
    final vendors = item.vendorIds
        .map(_vendorFor)
        .whereType<StudioVendor>()
        .map((vendor) => vendor.name)
        .join(', ');
    return _procurementRecordCard(
      title: requisition?.title ?? 'Request for quotation',
      subtitle: '$vendors · ${item.status}',
      status: item.status,
      detail: item.notes.isEmpty ? 'Vendors invited: $vendors' : item.notes,
      actions: [
        if (item.status == 'Draft' && canManage)
          _procurementButton(
            'Issue RFQ',
            () => _changeRfqStatus(item, 'Issued'),
          ),
        if (item.status == 'Issued' && canManage)
          _procurementButton(
            'Close RFQ',
            () => _changeRfqStatus(item, 'Closed'),
          ),
        if (_can(StudioPersona.manageCommunications))
          for (final vendorId in item.vendorIds)
            _procurementButton(
              'Contact ${_vendorFor(vendorId)?.name ?? 'vendor'}',
              () => _createCommunication(
                projectId: item.projectId,
                vendorId: vendorId,
                procurementRecordType: 'rfqs',
                procurementRecordId: item.id,
              ),
            ),
      ],
    );
  }

  Widget _vendorQuoteCard(StudioVendorQuote item) {
    final vendor = _vendorFor(item.vendorId)?.name ?? 'Vendor';
    final rfq = _rfqFor(item.rfqId);
    final canSelect =
        _can(StudioPersona.manageProcurement) && item.status == 'Submitted';
    return _procurementRecordCard(
      title: vendor,
      subtitle:
          '${_requisitionFor(rfq?.requisitionId ?? '')?.title ?? 'RFQ'} · ${item.status}',
      status: item.status,
      detail:
          '${_formatMinor(item.totalMinor, item.currency)} · ${item.deliveryDays == null ? 'Delivery time not specified' : '${item.deliveryDays} day delivery'}${item.terms.isEmpty ? '' : ' · ${item.terms}'}',
      actions: [
        if (canSelect)
          _procurementButton('Select quote', () => _selectVendorQuote(item)),
        if (_can(StudioPersona.manageCommunications))
          _procurementButton(
            'Contact vendor',
            () => _createCommunication(
              projectId: item.projectId,
              vendorId: item.vendorId,
              procurementRecordType: 'vendorQuotes',
              procurementRecordId: item.id,
            ),
          ),
      ],
    );
  }

  Widget _purchaseOrderCard(
    StudioPurchaseOrder item, {
    required bool canManage,
  }) {
    final pendingStep = item.approvalSteps
        .where((step) => step.status == 'Pending')
        .firstOrNull;
    final canDecide =
        pendingStep != null &&
        _canProcurementPermission(pendingStep.permission);
    return _procurementRecordCard(
      title:
          '${_vendorFor(item.vendorId)?.name ?? 'Vendor'} · ${_formatMinor(item.totalMinor, item.currency)}',
      subtitle: 'Purchase order ${item.id}',
      status: item.status,
      detail: item.notes,
      actions: [
        if (item.status == 'Draft' && canManage)
          _procurementButton(
            'Submit for approval',
            () => _submitPurchaseOrder(item),
          ),
        if (canDecide) ...[
          _procurementButton('Approve', () => _decidePurchaseOrder(item, true)),
          _procurementButton('Reject', () => _decidePurchaseOrder(item, false)),
        ],
        if (item.status == 'Approved' && canManage)
          _procurementButton('Issue', () => _issuePurchaseOrder(item)),
        if (_can(StudioPersona.manageCommunications))
          _procurementButton(
            'Contact vendor',
            () => _createCommunication(
              projectId: item.projectId,
              vendorId: item.vendorId,
              procurementRecordType: 'purchaseOrders',
              procurementRecordId: item.id,
            ),
          ),
      ],
    );
  }

  Widget _procurementRecordCard({
    required String title,
    required String subtitle,
    required String status,
    required String detail,
    required List<Widget> actions,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: canvas,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Chip(
              label: Text(status),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontFamily: 'Arial', fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Arial',
            color: muted,
            fontSize: 11,
          ),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(fontFamily: 'Arial', fontSize: 11),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: actions),
        ],
      ],
    ),
  );

  Widget _procurementButton(String label, VoidCallback onPressed) =>
      TextButton(onPressed: onPressed, child: Text(label));

  String _formatMinor(int amount, String currency) =>
      '$currency ${(amount / 100).toStringAsFixed(2)}';

  StudioMaterialRequisition? _requisitionFor(String id) {
    for (final item in _delivery.requisitions) {
      if (item.id == id) return item;
    }
    return null;
  }

  StudioRequestForQuotation? _rfqFor(String? id) {
    if (id == null) return null;
    for (final item in _delivery.rfqs) {
      if (item.id == id) return item;
    }
    return null;
  }

  StudioVendor? _vendorFor(String id) {
    for (final item in _delivery.vendors) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool _canProcurementPermission(String permission) => switch (permission) {
    'procurement.approve' => _can(StudioPersona.approveProcurement),
    'manageFinancials' => _can(StudioPersona.manageFinancials),
    _ => false,
  };

  Future<void> _createRequisition(StudioProject project) async {
    if (!_can(StudioPersona.manageProcurement)) return;
    final materials = _delivery.materials
        .where((item) => item.isActive)
        .toList();
    if (materials.isEmpty) {
      _toast('Add an active material before creating a requisition.');
      return;
    }
    final result = await showDialog<StudioMaterialRequisition>(
      context: context,
      builder: (context) =>
          RequisitionEditorDialog(projectId: project.id, materials: materials),
    );
    if (result == null) return;
    await _saveDelivery(
      _delivery.copyWith(requisitions: [..._delivery.requisitions, result]),
      confirmation: 'Requisition saved as a draft.',
      activityTitle: 'Material requisition created',
      activityDetails: '${project.name} · ${result.title}',
    );
  }

  Future<void> _submitRequisition(StudioMaterialRequisition requisition) async {
    final steps = _workspacePreferences
        .procurementApprovalPolicy
        .requisitionPermissions
        .map(
          (permission) => StudioProcurementApprovalStep(
            permission: permission,
            status: 'Pending',
            decisionNote: '',
            decidedAt: null,
          ),
        )
        .toList();
    final updated = requisition.copyWith(
      status: 'Pending approval',
      approvalSteps: steps,
    );
    await _saveDelivery(
      _delivery.copyWith(
        requisitions: [
          for (final item in _delivery.requisitions)
            if (item.id == requisition.id) updated else item,
        ],
      ),
      confirmation: 'Requisition submitted for approval.',
      activityTitle: 'Requisition submitted',
      activityDetails: requisition.title,
    );
  }

  Future<void> _decideRequisition(
    StudioMaterialRequisition requisition,
    bool approve,
  ) async {
    final note = await _procurementDecisionNote(approve);
    if (note == null) return;
    final steps = List<StudioProcurementApprovalStep>.of(
      requisition.approvalSteps,
    );
    final index = steps.indexWhere((step) => step.status == 'Pending');
    if (index < 0 || !_canProcurementPermission(steps[index].permission))
      return;
    steps[index] = StudioProcurementApprovalStep(
      permission: steps[index].permission,
      status: approve ? 'Approved' : 'Rejected',
      decisionNote: note,
      decidedAt: DateTime.now().toUtc(),
    );
    final updated = requisition.copyWith(
      status: approve
          ? steps.every((step) => step.status == 'Approved')
                ? 'Approved'
                : 'Pending approval'
          : 'Rejected',
      approvalSteps: steps,
    );
    await _saveDelivery(
      _delivery.copyWith(
        requisitions: [
          for (final item in _delivery.requisitions)
            if (item.id == requisition.id) updated else item,
        ],
      ),
      confirmation: approve
          ? 'Approval decision saved.'
          : 'Requisition rejected.',
      activityTitle: approve ? 'Requisition approved' : 'Requisition rejected',
      activityDetails: requisition.title,
    );
  }

  Future<String?> _procurementDecisionNote(bool approve) => showDialog<String>(
    context: context,
    builder: (context) => ProcurementDecisionDialog(approve: approve),
  );

  Future<void> _createRfq(StudioProject project) async {
    if (!_can(StudioPersona.manageProcurement)) return;
    final requisitions = _delivery.requisitions
        .where(
          (item) => item.projectId == project.id && item.status == 'Approved',
        )
        .toList();
    final vendors = _delivery.vendors.where((item) => item.isActive).toList();
    if (vendors.isEmpty) {
      _toast('Add an active vendor before issuing a request for quotation.');
      return;
    }
    final result = await showDialog<StudioRequestForQuotation>(
      context: context,
      builder: (context) => RequestForQuotationEditorDialog(
        projectId: project.id,
        requisitions: requisitions,
        vendors: vendors,
      ),
    );
    if (result == null) return;
    await _saveDelivery(
      _delivery.copyWith(rfqs: [..._delivery.rfqs, result]),
      confirmation: 'Request for quotation saved as a draft.',
      activityTitle: 'Vendor RFQ created',
      activityDetails: '${project.name} · ${result.vendorIds.length} vendors',
    );
  }

  Future<void> _changeRfqStatus(
    StudioRequestForQuotation rfq,
    String status,
  ) async {
    final updated = rfq.copyWith(status: status);
    await _saveDelivery(
      _delivery.copyWith(
        rfqs: [
          for (final item in _delivery.rfqs)
            if (item.id == rfq.id) updated else item,
        ],
      ),
      confirmation: status == 'Issued' ? 'RFQ issued.' : 'RFQ closed.',
      activityTitle: status == 'Issued'
          ? 'Vendor RFQ issued'
          : 'Vendor RFQ closed',
      activityDetails: _requisitionFor(rfq.requisitionId)?.title ?? rfq.id,
    );
  }

  Future<void> _createVendorQuote(StudioProject project) async {
    if (!_can(StudioPersona.manageProcurement)) return;
    final rfqs = _delivery.rfqs
        .where(
          (item) => item.projectId == project.id && item.status == 'Issued',
        )
        .toList();
    final result = await showDialog<StudioVendorQuote>(
      context: context,
      builder: (context) => VendorQuoteEditorDialog(
        projectId: project.id,
        rfqs: rfqs,
        requisitions: _delivery.requisitions,
        vendors: _delivery.vendors,
      ),
    );
    if (result == null) return;
    await _saveDelivery(
      _delivery.copyWith(vendorQuotes: [..._delivery.vendorQuotes, result]),
      confirmation: 'Vendor quote recorded.',
      activityTitle: 'Vendor quote received',
      activityDetails:
          '${_vendorFor(result.vendorId)?.name ?? ''} · ${_formatMinor(result.totalMinor, result.currency)}',
    );
  }

  Future<void> _selectVendorQuote(StudioVendorQuote quote) async {
    if (!_can(StudioPersona.manageProcurement)) return;
    final quotes = [
      for (final item in _delivery.vendorQuotes)
        if (item.rfqId == quote.rfqId && item.status == 'Selected')
          item.copyWith(status: 'Not selected')
        else if (item.id == quote.id)
          item.copyWith(status: 'Selected')
        else
          item,
    ];
    await _saveDelivery(
      _delivery.copyWith(vendorQuotes: quotes),
      confirmation: 'Vendor quote selected for the purchase order.',
      activityTitle: 'Vendor quote selected',
      activityDetails:
          '${_vendorFor(quote.vendorId)?.name ?? ''} · ${_formatMinor(quote.totalMinor, quote.currency)}',
    );
  }

  Future<void> _createPurchaseOrder(StudioProject project) async {
    if (!_can(StudioPersona.manageProcurement)) return;
    final quotes = _delivery.vendorQuotes
        .where(
          (item) => item.projectId == project.id && item.status == 'Selected',
        )
        .toList();
    final result = await showDialog<StudioPurchaseOrder>(
      context: context,
      builder: (context) => PurchaseOrderEditorDialog(
        projectId: project.id,
        quotes: quotes,
        rfqs: _delivery.rfqs,
        requisitions: _delivery.requisitions,
      ),
    );
    if (result == null) return;
    await _saveDelivery(
      _delivery.copyWith(purchaseOrders: [..._delivery.purchaseOrders, result]),
      confirmation: 'Purchase order saved as a draft.',
      activityTitle: 'Purchase order created',
      activityDetails:
          '${_vendorFor(result.vendorId)?.name ?? ''} · ${_formatMinor(result.totalMinor, result.currency)}',
    );
  }

  Future<void> _submitPurchaseOrder(StudioPurchaseOrder order) async {
    final steps = _workspacePreferences
        .procurementApprovalPolicy
        .purchaseOrderPermissions
        .map(
          (permission) => StudioProcurementApprovalStep(
            permission: permission,
            status: 'Pending',
            decisionNote: '',
            decidedAt: null,
          ),
        )
        .toList();
    final updated = order.copyWith(
      status: 'Pending approval',
      approvalSteps: steps,
    );
    await _saveDelivery(
      _delivery.copyWith(
        purchaseOrders: [
          for (final item in _delivery.purchaseOrders)
            if (item.id == order.id) updated else item,
        ],
      ),
      confirmation: 'Purchase order submitted for approval.',
      activityTitle: 'Purchase order submitted',
      activityDetails: order.id,
    );
  }

  Future<void> _decidePurchaseOrder(
    StudioPurchaseOrder order,
    bool approve,
  ) async {
    final note = await _procurementDecisionNote(approve);
    if (note == null) return;
    final steps = List<StudioProcurementApprovalStep>.of(order.approvalSteps);
    final index = steps.indexWhere((step) => step.status == 'Pending');
    if (index < 0 || !_canProcurementPermission(steps[index].permission))
      return;
    steps[index] = StudioProcurementApprovalStep(
      permission: steps[index].permission,
      status: approve ? 'Approved' : 'Rejected',
      decisionNote: note,
      decidedAt: DateTime.now().toUtc(),
    );
    final updated = order.copyWith(
      status: approve
          ? steps.every((step) => step.status == 'Approved')
                ? 'Approved'
                : 'Pending approval'
          : 'Rejected',
      approvalSteps: steps,
    );
    await _saveDelivery(
      _delivery.copyWith(
        purchaseOrders: [
          for (final item in _delivery.purchaseOrders)
            if (item.id == order.id) updated else item,
        ],
      ),
      confirmation: approve
          ? 'Approval decision saved.'
          : 'Purchase order rejected.',
      activityTitle: approve
          ? 'Purchase order approved'
          : 'Purchase order rejected',
      activityDetails: order.id,
    );
  }

  Future<void> _issuePurchaseOrder(StudioPurchaseOrder order) async {
    final updated = order.copyWith(
      status: 'Issued',
      issuedAt: DateTime.now().toUtc(),
    );
    await _saveDelivery(
      _delivery.copyWith(
        purchaseOrders: [
          for (final item in _delivery.purchaseOrders)
            if (item.id == order.id) updated else item,
        ],
      ),
      confirmation: 'Purchase order issued.',
      activityTitle: 'Purchase order issued',
      activityDetails: order.id,
    );
  }

  Future<void> _configureProcurementPolicy() async {
    if (!_can(StudioPersona.configureWorkspace)) {
      _toast('Workspace configuration permission is required.');
      return;
    }
    final policy = await showDialog<StudioProcurementApprovalPolicy>(
      context: context,
      builder: (context) => ProcurementApprovalPolicyDialog(
        policy: _workspacePreferences.procurementApprovalPolicy,
      ),
    );
    if (policy == null) return;
    await _saveWorkspace(
      preferences: _workspacePreferences.copyWith(
        procurementApprovalPolicy: policy,
      ),
      confirmation: 'Procurement approval policy updated.',
    );
  }

  Future<void> _openProcurementAudit(StudioProject project) async {
    if (_customerRepository is! RemoteCustomerWorkspaceRepository) {
      _toast('Audit history is available in configured remote workspaces.');
      return;
    }
    try {
      final remoteRepository = _customerRepository;
      final page = await remoteRepository.loadCollection(
        collection: 'procurementAudit',
        limit: 100,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Procurement audit history'),
          content: SizedBox(
            width: 600,
            child: page.records.isEmpty
                ? const Text('No procurement decisions have been recorded.')
                : SizedBox(
                    height: 420,
                    child: ListView.separated(
                      itemCount: page.records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = page.records[index];
                        final createdAt = DateTime.tryParse(
                          event['createdAt']?.toString() ?? '',
                        );
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${event['collection']} · ${event['action']}',
                          ),
                          subtitle: Text(
                            '${event['recordId']}${createdAt == null ? '' : ' · ${MaterialLocalizations.of(context).formatMediumDate(createdAt.toLocal())}'}'
                            '${event['fromStatus'] == null ? '' : ' · ${event['fromStatus']} -> ${event['toStatus']}'}',
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _toast('Could not load procurement audit history: $error');
    }
  }

  Widget _projectList(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_can(StudioPersona.manageProjects))
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('New project'),
            style: FilledButton.styleFrom(backgroundColor: ink),
          ),
        ),
      const SizedBox(height: 14),
      if (_delivery.projects.isEmpty)
        _emptyDeliveryCard(
          'No projects yet',
          'Create a project to connect phases, tasks, milestones, files, and approvals.',
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final count = wide
                ? 3
                : constraints.maxWidth < 530
                ? 1
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _delivery.projects.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 205,
              ),
              itemBuilder: (context, index) =>
                  _projectCard(_delivery.projects[index]),
            );
          },
        ),
    ],
  );

  Widget _schedulePage() {
    final project = _selectedProject;
    if (project == null) {
      return _emptyDeliveryCard(
        'No project schedule yet',
        'Create a project to schedule phases, milestones, and tasks.',
      );
    }
    final phases =
        _delivery.phases
            .where((phase) => phase.projectId == project.id)
            .toList()
          ..sort((first, second) => first.position.compareTo(second.position));
    final entries =
        <({DateTime? date, String kind, String title, String status})>[
          for (final phase in phases)
            (
              date: phase.startDate,
              kind: 'Phase',
              title: phase.name,
              status: phase.status,
            ),
          for (final milestone in _delivery.milestones.where(
            (item) => item.projectId == project.id,
          ))
            (
              date: milestone.dueDate,
              kind: 'Milestone',
              title: milestone.title,
              status: milestone.status,
            ),
          for (final task in _delivery.tasks.where(
            (item) => item.projectId == project.id,
          ))
            (
              date: task.dueDate,
              kind: 'Task',
              title: task.title,
              status: task.isComplete ? 'Complete' : task.priority,
            ),
        ]..sort((first, second) {
          final firstDate = first.date ?? DateTime(9999);
          final secondDate = second.date ?? DateTime(9999);
          return firstDate.compareTo(secondDate);
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: project.id,
          decoration: const InputDecoration(labelText: 'Project schedule'),
          items: _delivery.projects
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedProjectId = value),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (project.startDate != null)
              _pill('Starts ${_dateLabel(project.startDate)}'),
            if (project.targetDate != null)
              _pill('Target ${_dateLabel(project.targetDate)}'),
            if (_can(StudioPersona.viewFinancials) && project.budget != null)
              _pill(
                'Budget ${_formatCurrencyAmount(project.budget!, _financials.settings.currencySymbol)}',
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Project phases', style: _heading(19))),
            if (_can(StudioPersona.manageMilestones))
              TextButton.icon(
                onPressed: () => _createProjectPhase(project),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add phase'),
              ),
          ],
        ),
        if (phases.isEmpty)
          _emptyDeliveryCard(
            'No phases defined',
            'Add phases to organize work and relate milestones to the schedule.',
          )
        else
          ...phases.map(
            (phase) => Card(
              color: paper,
              child: ListTile(
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: line,
                  child: Text('${phase.position + 1}'),
                ),
                title: Text(phase.name),
                subtitle: Text(
                  '${phase.status} · ${_dateLabel(phase.startDate)} – ${_dateLabel(phase.endDate)}',
                ),
                trailing: _can(StudioPersona.manageMilestones)
                    ? IconButton(
                        tooltip: 'Edit phase',
                        onPressed: () => _editProjectPhase(phase),
                        icon: const Icon(Icons.edit_outlined),
                      )
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text('Timeline', style: _heading(19)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          _emptyDeliveryCard(
            'Nothing scheduled',
            'Set phase dates, task due dates, or milestone targets to build the timeline.',
          )
        else
          ...entries.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      _dateLabel(entry.date),
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title, style: const TextStyle(color: ink)),
                        const SizedBox(height: 3),
                        Text(
                          entry.kind,
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _pill(entry.status),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _materialsPage() {
    final materials = [..._delivery.materials]
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Material catalogue', style: _heading(20))),
            if (_can(StudioPersona.manageMaterials))
              FilledButton.icon(
                onPressed: _createMaterial,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add material'),
                style: FilledButton.styleFrom(backgroundColor: ink),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (materials.isEmpty)
          _emptyDeliveryCard(
            'No materials yet',
            'Add standardized material names, units, categories, and specifications.',
          )
        else
          ...materials.map(
            (material) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: _cardDecoration(),
              child: ListTile(
                title: Text(material.name),
                subtitle: Text(
                  '${material.category} · ${material.unit}${material.specification.isEmpty ? '' : ' · ${material.specification}'}',
                ),
                leading: Icon(
                  material.isActive
                      ? Icons.inventory_2_outlined
                      : Icons.archive_outlined,
                  color: material.isActive ? sage : muted,
                ),
                trailing: _can(StudioPersona.manageMaterials)
                    ? IconButton(
                        tooltip: 'Edit material',
                        onPressed: () => _editMaterial(material),
                        icon: const Icon(Icons.edit_outlined),
                      )
                    : _pill(material.isActive ? 'Active' : 'Archived'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vendorsPage() {
    final vendors = [..._delivery.vendors]
      ..sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Suppliers & contractors', style: _heading(20)),
            ),
            if (_can(StudioPersona.manageVendors))
              FilledButton.icon(
                onPressed: _createVendor,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add vendor'),
                style: FilledButton.styleFrom(backgroundColor: ink),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (vendors.isEmpty)
          _emptyDeliveryCard(
            'No vendors yet',
            'Keep supplier and contractor contacts, payment terms, and document records here.',
          )
        else
          ...vendors.map(
            (vendor) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: _cardDecoration(),
              child: ListTile(
                title: Text(vendor.name),
                subtitle: Text(
                  [
                    vendor.kind,
                    if (vendor.email.isNotEmpty) vendor.email,
                    if (vendor.phone.isNotEmpty) vendor.phone,
                    '${vendor.documents.length} document records',
                  ].join(' · '),
                ),
                leading: Icon(
                  vendor.kind == 'Contractor'
                      ? Icons.engineering_outlined
                      : Icons.storefront_outlined,
                  color: sage,
                ),
                trailing: _can(StudioPersona.manageVendors)
                    ? IconButton(
                        tooltip: 'Edit vendor',
                        onPressed: () => _editVendor(vendor),
                        icon: const Icon(Icons.edit_outlined),
                      )
                    : _pill(vendor.isActive ? 'Active' : 'Archived'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _projectCard(StudioProject project) {
    final milestones = _delivery.milestones
        .where((milestone) => milestone.projectId == project.id)
        .toList();
    final completed = milestones
        .where((milestone) => milestone.status == 'Complete')
        .length;
    final progress = milestones.isEmpty ? 0.0 : completed / milestones.length;
    final customer = _customerFor(project.customerId);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProject(project),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined, color: accent, size: 20),
                const Spacer(),
                _pill(project.status),
                if (_can(StudioPersona.manageProjects))
                  PopupMenuButton<String>(
                    tooltip: 'Project actions',
                    onSelected: (action) {
                      if (action == 'edit') _editProject(project);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit project')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              customer?.name ??
                  (project.location.isEmpty
                      ? 'No client linked'
                      : project.location),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: muted,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    milestones.isEmpty
                        ? 'No milestones'
                        : '$completed of ${milestones.length} milestones complete',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                color: sage,
                minHeight: 5,
                backgroundColor: line,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proposalsPage(bool wide) {
    if (!_can(StudioPersona.viewFinancials)) return _accessNotice();
    final canManage = _can(StudioPersona.manageFinancials);
    final quotations = List<StudioQuotation>.of(_financials.quotations)
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    final proposals = List<StudioProposal>.of(_financials.proposals)
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    final invoices = List<StudioInvoice>.of(_financials.invoices)
      ..sort((first, second) => second.issuedAt.compareTo(first.issuedAt));
    const tabs = [
      ('Quotations', Icons.request_quote_outlined),
      ('Proposals', Icons.description_outlined),
      ('Invoices', Icons.receipt_long_outlined),
      ('Line item catalog', Icons.inventory_2_outlined),
      ('Finance', Icons.account_balance_wallet_outlined),
    ];
    final tabContent = switch (_proposalTab) {
      'Quotations' => _financialSection(
        'Bills of quantities & quotations',
        'Itemized quantities, unit rates, tax, and totals',
        quotations.isEmpty
            ? _emptyDeliveryCard(
                'No quotations yet',
                canManage
                    ? 'Create a quotation from a project linked to a client.'
                    : 'Quotations will appear here when the studio creates them.',
              )
            : Column(children: quotations.map(_quotationRow).toList()),
      ),
      'Proposals' => _financialSection(
        'Proposals',
        'Client-ready snapshots using your studio template and layout',
        proposals.isEmpty
            ? _emptyDeliveryCard(
                'No proposals yet',
                'Generate a proposal from a saved quotation.',
              )
            : Column(children: proposals.map(_proposalRow).toList()),
      ),
      'Invoices' => _financialSection(
        'Invoices & payments',
        'Prepare invoices from approved proposals and track payment status',
        invoices.isEmpty
            ? _emptyDeliveryCard(
                'No invoices yet',
                'Approved proposals can be prepared as invoices.',
              )
            : Column(children: invoices.map(_invoiceRow).toList()),
      ),
      'Line item catalog' => _financialSection(
        'Workspace line item catalog',
        'Configure per-square-foot Basic, Medium, and Luxury rates for quotations',
        LineItemCatalogPanel(
          catalog: _lineItemCatalog,
          currencySymbol: _financials.settings.currencySymbol,
          canManage: canManage,
          loading: _lineItemCatalogLoading,
          error: _lineItemCatalogError,
          onSave: _saveLineItemCatalogEntry,
        ),
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canManage)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _manageTemplates,
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('Document templates'),
                ),
                OutlinedButton.icon(
                  onPressed: _editFinancialSettings,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Proposal settings'),
                ),
              ],
            ),
          if (canManage) const SizedBox(height: 14),
          _projectFinanceControls(canManage),
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('A BEAUTIFUL IDEA, CLEARLY PRESENTED'),
        const SizedBox(height: 8),
        Text('Proposals & finances', style: _heading(30)),
        const SizedBox(height: 7),
        const Text(
          'Build a considered scope, present it beautifully, and track payment.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _metricGrid(wide, finance: true),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canManage)
              FilledButton.icon(
                onPressed: _createQuotation,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New quotation'),
                style: FilledButton.styleFrom(backgroundColor: ink),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, icon) in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(label),
                    selected: _proposalTab == label,
                    onSelected: (_) {
                      setState(() => _proposalTab = label);
                      if (label == 'Line item catalog') {
                        _loadLineItemCatalog();
                      }
                    },
                    selectedColor: ink,
                    labelStyle: TextStyle(
                      color: _proposalTab == label ? paper : muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: _proposalTab == label ? ink : line),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        tabContent,
      ],
    );
  }

  Widget _projectFinanceControls(bool canManage) {
    final expenditures = _financials.projectExpenditures;
    final bills = _financials.vendorBills;
    final reconciliations = _financials.bankReconciliations;
    return _financialSection(
      'Project finance controls',
      'Expenditure, vendor liabilities, PO/receipt matching, and reconciliation',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canManage)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _recordProjectExpenditure,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Record expenditure'),
                ),
                OutlinedButton.icon(
                  onPressed: _recordVendorBill,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Record vendor bill'),
                ),
                OutlinedButton.icon(
                  onPressed: _recordBankReconciliation,
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('Reconcile account'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (expenditures.isEmpty && bills.isEmpty && reconciliations.isEmpty)
            _emptyDeliveryCard(
              'No project finance records',
              'Record expenditure or a matched vendor bill to establish the project ledger.',
            )
          else ...[
            for (final item in expenditures)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.description),
                subtitle: Text('${item.category} · ${item.reference}'),
                trailing: Text(
                  '${item.currency} ${(item.amountMinor / 100).toStringAsFixed(2)}',
                ),
              ),
            for (final bill in bills)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Vendor bill ${bill.billNumber}'),
                subtitle: Text(
                  '${bill.purchaseOrderId} · ${bill.receiptIds.length} receipt(s) · ${bill.status}',
                ),
                trailing: Text(
                  '${bill.currency} ${(bill.amountMinor / 100).toStringAsFixed(2)}',
                ),
              ),
            for (final item in reconciliations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.accountName),
                subtitle: Text(
                  '${_dateLabel(item.statementDate)} · ${item.status}',
                ),
                trailing: Text(
                  '${item.ledgerBalanceMinor == item.statementBalanceMinor ? 'Matched' : 'Difference'}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _recordProjectExpenditure() async {
    if (_delivery.projects.isEmpty) {
      _toast('Create a project before recording expenditure.');
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Project expenditure',
        fields: [
          'Project ID',
          'Category',
          'Description',
          'Amount',
          'Currency',
          'Reference',
        ],
      ),
    );
    if (values == null) return;
    final project = _delivery.projects
        .where((item) => item.id == values['Project ID'])
        .firstOrNull;
    final amount = double.tryParse(values['Amount'] ?? '');
    if (project == null || amount == null || amount < 0) {
      _toast('Enter a valid project ID and non-negative amount.');
      return;
    }
    final record = StudioProjectExpenditure(
      id: 'expenditure-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      category: values['Category']!,
      description: values['Description']!,
      amountMinor: (amount * 100).round(),
      currency:
          (values['Currency']!.trim().isEmpty ? 'USD' : values['Currency']!)
              .toUpperCase(),
      occurredAt: DateTime.now().toUtc(),
      reference: values['Reference']!,
    );
    await _saveFinancials(
      _financials.copyWith(
        projectExpenditures: [..._financials.projectExpenditures, record],
      ),
      confirmation: 'Project expenditure recorded.',
      activityTitle: 'Project expenditure recorded',
      activityDetails: '${project.name} · ${record.description}',
    );
  }

  Future<void> _recordVendorBill() async {
    final issuedOrders = _delivery.purchaseOrders
        .where((order) => order.status == 'Issued')
        .toList();
    if (issuedOrders.isEmpty) {
      _toast('Issue a purchase order before recording a vendor bill.');
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Vendor bill',
        fields: [
          'Purchase order ID',
          'Receipt ID',
          'Bill number',
          'Amount',
          'Currency',
          'Vendor ID',
        ],
      ),
    );
    if (values == null) return;
    final order = issuedOrders
        .where((item) => item.id == values['Purchase order ID'])
        .firstOrNull;
    final receipt = _delivery.goodsReceipts
        .where((item) => item.id == values['Receipt ID'])
        .firstOrNull;
    final amount = double.tryParse(values['Amount'] ?? '');
    if (order == null ||
        receipt == null ||
        receipt.projectId != order.projectId ||
        receipt.purchaseOrderId != order.id ||
        amount == null ||
        amount <= 0) {
      _toast('The bill must match an issued PO and a linked goods receipt.');
      return;
    }
    final bill = StudioVendorBill(
      id: 'vendor-bill-${DateTime.now().microsecondsSinceEpoch}',
      projectId: order.projectId,
      vendorId: values['Vendor ID']!.isEmpty
          ? order.vendorId
          : values['Vendor ID']!,
      purchaseOrderId: order.id,
      receiptIds: [receipt.id],
      billNumber: values['Bill number']!,
      amountMinor: (amount * 100).round(),
      currency:
          (values['Currency']!.trim().isEmpty ? 'USD' : values['Currency']!)
              .toUpperCase(),
      status: 'Open',
      dueAt: null,
    );
    await _saveFinancials(
      _financials.copyWith(vendorBills: [..._financials.vendorBills, bill]),
      confirmation: 'Vendor bill recorded and matched.',
      activityTitle: 'Vendor bill recorded',
      activityDetails: '${bill.billNumber} · ${bill.purchaseOrderId}',
    );
  }

  Future<void> _recordBankReconciliation() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Bank reconciliation',
        fields: [
          'Project ID',
          'Account name',
          'Statement balance',
          'Ledger balance',
        ],
      ),
    );
    if (values == null) return;
    final project = _delivery.projects
        .where((item) => item.id == values['Project ID'])
        .firstOrNull;
    final statement = double.tryParse(values['Statement balance'] ?? '');
    final ledger = double.tryParse(values['Ledger balance'] ?? '');
    if (project == null || statement == null || ledger == null) {
      _toast('Enter a valid project ID and both balances.');
      return;
    }
    final statementMinor = (statement * 100).round();
    final ledgerMinor = (ledger * 100).round();
    final reconciliation = StudioBankReconciliation(
      id: 'reconciliation-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      accountName: values['Account name']!,
      statementDate: DateTime.now().toUtc(),
      statementBalanceMinor: statementMinor,
      ledgerBalanceMinor: ledgerMinor,
      status: statementMinor == ledgerMinor ? 'Matched' : 'Difference',
    );
    await _saveFinancials(
      _financials.copyWith(
        bankReconciliations: [
          ..._financials.bankReconciliations,
          reconciliation,
        ],
      ),
      confirmation: 'Bank reconciliation recorded.',
      activityTitle: 'Bank reconciliation recorded',
      activityDetails: '${project.name} · ${reconciliation.status}',
    );
  }

  Widget _financialSection(String title, String subtitle, Widget child) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: muted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _quotationRow(StudioQuotation quotation) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.request_quote_outlined, color: accent, size: 19),
    title: Text(
      '${quotation.number} · ${quotation.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      '${quotation.clientName} · ${quotation.projectName} · ${quotation.items.length} line items',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
    ),
    trailing: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _formatCurrency(quotation.total, quotation.currencySymbol),
          style: const TextStyle(
            fontFamily: 'Arial',
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Quotation actions',
          onSelected: (action) {
            if (action == 'edit') _editQuotation(quotation);
            if (action == 'proposal') _generateProposal(quotation);
          },
          itemBuilder: (context) => [
            if (_can(StudioPersona.manageFinancials)) ...[
              const PopupMenuItem(value: 'edit', child: Text('Edit quotation')),
              const PopupMenuItem(
                value: 'proposal',
                child: Text('Generate proposal'),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _proposalRow(StudioProposal proposal) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.description_outlined, color: accent, size: 19),
    title: Text(
      '${proposal.number} · ${proposal.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      '${proposal.clientName} · ${proposal.projectName} · ${proposal.status} · ${_formatCurrency(proposal.total, proposal.currencySymbol)}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
    ),
    trailing: PopupMenuButton<String>(
      tooltip: 'Proposal actions',
      onSelected: (action) {
        if (action == 'preview') _previewProposal(proposal);
        if (action == 'export') _exportProposal(proposal);
        if (action == 'approval') _requestProposalApproval(proposal);
        if (action == 'invoice') _prepareInvoice(proposal);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'preview', child: Text('Preview')),
        const PopupMenuItem(value: 'export', child: Text('Export proposal')),
        if (_can(StudioPersona.manageFinancials) &&
            _can(StudioPersona.manageApprovals) &&
            ['Draft', 'Rejected'].contains(proposal.status))
          const PopupMenuItem(
            value: 'approval',
            child: Text('Request approval'),
          ),
        if (_can(StudioPersona.manageFinancials) &&
            proposal.status == 'Approved' &&
            !_financials.invoices.any(
              (invoice) => invoice.proposalId == proposal.id,
            ))
          const PopupMenuItem(value: 'invoice', child: Text('Prepare invoice')),
      ],
    ),
  );

  Widget _invoiceRow(StudioInvoice invoice) {
    final isOverdue =
        invoice.status != 'Draft' &&
        invoice.status != 'Paid' &&
        invoice.dueDate.isBefore(DateTime.now());
    final displayStatus = isOverdue ? 'Overdue' : invoice.status;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long_outlined, color: accent, size: 19),
      title: Text(
        '${invoice.number} · ${invoice.clientName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Arial',
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${invoice.projectName} · $displayStatus · Balance ${_formatCurrency(invoice.balance, invoice.currencySymbol)} · Due ${_dateLabel(invoice.dueDate)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Invoice actions',
        onSelected: (action) {
          if (action == 'preview') _previewInvoice(invoice);
          if (action == 'export') _exportInvoice(invoice);
          if (action == 'send') _markInvoiceSent(invoice);
          if (action == 'payment') _recordInvoicePayment(invoice);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'preview', child: Text('View invoice')),
          if (_can(StudioPersona.viewFinancials))
            const PopupMenuItem(value: 'export', child: Text('Export invoice')),
          if (_can(StudioPersona.manageFinancials) && invoice.status == 'Draft')
            const PopupMenuItem(value: 'send', child: Text('Mark as sent')),
          if (_can(StudioPersona.manageFinancials) &&
              invoice.status != 'Draft' &&
              invoice.status != 'Paid')
            const PopupMenuItem(
              value: 'payment',
              child: Text('Record payment'),
            ),
        ],
      ),
    );
  }

  Future<void> _requestProposalApproval(StudioProposal proposal) async {
    if (!_can(StudioPersona.manageFinancials) ||
        !_can(StudioPersona.manageApprovals)) {
      _toast('This studio role cannot route a proposal for approval.');
      return;
    }
    if (!['Draft', 'Rejected'].contains(proposal.status)) {
      _toast('Only draft or rejected proposals can be submitted for approval.');
      return;
    }
    final project = _projectFor(proposal.projectId);
    if (project == null) {
      _toast('The proposal project is no longer available.');
      return;
    }
    await _createApproval(project, proposal: proposal);
  }

  Future<void> _previewInvoice(StudioInvoice invoice) async {
    await showDialog<void>(
      context: context,
      builder: (context) => InvoicePreviewDialog(
        invoice: invoice,
        onExport: () => _exportInvoice(invoice),
      ),
    );
  }

  Future<void> _exportInvoice(StudioInvoice invoice) async {
    try {
      final lineRows = invoice.items.map((item) {
        return '<tr><td>${_escapeHtml(item.description)}</td>'
            '<td>${item.quantity}</td><td>${_escapeHtml(item.unit)}</td>'
            '<td>${_escapeHtml(_formatCurrency(item.unitRate, invoice.currencySymbol))}</td>'
            '<td>${_escapeHtml(_formatCurrency(item.amount, invoice.currencySymbol))}</td></tr>';
      }).join();
      final memo = invoice.memo.trim().isEmpty
          ? ''
          : '<section><h2>Notes</h2><p>${_escapeHtml(invoice.memo)}</p></section>';
      final html =
          '<!doctype html><html><head><meta charset="utf-8">'
          '<meta name="viewport" content="width=device-width, initial-scale=1">'
          '<title>${_escapeHtml(invoice.number)} · ${_escapeHtml(invoice.title)}</title>'
          '<style>body{font:16px Georgia,serif;color:#24332d;max-width:900px;margin:48px auto;padding:0 24px}'
          'header{border-bottom:3px solid #24332d;padding-bottom:24px;margin-bottom:32px}'
          'h1{font-size:34px}h2{font-size:18px}table{width:100%;border-collapse:collapse;font:14px Arial,sans-serif}'
          'th,td{text-align:left;padding:10px;border-bottom:1px solid #e9e6de}'
          '.total{text-align:right;font-weight:bold;margin-top:24px}</style></head>'
          '<body><header><h1>Invoice ${_escapeHtml(invoice.number)}</h1>'
          '<p>${_escapeHtml(invoice.clientName)} · ${_escapeHtml(invoice.clientEmail)}</p>'
          '<p>${_escapeHtml(invoice.projectName)} · ${_escapeHtml(invoice.title)}</p>'
          '<p>Issued ${_escapeHtml(_dateLabel(invoice.issuedAt))} · '
          'Due ${_escapeHtml(_dateLabel(invoice.dueDate))} · '
          '${_escapeHtml(invoice.status)}</p></header>'
          '<table><thead><tr><th>Description</th><th>Qty</th><th>Unit</th>'
          '<th>Rate</th><th>Amount</th></tr></thead><tbody>$lineRows</tbody></table>'
          '<section class="total"><p>Subtotal: ${_escapeHtml(_formatCurrency(invoice.subtotal, invoice.currencySymbol))}</p>'
          '<p>Tax (${invoice.taxRate.toStringAsFixed(2)}%): '
          '${_escapeHtml(_formatCurrency(invoice.taxAmount, invoice.currencySymbol))}</p>'
          '<p>Total: ${_escapeHtml(_formatCurrency(invoice.total, invoice.currencySymbol))}</p>'
          '<p>Paid: ${_escapeHtml(_formatCurrency(invoice.paidAmount, invoice.currencySymbol))}</p>'
          '<p>Balance due: ${_escapeHtml(_formatCurrency(invoice.balance, invoice.currencySymbol))}</p>'
          '</section>$memo</body></html>';
      final safeNumber = invoice.number.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '-',
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export client invoice',
        fileName: '$safeNumber.html',
        bytes: Uint8List.fromList(utf8.encode(html)),
      );
      if (path != null && mounted) {
        _toast('${invoice.number} exported.');
      }
    } on Exception catch (error) {
      if (mounted) _toast('Could not export invoice: $error');
    }
  }

  Widget _tasksPage() => !_can(StudioPersona.viewProjects)
      ? _accessNotice()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('THE DETAILS MAKE THE DIFFERENCE'),
            const SizedBox(height: 8),
            Text('Tasks & follow-through', style: _heading(30)),
            const SizedBox(height: 7),
            const Text(
              'Assigned, scheduled, and linked to studio projects.',
              style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _taskFilter,
                    decoration: const InputDecoration(labelText: 'Show tasks'),
                    items: const ['All', 'Open', 'Complete']
                        .map(
                          (filter) => DropdownMenuItem(
                            value: filter,
                            child: Text(filter),
                          ),
                        )
                        .toList(),
                    onChanged: (filter) {
                      if (filter != null) setState(() => _taskFilter = filter);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (_can(StudioPersona.manageTasks))
                  FilledButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New task'),
                    style: FilledButton.styleFrom(backgroundColor: ink),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  if (_filteredTasks.isEmpty)
                    _emptyDeliveryCard(
                      'No matching tasks',
                      _delivery.projects.isEmpty
                          ? 'Create a project before adding a task.'
                          : 'Adjust the filter or add a new project task.',
                    )
                  else
                    ..._filteredTasks.map(_taskRow),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _featureNote(
              'A calmer way to keep momentum',
              'Task suggestions use due dates, open milestones, and project activity to highlight practical next steps.',
            ),
          ],
        );

  Widget _deliveryPage() {
    if (!_can(StudioPersona.viewProjects)) return _accessNotice();
    final project = _selectedProject;
    if (project == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow('PROJECT DELIVERY'),
          const SizedBox(height: 8),
          Text('Project delivery', style: _heading(30)),
          const SizedBox(height: 14),
          _emptyDeliveryCard(
            'Start with a project',
            'Create a project to manage tasks, milestones, files, work logs, and approvals.',
          ),
          if (_can(StudioPersona.manageProjects))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: FilledButton.icon(
                onPressed: _createProject,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create project'),
                style: FilledButton.styleFrom(backgroundColor: ink),
              ),
            ),
        ],
      );
    }

    final tasks =
        _delivery.tasks.where((task) => task.projectId == project.id).toList()
          ..sort((first, second) {
            if (first.isComplete != second.isComplete) {
              return first.isComplete ? 1 : -1;
            }
            return (first.dueDate ?? DateTime(9999)).compareTo(
              second.dueDate ?? DateTime(9999),
            );
          });
    final milestones =
        _delivery.milestones
            .where((item) => item.projectId == project.id)
            .toList()
          ..sort(
            (first, second) => (first.dueDate ?? DateTime(9999)).compareTo(
              second.dueDate ?? DateTime(9999),
            ),
          );
    final punchItems = _delivery.punchItems
        .where((item) => item.projectId == project.id)
        .toList();
    final projectAssets = _delivery.assets
        .where((item) => item.projectId == project.id)
        .toList();
    final documents = projectAssets
        .where((item) => item.kind == 'document')
        .toList();
    final photos = projectAssets.where((item) => item.kind == 'photo').toList();
    final workLogs =
        _delivery.workLogs.where((log) => log.projectId == project.id).toList()
          ..sort((first, second) => second.loggedAt.compareTo(first.loggedAt));
    final approvals =
        _delivery.approvals
            .where((approval) => approval.projectId == project.id)
            .toList()
          ..sort(
            (first, second) => second.requestedAt.compareTo(first.requestedAt),
          );
    final projectCommunications =
        _communications.where((entry) => entry.projectId == project.id).toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('PROJECT DELIVERY'),
        const SizedBox(height: 8),
        Text('Project delivery', style: _heading(30)),
        const SizedBox(height: 7),
        const Text(
          'A working view of every project commitment and update.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: project.id,
                decoration: const InputDecoration(labelText: 'Project'),
                items: _delivery.projects
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) setState(() => _selectedProjectId = id);
                },
              ),
            ),
            const SizedBox(width: 10),
            if (_can(StudioPersona.manageProjects))
              IconButton(
                tooltip: 'Open project details',
                onPressed: () => _editProject(project),
                icon: const Icon(Icons.edit_outlined, color: ink),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Communication history',
          'Client messages and team notes for this project',
          onAdd: _can(StudioPersona.viewCommunications)
              ? () => _openCommunications(projectId: project.id)
              : null,
          addLabel: 'Open history',
          child: !_can(StudioPersona.viewCommunications)
              ? _accessNotice()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (projectCommunications.isEmpty)
                      _emptyDeliveryCard(
                        'No project conversations yet',
                        'Notes and client messages will be collected here.',
                      )
                    else
                      ...projectCommunications.take(3).map(_communicationRow),
                    if (_can(StudioPersona.manageCommunications))
                      TextButton.icon(
                        onPressed: () => _createCommunication(
                          clientId: project.customerId,
                          projectId: project.id,
                        ),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Add project note'),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _taskSuggestionsPanel(project, tasks, milestones, approvals),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Project tasks',
          'Assigned work and due dates',
          onAdd: _can(StudioPersona.manageTasks)
              ? () => _createProjectTask(projectId: project.id)
              : null,
          addLabel: 'Add task',
          child: tasks.isEmpty
              ? _emptyDeliveryCard(
                  'No project tasks',
                  'Create the first task for ${project.name}.',
                )
              : Column(children: tasks.map(_taskRow).toList()),
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Milestones & updates',
          'Progress and status history',
          onAdd: _can(StudioPersona.manageMilestones)
              ? () => _createMilestone(project)
              : null,
          addLabel: 'Add milestone',
          child: milestones.isEmpty
              ? _emptyDeliveryCard(
                  'No milestones yet',
                  'Add due dates and record progress as the project moves forward.',
                )
              : Column(
                  children: milestones
                      .map((item) => _milestoneRow(item))
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Punch list',
          'Outstanding site items',
          onAdd: _can(StudioPersona.managePunchList)
              ? () => _createPunchItem(project)
              : null,
          addLabel: 'Add item',
          child: punchItems.isEmpty
              ? _emptyDeliveryCard(
                  'Nothing on the punch list',
                  'Record site items, assign a person, and track resolution.',
                )
              : Column(
                  children: punchItems
                      .map((item) => _punchItemRow(item))
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Project documents',
          'Organized files with searchable metadata',
          onAdd: _can(StudioPersona.manageFiles)
              ? () => _addProjectAsset(project, 'document')
              : null,
          addLabel: 'Upload document',
          child: !_can(StudioPersona.viewFiles)
              ? _accessNotice()
              : Column(
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setState(() => _documentQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search project documents...',
                        prefixIcon: Icon(Icons.search, size: 17),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...documents
                        .where(
                          (asset) => '${asset.name} ${asset.caption}'
                              .toLowerCase()
                              .contains(_documentQuery.toLowerCase()),
                        )
                        .map(_assetRow),
                    if (documents.isEmpty)
                      _emptyDeliveryCard(
                        'No project documents',
                        'Upload a plan, specification, or client-approved file.',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Progress photos',
          'Dated, captioned site and design updates',
          onAdd: _can(StudioPersona.manageFiles)
              ? () => _addProjectAsset(project, 'photo')
              : null,
          addLabel: 'Add photo',
          child: !_can(StudioPersona.viewFiles)
              ? _accessNotice()
              : photos.isEmpty
              ? _emptyDeliveryCard(
                  'No progress photos',
                  'Add an image with a caption to record project progress.',
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: photos.map(_photoCard).toList(),
                ),
        ),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Work logs',
          'Time and notes against project work',
          onAdd: _can(StudioPersona.manageWorkLogs)
              ? () => _createWorkLog(project)
              : null,
          addLabel: 'Log work',
          child: !_can(StudioPersona.viewWorkLogs)
              ? _accessNotice()
              : workLogs.isEmpty
              ? _emptyDeliveryCard(
                  'No work logged',
                  'Record time against a project or a specific task.',
                )
              : Column(children: workLogs.map(_workLogRow).toList()),
        ),
        const SizedBox(height: 14),
        _siteExecutionPanel(project),
        const SizedBox(height: 14),
        _workforcePanel(project),
        const SizedBox(height: 14),
        _attendancePanel(),
        const SizedBox(height: 14),
        _deliveryPanel(
          'Approval routing',
          'Assign requests to studio roles and retain decisions',
          onAdd: _can(StudioPersona.manageApprovals)
              ? () => _createApproval(project)
              : null,
          addLabel: 'Request approval',
          child:
              !_can(StudioPersona.manageApprovals) &&
                  !_can(StudioPersona.approveApprovals)
              ? _accessNotice()
              : approvals.isEmpty
              ? _emptyDeliveryCard(
                  'No approval requests',
                  'Route a project decision to an authorized studio role.',
                )
              : Column(children: approvals.map(_approvalRow).toList()),
        ),
      ],
    );
  }

  Future<void> _createGoodsReceipt(StudioProject project) async {
    final issuedOrders = _delivery.purchaseOrders
        .where(
          (order) => order.projectId == project.id && order.status == 'Issued',
        )
        .toList();
    if (issuedOrders.isEmpty) {
      _toast('Issue a purchase order before recording goods received.');
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SimpleMultiPromptDialog(
        title: 'Goods receipt',
        fields: const [
          'Purchase order ID',
          'Location',
          'Purchase order line ID',
          'Received quantity',
          'Accepted quantity',
          'Notes',
        ],
      ),
    );
    if (values == null) return;
    final order = issuedOrders
        .where((item) => item.id == values['Purchase order ID'])
        .firstOrNull;
    final lineId = values['Purchase order line ID'];
    final quantity = double.tryParse(values['Received quantity'] ?? '');
    final accepted = double.tryParse(values['Accepted quantity'] ?? '');
    if (order == null ||
        lineId == null ||
        quantity == null ||
        accepted == null ||
        !order.items.any((line) => line.requisitionLineId == lineId) ||
        quantity <= 0 ||
        accepted < 0 ||
        accepted > quantity) {
      _toast(
        'Use an issued PO and a matching PO line; accepted quantity cannot exceed received quantity.',
      );
      return;
    }
    final receipt = StudioGoodsReceipt(
      id: 'receipt-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      purchaseOrderId: order.id,
      location: values['Location']!.trim(),
      notes: values['Notes']!.trim(),
      status: accepted == quantity ? 'Complete' : 'Partial',
      lines: [
        StudioGoodsReceiptLine(
          purchaseOrderLineId: lineId,
          quantityMilli: (quantity * 1000).round(),
          acceptedQuantityMilli: (accepted * 1000).round(),
        ),
      ],
      receivedAt: DateTime.now().toUtc(),
    );
    await _saveDelivery(
      _delivery.copyWith(goodsReceipts: [..._delivery.goodsReceipts, receipt]),
      confirmation: 'Goods receipt recorded.',
      activityTitle: 'Goods receipt recorded',
      activityDetails: '${project.name} · ${order.id} · $lineId',
    );
  }

  Future<void> _createStockMovement(StudioProject project) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SimpleMultiPromptDialog(
        title: 'Stock movement',
        fields: const [
          'Material ID',
          'Kind (Receipt, Transfer, Consumption, Adjustment)',
          'From location',
          'To location',
          'Quantity',
          'Reference',
          'Notes',
        ],
      ),
    );
    if (values == null) return;
    final quantity = double.tryParse(values['Quantity'] ?? '');
    final kind = values['Kind (Receipt, Transfer, Consumption, Adjustment)'];
    if (quantity == null ||
        quantity <= 0 ||
        !const [
          'Receipt',
          'Transfer',
          'Consumption',
          'Adjustment',
        ].contains(kind)) {
      _toast('Enter a valid stock kind and quantity.');
      return;
    }
    final movement = StudioStockMovement(
      id: 'stock-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      materialId: values['Material ID']!,
      kind: kind!,
      fromLocation: values['From location']!.trim().isEmpty
          ? null
          : values['From location']!.trim(),
      toLocation: values['To location']!.trim().isEmpty
          ? null
          : values['To location']!.trim(),
      quantityMilli: (quantity * 1000).round(),
      reference: values['Reference']!.trim(),
      notes: values['Notes']!.trim(),
      occurredAt: DateTime.now().toUtc(),
    );
    final movements = [..._delivery.stockMovements, movement];
    final existing = _delivery.stockBalances
        .where(
          (balance) =>
              balance.projectId == project.id &&
              balance.materialId == movement.materialId &&
              balance.location ==
                  (movement.toLocation ?? movement.fromLocation ?? ''),
        )
        .firstOrNull;
    final balances = _delivery.stockBalances
        .where(
          (balance) =>
              !(balance.projectId == project.id &&
                  balance.materialId == movement.materialId &&
                  balance.location ==
                      (movement.toLocation ?? movement.fromLocation ?? '')),
        )
        .toList();
    final delta = kind == 'Consumption'
        ? -movement.quantityMilli
        : movement.quantityMilli;
    balances.add(
      StudioStockBalance(
        id:
            existing?.id ??
            'stock-balance-${DateTime.now().microsecondsSinceEpoch}',
        projectId: project.id,
        materialId: movement.materialId,
        location: movement.toLocation ?? movement.fromLocation ?? 'Site',
        quantityMilli: (existing?.quantityMilli ?? 0) + delta,
      ),
    );
    await _saveDelivery(
      _delivery.copyWith(stockMovements: movements, stockBalances: balances),
      confirmation: 'Stock movement recorded.',
      activityTitle: 'Stock movement recorded',
      activityDetails: '${project.name} · ${movement.kind} · $kind',
    );
  }

  Future<void> _createWorkOrder(StudioProject project) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Work order',
        fields: ['Title', 'Contractor', 'Scope', 'Priority'],
      ),
    );
    if (values == null || values['Title']!.isEmpty) return;
    final order = StudioWorkOrder(
      id: 'work-order-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      title: values['Title']!,
      contractor: values['Contractor']!,
      scope: values['Scope']!,
      status: 'Open',
      priority: values['Priority']!.isEmpty ? 'Normal' : values['Priority']!,
      startDate: null,
      dueDate: null,
    );
    await _saveDelivery(
      _delivery.copyWith(workOrders: [..._delivery.workOrders, order]),
      confirmation: 'Work order created.',
      activityTitle: 'Work order created',
      activityDetails: '${project.name} · ${order.title}',
    );
  }

  Future<void> _createDailyReport(StudioProject project) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Daily project report',
        fields: ['Summary', 'Weather', 'Workforce count', 'Delays'],
      ),
    );
    if (values == null || values['Summary']!.isEmpty) return;
    final workforce = int.tryParse(values['Workforce count'] ?? '') ?? 0;
    if (workforce < 0) {
      _toast('Workforce count cannot be negative.');
      return;
    }
    final report = StudioDailyReport(
      id: 'daily-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      reportDate: DateTime.now().toUtc(),
      summary: values['Summary']!,
      weather: values['Weather']!,
      workforceCount: workforce,
      delays: values['Delays']!,
    );
    await _saveDelivery(
      _delivery.copyWith(dailyReports: [..._delivery.dailyReports, report]),
      confirmation: 'Daily report recorded.',
      activityTitle: 'Daily project report recorded',
      activityDetails: '${project.name} · ${report.summary}',
    );
  }

  Future<void> _createSiteInspection(StudioProject project) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Site inspection',
        fields: ['Title', 'Kind (Quality or Safety)', 'Inspector', 'Findings'],
      ),
    );
    if (values == null || values['Title']!.isEmpty) return;
    final kind = values['Kind (Quality or Safety)'];
    if (!const ['Quality', 'Safety'].contains(kind)) {
      _toast('Inspection kind must be Quality or Safety.');
      return;
    }
    final inspection = StudioSiteInspection(
      id: 'inspection-${DateTime.now().microsecondsSinceEpoch}',
      projectId: project.id,
      title: values['Title']!,
      kind: kind!,
      status: 'Open',
      inspector: values['Inspector']!,
      findings: values['Findings']!,
      inspectedAt: DateTime.now().toUtc(),
    );
    await _saveDelivery(
      _delivery.copyWith(
        siteInspections: [..._delivery.siteInspections, inspection],
      ),
      confirmation: 'Site inspection recorded.',
      activityTitle: 'Site inspection recorded',
      activityDetails: '${project.name} · ${inspection.title}',
    );
  }

  Widget _workforcePanel(StudioProject project) {
    final workers = _delivery.workers;
    final allocations = _delivery.workforceAllocations
        .where((item) => item.projectId == project.id)
        .toList();
    final attendance = _delivery.siteAttendance
        .where((item) => item.projectId == project.id)
        .toList();
    return _deliveryPanel(
      'Workforce & attendance',
      'Employee and contractor records, allocations, and site attendance',
      onAdd: _can(StudioPersona.manageAttendance)
          ? () => _createWorker()
          : null,
      addLabel: 'Add worker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_can(StudioPersona.manageAttendance)) ...[
            OutlinedButton.icon(
              onPressed: () => _allocateWorker(project),
              icon: const Icon(Icons.assignment_ind_outlined, size: 16),
              label: const Text('Allocate worker'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _recordSiteAttendance(project),
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: const Text('Record attendance'),
            ),
          ],
          const SizedBox(height: 10),
          if (workers.isEmpty)
            _procurementEmpty('No worker or contractor records.')
          else
            for (final worker in workers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(worker.name),
                subtitle: Text(
                  '${worker.kind} · ${worker.role} · ${worker.status}',
                ),
              ),
          if (allocations.isNotEmpty)
            for (final allocation in allocations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  workers
                          .where((worker) => worker.id == allocation.workerId)
                          .firstOrNull
                          ?.name ??
                      allocation.workerId,
                ),
                subtitle: Text(_dateLabel(allocation.startDate)),
              ),
          if (attendance.isNotEmpty)
            for (final entry in attendance)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  workers
                          .where((worker) => worker.id == entry.workerId)
                          .firstOrNull
                          ?.name ??
                      entry.workerId,
                ),
                subtitle: Text('${_dateLabel(entry.date)} · ${entry.status}'),
              ),
        ],
      ),
    );
  }

  Future<void> _createWorker() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Worker or contractor',
        fields: [
          'Name',
          'Kind (Employee or Contractor)',
          'Role',
          'Phone',
          'Email',
        ],
      ),
    );
    if (values == null || values['Name']!.isEmpty) return;
    final kind = values['Kind (Employee or Contractor)'];
    if (!const ['Employee', 'Contractor'].contains(kind)) {
      _toast('Worker kind must be Employee or Contractor.');
      return;
    }
    final worker = StudioWorker(
      id: 'worker-${DateTime.now().microsecondsSinceEpoch}',
      name: values['Name']!,
      kind: kind!,
      role: values['Role']!,
      phone: values['Phone']!,
      email: values['Email']!,
      status: 'Active',
    );
    await _saveDelivery(
      _delivery.copyWith(workers: [..._delivery.workers, worker]),
      confirmation: 'Worker record added.',
      activityTitle: 'Worker record added',
      activityDetails: worker.name,
    );
  }

  Future<void> _allocateWorker(StudioProject project) async {
    final workers = _delivery.workers
        .where((worker) => worker.status == 'Active')
        .toList();
    if (workers.isEmpty) {
      _toast('Add an active worker before allocation.');
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Allocate worker',
        fields: ['Worker ID', 'Notes'],
      ),
    );
    if (values == null) return;
    final worker = workers
        .where((item) => item.id == values['Worker ID'])
        .firstOrNull;
    if (worker == null) {
      _toast('Enter a valid active worker ID.');
      return;
    }
    await _saveDelivery(
      _delivery.copyWith(
        workforceAllocations: [
          ..._delivery.workforceAllocations,
          StudioWorkforceAllocation(
            id: 'allocation-${DateTime.now().microsecondsSinceEpoch}',
            workerId: worker.id,
            projectId: project.id,
            startDate: DateTime.now().toUtc(),
            endDate: null,
            notes: values['Notes']!,
          ),
        ],
      ),
      confirmation: 'Worker allocated to project.',
      activityTitle: 'Worker allocated',
      activityDetails: '${project.name} · ${worker.name}',
    );
  }

  Future<void> _recordSiteAttendance(StudioProject project) async {
    final workers = _delivery.workers
        .where((worker) => worker.status == 'Active')
        .toList();
    if (workers.isEmpty) {
      _toast('Add an active worker before recording attendance.');
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Site attendance',
        fields: ['Worker ID', 'Status (Present, Late, Away, Remote)', 'Note'],
      ),
    );
    if (values == null) return;
    final worker = workers
        .where((item) => item.id == values['Worker ID'])
        .firstOrNull;
    final status = values['Status (Present, Late, Away, Remote)'];
    if (worker == null ||
        !const ['Present', 'Late', 'Away', 'Remote'].contains(status)) {
      _toast('Enter a valid worker ID and attendance status.');
      return;
    }
    await _saveDelivery(
      _delivery.copyWith(
        siteAttendance: [
          ..._delivery.siteAttendance,
          StudioSiteAttendance(
            id: 'attendance-${DateTime.now().microsecondsSinceEpoch}',
            workerId: worker.id,
            projectId: project.id,
            date: DateTime.now().toUtc(),
            status: status!,
            checkIn: status == 'Away' ? null : DateTime.now().toUtc(),
            checkOut: null,
            note: values['Note']!,
          ),
        ],
      ),
      confirmation: 'Site attendance recorded.',
      activityTitle: 'Workforce attendance recorded',
      activityDetails: '${project.name} · ${worker.name} · $status',
    );
  }

  Widget _siteExecutionPanel(StudioProject project) {
    final receipts = _delivery.goodsReceipts
        .where((item) => item.projectId == project.id)
        .toList();
    final movements = _delivery.stockMovements
        .where((item) => item.projectId == project.id)
        .toList();
    final workOrders = _delivery.workOrders
        .where((item) => item.projectId == project.id)
        .toList();
    final reports = _delivery.dailyReports
        .where((item) => item.projectId == project.id)
        .toList();
    final inspections = _delivery.siteInspections
        .where((item) => item.projectId == project.id)
        .toList();
    final balances = _delivery.stockBalances
        .where((item) => item.projectId == project.id)
        .toList();

    return _deliveryPanel(
      'Inventory & site execution',
      'Receipts, stock, work orders, reports, and inspections',
      onAdd: _can(StudioPersona.manageMaterials)
          ? () => _createDailyReport(project)
          : null,
      addLabel: 'Add daily report',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_can(StudioPersona.manageMaterials))
                OutlinedButton.icon(
                  onPressed: () => _createGoodsReceipt(project),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Goods receipt'),
                ),
              if (_can(StudioPersona.manageMaterials))
                OutlinedButton.icon(
                  onPressed: () => _createStockMovement(project),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Stock movement'),
                ),
              if (_can(StudioPersona.manageProjects))
                OutlinedButton.icon(
                  onPressed: () => _createWorkOrder(project),
                  icon: const Icon(Icons.engineering_outlined, size: 16),
                  label: const Text('Work order'),
                ),
              if (_can(StudioPersona.managePunchList))
                OutlinedButton.icon(
                  onPressed: () => _createSiteInspection(project),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Inspection'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Stock balances', style: _heading(15)),
          const SizedBox(height: 6),
          if (balances.isEmpty)
            _procurementEmpty('No stock balances recorded.')
          else
            for (final balance in balances)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _delivery.materials
                          .where(
                            (material) => material.id == balance.materialId,
                          )
                          .firstOrNull
                          ?.name ??
                      balance.materialId,
                ),
                subtitle: Text(balance.location),
                trailing: Text(
                  balance.quantity.toStringAsFixed(3),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          if (receipts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Goods receipts', style: _heading(15)),
            for (final receipt in receipts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(receipt.purchaseOrderId),
                subtitle: Text(
                  '${receipt.location} · ${receipt.status} · ${receipt.lines.length} line(s)',
                ),
              ),
          ],
          if (movements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Stock movements', style: _heading(15)),
            for (final movement in movements)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(movement.kind),
                subtitle: Text(
                  '${movement.fromLocation ?? ''}${movement.fromLocation == null ? '' : ' -> '}${movement.toLocation ?? ''} · ${movement.quantityMilli / 1000} · ${movement.notes}',
                ),
              ),
          ],
          if (workOrders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Work orders', style: _heading(15)),
            for (final order in workOrders)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(order.title),
                subtitle: Text(
                  '${order.contractor} · ${order.status} · ${order.priority}',
                ),
              ),
          ],
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Daily reports', style: _heading(15)),
            for (final report in reports)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_dateLabel(report.reportDate)),
                subtitle: Text(
                  '${report.weather} · ${report.workforceCount} workforce · ${report.summary}',
                ),
              ),
          ],
          if (inspections.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Inspections', style: _heading(15)),
            for (final inspection in inspections)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(inspection.title),
                subtitle: Text(
                  '${inspection.kind} · ${inspection.status} · ${inspection.inspector}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryPanel(
    String title,
    String subtitle, {
    required Widget child,
    VoidCallback? onAdd,
    String? addLabel,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: Text(addLabel ?? 'Add'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _emptyDeliveryCard(String title, String detail) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ink,
            fontFamily: 'Arial',
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: const TextStyle(
            color: muted,
            fontFamily: 'Arial',
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _taskSuggestionsPanel(
    StudioProject project,
    List<StudioTaskRecord> tasks,
    List<StudioMilestone> milestones,
    List<StudioApproval> approvals,
  ) {
    final today = DateTime.now();
    final overdueTasks = tasks
        .where(
          (task) =>
              !task.isComplete &&
              task.dueDate != null &&
              task.dueDate!.isBefore(
                DateTime(today.year, today.month, today.day),
              ),
        )
        .toList();
    final suggestions = <Widget>[];
    if (overdueTasks.isNotEmpty) {
      suggestions.add(
        _suggestionRow(
          'Review ${overdueTasks.length} overdue task${overdueTasks.length == 1 ? '' : 's'}',
          'Open tasks have due dates before today.',
          Icons.schedule_outlined,
          () => _navigate(4),
        ),
      );
    }
    if (tasks.isEmpty && _can(StudioPersona.manageTasks)) {
      suggestions.add(
        _suggestionRow(
          'Set the next project action',
          'This project has no tasks scheduled yet.',
          Icons.add_task,
          () => _createProjectTask(projectId: project.id),
        ),
      );
    }
    final openMilestones = milestones
        .where((item) => item.status != 'Complete')
        .toList();
    if (openMilestones.isNotEmpty &&
        openMilestones.every(
          (item) =>
              item.dueDate == null ||
              item.dueDate!.isBefore(
                DateTime(today.year, today.month, today.day),
              ),
        )) {
      suggestions.add(
        _suggestionRow(
          'Update milestone dates',
          'Open milestones are overdue or do not have a target date.',
          Icons.flag_outlined,
          _can(StudioPersona.manageMilestones)
              ? () => _editMilestone(openMilestones.first)
              : null,
        ),
      );
    }
    if (approvals.any((approval) => approval.status == 'Pending')) {
      suggestions.add(
        _suggestionRow(
          'Follow up on a pending approval',
          'A project decision is still awaiting review.',
          Icons.pending_actions,
          null,
        ),
      );
    }
    return _deliveryPanel(
      'Suggested next steps',
      'Based on open tasks, milestones, and approvals',
      child: suggestions.isEmpty
          ? _emptyDeliveryCard(
              'No suggested actions',
              'Project work is scheduled and there are no pending approvals.',
            )
          : Column(children: suggestions),
    );
  }

  Widget _suggestionRow(
    String title,
    String detail,
    IconData icon,
    VoidCallback? onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: accent, size: 19),
    title: Text(
      title,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
    subtitle: Text(
      detail,
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 10),
    ),
    trailing: onTap == null
        ? null
        : const Icon(Icons.arrow_forward_ios, size: 13, color: muted),
    onTap: onTap,
  );

  Widget _milestoneRow(StudioMilestone milestone) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.flag_outlined, color: accent, size: 18),
    title: Text(
      milestone.title,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
    subtitle: Text(
      [
        milestone.status,
        'Due ${_dateLabel(milestone.dueDate)}',
        if (milestone.update.isNotEmpty) milestone.update,
      ].join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
    ),
    trailing: _can(StudioPersona.manageMilestones)
        ? IconButton(
            tooltip: 'Edit milestone update',
            onPressed: () => _editMilestone(milestone),
            icon: const Icon(Icons.edit_outlined, size: 17, color: muted),
          )
        : _pill(milestone.status),
    onTap: _can(StudioPersona.manageMilestones)
        ? () => _editMilestone(milestone)
        : null,
  );

  Widget _punchItemRow(StudioPunchItem item) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      item.status == 'Resolved'
          ? Icons.check_circle_outline
          : Icons.build_outlined,
      color: item.status == 'Resolved' ? sage : accent,
      size: 18,
    ),
    title: Text(
      item.description,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    ),
    subtitle: Text(
      '${item.assignee} · Due ${_dateLabel(item.dueDate)}',
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
    ),
    trailing: DropdownButton<String>(
      value: item.status,
      underline: const SizedBox.shrink(),
      style: const TextStyle(fontFamily: 'Arial', color: ink, fontSize: 10),
      items: StudioPunchItem.statuses
          .map((status) => DropdownMenuItem(value: status, child: Text(status)))
          .toList(),
      onChanged: _can(StudioPersona.managePunchList)
          ? (status) {
              if (status != null) _updatePunchItem(item, status);
            }
          : null,
    ),
  );

  Widget _assetRow(StudioProjectAsset asset) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      asset.kind == 'photo'
          ? Icons.image_outlined
          : Icons.insert_drive_file_outlined,
      color: accent,
      size: 18,
    ),
    title: Text(
      asset.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Arial',
        color: ink,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    ),
    subtitle: Text(
      '${_formatBytes(asset.sizeBytes)} · ${_dateLabel(asset.addedAt)} · ${asset.addedBy}',
      style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
    ),
    onTap: () => _viewProjectAsset(asset),
    trailing: Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: 'Download ${asset.name}',
          onPressed: _can(StudioPersona.viewFiles)
              ? () => _downloadProjectAsset(asset)
              : null,
          icon: const Icon(Icons.download_outlined, size: 18, color: muted),
        ),
        if (_can(StudioPersona.manageFiles))
          IconButton(
            tooltip: 'Remove ${asset.name}',
            onPressed: () => _deleteProjectAsset(asset),
            icon: const Icon(Icons.delete_outline, size: 18, color: muted),
          ),
      ],
    ),
  );

  String _formatBytes(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(0)} KB';

  Widget _photoCard(StudioProjectAsset asset) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => _viewProjectAsset(asset),
    child: SizedBox(
      width: 122,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: asset.bytes.isEmpty
                ? Container(
                    width: 122,
                    height: 92,
                    color: line,
                    child: const Icon(
                      Icons.cloud_download_outlined,
                      color: muted,
                    ),
                  )
                : Image.memory(
                    Uint8List.fromList(asset.bytes),
                    width: 122,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 122,
                      height: 92,
                      color: line,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: muted,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            asset.caption.isEmpty ? asset.name : asset.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: ink,
              fontSize: 9,
            ),
          ),
          Text(
            _dateLabel(asset.addedAt),
            style: const TextStyle(
              fontFamily: 'Arial',
              color: muted,
              fontSize: 8,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _workLogRow(StudioWorkLog log) {
    StudioTaskRecord? task;
    for (final item in _delivery.tasks) {
      if (item.id == log.taskId) {
        task = item;
        break;
      }
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.timer_outlined, color: accent, size: 18),
      title: Text(
        '${log.minutes} min · ${log.description}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Arial',
          color: ink,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      subtitle: Text(
        '${log.author} · ${_dateLabel(log.loggedAt)}${task == null ? '' : ' · ${task.title}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
      ),
    );
  }

  Widget _attendancePanel() {
    final records = List<StudioAttendance>.of(_delivery.attendance)
      ..sort((first, second) => second.date.compareTo(first.date));
    final canReview = _can(StudioPersona.manageAttendance);
    return _deliveryPanel(
      'Attendance',
      'Daily studio presence log',
      onAdd: canReview ? _recordAttendance : null,
      addLabel: 'Record attendance',
      child: !canReview
          ? _accessNotice()
          : records.isEmpty
          ? _emptyDeliveryCard(
              'No attendance recorded',
              'Choose a studio role and record its daily attendance.',
            )
          : Column(
              children: records.map((record) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_available_outlined,
                    color: accent,
                    size: 18,
                  ),
                  title: Text(
                    record.personaName,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_dateLabel(record.date)}${record.note.isEmpty ? '' : ' · ${record.note}'}',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                  trailing: _pill(record.status),
                );
              }).toList(),
            ),
    );
  }

  Widget _approvalRow(StudioApproval approval) {
    final canDecide =
        _can(StudioPersona.approveApprovals) &&
        (approval.approverPersonaId == _activePersona.id ||
            _can(StudioPersona.configureWorkspace));
    final auditTrail = [
      '${approval.status} · Requested ${_dateLabel(approval.requestedAt)} by ${approval.requestedBy}',
      'Assigned to ${approval.approverName}',
      if (approval.details.isNotEmpty) approval.details,
      if (approval.decisionNote.isNotEmpty)
        'Decision: ${approval.decisionNote}',
      if (approval.decidedAt != null)
        'Decided ${_dateLabel(approval.decidedAt)}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        approval.status == 'Pending'
            ? Icons.pending_actions
            : approval.status == 'Approved'
            ? Icons.check_circle_outline
            : Icons.cancel_outlined,
        color: approval.status == 'Approved' ? sage : accent,
        size: 18,
      ),
      title: Text(
        approval.title,
        style: const TextStyle(
          fontFamily: 'Arial',
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        auditTrail,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
      ),
      trailing: approval.status == 'Pending' && canDecide
          ? Wrap(
              spacing: 0,
              children: [
                IconButton(
                  tooltip: 'Approve request',
                  onPressed: () => _decideApproval(approval, 'Approved'),
                  icon: const Icon(Icons.check, color: sage, size: 19),
                ),
                IconButton(
                  tooltip: 'Reject request',
                  onPressed: () => _decideApproval(approval, 'Rejected'),
                  icon: const Icon(Icons.close, color: accent, size: 19),
                ),
              ],
            )
          : _pill(approval.status),
    );
  }

  void _openFeature(String feature) {
    switch (feature) {
      case 'Persona configuration':
        _configurePersonas();
        return;
      case 'Activity timeline':
        _showActivityTimeline();
        return;
      case 'Customer Management':
      case 'Requirement intake':
      case 'Communication history':
        _openCommunications();
        return;
      case 'Email sending':
        _openCommunications();
        _createCommunication(channel: 'Email');
        return;
      case 'WhatsApp messaging':
        _openCommunications();
        _createCommunication(channel: 'WhatsApp');
        return;
      case '@mentions':
        _openCommunications(filter: 'Mentions');
        return;
      case 'Lead pipeline configuration':
      case 'Bulk import (CSV)':
        _navigate(1);
        return;
      case 'Tasks':
        _navigate(4);
        return;
      case 'Project documents':
      case 'Milestone Updates':
      case 'Progress photos':
      case 'Punch list':
      case 'Project Task Creation':
      case 'Task suggestions':
      case 'Work logs':
      case 'Attendance Tracking':
      case 'File storage':
      case 'Approval routing':
        _navigate(5);
        return;
      case 'Proposal Generation':
      case 'BOQ / Quotation Creation':
      case 'Proposal settings':
      case 'Proposal layout designer':
      case 'Document templates':
      case 'Invoice Preparation':
        _navigate(3);
        return;
      case 'Report Generation':
        _navigate(7);
        return;
      default:
        _toast('$feature · Connect a workspace to begin.');
        return;
    }
  }

  Widget _featuresPage() {
    const groups = <String, List<String>>{
      'Relationships & growth': [
        'Customer Management',
        'Requirement intake',
        'Communication history',
        'Email sending',
        'WhatsApp messaging',
        '@mentions',
        'Referral program',
        'Persona configuration',
      ],
      'Leads & integrations': [
        'Lead pipeline configuration',
        'Lead Source Integration',
        'Meta Lead Ads',
        'Bulk import (CSV)',
        'Public API',
        'Third-party integrations',
      ],
      'Projects & delivery': [
        'Project documents',
        'Milestone Updates',
        'Progress photos',
        'Punch list',
        'Project Task Creation',
        'Tasks',
        'Task suggestions',
        'Work logs',
        'Attendance Tracking',
        'File storage',
      ],
      'Proposals & operations': [
        'BOQ / Quotation Creation',
        'Proposal Generation',
        'Proposal settings',
        'Proposal layout designer',
        'Document templates',
        'Invoice Preparation',
        'Approval routing',
      ],
      'Insights & workspace': [
        'Report Generation',
        'Activity timeline',
        'Localization',
      ],
    };
    final query = _query.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('YOUR STUDIO, BEAUTIFULLY CONNECTED'),
        const SizedBox(height: 8),
        Text('Studio features', style: _heading(30)),
        const SizedBox(height: 7),
        const Text(
          'A considered toolkit for the way interior studios work.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        ...groups.entries.map((entry) {
          final features = entry.value
              .where((feature) => feature.toLowerCase().contains(query))
              .toList();
          if (features.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.all(19),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _implementedFeatures.contains(feature)
                                ? Icons.check_circle_outline
                                : Icons.schedule_outlined,
                            color: _implementedFeatures.contains(feature)
                                ? sage
                                : muted,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontFamily: 'Arial',
                                color: ink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _pill(
                            _implementedFeatures.contains(feature)
                                ? 'Available'
                                : 'Planned',
                          ),
                          IconButton(
                            tooltip: _implementedFeatures.contains(feature)
                                ? 'Open $feature'
                                : '$feature is planned for a future milestone',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _implementedFeatures.contains(feature)
                                ? _openFeature(feature)
                                : _toast(
                                    '$feature is planned for a future milestone.',
                                  ),
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: muted,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (!groups.values
            .expand((features) => features)
            .any((feature) => feature.toLowerCase().contains(query)))
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'No features match that search.',
                style: TextStyle(fontFamily: 'Arial', color: muted),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _recordReportSnapshot() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const SimpleMultiPromptDialog(
        title: 'Report snapshot',
        fields: ['Project ID', 'Kind', 'Summary'],
      ),
    );
    if (values == null) return;
    final project = _delivery.projects
        .where((item) => item.id == values['Project ID'])
        .firstOrNull;
    if (project == null) {
      _toast('Enter a valid project ID.');
      return;
    }
    final now = DateTime.now().toUtc();
    final snapshot = StudioReportSnapshot(
      id: 'report-${now.microsecondsSinceEpoch}',
      projectId: project.id,
      kind: values['Kind']!.isEmpty ? 'Operational' : values['Kind']!,
      periodStart: DateTime(now.year, now.month, 1).toUtc(),
      periodEnd: now,
      summary: values['Summary']!,
      createdAt: now,
    );
    await _saveDelivery(
      _delivery.copyWith(
        reportSnapshots: [..._delivery.reportSnapshots, snapshot],
      ),
      confirmation: 'Report snapshot created.',
      activityTitle: 'Operational report snapshot created',
      activityDetails: '${project.name} · ${snapshot.kind}',
    );
  }

  Widget _reportsPage(bool wide) {
    final canViewClients = _can(StudioPersona.viewClients);
    final canViewProjects = _can(StudioPersona.viewProjects);
    final canViewFinance = _can(StudioPersona.viewFinancials);
    final activeProjects = _delivery.projects
        .where((project) => project.status != 'Complete')
        .length;
    final openTasks = _delivery.tasks.where((task) => !task.isComplete).length;
    final invoiceBalance = _financials.invoices
        .where((invoice) => invoice.status != 'Draft')
        .fold<double>(0, (total, invoice) => total + invoice.balance);
    final metrics = [
      (
        'Clients & leads',
        canViewClients ? '${_customers.length}' : 'Restricted',
        canViewClients
            ? '${_customers.where((item) => item.stage != 'Client' && item.stage != 'On hold').length} active inquiries'
            : 'Client access not included',
        Icons.people_outline,
      ),
      (
        'Active projects',
        canViewProjects ? '$activeProjects' : 'Restricted',
        canViewProjects
            ? '${_delivery.projects.length} total projects'
            : 'Project access not included',
        Icons.home_work_outlined,
      ),
      (
        'Open tasks',
        canViewProjects ? '$openTasks' : 'Restricted',
        canViewProjects
            ? '${_delivery.tasks.where((task) => task.isComplete).length} completed'
            : 'Project access not included',
        Icons.check_circle_outline,
      ),
      (
        'Invoice balance',
        canViewFinance
            ? _formatCurrency(
                invoiceBalance,
                _financials.settings.currencySymbol,
              )
            : 'Restricted',
        canViewFinance
            ? '${_financials.invoices.length} prepared invoices'
            : 'Financial access not included',
        Icons.receipt_long_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('A CLEARER VIEW OF THE BIG PICTURE'),
        const SizedBox(height: 8),
        Text('Studio reports', style: _heading(30)),
        const SizedBox(height: 7),
        const Text(
          'Live reporting from your client, project, and finance records.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = wide
                ? 4
                : constraints.maxWidth < 430
                ? 1
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 118,
              ),
              itemBuilder: (context, index) {
                final item = metrics[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.$1,
                              style: const TextStyle(
                                fontFamily: 'Arial',
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Icon(item.$4, color: accent, size: 17),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        _financialSection(
          'Imports & report snapshots',
          'Validated import history and authorized dated operational reports',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_delivery.importRecords.isEmpty &&
                  _delivery.reportSnapshots.isEmpty)
                _emptyDeliveryCard(
                  'No import or report history',
                  'New imports and generated reports will retain an auditable snapshot here.',
                )
              else ...[
                for (final record in _delivery.importRecords)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(record.fileName),
                    subtitle: Text(
                      '${record.kind} · ${record.status} · ${record.importedCount} imported · ${record.failedCount} failed',
                    ),
                  ),
                for (final report in _delivery.reportSnapshots)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${report.kind} report'),
                    subtitle: Text(
                      '${_dateLabel(report.periodStart)} – ${_dateLabel(report.periodEnd)} · ${report.summary}',
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _recordReportSnapshot,
                icon: const Icon(Icons.summarize_outlined, size: 16),
                label: const Text('Create report snapshot'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Studio activity report',
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Export permitted client, project, task, proposal, invoice, and activity records as CSV.',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        color: muted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: _generateStudioReport,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export report'),
                style: FilledButton.styleFrom(backgroundColor: ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (canViewClients) _pipelineCard(),
        const SizedBox(height: 14),
        _featureNote(
          'Built from live studio records',
          'Totals and exported rows reflect the saved workspace. Financial and client fields follow the active role preview.',
        ),
      ],
    );
  }

  Future<void> _generateStudioReport() async {
    if (!_can(StudioPersona.viewClients) &&
        !_can(StudioPersona.viewProjects) &&
        !_can(StudioPersona.viewFinancials) &&
        !_can(StudioPersona.manageAttendance)) {
      _toast('This studio role cannot export report records.');
      return;
    }
    if (_customerRepository is RemoteCustomerWorkspaceRepository &&
        !await _refreshRemoteWorkspace(announce: false)) {
      return;
    }
    final rows = <List<Object?>>[
      [
        'Record type',
        'Reference',
        'Client or owner',
        'Project',
        'Status',
        'Amount',
        'Date',
        'Details',
      ],
    ];
    if (_can(StudioPersona.viewClients)) {
      for (final customer in _customers) {
        rows.add([
          'Client',
          customer.id,
          customer.name,
          customer.project,
          customer.stage,
          _can(StudioPersona.viewFinancials) ? customer.value : '',
          '',
          customer.email,
        ]);
      }
      for (final activity in _recentActivities.where(
        (activity) =>
            (activity.kind != 'project_delivery' ||
                _can(StudioPersona.viewProjects)) &&
            (activity.kind != 'finance' || _can(StudioPersona.viewFinancials)),
      )) {
        rows.add([
          'Client activity',
          activity.id,
          activity.customerName,
          '',
          activity.kind,
          '',
          activity.occurredAt.toIso8601String(),
          '${activity.title} — ${activity.details}',
        ]);
      }
    } else if (_can(StudioPersona.viewProjects)) {
      for (final activity in _recentActivities.where(
        (item) => item.kind == 'project_delivery',
      )) {
        rows.add([
          'Project activity',
          activity.id,
          activity.actor,
          '',
          activity.kind,
          '',
          activity.occurredAt.toIso8601String(),
          '${activity.title} — ${activity.details}',
        ]);
      }
    }
    if (_can(StudioPersona.viewProjects)) {
      for (final project in _delivery.projects) {
        final client = _can(StudioPersona.viewClients)
            ? _customerFor(project.customerId)?.name ?? ''
            : '';
        rows.add([
          'Project',
          project.id,
          client,
          project.name,
          project.status,
          '',
          project.targetDate?.toIso8601String() ?? '',
          project.location,
        ]);
      }
      for (final task in _delivery.tasks) {
        rows.add([
          'Task',
          task.id,
          task.assignee.isEmpty ? 'Unassigned' : task.assignee,
          _projectFor(task.projectId)?.name ?? '',
          task.isComplete ? 'Complete' : 'Open',
          '',
          task.dueDate?.toIso8601String() ?? '',
          task.title,
        ]);
      }
      for (final milestone in _delivery.milestones) {
        rows.add([
          'Milestone',
          milestone.id,
          '',
          _projectFor(milestone.projectId)?.name ?? '',
          milestone.status,
          '',
          milestone.dueDate?.toIso8601String() ?? '',
          '${milestone.title} — ${milestone.update}',
        ]);
      }
    }
    if (_can(StudioPersona.viewFinancials)) {
      for (final quotation in _financials.quotations) {
        rows.add([
          'Quotation',
          quotation.number,
          quotation.clientName,
          quotation.projectName,
          'Draft',
          _formatCurrency(quotation.total, quotation.currencySymbol),
          quotation.updatedAt.toIso8601String(),
          quotation.title,
        ]);
      }
      for (final proposal in _financials.proposals) {
        rows.add([
          'Proposal',
          proposal.number,
          proposal.clientName,
          proposal.projectName,
          proposal.status,
          _formatCurrency(proposal.total, proposal.currencySymbol),
          proposal.updatedAt.toIso8601String(),
          proposal.title,
        ]);
      }
      for (final invoice in _financials.invoices) {
        rows.add([
          'Invoice',
          invoice.number,
          invoice.clientName,
          invoice.projectName,
          invoice.status,
          _formatCurrency(invoice.balance, invoice.currencySymbol),
          invoice.dueDate.toIso8601String(),
          invoice.title,
        ]);
      }
    }
    if (_can(StudioPersona.manageAttendance)) {
      for (final record in _delivery.attendance) {
        rows.add([
          'Attendance',
          record.id,
          record.personaName,
          '',
          record.status,
          '',
          record.date.toIso8601String(),
          record.note,
        ]);
      }
    }
    try {
      final csv = const ListToCsvConverter().convert(rows);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export studio report',
        fileName: 'atelier-studio-report-$date.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (path != null && mounted) {
        _toast('Studio report exported.');
      }
    } on Exception catch (error) {
      if (mounted) _toast('Could not export studio report: $error');
    }
  }

  Widget _summaryChip(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(fontFamily: 'Arial', color: ink, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _accessNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: _cardDecoration(),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, color: accent, size: 22),
        SizedBox(height: 12),
        Text(
          'Access is limited for this studio role.',
          style: TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Change the role preview in Studio roles and preferences.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _featureNote(String heading, String body) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFFF0EEE8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome_outlined, color: accent, size: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: muted,
                  fontSize: 11,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _legend(String title, String count, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$title  $count',
        style: const TextStyle(color: muted, fontFamily: 'Arial', fontSize: 9),
      ),
    ],
  );

  Widget _cardHeading(String title, String action, VoidCallback onPressed) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              textStyle: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(action),
          ),
        ],
      );

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F0EA),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF68685F),
        fontFamily: 'Arial',
        fontSize: 9,
      ),
    ),
  );

  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: accent,
      fontFamily: 'Arial',
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      fontSize: 9,
    ),
  );

  TextStyle _heading(double size) => TextStyle(
    color: ink,
    fontSize: size,
    fontWeight: FontWeight.w500,
    letterSpacing: -.5,
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: paper,
    border: Border.all(color: line),
    borderRadius: BorderRadius.circular(11),
  );

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
        ),
      );
  }
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({
    required this.initials,
    required this.title,
    required this.detail,
    required this.color,
  });

  final String initials;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: Text(
            initials,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: ink,
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CustomerEditorDialog extends StatefulWidget {
  const CustomerEditorDialog({
    super.key,
    required this.stages,
    this.allowFinancials = true,
    this.initialStage,
    this.customer,
  });

  final List<String> stages;
  final bool allowFinancials;
  final String? initialStage;
  final Customer? customer;

  @override
  State<CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<CustomerEditorDialog> {
  static const _colors = [
    Color(0xFFE9DDD0),
    Color(0xFFDCE3DA),
    Color(0xFFE9D9D5),
    Color(0xFFE9E5D9),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _project;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _budget;
  late final TextEditingController _notes;
  late String _stage;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _project = TextEditingController(text: customer?.project ?? '');
    _email = TextEditingController(text: customer?.email ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _budget = TextEditingController(
      text: customer == null || customer.value == '—' ? '' : customer.value,
    );
    _notes = TextEditingController(text: customer?.notes ?? '');
    final initialStage = widget.initialStage;
    _stage =
        customer?.stage ??
        (initialStage != null && widget.stages.contains(initialStage)
            ? initialStage
            : widget.stages.first);
  }

  @override
  void dispose() {
    _name.dispose();
    _project.dispose();
    _email.dispose();
    _phone.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final customer = widget.customer;
    Navigator.pop(
      context,
      Customer(
        id: customer?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        project: _project.text.trim(),
        stage: _stage,
        value: widget.allowFinancials
            ? _budget.text.trim().isEmpty
                  ? '—'
                  : _budget.text.trim()
            : customer?.value ?? '—',
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        notes: _notes.text.trim(),
        initials: initials,
        tint:
            customer?.tint ??
            _colors[DateTime.now().microsecondsSinceEpoch % _colors.length],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    scrollable: true,
    title: Text(widget.customer == null ? 'A new relationship' : 'Edit client'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(
              _name,
              'Client name *',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a client name.'
                  : null,
            ),
            _field(_project, 'Project or residence'),
            _field(
              _email,
              'Email address',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            _field(_phone, 'Phone number', keyboardType: TextInputType.phone),
            DropdownButtonFormField<String>(
              initialValue: _stage,
              decoration: const InputDecoration(labelText: 'Lead stage'),
              items: widget.stages
                  .map(
                    (stage) => DropdownMenuItem(
                      value: stage,
                      child: Text(
                        stage,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _stage = value);
              },
            ),
            if (widget.allowFinancials)
              _field(
                _budget,
                'Estimated budget',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final amount = double.tryParse(
                    value.replaceAll(RegExp(r'[$,\s]'), ''),
                  );
                  return amount == null || !amount.isFinite || amount < 0
                      ? 'Enter a valid non-negative amount.'
                      : null;
                },
              ),
            _field(_notes, 'Notes', maxLines: 3),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: Text(widget.customer == null ? 'Add client' : 'Save changes'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
    ),
  );
}

class PipelineConfiguration {
  const PipelineConfiguration({
    required this.stages,
    required this.renamedStages,
  });

  final List<String> stages;
  final Map<String, String> renamedStages;
}

class _PipelineStageDraft {
  _PipelineStageDraft({required this.originalName, required String name})
    : controller = TextEditingController(text: name);

  final String? originalName;
  final TextEditingController controller;
}

class PipelineEditorDialog extends StatefulWidget {
  const PipelineEditorDialog({
    super.key,
    required this.stages,
    required this.occupiedStages,
  });

  final List<String> stages;
  final Map<String, int> occupiedStages;

  @override
  State<PipelineEditorDialog> createState() => _PipelineEditorDialogState();
}

class _PipelineEditorDialogState extends State<PipelineEditorDialog> {
  late final List<_PipelineStageDraft> _drafts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = widget.stages
        .map((stage) => _PipelineStageDraft(originalName: stage, name: stage))
        .toList();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.controller.dispose();
    }
    super.dispose();
  }

  void _addStage() {
    if (_drafts.length >= 12) {
      setState(() => _error = 'A pipeline can have up to 12 stages.');
      return;
    }
    var name = 'New stage';
    var suffix = 2;
    while (_drafts.any(
      (draft) =>
          draft.controller.text.trim().toLowerCase() == name.toLowerCase(),
    )) {
      name = 'New stage $suffix';
      suffix++;
    }
    setState(() {
      _drafts.add(_PipelineStageDraft(originalName: null, name: name));
      _error = null;
    });
  }

  void _removeStage(int index) {
    final draft = _drafts[index];
    final occupied = draft.originalName == null
        ? 0
        : widget.occupiedStages[draft.originalName] ?? 0;
    if (_drafts.length <= 2 || occupied > 0) return;
    setState(() {
      _drafts.removeAt(index).controller.dispose();
      _error = null;
    });
  }

  void _save() {
    final stages = _drafts
        .map((draft) => draft.controller.text.trim())
        .toList();
    if (stages.any((stage) => stage.isEmpty || stage.length > 40)) {
      setState(() => _error = 'Stage names must be 1–40 characters.');
      return;
    }
    final normalized = stages.map((stage) => stage.toLowerCase()).toSet();
    if (normalized.length != stages.length) {
      setState(() => _error = 'Stage names must be unique.');
      return;
    }
    if (stages.length < 2) {
      setState(() => _error = 'Keep at least two stages in your pipeline.');
      return;
    }
    final renames = <String, String>{
      for (final draft in _drafts)
        if (draft.originalName != null &&
            draft.originalName != draft.controller.text.trim())
          draft.originalName!: draft.controller.text.trim(),
    };
    Navigator.pop(
      context,
      PipelineConfiguration(stages: stages, renamedStages: renames),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Configure lead pipeline'),
    content: SizedBox(
      width: 470,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rename or reorder stages. Move clients out of a stage before removing it.',
            style: TextStyle(
              fontFamily: 'Arial',
              color: muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 300,
            child: ReorderableListView.builder(
              itemCount: _drafts.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final draft = _drafts.removeAt(oldIndex);
                  _drafts.insert(newIndex, draft);
                });
              },
              itemBuilder: (context, index) {
                final draft = _drafts[index];
                final occupied = draft.originalName == null
                    ? 0
                    : widget.occupiedStages[draft.originalName] ?? 0;
                final canRemove = _drafts.length > 2 && occupied == 0;
                return Container(
                  key: ObjectKey(draft),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: draft.controller,
                          maxLength: 40,
                          onChanged: (_) => setState(() => _error = null),
                          decoration: InputDecoration(
                            labelText: 'Stage ${index + 1}',
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: canRemove
                            ? 'Remove stage'
                            : occupied > 0
                            ? 'Move clients out of this stage first'
                            : 'Keep at least two stages',
                        onPressed: canRemove ? () => _removeStage(index) : null,
                        icon: const Icon(Icons.delete_outline, size: 19),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle,
                            color: muted,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: Color(0xFF8A3528),
                fontSize: 11,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addStage,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add stage'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save pipeline'),
      ),
    ],
  );
}

class ProjectRequirementDialog extends StatefulWidget {
  const ProjectRequirementDialog({super.key, this.initial});

  final ProjectRequirement? initial;

  @override
  State<ProjectRequirementDialog> createState() =>
      _ProjectRequirementDialogState();
}

class _ProjectRequirementDialogState extends State<ProjectRequirementDialog> {
  static const _roomChoices = [
    'Living room',
    'Kitchen',
    'Dining room',
    'Bedroom',
    'Bathroom',
    'Entryway',
    'Home office',
    'Outdoor',
    'Entire home',
  ];
  static const _styleChoices = [
    'Contemporary',
    'Modern',
    'Transitional',
    'Classic',
    'Minimal',
    'Organic modern',
    'Eclectic',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  final _customStyle = TextEditingController();
  final _brief = TextEditingController();
  final Set<String> _rooms = {};
  String _style = _styleChoices.first;
  DateTime? _startDate;
  DateTime? _targetDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _rooms.addAll(initial.rooms);
    _budgetMin.text = _amountText(initial.budgetMin);
    _budgetMax.text = _amountText(initial.budgetMax);
    _startDate = initial.startDate;
    _targetDate = initial.targetDate;
    _brief.text = initial.brief;
    if (_styleChoices.contains(initial.style)) {
      _style = initial.style;
    } else {
      _style = 'Other';
      _customStyle.text = initial.style;
    }
  }

  @override
  void dispose() {
    _budgetMin.dispose();
    _budgetMax.dispose();
    _customStyle.dispose();
    _brief.dispose();
    super.dispose();
  }

  String _amountText(double? amount) =>
      amount == null ? '' : amount.toStringAsFixed(0);

  double? _parseAmount(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[$,\s]'), ''));
  }

  Future<void> _selectDate({required bool start}) async {
    final current = start ? _startDate : _targetDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: start
          ? 'Select target start date'
          : 'Select desired completion',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
      } else {
        _targetDate = selected;
      }
      _error = null;
    });
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'Not selected';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_rooms.isEmpty) {
      setState(() => _error = 'Choose at least one room or area.');
      return;
    }
    if (_style == 'Other' && _customStyle.text.trim().isEmpty) {
      setState(() => _error = 'Describe the preferred style.');
      return;
    }
    final minimum = _parseAmount(_budgetMin.text);
    final maximum = _parseAmount(_budgetMax.text);
    if (minimum != null && maximum != null && minimum > maximum) {
      setState(
        () => _error = 'The maximum budget must be at least the minimum.',
      );
      return;
    }
    if (_startDate != null &&
        _targetDate != null &&
        _targetDate!.isBefore(_startDate!)) {
      setState(
        () => _error = 'The completion date must follow the start date.',
      );
      return;
    }

    Navigator.pop(
      context,
      ProjectRequirement(
        rooms: _roomChoices.where(_rooms.contains).toList(),
        style: _style == 'Other' ? _customStyle.text.trim() : _style,
        budgetMin: minimum,
        budgetMax: maximum,
        startDate: _startDate,
        targetDate: _targetDate,
        brief: _brief.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    scrollable: true,
    title: const Text('Project requirements'),
    content: SizedBox(
      width: 490,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rooms and areas',
              style: TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: _roomChoices
                  .map(
                    (room) => FilterChip(
                      label: Text(room),
                      selected: _rooms.contains(room),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _rooms.add(room);
                        } else {
                          _rooms.remove(room);
                        }
                        _error = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _style,
              decoration: const InputDecoration(labelText: 'Design style'),
              items: _styleChoices
                  .map(
                    (style) => DropdownMenuItem(
                      value: style,
                      child: Text(
                        style,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (style) {
                if (style != null) {
                  setState(() {
                    _style = style;
                    _error = null;
                  });
                }
              },
            ),
            if (_style == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customStyle,
                decoration: const InputDecoration(
                  labelText: 'Describe the preferred style',
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Estimated budget (USD)',
              style: TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _budgetField(_budgetMin, 'Minimum')),
                const SizedBox(width: 10),
                Expanded(child: _budgetField(_budgetMax, 'Maximum')),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Project timeline',
              style: TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            _dateSelector(
              'Target start',
              _startDate,
              () => _selectDate(start: true),
            ),
            _dateSelector(
              'Desired completion',
              _targetDate,
              () => _selectDate(start: false),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _brief,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Project brief',
                hintText: 'What should the space feel like? Any must-haves or constraints?',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: Color(0xFF8A3528),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save requirements'),
      ),
    ],
  );

  Widget _budgetField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '\$ '),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final amount = _parseAmount(value);
          if (amount == null || !amount.isFinite || amount < 0) {
            return 'Enter a valid amount.';
          }
          return null;
        },
      );

  Widget _dateSelector(String label, DateTime? date, VoidCallback onSelect) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(
                  '$label · ${_dateText(date)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (date != null)
              IconButton(
                tooltip: 'Clear $label',
                onPressed: () => setState(() {
                  if (label == 'Target start') {
                    _startDate = null;
                  } else {
                    _targetDate = null;
                  }
                }),
                icon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      );
}

class ActivityEntryTile extends StatelessWidget {
  const ActivityEntryTile({super.key, required this.activity});

  final StudioActivity activity;

  @override
  Widget build(BuildContext context) {
    final occurredAt = activity.occurredAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(occurredAt);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt));
    final icon = switch (activity.kind) {
      'interaction' => Icons.forum_outlined,
      'stage_changed' => Icons.swap_horiz,
      'requirements_updated' => Icons.assignment_outlined,
      'client_created' || 'csv_import' => Icons.person_add_alt_1_outlined,
      'client_deleted' => Icons.person_remove_outlined,
      _ => Icons.edit_note_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE9DDD0),
            child: Icon(icon, size: 16, color: ink),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    activity.customerName,
                    if (activity.details.isNotEmpty) activity.details,
                  ].join(' · '),
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date · $time · ${activity.actor}',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityTimelineDialog extends StatelessWidget {
  const ActivityTimelineDialog({super.key, required this.activities});

  final List<StudioActivity> activities;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height - 210)
        .clamp(230.0, 560.0)
        .toDouble();
    return AlertDialog(
      backgroundColor: paper,
      title: const Text('Activity timeline'),
      content: SizedBox(
        width: 560,
        height: height,
        child: activities.isEmpty
            ? const Center(
                child: Text(
                  'No client changes or conversations recorded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: activities.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: line),
                itemBuilder: (context, index) =>
                    ActivityEntryTile(activity: activities[index]),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class InteractionDraft {
  const InteractionDraft({required this.type, required this.details});

  final String type;
  final String details;
}

class InteractionDialog extends StatefulWidget {
  const InteractionDialog({super.key});

  @override
  State<InteractionDialog> createState() => _InteractionDialogState();
}

class _InteractionDialogState extends State<InteractionDialog> {
  static const _types = [
    'Call',
    'Meeting',
    'Email',
    'Message',
    'Note',
    'Other',
  ];
  final _details = TextEditingController();
  String _type = _types.first;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Log a client interaction'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Interaction type'),
            items: _types
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (type) {
              if (type != null) setState(() => _type = type);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            onChanged: (value) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'What was discussed or agreed?',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _details.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                InteractionDraft(type: _type, details: _details.text.trim()),
              ),
        child: const Text('Add to timeline'),
      ),
    ],
  );
}

class PersonaConfiguration {
  const PersonaConfiguration({
    required this.personas,
    required this.preferences,
  });

  final List<StudioPersona> personas;
  final WorkspacePreferences preferences;
}

class PersonaConfigurationDialog extends StatefulWidget {
  const PersonaConfigurationDialog({
    super.key,
    required this.personas,
    required this.preferences,
    required this.stages,
    required this.protectedPersonaIds,
    required this.allowConfigure,
  });

  final List<StudioPersona> personas;
  final WorkspacePreferences preferences;
  final List<String> stages;
  final Set<String> protectedPersonaIds;
  final bool allowConfigure;

  @override
  State<PersonaConfigurationDialog> createState() =>
      _PersonaConfigurationDialogState();
}

class _PersonaConfigurationDialogState
    extends State<PersonaConfigurationDialog> {
  late final TextEditingController _studioName;
  late List<StudioPersona> _personas;
  late String _defaultStage;
  late String _activePersonaId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _studioName = TextEditingController(text: widget.preferences.studioName);
    _personas = List<StudioPersona>.of(widget.personas);
    _defaultStage = widget.preferences.defaultPipelineStage;
    _activePersonaId = widget.preferences.activePersonaId;
  }

  @override
  void dispose() {
    _studioName.dispose();
    super.dispose();
  }

  Future<void> _addPersona() async {
    final newPersona = StudioPersona(
      id: 'role-${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      description: '',
      permissions: const [StudioPersona.viewClients],
    );
    await _editPersona(newPersona, isNew: true);
  }

  Future<void> _editPersona(StudioPersona persona, {bool isNew = false}) async {
    final edited = await showDialog<StudioPersona>(
      context: context,
      builder: (context) => StudioPersonaEditorDialog(persona: persona),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _error = null;
      if (isNew) {
        _personas = [..._personas, edited];
      } else {
        _personas = _personas
            .map((item) => item.id == edited.id ? edited : item)
            .toList();
      }
    });
  }

  Future<void> _removePersona(StudioPersona persona) async {
    if (_personas.length <= 1) return;
    if (widget.protectedPersonaIds.contains(persona.id)) {
      setState(
        () => _error = 'Resolve pending approvals assigned to this role before removing it.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Remove this studio role?'),
        content: Text('${persona.name} will be removed from this workspace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove role'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _personas.removeWhere((item) => item.id == persona.id);
      if (_activePersonaId == persona.id) {
        _activePersonaId = _personas.first.id;
      }
    });
  }

  void _save() {
    final studioName = _studioName.text.trim();
    final names = _personas
        .map((persona) => persona.name.trim().toLowerCase())
        .toList();
    if (studioName.isEmpty || studioName.length > 80) {
      setState(() => _error = 'Studio name must be 1–80 characters.');
      return;
    }
    if (_personas.any((persona) => persona.name.trim().isEmpty)) {
      setState(() => _error = 'Every role needs a name.');
      return;
    }
    if (names.toSet().length != names.length) {
      setState(() => _error = 'Role names must be unique.');
      return;
    }
    if (!_personas.any((persona) => persona.id == _activePersonaId)) {
      setState(() => _error = 'Choose a role preview.');
      return;
    }
    Navigator.pop(
      context,
      PersonaConfiguration(
        personas: _personas,
        preferences: widget.preferences.copyWith(
          studioName: studioName,
          defaultPipelineStage: _defaultStage,
          activePersonaId: _activePersonaId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height - 170)
        .clamp(320.0, 650.0)
        .toDouble();
    return AlertDialog(
      backgroundColor: paper,
      title: const Text('Studio roles & preferences'),
      content: SizedBox(
        width: 570,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Role preview is local only; authentication and server-side access enforcement are not configured.',
              style: TextStyle(
                fontFamily: 'Arial',
                color: muted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
            if (!widget.allowConfigure)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Switch to a role with workspace access to edit roles and preferences.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: accent,
                    fontSize: 10,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _studioName,
              maxLength: 80,
              enabled: widget.allowConfigure,
              decoration: const InputDecoration(labelText: 'Studio name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _defaultStage,
              decoration: const InputDecoration(
                labelText: 'Default lead stage',
              ),
              items: widget.stages
                  .map(
                    (stage) =>
                        DropdownMenuItem(value: stage, child: Text(stage)),
                  )
                  .toList(),
              onChanged: widget.allowConfigure
                  ? (stage) {
                      if (stage != null) setState(() => _defaultStage = stage);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _activePersonaId,
              decoration: const InputDecoration(labelText: 'Preview role as'),
              items: _personas
                  .map(
                    (persona) => DropdownMenuItem(
                      value: persona.id,
                      child: Text(persona.name),
                    ),
                  )
                  .toList(),
              onChanged: (personaId) {
                if (personaId != null) {
                  setState(() => _activePersonaId = personaId);
                }
              },
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Studio roles',
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.allowConfigure ? _addPersona : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add role'),
                ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _personas.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: line),
                itemBuilder: (context, index) {
                  final persona = _personas[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      persona.name,
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      persona.description.isEmpty
                          ? '${persona.permissions.length} permissions'
                          : persona.description,
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${persona.name}',
                          onPressed: widget.allowConfigure
                              ? () => _editPersona(persona)
                              : null,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: muted,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${persona.name}',
                          onPressed:
                              !widget.allowConfigure ||
                                  _personas.length <= 1 ||
                                  widget.protectedPersonaIds.contains(
                                    persona.id,
                                  )
                              ? null
                              : () => _removePersona(persona),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: muted,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: Color(0xFF9C4B3D),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ink),
          onPressed: _save,
          child: const Text('Save preferences'),
        ),
      ],
    );
  }
}

class StudioPersonaEditorDialog extends StatefulWidget {
  const StudioPersonaEditorDialog({super.key, required this.persona});

  final StudioPersona persona;

  @override
  State<StudioPersonaEditorDialog> createState() =>
      _StudioPersonaEditorDialogState();
}

class _StudioPersonaEditorDialogState extends State<StudioPersonaEditorDialog> {
  static const _permissionLabels = _studioPermissionLabels;
  static const _projectPermissions = {
    StudioPersona.manageProjects,
    StudioPersona.manageTasks,
    StudioPersona.manageFiles,
    StudioPersona.viewFiles,
    StudioPersona.manageMilestones,
    StudioPersona.managePunchList,
    StudioPersona.viewWorkLogs,
    StudioPersona.manageWorkLogs,
    StudioPersona.manageAttendance,
    StudioPersona.manageApprovals,
    StudioPersona.approveApprovals,
  };
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Set<String> _permissions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.persona.name);
    _description = TextEditingController(text: widget.persona.description);
    _permissions = Set<String>.of(widget.persona.permissions);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 50) {
      setState(() => _error = 'Role name must be 1–50 characters.');
      return;
    }
    if (_description.text.trim().length > 160) {
      setState(() => _error = 'Description must be 160 characters or fewer.');
      return;
    }
    Navigator.pop(
      context,
      StudioPersona(
        id: widget.persona.id,
        name: name,
        description: _description.text.trim(),
        permissions: _permissions.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.persona.name.isEmpty
          ? 'Create studio role'
          : 'Edit ${widget.persona.name}',
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Role name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  'ACCESS BOUNDARIES',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            ..._permissionLabels.entries.map(
              (entry) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontSize: 11,
                  ),
                ),
                value: _permissions.contains(entry.key),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _permissions.add(entry.key);
                      if (StudioPersona.clientManagementPermissions.contains(
                        entry.key,
                      )) {
                        _permissions.add(StudioPersona.viewClients);
                      }
                      if (StudioPersona.communicationPermissionKeys.contains(
                        entry.key,
                      )) {
                        _permissions
                          ..add(StudioPersona.viewClients)
                          ..add(StudioPersona.viewProjects)
                          ..add(StudioPersona.viewCommunications);
                      }
                      if (_projectPermissions.contains(entry.key)) {
                        _permissions.add(StudioPersona.viewProjects);
                      }
                      if (entry.key == StudioPersona.manageFiles) {
                        _permissions.add(StudioPersona.viewFiles);
                      }
                      if (entry.key == StudioPersona.manageWorkLogs) {
                        _permissions.add(StudioPersona.viewWorkLogs);
                      }
                      if (entry.key == StudioPersona.manageFinancials) {
                        _permissions.add(StudioPersona.viewFinancials);
                      }
                    } else {
                      _permissions.remove(entry.key);
                      if (entry.key == StudioPersona.viewClients) {
                        _permissions.removeAll(
                          StudioPersona.clientManagementPermissions,
                        );
                        _permissions.removeAll(
                          StudioPersona.communicationPermissionKeys,
                        );
                      }
                      if (entry.key == StudioPersona.viewCommunications) {
                        _permissions.remove(StudioPersona.manageCommunications);
                      }
                      if (entry.key == StudioPersona.viewProjects) {
                        _permissions.removeAll(_projectPermissions);
                        _permissions.removeAll(
                          StudioPersona.communicationPermissionKeys,
                        );
                      }
                      if (entry.key == StudioPersona.viewFiles) {
                        _permissions.remove(StudioPersona.manageFiles);
                      }
                      if (entry.key == StudioPersona.viewWorkLogs) {
                        _permissions.remove(StudioPersona.manageWorkLogs);
                      }
                      if (entry.key == StudioPersona.viewFinancials) {
                        _permissions.remove(StudioPersona.manageFinancials);
                      }
                    }
                  });
                },
              ),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: Color(0xFF9C4B3D),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save role'),
      ),
    ],
  );
}

class CsvImportEntry {
  const CsvImportEntry({
    required this.rowNumber,
    required this.name,
    this.customer,
    this.issue,
    this.duplicateReason,
    this.defaultedStage = false,
  });

  final int rowNumber;
  final String name;
  final Customer? customer;
  final String? issue;
  final String? duplicateReason;
  final bool defaultedStage;
}

class CsvImportPreview {
  const CsvImportPreview(this.entries);

  final List<CsvImportEntry> entries;

  List<Customer> get importable => entries
      .where(
        (entry) =>
            entry.customer != null &&
            entry.issue == null &&
            entry.duplicateReason == null,
      )
      .map((entry) => entry.customer!)
      .toList();

  int get duplicateCount =>
      entries.where((entry) => entry.duplicateReason != null).length;

  int get issueCount => entries.where((entry) => entry.issue != null).length;
}

class CsvImportPreviewDialog extends StatelessWidget {
  const CsvImportPreviewDialog({super.key, required this.preview});

  final CsvImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final importable = preview.importable;
    final contentHeight = (MediaQuery.sizeOf(context).height - 250)
        .clamp(210.0, 470.0)
        .toDouble();
    return AlertDialog(
      backgroundColor: paper,
      title: const Text('Review client import'),
      content: SizedBox(
        width: 560,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required: name. Optional: email, phone, project, stage, budget, notes.',
              style: TextStyle(
                fontFamily: 'Arial',
                color: muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CsvCountChip(label: '${importable.length} ready', color: sage),
                _CsvCountChip(
                  label: '${preview.duplicateCount} duplicates skipped',
                  color: accent,
                ),
                _CsvCountChip(
                  label: '${preview.issueCount} rows need attention',
                  color: const Color(0xFF9C4B3D),
                ),
              ],
            ),
            const Divider(height: 20, color: line),
            Expanded(
              child: ListView.separated(
                itemCount: preview.entries.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: line),
                itemBuilder: (context, index) {
                  final entry = preview.entries[index];
                  final ready = entry.customer != null;
                  final title = entry.name.isEmpty
                      ? 'Row ${entry.rowNumber}'
                      : entry.name;
                  final customer = entry.customer;
                  final metadata = customer == null
                      ? ''
                      : [
                          customer.email,
                          customer.project,
                        ].where((value) => value.isNotEmpty).join(' · ');
                  final detail =
                      entry.issue ??
                      entry.duplicateReason ??
                      [
                        metadata,
                        entry.defaultedStage
                            ? 'Default stage: ${customer!.stage}'
                            : 'Stage: ${customer!.stage}',
                      ].where((value) => value.isNotEmpty).join(' · ');
                  final color = entry.issue != null
                      ? const Color(0xFF9C4B3D)
                      : entry.duplicateReason != null
                      ? accent
                      : sage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          entry.issue != null
                              ? Icons.error_outline
                              : entry.duplicateReason != null
                              ? Icons.content_copy
                              : Icons.check_circle_outline,
                          color: color,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Arial',
                                  color: ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Arial',
                                  color: color,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (ready)
                          const Icon(
                            Icons.arrow_forward,
                            color: muted,
                            size: 14,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ink),
          onPressed: importable.isEmpty
              ? null
              : () => Navigator.pop(context, importable),
          child: Text('Import ${importable.length} clients'),
        ),
      ],
    );
  }
}

class _CsvCountChip extends StatelessWidget {
  const _CsvCountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'Arial',
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 9,
      ),
    ),
  );
}

Future<DateTime?> _pickDeliveryDate(
  BuildContext context,
  DateTime? initialDate,
) async {
  final today = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? today,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
}

class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({
    super.key,
    required this.customers,
    required this.canViewBudget,
    required this.canManageBudget,
    required this.project,
  });

  final List<Customer> customers;
  final bool canViewBudget;
  final bool canManageBudget;
  final StudioProject project;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _budget;
  late String _status;
  late String _customerId;
  DateTime? _startDate;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.project.name);
    _location = TextEditingController(text: widget.project.location);
    _budget = TextEditingController(
      text: widget.project.budget?.toStringAsFixed(2) ?? '',
    );
    _status = widget.project.status;
    _customerId = widget.project.customerId ?? '';
    _startDate = widget.project.startDate;
    _targetDate = widget.project.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final budget = widget.canManageBudget
        ? _budget.text.trim().isEmpty
              ? null
              : double.parse(_budget.text.trim())
        : widget.project.budget;
    if (_startDate != null &&
        _targetDate != null &&
        _startDate!.isAfter(_targetDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The target date must follow the start date.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      StudioProject(
        id: widget.project.id,
        name: _name.text.trim(),
        location: _location.text.trim(),
        status: _status,
        customerId: _customerId.isEmpty ? null : _customerId,
        targetDate: _targetDate,
        budget: budget,
        startDate: _startDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.project.name.isEmpty ? 'Create a project' : 'Edit project',
    ),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Project name *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a project name.'
                    : null,
              ),
              TextField(
                controller: _location,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Site address or location',
                ),
              ),
              if (widget.canViewBudget)
                TextFormField(
                  controller: _budget,
                  readOnly: !widget.canManageBudget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Project budget (optional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final amount = double.tryParse(value.trim());
                    return amount == null ||
                            !amount.isFinite ||
                            amount < 0 ||
                            amount > 1000000000000 ||
                            !RegExp(r'^(?:\d+(?:\.\d{1,2})?|\.\d{1,2})$')
                                .hasMatch(value.trim())
                        ? 'Enter a valid non-negative budget.'
                        : null;
                  },
                ),
              DropdownButtonFormField<String>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Linked client'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('No linked client'),
                  ),
                  ...widget.customers.map(
                    (customer) => DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _customerId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: StudioProject.statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(
                  _startDate == null
                      ? 'Not set'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_startDate!),
                ),
                trailing: IconButton(
                  tooltip: 'Choose start date',
                  onPressed: () async {
                    final date = await _pickDeliveryDate(context, _startDate);
                    if (date != null && mounted) {
                      setState(() => _startDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final date = await _pickDeliveryDate(context, _startDate);
                  if (date != null && mounted) {
                    setState(() => _startDate = date);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(
                  _targetDate == null
                      ? 'Not set'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_targetDate!),
                ),
                trailing: IconButton(
                  tooltip: 'Choose target date',
                  onPressed: () async {
                    final date = await _pickDeliveryDate(context, _targetDate);
                    if (date != null && mounted) {
                      setState(() => _targetDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final date = await _pickDeliveryDate(context, _targetDate);
                  if (date != null && mounted) {
                    setState(() => _targetDate = date);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save project'),
      ),
    ],
  );
}

class ProjectTaskEditorDialog extends StatefulWidget {
  const ProjectTaskEditorDialog({
    super.key,
    required this.projects,
    required this.personas,
    required this.tasks,
    required this.task,
    this.loadProjectAssignees,
  });

  final List<StudioProject> projects;
  final List<StudioPersona> personas;
  final List<StudioTaskRecord> tasks;
  final StudioTaskRecord task;
  final Future<List<String>> Function(String projectId)? loadProjectAssignees;

  @override
  State<ProjectTaskEditorDialog> createState() =>
      _ProjectTaskEditorDialogState();
}

class _ProjectTaskEditorDialogState extends State<ProjectTaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late String _projectId;
  late String _assignee;
  late String _priority;
  DateTime? _dueDate;
  late Set<String> _dependencyIds;
  List<String> _projectAssignees = const [];
  String? _assigneeLoadError;
  bool _isLoadingAssignees = false;
  int _assigneeRequest = 0;

  List<String> get _assignees {
    final names = widget.loadProjectAssignees == null
        ? widget.personas.map((persona) => persona.name)
        : _projectAssignees;
    return {
      ...names.where((name) => name.isNotEmpty),
      if (_assignee.isNotEmpty) _assignee,
    }.toList();
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _projectId = widget.task.projectId;
    _assignee = widget.task.assignee;
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _dependencyIds = widget.task.dependsOnTaskIds.toSet();
    if (widget.loadProjectAssignees != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProjectAssignees(_projectId);
      });
    }
  }

  Future<void> _loadProjectAssignees(String projectId) async {
    final loader = widget.loadProjectAssignees;
    if (loader == null) return;
    final request = ++_assigneeRequest;
    setState(() {
      _isLoadingAssignees = true;
      _assigneeLoadError = null;
    });
    try {
      final assignees = await loader(projectId);
      if (!mounted || request != _assigneeRequest) return;
      setState(() {
        _projectAssignees = assignees;
        if (_assignee.isNotEmpty && !_projectAssignees.contains(_assignee)) {
          _assignee = '';
        }
      });
    } catch (error) {
      if (!mounted || request != _assigneeRequest) return;
      setState(() {
        _assigneeLoadError = 'Project members could not be loaded: $error';
      });
    } finally {
      if (mounted && request == _assigneeRequest) {
        setState(() => _isLoadingAssignees = false);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioTaskRecord(
        id: widget.task.id,
        projectId: _projectId,
        title: _title.text.trim(),
        assignee: _assignee,
        dueDate: _dueDate,
        isComplete: widget.task.isComplete,
        priority: _priority,
        dependsOnTaskIds: _dependencyIds.toList(),
      ),
    );
  }

  bool _wouldCreateCycle(String dependencyId) {
    final tasksById = {for (final task in widget.tasks) task.id: task};
    final pending = <String>[dependencyId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final taskId = pending.removeLast();
      if (taskId == widget.task.id) return true;
      if (!visited.add(taskId)) continue;
      pending.addAll(tasksById[taskId]?.dependsOnTaskIds ?? const []);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.task.title.isEmpty ? 'Create a project task' : 'Edit task',
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Task *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a task.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _projectId = value;
                      _dependencyIds.clear();
                      if (widget.loadProjectAssignees != null) {
                        _assignee = '';
                      }
                    });
                    _loadProjectAssignees(value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('task-assignee-$_projectId-$_assignee'),
                initialValue: _assignee,
                decoration: const InputDecoration(labelText: 'Assigned to'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unassigned')),
                  ..._assignees.map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _assignee = value);
                },
              ),
              if (_isLoadingAssignees)
                const LinearProgressIndicator(minHeight: 2),
              if (_assigneeLoadError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _assigneeLoadError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                )
              else if (widget.loadProjectAssignees != null &&
                  !_isLoadingAssignees &&
                  _projectAssignees.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'No active members are assigned to this project.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: StudioTaskRecord.priorities
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Depends on',
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.tasks
                  .where(
                    (task) =>
                        task.projectId == _projectId &&
                        task.id != widget.task.id,
                  )
                  .isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No other tasks in this project.',
                    style: TextStyle(fontFamily: 'Arial', color: muted),
                  ),
                ),
              ...widget.tasks
                  .where(
                    (task) =>
                        task.projectId == _projectId &&
                        task.id != widget.task.id,
                  )
                  .map((task) {
                    final wouldCycle = _wouldCreateCycle(task.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(task.title),
                      subtitle: wouldCycle
                          ? const Text('Would create a dependency cycle')
                          : null,
                      value: _dependencyIds.contains(task.id),
                      onChanged: wouldCycle
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _dependencyIds.add(task.id);
                              } else {
                                _dependencyIds.remove(task.id);
                              }
                            }),
                    );
                  }),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Not scheduled'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_dueDate!),
                ),
                trailing: IconButton(
                  tooltip: 'Choose due date',
                  onPressed: () async {
                    final date = await _pickDeliveryDate(context, _dueDate);
                    if (date != null && mounted) {
                      setState(() => _dueDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final date = await _pickDeliveryDate(context, _dueDate);
                  if (date != null && mounted) {
                    setState(() => _dueDate = date);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save task'),
      ),
    ],
  );
}

class MilestoneEditorDialog extends StatefulWidget {
  const MilestoneEditorDialog({
    super.key,
    required this.projectId,
    required this.phases,
    required this.milestone,
  });

  final String projectId;
  final List<StudioProjectPhase> phases;
  final StudioMilestone milestone;

  @override
  State<MilestoneEditorDialog> createState() => _MilestoneEditorDialogState();
}

class _MilestoneEditorDialogState extends State<MilestoneEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _update;
  late String _status;
  String? _phaseId;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.milestone.title);
    _update = TextEditingController(text: widget.milestone.update);
    _status = widget.milestone.status;
    _phaseId = widget.milestone.phaseId;
    _dueDate = widget.milestone.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _update.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioMilestone(
        id: widget.milestone.id,
        projectId: widget.projectId,
        title: _title.text.trim(),
        dueDate: _dueDate,
        status: _status,
        update: _update.text.trim(),
        updatedAt: DateTime.now(),
        phaseId: _phaseId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.milestone.title.isEmpty
          ? 'Add project milestone'
          : 'Update milestone',
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Milestone *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a milestone.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: StudioMilestone.statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _phaseId,
                decoration: const InputDecoration(labelText: 'Project phase'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No phase'),
                  ),
                  ...widget.phases.map(
                    (phase) => DropdownMenuItem<String?>(
                      value: phase.id,
                      child: Text(phase.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _phaseId = value),
              ),
              TextField(
                controller: _update,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Progress update'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Not set'
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_dueDate!),
                ),
                trailing: IconButton(
                  tooltip: 'Choose target date',
                  onPressed: () async {
                    final date = await _pickDeliveryDate(context, _dueDate);
                    if (date != null && mounted) {
                      setState(() => _dueDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save update'),
      ),
    ],
  );
}

class PunchItemEditorDialog extends StatefulWidget {
  const PunchItemEditorDialog({
    super.key,
    required this.projectId,
    required this.personas,
    required this.assignee,
  });

  final String projectId;
  final List<StudioPersona> personas;
  final String assignee;

  @override
  State<PunchItemEditorDialog> createState() => _PunchItemEditorDialogState();
}

class _PunchItemEditorDialogState extends State<PunchItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  late String _assignee;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _assignee = widget.assignee;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioPunchItem(
        id: 'punch-${DateTime.now().microsecondsSinceEpoch}',
        projectId: widget.projectId,
        description: _description.text.trim(),
        assignee: _assignee,
        dueDate: _dueDate,
        status: 'Open',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Add punch-list item'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _description,
              autofocus: true,
              maxLength: 240,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Site item *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe the item.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _assignee,
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: widget.personas
                  .map(
                    (persona) => DropdownMenuItem(
                      value: persona.name,
                      child: Text(persona.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _assignee = value);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due date'),
              subtitle: Text(
                _dueDate == null
                    ? 'Not set'
                    : MaterialLocalizations.of(context)
                          .formatMediumDate(_dueDate!),
              ),
              trailing: IconButton(
                tooltip: 'Choose due date',
                onPressed: () async {
                  final date = await _pickDeliveryDate(context, _dueDate);
                  if (date != null && mounted) {
                    setState(() => _dueDate = date);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Add item'),
      ),
    ],
  );
}

class PhotoCaptionDialog extends StatefulWidget {
  const PhotoCaptionDialog({super.key});

  @override
  State<PhotoCaptionDialog> createState() => _PhotoCaptionDialogState();
}

class _PhotoCaptionDialogState extends State<PhotoCaptionDialog> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Caption progress photo'),
    content: TextField(
      controller: _caption,
      autofocus: true,
      maxLength: 200,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Caption (optional)',
        hintText: 'Room, milestone, or design detail',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: () => Navigator.pop(context, _caption.text.trim()),
        child: const Text('Add photo'),
      ),
    ],
  );
}

class ProjectAssetPreviewDialog extends StatelessWidget {
  const ProjectAssetPreviewDialog({
    super.key,
    required this.asset,
    required this.canManage,
    required this.onDownload,
    required this.onDelete,
  });

  final StudioProjectAsset asset;
  final bool canManage;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset.kind == 'photo')
              Image.memory(
                Uint8List.fromList(asset.bytes),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'This image could not be previewed.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              )
            else
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 44,
                color: accent,
              ),
            const SizedBox(height: 12),
            Text(
              [
                asset.mimeType,
                '${asset.sizeBytes} bytes',
                'Added ${MaterialLocalizations.of(context).formatMediumDate(asset.addedAt.toLocal())}',
                'By ${asset.addedBy}',
              ].join(' · '),
              style: const TextStyle(
                fontFamily: 'Arial',
                color: muted,
                fontSize: 10,
                height: 1.5,
              ),
            ),
            if (asset.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                asset.caption,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: ink,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      if (canManage)
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Remove'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: onDownload,
        icon: const Icon(Icons.download_outlined, size: 16),
        label: const Text('Download'),
      ),
    ],
  );
}

class WorkLogEditorDialog extends StatefulWidget {
  const WorkLogEditorDialog({
    super.key,
    required this.project,
    required this.tasks,
    required this.author,
    required this.id,
  });

  final StudioProject project;
  final List<StudioTaskRecord> tasks;
  final String author;
  final String id;

  @override
  State<WorkLogEditorDialog> createState() => _WorkLogEditorDialogState();
}

class _WorkLogEditorDialogState extends State<WorkLogEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _minutes = TextEditingController();
  final _description = TextEditingController();
  String _taskId = '';

  @override
  void dispose() {
    _minutes.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioWorkLog(
        id: widget.id,
        projectId: widget.project.id,
        taskId: _taskId.isEmpty ? null : _taskId,
        author: widget.author,
        minutes: int.parse(_minutes.text.trim()),
        description: _description.text.trim(),
        loggedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text('Log work · ${widget.project.name}'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration in minutes *',
              ),
              validator: (value) {
                final minutes = int.tryParse(value?.trim() ?? '');
                return minutes == null || minutes < 1 || minutes > 1440
                    ? 'Enter a duration from 1 to 1,440 minutes.'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _taskId,
              decoration: const InputDecoration(
                labelText: 'Related task (optional)',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Project only')),
                ...widget.tasks.map(
                  (task) =>
                      DropdownMenuItem(value: task.id, child: Text(task.title)),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _taskId = value);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Work notes *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe the work.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save work log'),
      ),
    ],
  );
}

class AttendanceEditorDialog extends StatefulWidget {
  const AttendanceEditorDialog({
    super.key,
    required this.personas,
    required this.activePersona,
    required this.id,
  });

  final List<StudioPersona> personas;
  final StudioPersona activePersona;
  final String id;

  @override
  State<AttendanceEditorDialog> createState() => _AttendanceEditorDialogState();
}

class _AttendanceEditorDialogState extends State<AttendanceEditorDialog> {
  static const _statuses = StudioAttendance.statuses;
  late String _personaId;
  String _status = 'Present';
  DateTime _date = DateTime.now();
  final _note = TextEditingController();

  StudioPersona get _selectedPersona => widget.personas.firstWhere(
    (persona) => persona.id == _personaId,
    orElse: () => widget.activePersona,
  );

  @override
  void initState() {
    super.initState();
    _personaId = widget.activePersona.id;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(
    context,
    StudioAttendance(
      id: widget.id,
      personaId: _personaId,
      personaName: _selectedPersona.name,
      date: DateTime(_date.year, _date.month, _date.day),
      status: _status,
      note: _note.text.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Record attendance'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _personaId,
            decoration: const InputDecoration(labelText: 'Studio role'),
            items: widget.personas
                .map(
                  (persona) => DropdownMenuItem(
                    value: persona.id,
                    child: Text(persona.name),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) setState(() => _personaId = id);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: _statuses
                .map(
                  (status) =>
                      DropdownMenuItem(value: status, child: Text(status)),
                )
                .toList(),
            onChanged: (status) {
              if (status != null) setState(() => _status = status);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(
              MaterialLocalizations.of(context).formatMediumDate(_date),
            ),
            trailing: IconButton(
              tooltip: 'Choose date',
              onPressed: () async {
                final date = await _pickDeliveryDate(context, _date);
                if (date != null && mounted) setState(() => _date = date);
              },
              icon: const Icon(Icons.calendar_today_outlined),
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Save attendance'),
      ),
    ],
  );
}

class ApprovalRequestDialog extends StatefulWidget {
  const ApprovalRequestDialog({
    super.key,
    required this.project,
    required this.approvers,
    required this.requester,
    required this.id,
    this.relatedProposalId,
    this.initialTitle = '',
  });

  final StudioProject project;
  final List<StudioPersona> approvers;
  final String requester;
  final String id;
  final String? relatedProposalId;
  final String initialTitle;

  @override
  State<ApprovalRequestDialog> createState() => _ApprovalRequestDialogState();
}

class _ApprovalRequestDialogState extends State<ApprovalRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  late String _approverId;

  StudioPersona get _approver => widget.approvers.firstWhere(
    (persona) => persona.id == _approverId,
    orElse: () => widget.approvers.first,
  );

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle;
    _approverId = widget.approvers.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioApproval(
        id: widget.id,
        projectId: widget.project.id,
        title: _title.text.trim(),
        details: _details.text.trim(),
        requestedBy: widget.requester,
        approverPersonaId: _approver.id,
        approverName: _approver.name,
        relatedProposalId: widget.relatedProposalId,
        status: 'Pending',
        decisionNote: '',
        requestedAt: DateTime.now(),
        decidedAt: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: const Text('Route an approval'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Decision needed *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe the decision.'
                  : null,
            ),
            TextFormField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Context (optional)',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _approverId,
              decoration: const InputDecoration(labelText: 'Approver'),
              items: widget.approvers
                  .map(
                    (persona) => DropdownMenuItem(
                      value: persona.id,
                      child: Text(persona.name),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) setState(() => _approverId = id);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink),
        onPressed: _save,
        child: const Text('Submit request'),
      ),
    ],
  );
}

class ApprovalDecision {
  const ApprovalDecision({required this.status, required this.note});

  final String status;
  final String note;
}

class ApprovalDecisionDialog extends StatefulWidget {
  const ApprovalDecisionDialog({
    super.key,
    required this.title,
    required this.status,
  });

  final String title;
  final String status;

  @override
  State<ApprovalDecisionDialog> createState() => _ApprovalDecisionDialogState();
}

class _ApprovalDecisionDialogState extends State<ApprovalDecisionDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text('${widget.status} request?'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: ink,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Decision note (optional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: widget.status == 'Approved'
              ? sage
              : const Color(0xFF9C4B3D),
        ),
        onPressed: () => Navigator.pop(
          context,
          ApprovalDecision(status: widget.status, note: _note.text.trim()),
        ),
        child: Text(widget.status),
      ),
    ],
  );
}
