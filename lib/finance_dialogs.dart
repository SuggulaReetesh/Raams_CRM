part of 'main.dart';

class QuotationEditorDialog extends StatefulWidget {
  const QuotationEditorDialog({super.key, required this.quotation});

  final StudioQuotation quotation;

  @override
  State<QuotationEditorDialog> createState() => _QuotationEditorDialogState();
}

class _QuotationEditorDialogState extends State<QuotationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _taxRate;
  late List<StudioQuoteLine> _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.quotation.title);
    _taxRate = TextEditingController(
        text: widget.quotation.taxRate.toStringAsFixed(2));
    _items = List.of(widget.quotation.items);
  }

  @override
  void dispose() {
    _title.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  Future<void> _editLine([StudioQuoteLine? existing]) async {
    final item = await showDialog<StudioQuoteLine>(
      context: context,
      builder: (context) => QuoteLineEditorDialog(
        line: existing ??
            StudioQuoteLine(
              id: 'quote-line-${DateTime.now().microsecondsSinceEpoch}',
              description: '',
              quantity: 1,
              unit: 'item',
              unitRate: 0,
            ),
      ),
    );
    if (item == null || !mounted) return;
    setState(() {
      _error = null;
      if (existing == null) {
        _items = [..._items, item];
      } else {
        _items = _items.map((line) => line.id == item.id ? item : line).toList();
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one line item.');
      return;
    }
    Navigator.pop(
      context,
      widget.quotation.copyWith(
        title: _title.text.trim(),
        items: _items,
        taxRate: double.parse(_taxRate.text.trim()),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        scrollable: true,
        title: Text(widget.quotation.items.isEmpty
            ? 'Build a quotation'
            : 'Edit quotation'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.quotation.number} · ${widget.quotation.projectName}',
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 10)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration:
                      const InputDecoration(labelText: 'Quotation title *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a quotation title.'
                      : null,
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Line items',
                          style: TextStyle(
                              color: ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: _editLine,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Add the services, quantities, units, and rates.',
                        style: TextStyle(
                            fontFamily: 'Arial', color: muted, fontSize: 10)),
                  )
                else
                  ..._items.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Arial',
                                color: ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${item.quantity} ${item.unit} × ${_formatCurrencyAmount(item.unitRate, widget.quotation.currencySymbol)}',
                            style: const TextStyle(
                                fontFamily: 'Arial',
                                color: muted,
                                fontSize: 9)),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_formatCurrencyAmount(
                                item.amount, widget.quotation.currencySymbol)),
                            IconButton(
                              tooltip: 'Edit line item',
                              onPressed: () => _editLine(item),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                            ),
                            IconButton(
                              tooltip: 'Remove line item',
                              onPressed: () => setState(() =>
                                  _items.removeWhere((line) => line.id == item.id)),
                              icon: const Icon(Icons.delete_outline, size: 16),
                            ),
                          ],
                        ),
                      )),
                TextFormField(
                  controller: _taxRate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Tax rate', suffixText: '%'),
                  validator: (value) {
                    final rate = double.tryParse(value?.trim() ?? '');
                    return rate == null ||
                            !rate.isFinite ||
                            rate < 0 ||
                            rate > 100
                        ? 'Enter a rate from 0 to 100.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Estimated total: ${_formatCurrencyAmount(_items.fold<double>(0, (total, item) => total + item.amount) * (1 + (double.tryParse(_taxRate.text) ?? 0) / 100), widget.quotation.currencySymbol)}',
                      style: const TextStyle(
                          color: ink,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFF9C4B3D),
                          fontSize: 10)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Save quotation'),
          ),
        ],
      );
}

class QuoteLineEditorDialog extends StatefulWidget {
  const QuoteLineEditorDialog({super.key, required this.line});

  final StudioQuoteLine line;

  @override
  State<QuoteLineEditorDialog> createState() => _QuoteLineEditorDialogState();
}

