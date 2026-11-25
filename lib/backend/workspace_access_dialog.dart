import 'package:flutter/material.dart';
import 'package:raams_crm/backend/workspace_access.dart';
import 'package:raams_crm/delivery.dart';

class WorkspaceAccessDialog extends StatefulWidget {
  const WorkspaceAccessDialog({
    required this.client,
    required this.projects,
    required this.permissions,
    super.key,
  });

  final WorkspaceAccessClient client;
  final List<StudioProject> projects;
  final List<String> permissions;

  @override
  State<WorkspaceAccessDialog> createState() => _WorkspaceAccessDialogState();
}

class _WorkspaceAccessDialogState extends State<WorkspaceAccessDialog> {
  static const _rolePermissions = <String, String>{
    'workspace.read': 'Read organization records',
    'members.view': 'View organization members',
    'members.manage': 'Invite and manage members',
    'roles.view': 'View organization and project roles',
    'roles.manage': 'Create and edit roles',
    'manageClients': 'Manage clients',
    'managePipeline': 'Manage the lead pipeline',
    'manageRequirements': 'Manage client requirements',
    'viewFinancials': 'View financial records',
    'configureWorkspace': 'Configure organization settings',
    'viewProjects': 'View project records',
    'manageProjects': 'Manage projects',
    'manageTasks': 'Manage project tasks',
    'viewFiles': 'View project files',
    'manageFiles': 'Manage project files',
    'manageMilestones': 'Manage milestones',
    'managePunchList': 'Manage punch lists',
    'viewWorkLogs': 'View work logs',
    'manageWorkLogs': 'Manage work logs',
    'manageAttendance': 'Manage attendance',
    'manageApprovals': 'Manage approvals',
    'approveApprovals': 'Approve requests',
    'manageFinancials': 'Manage financial records',
    'viewCommunications': 'View communications',
    'manageCommunications': 'Manage communications',
    'procurement.view': 'View procurement',
    'procurement.manage': 'Manage procurement',
    'inventory.view': 'View inventory',
    'inventory.manage': 'Manage inventory',
    'finance.view': 'View finance',
    'finance.manage': 'Manage finance',
    'documents.view': 'View documents',
    'documents.manage': 'Manage documents',
    'reports.view': 'View reports',
  };

  final _email = TextEditingController();
  WorkspaceAccessData? _data;
  String? _error;
  bool _loading = true;
  bool _working = false;

  bool get _canManageMembers => _allows('members.manage') || _allows('*');
  bool get _canManageRoles => _allows('roles.manage') || _allows('*');

