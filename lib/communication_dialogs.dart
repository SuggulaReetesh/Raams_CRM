part of 'main.dart';

class CommunicationDraft {
  const CommunicationDraft({
    required this.clientId,
    required this.projectId,
    required this.channel,
    required this.subject,
    required this.body,
    required this.recipient,
    required this.mentionedPersonaIds,
    required this.status,
  });

  final String? clientId;
  final String? projectId;
  final String channel;
  final String subject;
  final String body;
  final String recipient;
  final List<String> mentionedPersonaIds;
  final String status;
}

class CommunicationComposerDialog extends StatefulWidget {
  const CommunicationComposerDialog({
    super.key,
    required this.customers,
    required this.projects,
    required this.personas,
    required this.activePersonaId,
    required this.initialChannel,
    this.initialClientId,
    this.initialProjectId,
    this.initialRecipient,
  });

  final List<Customer> customers;
  final List<StudioProject> projects;
  final List<StudioPersona> personas;
  final String activePersonaId;
  final String initialChannel;
  final String? initialClientId;
  final String? initialProjectId;
  final String? initialRecipient;

  @override
  State<CommunicationComposerDialog> createState() =>
      _CommunicationComposerDialogState();
}

class _CommunicationComposerDialogState
    extends State<CommunicationComposerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final TextEditingController _recipient;
  late String _channel;
  String? _clientId;
  String? _projectId;
  final Set<String> _mentionedPersonaIds = {};

  bool get _externalMessage => _channel == 'Email' || _channel == 'WhatsApp';
  bool _received = false;
  Customer? get _client {
    for (final customer in widget.customers) {
      if (customer.id == _clientId) return customer;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _channel = StudioCommunication.channels.contains(widget.initialChannel)
        ? widget.initialChannel
        : 'Internal note';
    _projectId =
        widget.projects.any((project) => project.id == widget.initialProjectId)
        ? widget.initialProjectId
        : null;
    final projectClientId = _projectId == null
        ? null
        : widget.projects
              .firstWhere((project) => project.id == _projectId)
              .customerId;
    final initialClientMatchesProject =
        projectClientId == null || widget.initialClientId == projectClientId;
    _clientId =
        widget.customers.any(
              (customer) => customer.id == widget.initialClientId,
            ) &&
            initialClientMatchesProject
        ? widget.initialClientId
        : widget.customers.any((customer) => customer.id == projectClientId)
        ? projectClientId
        : null;
    _subject = TextEditingController();
    _body = TextEditingController();
    _recipient = TextEditingController(
      text: _channel == 'Email'
          ? widget.initialRecipient ?? _client?.email ?? ''
          : _client?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _recipient.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CommunicationDraft(
        clientId: _clientId,
        projectId: _projectId,
        channel: _channel,
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        recipient: _externalMessage ? _recipient.text.trim() : '',
        mentionedPersonaIds: _channel == 'Internal note'
            ? List.of(_mentionedPersonaIds)
            : const [],
        status: _externalMessage
            ? (_received ? 'Received' : 'Draft')
            : 'Logged',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_channel) {
      'Email' => _received ? 'Log received email' : 'Compose email',
      'WhatsApp' =>
        _received
            ? 'Log received WhatsApp message'
            : 'Compose WhatsApp message',
      'Internal note' => 'Add internal note',
      _ => 'Log $_channel',
    };
    return AlertDialog(
      backgroundColor: paper,
      scrollable: true,
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: StudioCommunication.channels
                    .map(
                      (channel) => DropdownMenuItem(
                        value: channel,
                        child: Text(channel),
                      ),
                    )
                    .toList(),
                onChanged: (channel) {
                  if (channel == null) return;
                  setState(() {
                    _channel = channel;
                    _received = false;
                    if (channel == 'Email') {
                      _recipient.text =
                          widget.initialRecipient ?? _client?.email ?? '';
                    } else if (channel == 'WhatsApp') {
                      _recipient.text = _client?.phone ?? '';
                    } else {
                      _recipient.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                hint: const Text('No client linked'),
                decoration: const InputDecoration(
                  labelText: 'Client (optional)',
                ),
                items: widget.customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Text(customer.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _clientId = id;
                    if (_projectId != null &&
                        widget.projects.any(
                          (project) =>
                              project.id == _projectId &&
                              project.customerId != null &&
                              project.customerId != id,
                        )) {
                      _projectId = null;
                    }
                    if (_channel == 'Email') {
                      _recipient.text = _client?.email ?? '';
                    } else if (_channel == 'WhatsApp') {
                      _recipient.text = _client?.phone ?? '';
                    }
                  });
                },
              ),
              if (widget.projects.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _projectId,
                  hint: const Text('No project linked'),
                  decoration: const InputDecoration(
                    labelText: 'Project (optional)',
                  ),
                  items: widget.projects
                      .where(
                        (project) =>
                            _clientId == null ||
                            project.customerId == null ||
                            project.customerId == _clientId,
                      )
                      .map(
                        (project) => DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => setState(() {
                    _projectId = id;
                    for (final project in widget.projects) {
                      if (project.id == id && project.customerId != null) {
                        _clientId = project.customerId;
                        if (_channel == 'Email') {
                          _recipient.text = _client?.email ?? '';
                        } else if (_channel == 'WhatsApp') {
                          _recipient.text = _client?.phone ?? '';
                        }
                        break;
                      }
                    }
                  }),
                ),
              if (_externalMessage) ...[
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Prepare to send'),
                      icon: Icon(Icons.outbox_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Log received'),
                      icon: Icon(Icons.inbox_outlined),
                    ),
                  ],
                  selected: {_received},
                  onSelectionChanged: (selection) =>
                      setState(() => _received = selection.first),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recipient,
                  keyboardType: _channel == 'Email'
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _channel == 'Email'
                        ? _received
                              ? 'Sender email *'
                              : 'Recipient email *'
                        : _received
                        ? 'Sender WhatsApp number *'
                        : 'Recipient WhatsApp number *',
                    hintText: _channel == 'WhatsApp' ? '+1 555 123 4567' : null,
                  ),
                  validator: (value) {
                    final recipient = value?.trim() ?? '';
                    if (_channel == 'Email' &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(recipient)) {
                      return 'Enter a valid email address.';
                    }
                    if (_channel == 'WhatsApp') {
                      final digits = recipient.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 8 || digits.length > 15) {
                        return 'Use an international phone number (8–15 digits).';
                      }
                    }
                    return null;
                  },
                ),
              ],
              if (_channel == 'Email')
                TextFormField(
                  controller: _subject,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                  ),
                  validator: (value) =>
                      value != null && RegExp(r'[\r\n]').hasMatch(value)
                      ? 'Subject cannot contain line breaks.'
                      : null,
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                autofocus: true,
                maxLength: _channel == 'WhatsApp' ? 4096 : 5000,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: _channel == 'Internal note'
                      ? 'Note *'
                      : _externalMessage
                      ? 'Message *'
                      : 'Interaction summary *',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a message or summary.'
                    : null,
              ),
              if (_channel == 'Internal note') ...[
                const SizedBox(height: 8),
                const Text(
                  'Notify teammates with @mentions',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: widget.personas
                      .where(
                        (persona) =>
                            persona.id != widget.activePersonaId &&
                            persona.allows(StudioPersona.viewCommunications),
                      )
                      .map(
                        (persona) => FilterChip(
                          label: Text('@${persona.name}'),
                          selected: _mentionedPersonaIds.contains(persona.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _mentionedPersonaIds.add(persona.id);
                            } else {
                              _mentionedPersonaIds.remove(persona.id);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_externalMessage) ...[
                const SizedBox(height: 10),
                Text(
                  _received
                      ? 'This records a received message; it does not import content from your messaging app.'
                      : 'Send from a connected workspace account or open your email or WhatsApp app. External-app delivery must be confirmed manually.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: muted,
                    fontSize: 10,
                    height: 1.4,
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
          child: Text(
            _externalMessage && !_received
                ? 'Save and open app'
                : _received
                ? 'Log received message'
                : 'Save entry',
          ),
        ),
      ],
    );
  }
}

class CommunicationIntegrationDialog extends StatefulWidget {
  const CommunicationIntegrationDialog({
    super.key,
    required this.repository,
    required this.workspaceName,
  });

  final RemoteCustomerWorkspaceRepository repository;
  final String workspaceName;

  @override
  State<CommunicationIntegrationDialog> createState() =>
      _CommunicationIntegrationDialogState();
}

class _CommunicationIntegrationDialogState
    extends State<CommunicationIntegrationDialog> {
  final _postalFormKey = GlobalKey<FormState>();
  final _whatsappFormKey = GlobalKey<FormState>();
  final _smtpUser = TextEditingController();
  final _smtpPassword = TextEditingController();
  final _fromAddress = TextEditingController();
  final _fromName = TextEditingController();
  final _phoneNumberId = TextEditingController();
  final _accessToken = TextEditingController();
  late Future<Map<String, String>> _integrations;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _integrations = widget.repository.loadCommunicationIntegrations();
  }

  @override
  void dispose() {
    _smtpUser.dispose();
    _smtpPassword.dispose();
    _fromAddress.dispose();
    _fromName.dispose();
    _phoneNumberId.dispose();
    _accessToken.dispose();
    super.dispose();
  }

  Future<void> _save(String provider) async {
    final formKey = provider == 'postal' ? _postalFormKey : _whatsappFormKey;
    if (!formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveCommunicationIntegration(
        provider: provider,
        workspaceName: widget.workspaceName,
        settings: provider == 'postal'
            ? {
                'smtpUser': _smtpUser.text.trim(),
                'smtpPassword': _smtpPassword.text,
                'fromAddress': _fromAddress.text.trim(),
                'fromName': _fromName.text.trim(),
              }
            : {
                'phoneNumberId': _phoneNumberId.text.trim(),
                'accessToken': _accessToken.text.trim(),
              },
      );
      if (!mounted) return;
      _clearSecrets(provider);
      setState(
        () => _integrations = widget.repository.loadCommunicationIntegrations(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sender account saved securely.')),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save sender account: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(String provider) async {
    setState(() => _saving = true);
    try {
      await widget.repository.removeCommunicationIntegration(provider);
      if (!mounted) return;
      _clearSecrets(provider);
      setState(
        () => _integrations = widget.repository.loadCommunicationIntegrations(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sender account removed.')));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove sender account: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearSecrets(String provider) {
    if (provider == 'postal') {
      _smtpUser.clear();
      _smtpPassword.clear();
    } else {
      _accessToken.clear();
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required.' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    scrollable: true,
    title: const Text('Sender accounts'),
    content: SizedBox(
      width: 520,
      child: FutureBuilder<Map<String, String>>(
        future: _integrations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Text('Could not load sender accounts: ${snapshot.error}');
          }
          final integrations = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Credentials are encrypted on the server and are never '
                'saved on this device. Configure the SMTP host and '
                'WhatsApp webhook in the server environment.',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _integrationHeader(
                title: 'Postal email',
                hint: integrations['postal'],
                provider: 'postal',
              ),
              Form(
                key: _postalFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _smtpUser,
                      decoration: const InputDecoration(
                        labelText: 'SMTP username',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _smtpPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'SMTP password',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fromAddress,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Sender email address',
                      ),
                      validator: (value) {
                        final address = value?.trim() ?? '';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(address)
                            ? null
                            : 'Enter a valid email address.';
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fromName,
                      decoration: const InputDecoration(
                        labelText: 'Sender name',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save('postal'),
                        child: const Text('Save email account'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 28),
              _integrationHeader(
                title: 'WhatsApp Business',
                hint: integrations['whatsapp'],
                provider: 'whatsapp',
              ),
              Form(
                key: _whatsappFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _phoneNumberId,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Phone number ID',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accessToken,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Permanent access token',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 20) {
                          return 'Enter a valid access token.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save('whatsapp'),
                        child: const Text('Save WhatsApp account'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );

  Widget _integrationHeader({
    required String title,
    required String? hint,
    required String provider,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
              ),
              Text(
                hint == null ? 'Not connected' : 'Connected: $hint',
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (hint != null)
          TextButton(
            onPressed: _saving ? null : () => _remove(provider),
            child: const Text('Remove'),
          ),
      ],
    ),
  );
}