class _QuoteLineEditorDialogState extends State<QuoteLineEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _unitRate;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.line.description);
    _quantity = TextEditingController(text: widget.line.quantity.toString());
    _unit = TextEditingController(text: widget.line.unit);
    _unitRate = TextEditingController(text: widget.line.unitRate.toString());
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    _unitRate.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioQuoteLine(
        id: widget.line.id,
        description: _description.text.trim(),
        quantity: double.parse(_quantity.text.trim()),
        unit: _unit.text.trim(),
        unitRate: double.parse(_unitRate.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Quotation line item'),
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
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Description *'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter a description.'
                          : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Quantity *'),
                        validator: (value) {
                          final quantity =
                              double.tryParse(value?.trim() ?? '');
                          return quantity == null ||
                                  !quantity.isFinite ||
                                  quantity <= 0
                              ? 'Enter a quantity above zero.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        maxLength: 30,
                        decoration: const InputDecoration(labelText: 'Unit *'),
                        validator: (value) => value == null ||
                                value.trim().isEmpty
                            ? 'Enter a unit.'
                            : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _unitRate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rate per unit *'),
                  validator: (value) {
                    final rate = double.tryParse(value?.trim() ?? '');
                    return rate == null || !rate.isFinite || rate < 0
                        ? 'Enter a non-negative rate.'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Save item'),
          ),
        ],
      );
}

class DocumentTemplateManagerDialog extends StatefulWidget {
  const DocumentTemplateManagerDialog({super.key, required this.templates});

  final List<StudioDocumentTemplate> templates;

  @override
  State<DocumentTemplateManagerDialog> createState() =>
      _DocumentTemplateManagerDialogState();
}

class _DocumentTemplateManagerDialogState
    extends State<DocumentTemplateManagerDialog> {
  late List<StudioDocumentTemplate> _templates;
  String? _error;

  @override
  void initState() {
    super.initState();
    _templates = List.of(widget.templates);
  }

  Future<void> _editTemplate([StudioDocumentTemplate? template]) async {
    final initial = template ??
        StudioDocumentTemplate(
          id: 'template-${DateTime.now().microsecondsSinceEpoch}',
          name: '',
          brandName: '',
          introduction: StudioDocumentTemplate.standard.introduction,
          terms: StudioDocumentTemplate.standard.terms,
          footer: StudioDocumentTemplate.standard.footer,
          accentColor: StudioDocumentTemplate.standard.accentColor,
          sectionOrder: List.of(StudioDocumentTemplate.standard.sectionOrder),
        );
    final updated = await showDialog<StudioDocumentTemplate>(
      context: context,
      builder: (context) => DocumentTemplateEditorDialog(template: initial),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _error = null;
      if (template == null) {
        _templates = [..._templates, updated];
      } else {
        _templates = _templates
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      }
    });
  }

  void _save() {
    final names = _templates.map((item) => item.name.trim().toLowerCase());
    if (_templates.isEmpty) {
      setState(() => _error = 'Keep at least one document template.');
      return;
    }
    if (names.any((name) => name.isEmpty) ||
        names.toSet().length != _templates.length) {
      setState(() => _error = 'Template names must be non-empty and unique.');
      return;
    }
    Navigator.pop(context, _templates);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Document templates'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _editTemplate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New template'),
                ),
              ),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: line),
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(template.accentColor),
                      ),
                      title: Text(template.name,
                          style: const TextStyle(
                              fontFamily: 'Arial',
                              color: ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          template.brandName.trim().isEmpty
                              ? 'Uses current studio name'
                              : template.brandName,
                          style: const TextStyle(
                              fontFamily: 'Arial',
                              color: muted,
                              fontSize: 9)),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Edit template',
                            onPressed: () => _editTemplate(template),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                          ),
                          IconButton(
                            tooltip: 'Remove template',
                            onPressed: _templates.length <= 1
                                ? null
                                : () => setState(() => _templates.removeWhere(
                                    (item) => item.id == template.id)),
                            icon: const Icon(Icons.delete_outline, size: 17),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!,
                      style: const TextStyle(
                          fontFamily: 'Arial',
                          color: Color(0xFF9C4B3D),
                          fontSize: 10)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Save templates'),
          ),
        ],
      );
}

