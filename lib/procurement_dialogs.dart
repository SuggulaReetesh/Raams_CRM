part of 'main.dart';

class SimpleMultiPromptDialog extends StatefulWidget {
  const SimpleMultiPromptDialog({
    required this.title,
    required this.fields,
    super.key,
  });

  final String title;
  final List<String> fields;

  @override
  State<SimpleMultiPromptDialog> createState() =>
      _SimpleMultiPromptDialogState();
}

class _SimpleMultiPromptDialogState extends State<SimpleMultiPromptDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields) field: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.fields) ...[
              TextField(
                controller: _controllers[field],
                decoration: InputDecoration(labelText: field),
                maxLines:
                    field.contains('summary') ||
                        field.contains('notes') ||
                        field.contains('Scope') ||
                        field.contains('findings')
                    ? 3
                    : 1,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop({
          for (final field in widget.fields)
            field: _controllers[field]!.text.trim(),
        }),
        child: const Text('Save'),
      ),
    ],
  );
}

class RequisitionEditorDialog extends StatefulWidget {
  const RequisitionEditorDialog({
    required this.projectId,
    required this.materials,
    super.key,
  });

  final String projectId;
  final List<StudioMaterial> materials;

  @override
  State<RequisitionEditorDialog> createState() =>
      _RequisitionEditorDialogState();
}

class _RequisitionEditorDialogState extends State<RequisitionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String? _materialId;

  @override
  void initState() {
    super.initState();
    _materialId = widget.materials.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final material = widget.materials.firstWhere(
      (item) => item.id == _materialId,
    );
    final quantityMilli = (double.parse(_quantity.text.trim()) * 1000).round();
    final id = 'requisition-${DateTime.now().microsecondsSinceEpoch}';
    Navigator.of(context).pop(
      StudioMaterialRequisition(
        id: id,
        projectId: widget.projectId,
        title: _title.text.trim(),
        requiredBy: null,
        notes: _notes.text.trim(),
        status: 'Draft',
        items: [
          StudioRequisitionLine(
            id: '$id-line-1',
            materialId: material.id,
            name: material.name,
            unit: material.unit,
            quantityMilli: quantityMilli,
            specification: material.specification,
          ),
        ],
        approvalSteps: const [],
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New material requisition'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Request title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _materialId,
                decoration: const InputDecoration(labelText: 'Material'),
                items: widget.materials
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.name} · ${item.unit}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _materialId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  helperText: 'Up to three decimal places.',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final number = double.tryParse(value?.trim() ?? '');
                  if (number == null ||
                      !number.isFinite ||
                      number <= 0 ||
                      number > 1000000) {
                    return 'Enter a quantity greater than zero.';
                  }
                  if ((number * 1000).round() < 1) {
                    return 'Quantity is too small.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save draft')),
    ],
  );
}

class RequestForQuotationEditorDialog extends StatefulWidget {
  const RequestForQuotationEditorDialog({
    required this.projectId,
    required this.requisitions,
    required this.vendors,
    super.key,
  });

  final String projectId;
  final List<StudioMaterialRequisition> requisitions;
  final List<StudioVendor> vendors;

  @override
  State<RequestForQuotationEditorDialog> createState() =>
      _RequestForQuotationEditorDialogState();
}

class _RequestForQuotationEditorDialogState
    extends State<RequestForQuotationEditorDialog> {
  final _notes = TextEditingController();
  final Set<String> _vendorIds = {};
  String? _requisitionId;

  @override
  void initState() {
    super.initState();
    _requisitionId = widget.requisitions.first.id;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final requisitionId = _requisitionId;
    if (requisitionId == null || _vendorIds.isEmpty) return;
    Navigator.of(context).pop(
      StudioRequestForQuotation(
        id: 'rfq-${DateTime.now().microsecondsSinceEpoch}',
        projectId: widget.projectId,
        requisitionId: requisitionId,
        vendorIds: _vendorIds.toList()..sort(),
        quoteDueAt: null,
        notes: _notes.text.trim(),
        status: 'Draft',
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New vendor request for quotation'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _requisitionId,
              decoration: const InputDecoration(
                labelText: 'Approved requisition',
              ),
              items: widget.requisitions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _requisitionId = value),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Invite vendors',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...widget.vendors.map(
              (vendor) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(vendor.name),
                value: _vendorIds.contains(vendor.id),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _vendorIds.add(vendor.id);
                  } else {
                    _vendorIds.remove(vendor.id);
                  }
                }),
              ),
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _vendorIds.isEmpty ? null : _save,
        child: const Text('Save draft'),
      ),
    ],
  );
}

class VendorQuoteEditorDialog extends StatefulWidget {
  const VendorQuoteEditorDialog({
    required this.projectId,
    required this.rfqs,
    required this.requisitions,
    required this.vendors,
    super.key,
  });

  final String projectId;
  final List<StudioRequestForQuotation> rfqs;
  final List<StudioMaterialRequisition> requisitions;
  final List<StudioVendor> vendors;

