import 'package:flutter/material.dart';
import 'package:raams_crm/backend/workspace_access.dart';

class WorkspaceSelectionGate extends StatefulWidget {
  const WorkspaceSelectionGate({
    required this.baseUri,
    required this.accessTokenProvider,
    required this.onSignOut,
    required this.organizationBuilder,
    super.key,
  });

  final Uri baseUri;
  final WorkspaceAccessTokenProvider accessTokenProvider;
  final Future<void> Function() onSignOut;
  final Widget Function(
    OrganizationWorkspace organization,
    VoidCallback onSwitchWorkspace,
  )
  organizationBuilder;

  @override
  State<WorkspaceSelectionGate> createState() => _WorkspaceSelectionGateState();
}

class _WorkspaceSelectionGateState extends State<WorkspaceSelectionGate> {
  late final WorkspaceAccessClient _accessClient;
  late Future<void> _loading;
  List<OrganizationWorkspace> _organizations = const [];
  List<WorkspaceInvitation> _invitations = const [];
  OrganizationWorkspace? _selected;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _accessClient = WorkspaceAccessClient(
      baseUri: widget.baseUri,
      accessTokenProvider: widget.accessTokenProvider,
    );
    _loading = _refresh();
  }

  @override
  void dispose() {
    _accessClient.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final organizations = await _accessClient.loadOrganizations();
      final invitations = await _accessClient.loadInvitations();
      if (!mounted) return;
      setState(() {
        _organizations = organizations;
        _invitations = invitations;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _accept(WorkspaceInvitation invitation) async {
    try {
      await _accessClient.acceptInvitation(invitation.id);
      await _refresh();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _createOrganization() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create an organization'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Organization name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final organization = await _accessClient.createOrganization(name.trim());
      if (mounted) {
        setState(() {
          _organizations = [..._organizations, organization];
          _selected = organization;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected != null) {
      return widget.organizationBuilder(selected, () {
        if (mounted) setState(() => _selected = null);
      });
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose your organization',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account can belong to more than one organization.',
                      style: TextStyle(fontFamily: 'Arial'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _loading = _refresh()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ),
                    ],
                    if (_invitations.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Invitations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final invitation in _invitations)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(invitation.workspaceName),
                          subtitle: Text('Join as ${invitation.roleName}'),
                          trailing: TextButton(
                            onPressed: () => _accept(invitation),
                            child: const Text('Accept'),
                          ),
                        ),
                    ],
                    if (_organizations.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      for (final organization in _organizations)
                        Card(
                          child: ListTile(
                            title: Text(organization.name),
                            subtitle: Text(organization.roleName),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () =>
                                setState(() => _selected = organization),
                          ),
                        ),
                    ] else if (_invitations.isEmpty && _error == null) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'You do not belong to an organization yet. Create one or accept an invitation.',
                        style: TextStyle(fontFamily: 'Arial'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _creating ? null : _createOrganization,
                      icon: const Icon(Icons.add),
                      label: Text(
                        _creating ? 'Creating…' : 'Create organization',
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: widget.onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