class DocumentTemplateEditorDialog extends StatefulWidget {
  const DocumentTemplateEditorDialog({super.key, required this.template});

  final StudioDocumentTemplate template;

  @override
  State<DocumentTemplateEditorDialog> createState() =>
      _DocumentTemplateEditorDialogState();
}

class _DocumentTemplateEditorDialogState
    extends State<DocumentTemplateEditorDialog> {
  static const _colors = <int>[
    0xFFB77C56,
    0xFF24332D,
    0xFF758A78,
    0xFF806A83,
    0xFF9C4B3D,
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brandName;
  late final TextEditingController _introduction;
  late final TextEditingController _terms;
  late final TextEditingController _footer;
  late List<String> _sectionOrder;
  late int _accentColor;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template.name);
    _brandName = TextEditingController(text: widget.template.brandName);
    _introduction =
        TextEditingController(text: widget.template.introduction);
    _terms = TextEditingController(text: widget.template.terms);
    _footer = TextEditingController(text: widget.template.footer);
    _sectionOrder = List.of(widget.template.sectionOrder);
    _accentColor = _colors.contains(widget.template.accentColor)
        ? widget.template.accentColor
        : _colors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _brandName.dispose();
    _introduction.dispose();
    _terms.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _moveSection(int index, int offset) {
    final destination = index + offset;
    if (destination < 0 || destination >= _sectionOrder.length) return;
    setState(() {
      final item = _sectionOrder.removeAt(index);
      _sectionOrder.insert(destination, item);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.template.copyWith(
        name: _name.text.trim(),
        brandName: _brandName.text.trim(),
        introduction: _introduction.text.trim(),
        terms: _terms.text.trim(),
        footer: _footer.text.trim(),
        accentColor: _accentColor,
        sectionOrder: _sectionOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        scrollable: true,
        title: Text(widget.template.name.isEmpty
            ? 'Create document template'
            : 'Design ${widget.template.name}'),
        content: SizedBox(
          width: 540,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 80,
                  decoration:
                      const InputDecoration(labelText: 'Template name *'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter a template name.'
                          : null,
                ),
                TextField(
                  controller: _brandName,
                  maxLength: 120,
                  decoration: const InputDecoration(
                      labelText: 'Brand name',
                      helperText: 'Leave blank to use the current studio name.'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _accentColor,
                  decoration:
                      const InputDecoration(labelText: 'Accent color'),
                  items: _colors
                      .map((color) => DropdownMenuItem(
                            value: color,
                            child: Row(children: [
                              CircleAvatar(
                                  radius: 9, backgroundColor: Color(color)),
                              const SizedBox(width: 8),
                              Text('#${(color & 0xFFFFFF).toRadixString(16)}'),
                            ]),
                          ))
                      .toList(),
                  onChanged: (color) {
                    if (color != null) setState(() => _accentColor = color);
                  },
                ),
                TextField(
                  controller: _introduction,
                  maxLength: 1500,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Introduction'),
                ),
                TextField(
                  controller: _terms,
                  maxLength: 3000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Terms'),
                ),
                TextField(
                  controller: _footer,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Footer'),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 4),
                    child: Text('PROPOSAL SECTION ORDER',
                        style: TextStyle(
                            fontFamily: 'Arial',
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                  ),
                ),
                ..._sectionOrder.indexed.map((entry) {
                  final index = entry.$1;
                  final section = entry.$2;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        StudioDocumentTemplate.sectionLabels[section] ??
                            section),
                    leading: const Icon(Icons.drag_handle, size: 18),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Move section up',
                          onPressed:
                              index == 0 ? null : () => _moveSection(index, -1),
                          icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Move section down',
                          onPressed: index == _sectionOrder.length - 1
                              ? null
                              : () => _moveSection(index, 1),
                          icon:
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Save template'),
          ),
        ],
      );
}

class ProposalDraft {
  const ProposalDraft({
    required this.title,
    required this.templateId,
    required this.introduction,
    required this.terms,
  });

  final String title;
  final String templateId;
  final String introduction;
  final String terms;
}

class ProposalGenerationDialog extends StatefulWidget {
  const ProposalGenerationDialog({
    super.key,
    required this.quotation,
    required this.templates,
    required this.defaultTerms,
  });

  final StudioQuotation quotation;
  final List<StudioDocumentTemplate> templates;
  final String defaultTerms;

  @override
  State<ProposalGenerationDialog> createState() =>
      _ProposalGenerationDialogState();
}

class _ProposalGenerationDialogState extends State<ProposalGenerationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _introduction;
  late final TextEditingController _terms;
  late String _templateId;

  StudioDocumentTemplate get _template => widget.templates.firstWhere(
        (template) => template.id == _templateId,
        orElse: () => widget.templates.first,
      );

  @override
  void initState() {
    super.initState();
    _templateId = widget.templates.first.id;
    final template = widget.templates.first;
    _title = TextEditingController(text: widget.quotation.title);
    _introduction = TextEditingController(text: template.introduction);
    _terms = TextEditingController(
        text: template.terms.isEmpty ? widget.defaultTerms : template.terms);
  }

  @override
  void dispose() {
    _title.dispose();
    _introduction.dispose();
    _terms.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ProposalDraft(
        title: _title.text.trim(),
        templateId: _templateId,
        introduction: _introduction.text.trim(),
        terms: _terms.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        scrollable: true,
        title: const Text('Generate client proposal'),
        content: SizedBox(
          width: 470,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${widget.quotation.number} · ${widget.quotation.clientName} · ${_formatCurrencyAmount(widget.quotation.total, widget.quotation.currencySymbol)}',
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 10)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration:
                      const InputDecoration(labelText: 'Proposal title *'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter a proposal title.'
                          : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _templateId,
                  decoration:
                      const InputDecoration(labelText: 'Document template'),
                  items: widget.templates
                      .map((template) => DropdownMenuItem(
                          value: template.id, child: Text(template.name)))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _templateId = id;
                      _introduction.text = _template.introduction;
                      _terms.text = _template.terms.isEmpty
                          ? widget.defaultTerms
                          : _template.terms;
                    });
                  },
                ),
                TextField(
                  controller: _introduction,
                  maxLength: 1500,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Project introduction'),
                ),
                TextField(
                  controller: _terms,
                  maxLength: 3000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Proposal terms'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Generate proposal'),
          ),
        ],
      );
}