  @override
  State<VendorQuoteEditorDialog> createState() =>
      _VendorQuoteEditorDialogState();
}

class _VendorQuoteEditorDialogState extends State<VendorQuoteEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currency = TextEditingController(text: 'USD');
  final _terms = TextEditingController();
  final _deliveryDays = TextEditingController();
  final Map<String, TextEditingController> _prices = {};
  String? _rfqId;
  String? _vendorId;

  StudioRequestForQuotation? get _rfq =>
      widget.rfqs.where((item) => item.id == _rfqId).firstOrNull;

  StudioMaterialRequisition? get _requisition => widget.requisitions
      .where((item) => item.id == _rfq?.requisitionId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _rfqId = widget.rfqs.first.id;
    _vendorId = widget.rfqs.first.vendorIds.firstOrNull;
    _ensurePriceFields();
  }

  void _ensurePriceFields() {
    for (final line in _requisition?.items ?? const <StudioRequisitionLine>[]) {
      _prices.putIfAbsent(line.id, () => TextEditingController());
    }
  }

  @override
  void dispose() {
    _currency.dispose();
    _terms.dispose();
    _deliveryDays.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null || !price.isFinite || price < 0 || price > 10000000000) {
      return 'Enter a valid non-negative price.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final rfq = _rfq;
    final requisition = _requisition;
    final vendorId = _vendorId;
    if (rfq == null ||
        requisition == null ||
        vendorId == null ||
        !rfq.vendorIds.contains(vendorId)) {
      return;
    }
    final items = requisition.items
        .map(
          (line) => StudioVendorQuoteLine(
            requisitionLineId: line.id,
            unitPriceMinor: (double.parse(_prices[line.id]!.text.trim()) * 100)
                .round(),
          ),
        )
        .toList();
    final totalMinor = items.fold<int>(0, (total, item) {
      final line = requisition.items.firstWhere(
        (requestLine) => requestLine.id == item.requisitionLineId,
      );
      return total +
          ((line.quantityMilli * item.unitPriceMinor) / 1000).round();
    });
    final currency = _currency.text.trim().toUpperCase();
    if (totalMinor <= 0 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) return;
    final deliveryDays = int.tryParse(_deliveryDays.text.trim());
    if (_deliveryDays.text.trim().isNotEmpty &&
        (deliveryDays == null || deliveryDays < 0 || deliveryDays > 3650)) {
      return;
    }
    Navigator.of(context).pop(
      StudioVendorQuote(
        id: 'quote-${DateTime.now().microsecondsSinceEpoch}',
        projectId: widget.projectId,
        rfqId: rfq.id,
        vendorId: vendorId,
        currency: currency,
        items: items,
        totalMinor: totalMinor,
        validUntil: null,
        deliveryDays: deliveryDays,
        terms: _terms.text.trim(),
        status: 'Submitted',
        submittedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensurePriceFields();
    final rfq = _rfq;
    return AlertDialog(
      title: const Text('Record vendor quote'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _rfqId,
                  decoration: const InputDecoration(labelText: 'Issued RFQ'),
                  items: widget.rfqs
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            widget.requisitions
                                    .where(
                                      (request) =>
                                          request.id == item.requisitionId,
                                    )
                                    .firstOrNull
                                    ?.title ??
                                item.id,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _rfqId = value;
                    _vendorId = _rfq?.vendorIds.firstOrNull;
                    _ensurePriceFields();
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _vendorId,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: (rfq?.vendorIds ?? const <String>[]).map((id) {
                    final name =
                        widget.vendors
                            .where((vendor) => vendor.id == id)
                            .firstOrNull
                            ?.name ??
                        id;
                    return DropdownMenuItem(value: id, child: Text(name));
                  }).toList(),
                  onChanged: (value) => setState(() => _vendorId = value),
                ),
                const SizedBox(height: 12),
                for (final line
                    in _requisition?.items ?? const <StudioRequisitionLine>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: _prices[line.id],
                      decoration: InputDecoration(
                        labelText: '${line.name} (${line.unit}) unit price',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validatePrice,
                    ),
                  ),
                TextFormField(
                  controller: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency code',
                    helperText: 'Three-letter ISO currency code.',
                  ),
                  validator: (value) =>
                      RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a three-letter currency code.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _deliveryDays,
                  decoration: const InputDecoration(
                    labelText: 'Delivery days (optional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _terms,
                  decoration: const InputDecoration(labelText: 'Terms'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Record quote')),
      ],
    );
  }
}

class PurchaseOrderEditorDialog extends StatefulWidget {
  const PurchaseOrderEditorDialog({
    required this.projectId,
    required this.quotes,
    required this.rfqs,
    required this.requisitions,
    super.key,
  });

  final String projectId;
  final List<StudioVendorQuote> quotes;
  final List<StudioRequestForQuotation> rfqs;
  final List<StudioMaterialRequisition> requisitions;

  @override
  State<PurchaseOrderEditorDialog> createState() =>
      _PurchaseOrderEditorDialogState();
}

class _PurchaseOrderEditorDialogState extends State<PurchaseOrderEditorDialog> {
  final _notes = TextEditingController();
  String? _quoteId;

  StudioVendorQuote? get _quote =>
      widget.quotes.where((item) => item.id == _quoteId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _quoteId = widget.quotes.first.id;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final quote = _quote;
    if (quote == null) return;
    final rfq = widget.rfqs.where((item) => item.id == quote.rfqId).firstOrNull;
    final requisition = widget.requisitions
        .where((item) => item.id == rfq?.requisitionId)
        .firstOrNull;
    if (rfq == null || requisition == null) return;
    final id = 'po-${DateTime.now().microsecondsSinceEpoch}';
    final lines = quote.items.map((quoteLine) {
      final requestLine = requisition.items.firstWhere(
        (line) => line.id == quoteLine.requisitionLineId,
      );
      final lineTotal =
          ((requestLine.quantityMilli * quoteLine.unitPriceMinor) / 1000)
              .round();
      return StudioPurchaseOrderLine(
        requisitionLineId: requestLine.id,
        description: requestLine.name,
        unit: requestLine.unit,
        quantityMilli: requestLine.quantityMilli,
        unitPriceMinor: quoteLine.unitPriceMinor,
        lineTotalMinor: lineTotal,
      );
    }).toList();
    Navigator.of(context).pop(
      StudioPurchaseOrder(
        id: id,
        projectId: widget.projectId,
        requisitionId: requisition.id,
        rfqId: rfq.id,
        quoteId: quote.id,
        vendorId: quote.vendorId,
        currency: quote.currency,
        items: lines,
        totalMinor: lines.fold<int>(
          0,
          (total, line) => total + line.lineTotalMinor,
        ),
        notes: _notes.text.trim(),
        status: 'Draft',
        approvalSteps: const [],
        createdAt: DateTime.now().toUtc(),
        issuedAt: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New purchase order'),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _quoteId,
            decoration: const InputDecoration(labelText: 'Selected quote'),
            items: widget.quotes
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.vendorId} · ${item.currency} ${(item.totalMinor / 100).toStringAsFixed(2)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _quoteId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Order notes'),
            maxLines: 3,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save draft')),
    ],
  );
}

class ProcurementApprovalPolicyDialog extends StatefulWidget {
  const ProcurementApprovalPolicyDialog({required this.policy, super.key});

  final StudioProcurementApprovalPolicy policy;

  @override
  State<ProcurementApprovalPolicyDialog> createState() =>
      _ProcurementApprovalPolicyDialogState();
}

class _ProcurementApprovalPolicyDialogState
    extends State<ProcurementApprovalPolicyDialog> {
  late final Set<String> _requisitionPermissions = Set<String>.of(
    widget.policy.requisitionPermissions,
  );
  late final Set<String> _purchaseOrderPermissions = Set<String>.of(
    widget.policy.purchaseOrderPermissions,
  );

  void _save() {
    if (_requisitionPermissions.isEmpty || _purchaseOrderPermissions.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      StudioProcurementApprovalPolicy(
        requisitionPermissions: _requisitionPermissions.toList(),
        purchaseOrderPermissions: _purchaseOrderPermissions.toList(),
      ),
    );
  }

  Widget _permissionOptions(String title, Set<String> selected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Procurement approver'),
        value: selected.contains('procurement.approve'),
        onChanged: (value) => setState(() {
          if (value == true) {
            selected.add('procurement.approve');
          } else {
            selected.remove('procurement.approve');
          }
        }),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Finance manager'),
        value: selected.contains('manageFinancials'),
        onChanged: (value) => setState(() {
          if (value == true) {
            selected.add('manageFinancials');
          } else {
            selected.remove('manageFinancials');
          }
        }),
      ),
      if (selected.isEmpty)
        const Text(
          'At least one approval step is required.',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Procurement approval policy'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _permissionOptions('Requisitions', _requisitionPermissions),
            const Divider(),
            _permissionOptions('Purchase orders', _purchaseOrderPermissions),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            _requisitionPermissions.isEmpty || _purchaseOrderPermissions.isEmpty
            ? null
            : _save,
        child: const Text('Save policy'),
      ),
    ],
  );
}

class ProcurementDecisionDialog extends StatefulWidget {
  const ProcurementDecisionDialog({required this.approve, super.key});

  final bool approve;

  @override
  State<ProcurementDecisionDialog> createState() =>
      _ProcurementDecisionDialogState();
}

class _ProcurementDecisionDialogState extends State<ProcurementDecisionDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.approve ? 'Approve request?' : 'Reject request?'),
    content: SizedBox(
      width: 400,
      child: TextField(
        controller: _note,
        decoration: const InputDecoration(
          labelText: 'Decision note (optional)',
        ),
        maxLength: 500,
        maxLines: 3,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_note.text.trim()),
        child: Text(widget.approve ? 'Approve' : 'Reject'),
      ),
    ],
  );
}