  bool _allows(String permission) =>
      widget.permissions.contains('*') ||
      widget.permissions.contains(permission);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.client.loadAccess();
      if (mounted) setState(() => _data = data);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      await _reload();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final data = _data;
    if (data == null) return;
    final roles = data.roles.where((role) => role.scope == 'organization');
    if (roles.isEmpty) return;
    final roleId = await showDialog<String>(
      context: context,
      builder: (context) => _SelectionDialog(
        title: 'Choose an organization role',
        options: {for (final role in roles) role.id: role.name},
      ),
    );
    if (roleId == null) return;
    await _run(() => widget.client.inviteMember(_email.text.trim(), roleId));
    if (_error == null) _email.clear();
  }

  Future<void> _createRole() async {
    final result = await showDialog<_RoleDraft>(
      context: context,
      builder: (context) => _RoleEditorDialog(projects: widget.projects),
    );
    if (result == null) return;
    await _run(
      () => widget.client.createRole(
        scope: result.scope,
        name: result.name,
        permissions: result.permissions,
        projectId: result.projectId,
      ),
    );
  }

  Future<void> _editRole(WorkspaceRole role) async {
    if (role.isSystem) return;
    final result = await showDialog<_RoleDraft>(
      context: context,
      builder: (context) =>
          _RoleEditorDialog(projects: widget.projects, role: role),
    );
    if (result == null) return;
    await _run(
      () => widget.client.updateRole(
        roleId: role.id,
        name: result.name,
        permissions: result.permissions,
      ),
    );
  }

  Future<void> _assignProjectRole(WorkspaceAccessMember member) async {
    final data = _data;
    if (data == null) return;
    final roles = data.roles.where((role) => role.scope == 'project').toList();
    if (widget.projects.isEmpty || roles.isEmpty) {
      setState(() => _error = 'Create a project and project role first.');
      return;
    }
    final selection = await showDialog<({String projectId, String roleId})>(
      context: context,
      builder: (context) =>
          _ProjectRoleDialog(projects: widget.projects, roles: roles),
    );
    if (selection == null) return;
    await _run(
      () => widget.client.assignProjectRole(
        projectId: selection.projectId,
        userId: member.id,
        roleId: selection.roleId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final organizationRoles = data?.roles
        .where((role) => role.scope == 'organization')
        .toList();
    return AlertDialog(
      title: const Text('Organization & access'),
      content: SizedBox(
        width: 680,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_canManageMembers) ...[
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Invite a teammate by email',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _working || _email.text.trim().isEmpty
                              ? null
                              : _invite,
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Send invitation'),
                        ),
                      ),
                    ],
                    if (_canManageRoles) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Roles',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _working ? null : _createRole,
                            icon: const Icon(Icons.add),
                            label: const Text('Create role'),
                          ),
                        ],
                      ),
                      for (final role in data?.roles ?? const <WorkspaceRole>[])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(role.name),
                          subtitle: Text(
                            role.scope == 'organization'
                                ? 'Organization role · ${role.permissions.length} permissions'
                                : 'Project role · ${role.permissions.length} permissions',
                          ),
                          trailing: IconButton(
                            tooltip: role.isSystem
                                ? 'System role'
                                : 'Edit role',
                            onPressed: _working || role.isSystem
                                ? null
                                : () => _editRole(role),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                    ],
                    if (data != null) ...[
                      const Divider(height: 28),
                      Text(
                        'Members (${data.members.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (final member in data.members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            member.displayName.isEmpty
                                ? member.email ?? member.id
                                : member.displayName,
                          ),
                          subtitle: Text(
                            '${member.email ?? 'No email'} · ${member.roleName} · ${member.status}',
                          ),
                          trailing: _canManageMembers
                              ? PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'assign_project') {
                                      _assignProjectRole(member);
                                    } else if (action == 'remove') {
                                      _run(
                                        () => widget.client.removeMember(
                                          member.id,
                                        ),
                                      );
                                    } else if (action.startsWith('status:')) {
                                      _run(
                                        () => widget.client.setMemberStatus(
                                          member.id,
                                          action.substring(7),
                                        ),
                                      );
                                    } else if (action.startsWith('role:')) {
                                      _run(
                                        () => widget.client.assignMemberRole(
                                          member.id,
                                          action.substring(5),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    for (final role
                                        in organizationRoles ??
                                            const <WorkspaceRole>[])
                                      if (role.id != member.roleId)
                                        PopupMenuItem(
                                          value: 'role:${role.id}',
                                          child: Text('Assign ${role.name}'),
                                        ),
                                    const PopupMenuItem(
                                      value: 'assign_project',
                                      child: Text('Assign project role'),
                                    ),
                                    PopupMenuItem(
                                      value:
                                          'status:${member.status == 'active' ? 'suspended' : 'active'}',
                                      child: Text(
                                        member.status == 'active'
                                            ? 'Suspend access'
                                            : 'Reactivate access',
                                      ),
                                    ),
                                    if (member.status == 'active')
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove access'),
                                      ),
                                  ],
                                )
                              : null,
                        ),
                      if (data.invitations.isNotEmpty) ...[
                        const Divider(height: 28),
                        const Text(
                          'Pending invitations',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final invitation in data.invitations)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(invitation['email'] as String? ?? ''),
                            subtitle: Text(
                              invitation['status'] as String? ?? 'pending',
                            ),
                            trailing: _canManageMembers
                                ? IconButton(
                                    tooltip: 'Revoke invitation',
                                    onPressed: _working
                                        ? null
                                        : () => _run(
                                            () =>
                                                widget.client.revokeInvitation(
                                                  invitation['id'] as String,
                                                ),
                                          ),
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                          ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _loading || _working ? null : _reload,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _RoleDraft {
  const _RoleDraft({
    required this.scope,
    required this.name,
    required this.permissions,
    this.projectId,
  });

  final String scope;
  final String name;
  final List<String> permissions;
  final String? projectId;
}

class _RoleEditorDialog extends StatefulWidget {
  const _RoleEditorDialog({required this.projects, this.role});

  final List<StudioProject> projects;
  final WorkspaceRole? role;

  @override
  State<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<_RoleEditorDialog> {
  static const _projectPermissionKeys = {
    'projects.view',
    'projects.manage',
    'viewFinancials',
    'viewProjects',
    'manageProjects',
    'manageTasks',
    'manageFiles',
    'viewFiles',
    'manageMilestones',
    'managePunchList',
    'viewWorkLogs',
    'manageWorkLogs',
    'manageAttendance',
    'manageApprovals',
    'approveApprovals',
    'manageFinancials',
    'viewCommunications',
    'manageCommunications',
    'procurement.view',
    'procurement.manage',
    'inventory.view',
    'inventory.manage',
    'finance.view',
    'finance.manage',
    'documents.view',
    'documents.manage',
    'reports.view',
  };

  late final TextEditingController _name;
  late String _scope;
  String? _projectId;
  late final Set<String> _permissions;

  Iterable<MapEntry<String, String>> get _visiblePermissions =>
      _WorkspaceAccessDialogState._rolePermissions.entries.where(
        (entry) =>
            _scope != 'project' || _projectPermissionKeys.contains(entry.key),
      );

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.role?.name);
    _scope = widget.role?.scope ?? 'organization';
    _projectId =
        widget.role?.projectId ??
        (widget.projects.isEmpty ? null : widget.projects.first.id);
    _permissions = {...?widget.role?.permissions};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.role == null ? 'Create role' : 'Edit role'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Role name'),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.role == null)
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Role scope'),
                items: const [
                  DropdownMenuItem(
                    value: 'organization',
                    child: Text('Organization'),
                  ),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                ],
                onChanged: (value) => setState(() => _scope = value ?? _scope),
              ),
            if (_scope == 'project' && widget.role == null)
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final project in widget.projects)
                    DropdownMenuItem(
                      value: project.id,
                      child: Text(project.name),
                    ),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
            const SizedBox(height: 12),
            for (final entry in _visiblePermissions)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _permissions.contains(entry.key),
                title: Text(entry.value),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _permissions.add(entry.key);
                  } else {
                    _permissions.remove(entry.key);
                  }
                }),
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
        onPressed:
            _name.text.trim().isEmpty ||
                (_scope == 'project' && _projectId == null)
            ? null
            : () => Navigator.pop(
                context,
                _RoleDraft(
                  scope: _scope,
                  name: _name.text.trim(),
                  permissions: _permissions.toList(),
                  projectId: _scope == 'project' ? _projectId : null,
                ),
              ),
        child: const Text('Save role'),
      ),
    ],
  );
}

