part of 'main.dart';

class ProjectPhaseEditorDialog extends StatefulWidget {
  const ProjectPhaseEditorDialog({required this.phase, super.key});

  final StudioProjectPhase phase;

  @override
  State<ProjectPhaseEditorDialog> createState() =>
      _ProjectPhaseEditorDialogState();
}

class _ProjectPhaseEditorDialogState extends State<ProjectPhaseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.phase.name);
    _status = widget.phase.status;
    _startDate = widget.phase.startDate;
    _endDate = widget.phase.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The phase end date must follow its start date.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      StudioProjectPhase(
        id: widget.phase.id,
        projectId: widget.phase.projectId,
        name: _name.text.trim(),
        position: widget.phase.position,
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(widget.phase.name.isEmpty ? 'Add project phase' : 'Edit phase'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Phase name *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a phase name.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: StudioProjectPhase.statuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            _PhaseDateTile(
              title: 'Start date',
              date: _startDate,
              onChanged: (date) => setState(() => _startDate = date),
            ),
            _PhaseDateTile(
              title: 'End date',
              date: _endDate,
              onChanged: (date) => setState(() => _endDate = date),
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
        child: const Text('Save phase'),
      ),
    ],
  );
}

class _PhaseDateTile extends StatelessWidget {
  const _PhaseDateTile({
    required this.title,
    required this.date,
    required this.onChanged,
  });

  final String title;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(
      date == null
          ? 'Not set'
          : MaterialLocalizations.of(context).formatMediumDate(date!),
    ),
    trailing: IconButton(
      tooltip: 'Choose $title',
      onPressed: () async {
        final selected = await _pickDeliveryDate(context, date);
        if (selected != null) onChanged(selected);
      },
      icon: const Icon(Icons.calendar_today_outlined),
    ),
  );
}

class MaterialEditorDialog extends StatefulWidget {
  const MaterialEditorDialog({required this.material, super.key});

  final StudioMaterial material;

  @override
  State<MaterialEditorDialog> createState() => _MaterialEditorDialogState();
}

class _MaterialEditorDialogState extends State<MaterialEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _specification;
  late final TextEditingController _description;
  late String _category;
  late String _unit;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.material.name);
    _category = widget.material.category;
    _specification = TextEditingController(text: widget.material.specification);
    _description = TextEditingController(text: widget.material.description);
    _unit = widget.material.unit;
    _isActive = widget.material.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _specification.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioMaterial(
        id: widget.material.id,
        name: _name.text.trim(),
        category: _category,
        unit: _unit,
        specification: _specification.text.trim(),
        description: _description.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.material.name.isEmpty ? 'Add material' : 'Edit material',
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
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Material name *'),
                validator: _requiredValidator,
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: StudioMaterial.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unit of measure'),
                items: StudioMaterial.units
                    .map(
                      (unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _unit = value);
                },
              ),
              TextFormField(
                controller: _specification,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Specification'),
              ),
              TextFormField(
                controller: _description,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text('Available for use'),
                onChanged: (value) => setState(() => _isActive = value),
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
        child: const Text('Save material'),
      ),
    ],
  );
}

class VendorEditorDialog extends StatefulWidget {
  const VendorEditorDialog({required this.vendor, super.key});

  final StudioVendor vendor;

  @override
  State<VendorEditorDialog> createState() => _VendorEditorDialogState();
}

class _VendorEditorDialogState extends State<VendorEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _taxId;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _notes;
  late String _kind;
  late bool _isActive;
  late List<StudioVendorDocument> _documents;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.vendor.name);
    _email = TextEditingController(text: widget.vendor.email);
    _phone = TextEditingController(text: widget.vendor.phone);
    _address = TextEditingController(text: widget.vendor.address);
    _taxId = TextEditingController(text: widget.vendor.taxId);
    _paymentTerms = TextEditingController(text: widget.vendor.paymentTerms);
    _notes = TextEditingController(text: widget.vendor.notes);
    _kind = widget.vendor.kind;
    _isActive = widget.vendor.isActive;
    _documents = [...widget.vendor.documents];
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _taxId.dispose();
    _paymentTerms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addDocument([StudioVendorDocument? document]) async {
    final result = await showDialog<StudioVendorDocument>(
      context: context,
      builder: (context) => VendorDocumentEditorDialog(document: document),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _documents.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        _documents = [..._documents, result];
      } else {
        _documents[index] = result;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioVendor(
        id: widget.vendor.id,
        name: _name.text.trim(),
        kind: _kind,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        taxId: _taxId.text.trim(),
        paymentTerms: _paymentTerms.text.trim(),
        notes: _notes.text.trim(),
        isActive: _isActive,
        documents: _documents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(widget.vendor.name.isEmpty ? 'Add vendor' : 'Edit vendor'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Company name *'),
                validator: _requiredValidator,
              ),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Record type'),
                items: StudioVendor.kinds
                    .map(
                      (kind) =>
                          DropdownMenuItem(value: kind, child: Text(kind)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              TextFormField(
                controller: _email,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.isNotEmpty &&
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? 'Enter a valid email address.'
                      : null;
                },
              ),
              TextFormField(
                controller: _phone,
                maxLength: 40,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextFormField(
                controller: _address,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextFormField(
                controller: _taxId,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Tax ID'),
              ),
              TextFormField(
                controller: _paymentTerms,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Payment terms'),
              ),
              TextFormField(
                controller: _notes,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text('Active vendor'),
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const Divider(),
              Row(
                children: [
                  const Expanded(child: Text('Document register')),
                  TextButton.icon(
                    onPressed: () => _addDocument(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add record'),
                  ),
                ],
              ),
              if (_documents.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Track licences, certificates, and expiry dates.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ..._documents.map(
                (document) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(document.name),
                  subtitle: Text(
                    [
                      document.documentType,
                      if (document.reference.isNotEmpty) document.reference,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit document record',
                    onPressed: () => _addDocument(document),
                    icon: const Icon(Icons.edit_outlined),
                  ),
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
        child: const Text('Save vendor'),
      ),
    ],
  );
}

class VendorDocumentEditorDialog extends StatefulWidget {
  const VendorDocumentEditorDialog({this.document, super.key});

  final StudioVendorDocument? document;

  @override
  State<VendorDocumentEditorDialog> createState() =>
      _VendorDocumentEditorDialogState();
}

class _VendorDocumentEditorDialogState
    extends State<VendorDocumentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _type;
  late final TextEditingController _reference;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.document?.name ?? '');
    _type = TextEditingController(text: widget.document?.documentType ?? '');
    _reference = TextEditingController(text: widget.document?.reference ?? '');
    _expiresAt = widget.document?.expiresAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioVendorDocument(
        id:
            widget.document?.id ??
            'vendor-document-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        documentType: _type.text.trim(),
        reference: _reference.text.trim(),
        expiresAt: _expiresAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: paper,
    title: Text(
      widget.document == null ? 'Add document record' : 'Edit document',
    ),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Document name *'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _type,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Document type *'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _reference,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Reference or storage link',
              ),
            ),
            _PhaseDateTile(
              title: 'Expiry date',
              date: _expiresAt,
              onChanged: (date) => setState(() => _expiresAt = date),
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
        child: const Text('Save record'),
      ),
    ],
  );
}

String? _requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