class ProposalSettingsDialog extends StatefulWidget {
  const ProposalSettingsDialog({super.key, required this.settings});

  final StudioFinancialSettings settings;

  @override
  State<ProposalSettingsDialog> createState() =>
      _ProposalSettingsDialogState();
}

class _ProposalSettingsDialogState extends State<ProposalSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quotationPrefix;
  late final TextEditingController _nextQuotation;
  late final TextEditingController _proposalPrefix;
  late final TextEditingController _nextProposal;
  late final TextEditingController _invoicePrefix;
  late final TextEditingController _nextInvoice;
  late final TextEditingController _currency;
  late final TextEditingController _taxRate;
  late final TextEditingController _terms;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _quotationPrefix = TextEditingController(text: settings.quotationPrefix);
    _nextQuotation =
        TextEditingController(text: '${settings.nextQuotationNumber}');
    _proposalPrefix = TextEditingController(text: settings.proposalPrefix);
    _nextProposal = TextEditingController(text: '${settings.nextProposalNumber}');
    _invoicePrefix = TextEditingController(text: settings.invoicePrefix);
    _nextInvoice = TextEditingController(text: '${settings.nextInvoiceNumber}');
    _currency = TextEditingController(text: settings.currencySymbol);
    _taxRate = TextEditingController(text: settings.defaultTaxRate.toString());
    _terms = TextEditingController(text: settings.defaultTerms);
  }

  @override
  void dispose() {
    _quotationPrefix.dispose();
    _nextQuotation.dispose();
    _proposalPrefix.dispose();
    _nextProposal.dispose();
    _invoicePrefix.dispose();
    _nextInvoice.dispose();
    _currency.dispose();
    _taxRate.dispose();
    _terms.dispose();
    super.dispose();
  }

  String? _validatePrefix(String? value) =>
      value == null || value.trim().isEmpty || value.trim().length > 12
          ? 'Use a prefix of 1–12 characters.'
          : null;

  String? _validateSequence(String? value) {
    final sequence = int.tryParse(value?.trim() ?? '');
    return sequence == null || sequence < 1
        ? 'Enter a positive next number.'
        : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StudioFinancialSettings(
        quotationPrefix: _quotationPrefix.text.trim(),
        nextQuotationNumber: int.parse(_nextQuotation.text.trim()),
        proposalPrefix: _proposalPrefix.text.trim(),
        nextProposalNumber: int.parse(_nextProposal.text.trim()),
        invoicePrefix: _invoicePrefix.text.trim(),
        nextInvoiceNumber: int.parse(_nextInvoice.text.trim()),
        currencySymbol: _currency.text.trim(),
        defaultTaxRate: double.parse(_taxRate.text.trim()),
        defaultTerms: _terms.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        scrollable: true,
        title: const Text('Proposal & invoice settings'),
        content: SizedBox(
          width: 490,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DOCUMENT NUMBERING',
                      style: TextStyle(
                          fontFamily: 'Arial',
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ),
                _numberingRow('Quotation', _quotationPrefix, _nextQuotation),
                _numberingRow('Proposal', _proposalPrefix, _nextProposal),
                _numberingRow('Invoice', _invoicePrefix, _nextInvoice),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _currency,
                        maxLength: 4,
                        decoration: const InputDecoration(
                            labelText: 'Currency symbol'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a currency symbol.'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _taxRate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Default tax rate', suffixText: '%'),
                        validator: (value) {
                          final rate = double.tryParse(value?.trim() ?? '');
                          return rate == null ||
                                  !rate.isFinite ||
                                  rate < 0 ||
                                  rate > 100
                              ? 'Enter a rate from 0 to 100.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _terms,
                  maxLength: 3000,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Default terms'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Save settings'),
          ),
        ],
      );

  Widget _numberingRow(
    String label,
    TextEditingController prefix,
    TextEditingController next,
  ) =>
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: prefix,
              maxLength: 12,
              decoration: InputDecoration(labelText: '$label prefix'),
              validator: _validatePrefix,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: next,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Next $label #'),
              validator: _validateSequence,
            ),
          ),
        ],
      );
}