class _ProjectRoleDialog extends StatefulWidget {
  const _ProjectRoleDialog({required this.projects, required this.roles});

  final List<StudioProject> projects;
  final List<WorkspaceRole> roles;

  @override
  State<_ProjectRoleDialog> createState() => _ProjectRoleDialogState();
}

class _ProjectRoleDialogState extends State<_ProjectRoleDialog> {
  late String _projectId = widget.projects.first.id;
  String? _roleId;

  List<WorkspaceRole> get _rolesForProject =>
      widget.roles.where((role) => role.projectId == _projectId).toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Assign project role'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_projectId),
          initialValue: _projectId,
          decoration: const InputDecoration(labelText: 'Project'),
          items: [
            for (final project in widget.projects)
              DropdownMenuItem(value: project.id, child: Text(project.name)),
          ],
          onChanged: (value) => setState(() {
            _projectId = value ?? _projectId;
            _roleId = null;
          }),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('role:$_projectId'),
          initialValue: _rolesForProject.isEmpty
              ? null
              : _rolesForProject.first.id,
          decoration: const InputDecoration(labelText: 'Project role'),
          items: [
            for (final role in _rolesForProject)
              DropdownMenuItem(value: role.id, child: Text(role.name)),
          ],
          onChanged: (value) => setState(() => _roleId = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _rolesForProject.isEmpty
            ? null
            : () => Navigator.pop(context, (
                projectId: _projectId,
                roleId: _roleId ?? _rolesForProject.first.id,
              )),
        child: const Text('Assign'),
      ),
    ],
  );
}

class _SelectionDialog extends StatelessWidget {
  const _SelectionDialog({required this.title, required this.options});

  final String title;
  final Map<String, String> options;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options.entries)
          ListTile(
            title: Text(option.value),
            onTap: () => Navigator.pop(context, option.key),
          ),
      ],
    ),
  );
}