class InvoiceDraft {
  const InvoiceDraft({required this.dueDate, required this.memo});

  final DateTime dueDate;
  final String memo;
}

class InvoiceEditorDialog extends StatefulWidget {
  const InvoiceEditorDialog({super.key, required this.proposal});

  final StudioProposal proposal;

  @override
  State<InvoiceEditorDialog> createState() => _InvoiceEditorDialogState();
}

class _InvoiceEditorDialogState extends State<InvoiceEditorDialog> {
  final _memo = TextEditingController();
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Prepare invoice'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.proposal.number} · ${widget.proposal.clientName}',
                  style: const TextStyle(
                      fontFamily: 'Arial', color: muted, fontSize: 10)),
              const SizedBox(height: 8),
              Text(
                  'Invoice total · ${_formatCurrencyAmount(widget.proposal.total, widget.proposal.currencySymbol)}',
                  style: const TextStyle(
                      fontFamily: 'Arial',
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(_dueDate),
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 10)),
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
              TextField(
                controller: _memo,
                maxLength: 500,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Invoice note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: () => Navigator.pop(
              context,
              InvoiceDraft(dueDate: _dueDate, memo: _memo.text.trim()),
            ),
            child: const Text('Prepare draft'),
          ),
        ],
      );
}

class InvoicePaymentDialog extends StatefulWidget {
  const InvoicePaymentDialog({super.key, required this.invoice});

  final StudioInvoice invoice;

  @override
  State<InvoicePaymentDialog> createState() => _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends State<InvoicePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, double.parse(_amount.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: Text('Record payment · ${widget.invoice.number}'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Remaining balance: ${_formatCurrencyAmount(widget.invoice.balance, widget.invoice.currencySymbol)}',
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 11)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Payment received *',
                      prefixText: '${widget.invoice.currencySymbol} '),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null ||
                            !amount.isFinite ||
                            amount <= 0 ||
                            !RegExp(r'^\d+(\.\d{1,2})?$')
                                .hasMatch(value?.trim() ?? '') ||
                            amount > widget.invoice.balance
                        ? 'Enter an amount above zero and no more than the balance.'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: _save,
            child: const Text('Record payment'),
          ),
        ],
      );
}

class ProposalPreviewDialog extends StatelessWidget {
  const ProposalPreviewDialog({
    super.key,
    required this.proposal,
    required this.onExport,
  });

  final StudioProposal proposal;
  final VoidCallback onExport;

  Widget _section(String section, BuildContext context) {
    switch (section) {
      case 'cover':
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(proposal.brandName.toUpperCase(),
                  style: TextStyle(
                      fontFamily: 'Arial',
                      color: Color(proposal.accentColor),
                      letterSpacing: 1.4,
                      fontSize: 9)),
              const SizedBox(height: 10),
              Text(proposal.title,
                  style: const TextStyle(
                      color: ink, fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                  '${proposal.number} · ${proposal.projectName} · Prepared for ${proposal.clientName}',
                  style: const TextStyle(
                      fontFamily: 'Arial', color: muted, fontSize: 10)),
            ],
          ),
        );
      case 'overview':
        final overview = <Widget>[
          Text(proposal.introduction,
              style: const TextStyle(
                  fontFamily: 'Arial', color: ink, fontSize: 11, height: 1.5)),
          if (proposal.designStyle.isNotEmpty)
            _briefDetail('Design direction', proposal.designStyle),
          if (proposal.requirementRooms.isNotEmpty)
            _briefDetail('Spaces', proposal.requirementRooms.join(', ')),
          if (proposal.startDate != null || proposal.targetDate != null)
            _briefDetail(
                'Project timeline',
                [
                  if (proposal.startDate != null)
                    'Starts ${MaterialLocalizations.of(context).formatMediumDate(proposal.startDate!)}',
                  if (proposal.targetDate != null)
                    'Target ${MaterialLocalizations.of(context).formatMediumDate(proposal.targetDate!)}',
                ].join(' · ')),
          if (proposal.budgetMin != null || proposal.budgetMax != null)
            _briefDetail(
                'Client budget',
                '${proposal.budgetMin == null ? '—' : _formatCurrencyAmount(proposal.budgetMin!, proposal.currencySymbol)}'
                ' – '
                '${proposal.budgetMax == null ? '—' : _formatCurrencyAmount(proposal.budgetMax!, proposal.currencySymbol)}'),
          if (proposal.projectBrief.trim().isNotEmpty)
            _briefDetail('Project brief', proposal.projectBrief),
        ];
        return _proposalSection('Project overview', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: overview,
        ));
      case 'scope':
        return _proposalSection(
          'Scope of work',
          Column(
            children: proposal.items
                .map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.description,
                          style: const TextStyle(
                              fontFamily: 'Arial',
                              color: ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${item.quantity} ${item.unit} × ${_formatCurrencyAmount(item.unitRate, proposal.currencySymbol)}',
                          style: const TextStyle(
                              fontFamily: 'Arial', color: muted, fontSize: 9)),
                      trailing: Text(
                          _formatCurrencyAmount(
                              item.amount, proposal.currencySymbol),
                          style: const TextStyle(
                              fontFamily: 'Arial', color: ink, fontSize: 10)),
                    ))
                .toList(),
          ),
        );
      case 'investment':
        return _proposalSection(
          'Investment',
          Column(
            children: [
              _amountRow('Subtotal', proposal.subtotal, proposal.currencySymbol),
              _amountRow('Tax (${proposal.taxRate.toStringAsFixed(2)}%)',
                  proposal.taxAmount, proposal.currencySymbol),
              const Divider(color: line),
              _amountRow('Total', proposal.total, proposal.currencySymbol,
                  strong: true),
            ],
          ),
        );
      case 'terms':
        return _proposalSection(
          'Terms',
          Text(proposal.terms,
              style: const TextStyle(
                  fontFamily: 'Arial', color: muted, fontSize: 10, height: 1.5)),
        );
      case 'footer':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(proposal.footer,
              style: const TextStyle(
                  fontFamily: 'Arial', color: muted, fontSize: 9)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _briefDetail(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontFamily: 'Arial', color: ink, fontSize: 10, height: 1.45),
            children: [
              TextSpan(
                  text: '$label  ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Widget _proposalSection(String title, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: ink, fontSize: 14, fontWeight: FontWeight.w600)),
            const Divider(color: line),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: const Text('Proposal preview'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: proposal.sectionOrder
                  .map((section) => _section(section, context))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export HTML'),
          ),
        ],
      );
}

Widget _amountRow(
  String label,
  double amount,
  String currencySymbol, {
  bool strong = false,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Arial',
                    color: strong ? ink : muted,
                    fontSize: 10,
                    fontWeight:
                        strong ? FontWeight.w700 : FontWeight.w400)),
          ),
          Text(_formatCurrencyAmount(amount, currencySymbol),
              style: TextStyle(
                  fontFamily: 'Arial',
                  color: ink,
                  fontSize: 10,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );

class InvoicePreviewDialog extends StatelessWidget {
  const InvoicePreviewDialog({
    super.key,
    required this.invoice,
    required this.onExport,
  });

  final StudioInvoice invoice;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: paper,
        title: Text('Invoice ${invoice.number}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.clientName,
                    style: const TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text(invoice.clientEmail,
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 10)),
                const SizedBox(height: 10),
                Text('${invoice.projectName} · ${invoice.title}',
                    style: const TextStyle(
                        fontFamily: 'Arial', color: ink, fontSize: 11)),
                Text(
                    'Issued ${MaterialLocalizations.of(context).formatMediumDate(invoice.issuedAt)} · Due ${MaterialLocalizations.of(context).formatMediumDate(invoice.dueDate)} · ${invoice.status}',
                    style: const TextStyle(
                        fontFamily: 'Arial', color: muted, fontSize: 9)),
                const Divider(height: 24, color: line),
                ...invoice.items.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.description,
                          style: const TextStyle(
                              fontFamily: 'Arial', color: ink, fontSize: 10)),
                      subtitle: Text(
                          '${item.quantity} ${item.unit} × ${_formatCurrencyAmount(item.unitRate, invoice.currencySymbol)}',
                          style: const TextStyle(
                              fontFamily: 'Arial', color: muted, fontSize: 9)),
                      trailing: Text(
                          _formatCurrencyAmount(
                              item.amount, invoice.currencySymbol),
                          style: const TextStyle(
                              fontFamily: 'Arial', color: ink, fontSize: 10)),
                    )),
                const Divider(height: 20, color: line),
                _amountRow('Subtotal', invoice.subtotal, invoice.currencySymbol),
                _amountRow('Tax (${invoice.taxRate.toStringAsFixed(2)}%)',
                    invoice.taxAmount, invoice.currencySymbol),
                _amountRow('Invoice total', invoice.total,
                    invoice.currencySymbol,
                    strong: true),
                _amountRow('Paid', invoice.paidAmount, invoice.currencySymbol),
                _amountRow('Balance due', invoice.balance,
                    invoice.currencySymbol,
                    strong: true),
                if (invoice.memo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(invoice.memo,
                      style: const TextStyle(
                          fontFamily: 'Arial',
                          color: muted,
                          fontSize: 10,
                          height: 1.5)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ink),
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export HTML'),
          ),
        ],
      );
}
