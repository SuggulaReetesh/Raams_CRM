part of 'main.dart';

class QuotationEditorPage extends StatefulWidget {
  const QuotationEditorPage({
    super.key,
    required this.quotation,
    this.catalog = const [],
  });

  final StudioQuotation quotation;
  final List<StudioLineItemCatalogEntry> catalog;

  @override
  State<QuotationEditorPage> createState() => _QuotationEditorPageState();
}

class _QuotationEditorPageState extends State<QuotationEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _title;
  late final TextEditingController _taxRate;
  late final TextEditingController _catalogSearch;
  late final List<_QuotationLineDraft> _lines;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _title = TextEditingController(text: widget.quotation.title);
    _catalogSearch = TextEditingController();
    _taxRate = TextEditingController(
      text: widget.quotation.taxRate.toStringAsFixed(2),
    );
    _lines = widget.quotation.items.map(_QuotationLineDraft.fromLine).toList();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _title.dispose();
    _taxRate.dispose();
    _catalogSearch.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      _lines.fold<double>(0, (total, line) => total + line.amount);

  double get _parsedTaxRate => double.tryParse(_taxRate.text.trim()) ?? 0;

  double get _total =>
      (_subtotal * (1 + _parsedTaxRate / 100) * 100).round() / 100;

  void _lineChanged(String _) {
    setState(() => _error = null);
  }

  void _addLine() {
    setState(() {
      _error = null;
      _lines.add(
        _QuotationLineDraft.empty(
          'quote-line-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
    });
  }

  void _addCatalogItem(StudioLineItemCatalogEntry? entry) {
    if (entry == null) {
      setState(
        () => _error = 'This starter item is not available in the catalog.',
      );
      return;
    }
    final rate = entry.rateForQuality('Basic');
    if (rate == null) {
      setState(
        () => _error =
            'Set a Basic rate for ${entry.name} in the workspace Line item catalog first.',
      );
      return;
    }
    setState(() {
      _error = null;
      _lines.add(
        _QuotationLineDraft.fromCatalog(
          entry,
          'quote-line-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
    });
  }

  void _removeLine(_QuotationLineDraft line) {
    setState(() {
      line.dispose();
      _lines.remove(line);
      _error = null;
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter a quotation title in the Details tab.';
        _tabs.animateTo(0);
      });
      return;
    }
    final taxRate = double.tryParse(_taxRate.text.trim());
    if (taxRate == null || !taxRate.isFinite || taxRate < 0 || taxRate > 100) {
      setState(() {
        _error = 'Enter a tax rate from 0 to 100 in the Review tab.';
        _tabs.animateTo(2);
      });
      return;
    }
    if (_lines.isEmpty) {
      setState(() {
        _error = 'Add at least one line item before saving.';
        _tabs.animateTo(1);
      });
      return;
    }

    final items = <StudioQuoteLine>[];
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final validationError = line.validationError;
      if (validationError != null) {
        setState(() {
          _error = 'Line ${index + 1}: $validationError';
          _tabs.animateTo(1);
        });
        return;
      }
      items.add(line.toQuoteLine());
    }

    Navigator.of(context).pop(
      widget.quotation.copyWith(
        title: _title.text.trim(),
        items: items,
        taxRate: taxRate,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.quotation.items.isEmpty ? 'New quotation' : 'Edit quotation',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Text(
            '${widget.quotation.number} · ${widget.quotation.projectName}',
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
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        indicatorColor: accent,
        labelColor: ink,
        unselectedLabelColor: muted,
        tabs: [
          const Tab(text: 'Details'),
          Tab(text: 'Line items (${_lines.length})'),
          const Tab(text: 'Review & totals'),
        ],
      ),
    ),
    body: Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9EAE6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: Color(0xFF9C4B3D),
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_detailsTab(), _lineItemsTab(), _reviewTab()],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        decoration: const BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Estimated total',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _formatCurrencyAmount(
                      _total,
                      widget.quotation.currencySymbol,
                    ),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ink),
              onPressed: _save,
              child: const Text('Save quotation'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detailsTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Quotation details',
        style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'Confirm the project and give this quotation a clear title.',
        style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 12),
      ),
      const SizedBox(height: 18),
      _infoCard(
        children: [
          _detailRow('Quotation number', widget.quotation.number),
          _detailRow('Project', widget.quotation.projectName),
          _detailRow('Client', widget.quotation.clientName),
          if (widget.quotation.clientEmail.isNotEmpty)
            _detailRow('Client email', widget.quotation.clientEmail),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _title,
        maxLength: 120,
        onChanged: _lineChanged,
        decoration: const InputDecoration(
          labelText: 'Quotation title *',
          hintText: 'For example, Kitchen cabinetry and installation',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _lineItemsTab() {
    final activeCatalog = widget.catalog
        .where((entry) => entry.active)
        .toList(growable: false);
    final query = _catalogSearch.text.trim().toLowerCase();
    final searchResults = query.isEmpty
        ? const <StudioLineItemCatalogEntry>[]
        : activeCatalog
              .where((entry) => entry.name.toLowerCase().contains(query))
              .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build the bill of quantities',
                    style: TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Search your workspace catalog or edit each line in the table. Dimensions are in millimeters.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Add custom line'),
              style: FilledButton.styleFrom(backgroundColor: ink),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _catalogSearch,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Search workspace line items',
            hintText: 'Try wardrobe, kitchen cabinet, or TV unit',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _catalogSearch.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _catalogSearch.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Quick add · common items',
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final starter in StudioLineItemCatalogEntry.starterItems)
              ActionChip(
                avatar: const Icon(Icons.add, size: 15),
                label: Text(starter.name),
                onPressed: () {
                  final entry = _catalogEntryById(starter.id);
                  _addCatalogItem(entry?.active == true ? entry : null);
                },
              ),
          ],
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (searchResults.isEmpty)
            const Text(
              'No active catalog items match that search.',
              style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 12),
            )
          else
            _infoCard(
              children: [
                for (final entry in searchResults)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.name),
                    subtitle: Text(_catalogRateSummary(entry)),
                    trailing: IconButton(
                      tooltip: 'Add ${entry.name} at the Basic rate',
                      onPressed: () => _addCatalogItem(entry),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 16),
        _infoCard(
          children: [
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    'No line items yet. Search the catalog or add a custom line.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 12,
                  headingRowHeight: 42,
                  dataRowMinHeight: 66,
                  dataRowMaxHeight: 76,
                  columns: const [
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Quality')),
                    DataColumn(label: Text('Length (mm)')),
                    DataColumn(label: Text('Width (mm)')),
                    DataColumn(label: Text('Area (sq ft)')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final line in _lines)
                      DataRow(
                        key: ValueKey(line.id),
                        cells: [
                          DataCell(
                            _lineField(
                              line.description,
                              'Item description',
                              width: 180,
                              maxLength: 160,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 118,
                              child: DropdownButtonFormField<String>(
                                initialValue: line.packageName,
                                isExpanded: true,
                                decoration: _cellDecoration('Quality'),
                                items: const ['Basic', 'Medium', 'Luxury'].map((
                                  quality,
                                ) {
                                  final entry = _catalogEntryById(
                                    line.catalogItemId,
                                  );
                                  final configured =
                                      line.catalogItemId == null ||
                                      entry?.rateForQuality(quality) != null;
                                  return DropdownMenuItem(
                                    value: quality,
                                    enabled: configured,
                                    child: Text(
                                      quality,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (quality) {
                                  if (quality == null) return;
                                  final entry = _catalogEntryById(
                                    line.catalogItemId,
                                  );
                                  final rate = entry?.rateForQuality(quality);
                                  if (line.catalogItemId != null &&
                                      rate == null) {
                                    setState(
                                      () => _error =
                                          '$quality pricing is not configured for ${entry?.name ?? 'this item'}.',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    line.packageName = quality;
                                    if (rate != null) {
                                      line.unitRate.text = rate.toString();
                                    }
                                    _error = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            _lineField(
                              line.lengthMm,
                              'mm',
                              width: 84,
                              numeric: true,
                            ),
                          ),
                          DataCell(
                            _lineField(
                              line.widthMm,
                              'mm',
                              width: 84,
                              numeric: true,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 86,
                              child: Text(
                                line.pricingBasis == 'area_sqft'
                                    ? line.areaSquareFeet.toStringAsFixed(2)
                                    : '—',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          DataCell(
                            _lineField(
                              line.quantity,
                              'Qty',
                              width: 76,
                              numeric: true,
                            ),
                          ),
                          DataCell(
                            _lineField(
                              line.unitRate,
                              line.pricingBasis == 'area_sqft'
                                  ? '${widget.quotation.currencySymbol}/sq ft'
                                  : 'Rate',
                              width: 112,
                              numeric: true,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 105,
                              child: Text(
                                _formatCurrencyAmount(
                                  line.amount,
                                  widget.quotation.currencySymbol,
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              tooltip: 'Remove line item',
                              onPressed: () => _removeLine(line),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Color(0xFF9C4B3D),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal  ${_formatCurrencyAmount(_subtotal, widget.quotation.currencySymbol)}',
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  StudioLineItemCatalogEntry? _catalogEntryById(String? id) {
    if (id == null) return null;
    for (final entry in widget.catalog) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  String _catalogRateSummary(StudioLineItemCatalogEntry entry) {
    String rateLabel(String quality, double? rate) => rate == null
        ? '$quality: not configured'
        : '$quality: ${_formatCurrencyAmount(rate, widget.quotation.currencySymbol)}/sq ft';
    return [
      rateLabel('Basic', entry.basicRatePerSqft),
      rateLabel('Medium', entry.mediumRatePerSqft),
      rateLabel('Luxury', entry.luxuryRatePerSqft),
    ].join(' · ');
  }

  Widget _reviewTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Review quotation',
        style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'Check the totals before saving. You can return to Line items to make changes.',
        style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 12),
      ),
      const SizedBox(height: 18),
      _infoCard(
        children: [
          _detailRow('Quotation', widget.quotation.number),
          _detailRow(
            'Title',
            _title.text.trim().isEmpty ? 'Untitled' : _title.text,
          ),
          _detailRow('Project', widget.quotation.projectName),
          _detailRow('Client', widget.quotation.clientName),
          _detailRow('Line items', '${_lines.length}'),
        ],
      ),
      const SizedBox(height: 16),
      _infoCard(
        children: [
          TextField(
            controller: _taxRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _lineChanged,
            decoration: const InputDecoration(
              labelText: 'Tax rate',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          _totalRow(
            'Subtotal',
            _formatCurrencyAmount(_subtotal, widget.quotation.currencySymbol),
          ),
          const SizedBox(height: 8),
          _totalRow(
            'Tax (${_taxRate.text.isEmpty ? '0' : _taxRate.text}%)',
            _formatCurrencyAmount(
              _subtotal * _parsedTaxRate / 100,
              widget.quotation.currencySymbol,
            ),
          ),
          const Divider(height: 24),
          _totalRow(
            'Total',
            _formatCurrencyAmount(_total, widget.quotation.currencySymbol),
            emphasize: true,
          ),
        ],
      ),
    ],
  );

  Widget _lineField(
    TextEditingController controller,
    String hint, {
    required double width,
    bool numeric = false,
    int? maxLength,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: _lineChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _cellDecoration(hint),
    ),
  );

  InputDecoration _cellDecoration(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: line),
    ),
  );

  Widget _infoCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: muted,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _totalRow(String label, String value, {bool emphasize = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Arial',
            color: emphasize ? ink : muted,
            fontSize: emphasize ? 14 : 12,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: ink,
          fontSize: emphasize ? 18 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QuotationLineDraft {
  _QuotationLineDraft.empty(this.id)
    : description = TextEditingController(),
      lengthMm = TextEditingController(),
      heightMm = TextEditingController(),
      widthMm = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'sq ft'),
      unitRate = TextEditingController(text: '0'),
      packageName = 'Basic',
      catalogItemId = null,
      pricingBasis = 'area_sqft';

  _QuotationLineDraft.fromCatalog(StudioLineItemCatalogEntry entry, this.id)
    : description = TextEditingController(text: entry.name),
      lengthMm = TextEditingController(),
      heightMm = TextEditingController(),
      widthMm = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'sq ft'),
      unitRate = TextEditingController(
        text: entry.basicRatePerSqft!.toString(),
      ),
      packageName = 'Basic',
      catalogItemId = entry.id,
      pricingBasis = 'area_sqft';

  _QuotationLineDraft.fromLine(StudioQuoteLine line)
    : id = line.id,
      description = TextEditingController(text: line.description),
      lengthMm = TextEditingController(text: line.lengthMm?.toString() ?? ''),
      heightMm = TextEditingController(text: line.heightMm?.toString() ?? ''),
      widthMm = TextEditingController(text: line.widthMm?.toString() ?? ''),
      quantity = TextEditingController(text: line.quantity.toString()),
      unit = TextEditingController(text: line.unit),
      unitRate = TextEditingController(text: line.unitRate.toString()),
      packageName = line.packageName ?? 'Basic',
      catalogItemId = line.catalogItemId,
      pricingBasis = line.pricingBasis;

  final String id;
  final TextEditingController description;
  final TextEditingController lengthMm;
  final TextEditingController heightMm;
  final TextEditingController widthMm;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitRate;
  String packageName;
  final String? catalogItemId;
  final String pricingBasis;

  double get areaSquareFeet {
    final lengthValue = double.tryParse(lengthMm.text.trim());
    final widthValue = double.tryParse(widthMm.text.trim());
    if (lengthValue == null ||
        widthValue == null ||
        !lengthValue.isFinite ||
        !widthValue.isFinite) {
      return 0;
    }
    return lengthValue * widthValue / 92903.04;
  }

  double get amount {
    final quantityValue = double.tryParse(quantity.text.trim());
    final rateValue = double.tryParse(unitRate.text.trim());
    if (quantityValue == null ||
        rateValue == null ||
        !quantityValue.isFinite ||
        !rateValue.isFinite) {
      return 0;
    }
    final billableQuantity = pricingBasis == 'area_sqft'
        ? quantityValue * areaSquareFeet
        : quantityValue;
    return (billableQuantity * rateValue * 100).round() / 100;
  }

  String? get validationError {
    if (description.text.trim().isEmpty) return 'enter a description.';
    final quantityValue = double.tryParse(quantity.text.trim());
    if (quantityValue == null ||
        !quantityValue.isFinite ||
        quantityValue <= 0) {
      return 'enter a quantity above zero.';
    }
    if (unit.text.trim().isEmpty) return 'enter a unit.';
    final rateValue = double.tryParse(unitRate.text.trim());
    if (rateValue == null || !rateValue.isFinite || rateValue < 0) {
      return 'enter a non-negative rate.';
    }
    if (pricingBasis == 'area_sqft' &&
        (lengthMm.text.trim().isEmpty || widthMm.text.trim().isEmpty)) {
      return 'enter both length and width for square-foot pricing.';
    }
    for (final dimension in [
      ('length', lengthMm),
      ('height', heightMm),
      ('width', widthMm),
    ]) {
      final value = dimension.$2.text.trim();
      if (value.isEmpty) continue;
      final parsed = double.tryParse(value);
      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        return 'enter a positive ${dimension.$1} or leave it blank.';
      }
    }
    return null;
  }

  StudioQuoteLine toQuoteLine() => StudioQuoteLine(
    id: id,
    description: description.text.trim(),
    quantity: double.parse(quantity.text.trim()),
    unit: unit.text.trim(),
    unitRate: double.parse(unitRate.text.trim()),
    packageName: packageName,
    catalogItemId: catalogItemId,
    pricingBasis: pricingBasis,
    lengthMm: _optionalDimension(lengthMm),
    heightMm: _optionalDimension(heightMm),
    widthMm: _optionalDimension(widthMm),
  );

  double? _optionalDimension(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.parse(value);
  }

  void dispose() {
    description.dispose();
    lengthMm.dispose();
    heightMm.dispose();
    widthMm.dispose();
    quantity.dispose();
    unit.dispose();
    unitRate.dispose();
  }
}

class LineItemCatalogPanel extends StatefulWidget {
  const LineItemCatalogPanel({
    super.key,
    required this.catalog,
    required this.currencySymbol,
    required this.canManage,
    required this.loading,
    required this.error,
    required this.onSave,
  });

  final List<StudioLineItemCatalogEntry> catalog;
  final String currencySymbol;
  final bool canManage;
  final bool loading;
  final String? error;
  final Future<bool> Function(StudioLineItemCatalogEntry entry) onSave;

  @override
  State<LineItemCatalogPanel> createState() => _LineItemCatalogPanelState();
}

class _LineItemCatalogPanelState extends State<LineItemCatalogPanel> {
  final _name = TextEditingController();
  final _basicRate = TextEditingController();
  final _mediumRate = TextEditingController();
  final _luxuryRate = TextEditingController();
  String? _formError;
  bool _adding = false;

  @override
  void dispose() {
    _name.dispose();
    _basicRate.dispose();
    _mediumRate.dispose();
    _luxuryRate.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Enter a line item name.');
      return;
    }
    final rates = _readRates(
      _basicRate.text,
      _mediumRate.text,
      _luxuryRate.text,
    );
    if (rates == null) return;
    setState(() {
      _adding = true;
      _formError = null;
    });
    final entry = StudioLineItemCatalogEntry(
      id: 'line-item-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      basicRatePerSqft: rates.$1,
      mediumRatePerSqft: rates.$2,
      luxuryRatePerSqft: rates.$3,
    );
    final saved = await widget.onSave(entry);
    if (!mounted) return;
    setState(() => _adding = false);
    if (!saved) return;
    _name.clear();
    _basicRate.clear();
    _mediumRate.clear();
    _luxuryRate.clear();
  }

  (double?, double?, double?)? _readRates(
    String basicText,
    String mediumText,
    String luxuryText,
  ) {
    final values = <double?>[];
    for (final (label, text) in [
      ('Basic', basicText),
      ('Medium', mediumText),
      ('Luxury', luxuryText),
    ]) {
      if (text.trim().isEmpty) {
        values.add(null);
        continue;
      }
      final rate = double.tryParse(text.trim());
      if (rate == null || !rate.isFinite || rate < 0) {
        setState(() => _formError = 'Enter a non-negative $label rate.');
        return null;
      }
      values.add(rate);
    }
    return (values[0], values[1], values[2]);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Each rate is for one square foot. Starter names are unpriced until you configure them.',
        style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 11),
      ),
      if (widget.canManage) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _name,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'New line item name',
                  counterText: '',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            _rateField(_basicRate, 'Basic'),
            _rateField(_mediumRate, 'Medium'),
            _rateField(_luxuryRate, 'Luxury'),
            FilledButton.icon(
              onPressed: widget.loading || _adding ? null : _addEntry,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add item'),
              style: FilledButton.styleFrom(backgroundColor: ink),
            ),
          ],
        ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _formError!,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: Color(0xFF9C4B3D),
                fontSize: 11,
              ),
            ),
          ),
      ],
      if (widget.loading) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (widget.error != null) ...[
        const SizedBox(height: 12),
        Text(
          widget.error!,
          style: const TextStyle(
            fontFamily: 'Arial',
            color: Color(0xFF9C4B3D),
            fontSize: 11,
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (widget.catalog.isEmpty && !widget.loading)
        const Text(
          'No line items are available.',
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 12),
        )
      else
        for (final entry in widget.catalog)
          _LineItemCatalogEntryRow(
            key: ValueKey(entry.id),
            entry: entry,
            currencySymbol: widget.currencySymbol,
            canManage: widget.canManage,
            saving: widget.loading,
            onSave: widget.onSave,
          ),
    ],
  );

  Widget _rateField(TextEditingController controller, String quality) =>
      SizedBox(
        width: 135,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '$quality ${widget.currencySymbol}/sq ft',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}

class _LineItemCatalogEntryRow extends StatefulWidget {
  const _LineItemCatalogEntryRow({
    super.key,
    required this.entry,
    required this.currencySymbol,
    required this.canManage,
    required this.saving,
    required this.onSave,
  });

  final StudioLineItemCatalogEntry entry;
  final String currencySymbol;
  final bool canManage;
  final bool saving;
  final Future<bool> Function(StudioLineItemCatalogEntry entry) onSave;

  @override
  State<_LineItemCatalogEntryRow> createState() =>
      _LineItemCatalogEntryRowState();
}

class _LineItemCatalogEntryRowState extends State<_LineItemCatalogEntryRow> {
  late final TextEditingController _name;
  late final TextEditingController _basicRate;
  late final TextEditingController _mediumRate;
  late final TextEditingController _luxuryRate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry.name);
    _basicRate = TextEditingController(
      text: widget.entry.basicRatePerSqft?.toString() ?? '',
    );
    _mediumRate = TextEditingController(
      text: widget.entry.mediumRatePerSqft?.toString() ?? '',
    );
    _luxuryRate = TextEditingController(
      text: widget.entry.luxuryRatePerSqft?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _LineItemCatalogEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.version != widget.entry.version) {
      _name.text = widget.entry.name;
      _basicRate.text = widget.entry.basicRatePerSqft?.toString() ?? '';
      _mediumRate.text = widget.entry.mediumRatePerSqft?.toString() ?? '';
      _luxuryRate.text = widget.entry.luxuryRatePerSqft?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _basicRate.dispose();
    _mediumRate.dispose();
    _luxuryRate.dispose();
    super.dispose();
  }

  Future<void> _save({bool? active}) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a line item name.');
      return;
    }
    final rates = _parseRates();
    if (rates == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final entry = StudioLineItemCatalogEntry(
      id: widget.entry.id,
      name: _name.text.trim(),
      basicRatePerSqft: rates.$1,
      mediumRatePerSqft: rates.$2,
      luxuryRatePerSqft: rates.$3,
      active: active ?? widget.entry.active,
      version: widget.entry.version + 1,
    );
    final saved = await widget.onSave(entry);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) _error = 'The catalog entry could not be saved.';
    });
  }

  (double?, double?, double?)? _parseRates() {
    final values = <double?>[];
    for (final (label, text) in [
      ('Basic', _basicRate.text),
      ('Medium', _mediumRate.text),
      ('Luxury', _luxuryRate.text),
    ]) {
      if (text.trim().isEmpty) {
        values.add(null);
        continue;
      }
      final rate = double.tryParse(text.trim());
      if (rate == null || !rate.isFinite || rate < 0) {
        setState(() => _error = 'Enter a non-negative $label rate.');
        return null;
      }
      values.add(rate);
    }
    return (values[0], values[1], values[2]);
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: widget.entry.active ? paper : const Color(0xFFF4F2EF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: _field(
                _name,
                'Line item name',
                readOnly: !widget.canManage,
              ),
            ),
            _field(
              _basicRate,
              'Basic ${widget.currencySymbol}/sq ft',
              readOnly: !widget.canManage,
              numeric: true,
            ),
            _field(
              _mediumRate,
              'Medium ${widget.currencySymbol}/sq ft',
              readOnly: !widget.canManage,
              numeric: true,
            ),
            _field(
              _luxuryRate,
              'Luxury ${widget.currencySymbol}/sq ft',
              readOnly: !widget.canManage,
              numeric: true,
            ),
            Chip(
              label: Text(widget.entry.active ? 'Active' : 'Archived'),
              visualDensity: VisualDensity.compact,
            ),
            if (widget.canManage) ...[
              IconButton(
                tooltip: 'Save ${widget.entry.name}',
                onPressed: widget.saving || _saving ? null : () => _save(),
                icon: const Icon(Icons.save_outlined),
              ),
              IconButton(
                tooltip: widget.entry.active
                    ? 'Archive ${widget.entry.name}'
                    : 'Restore ${widget.entry.name}',
                onPressed: widget.saving || _saving
                    ? null
                    : () => _save(active: !widget.entry.active),
                icon: Icon(
                  widget.entry.active
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                ),
              ),
            ],
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: Color(0xFF9C4B3D),
                fontSize: 11,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    bool numeric = false,
  }) => SizedBox(
    width: 150,
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

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
                            '${item.packageName == null ? '' : '${item.packageName} · '}${item.lengthMm == null ? '' : '${item.lengthMm!.toStringAsFixed(0)}L × '}${item.heightMm == null ? '' : '${item.heightMm!.toStringAsFixed(0)}H × '}${item.quantity} ${item.unit} × ${_formatCurrencyAmount(item.unitRate, widget.quotation.currencySymbol)}',
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
  late final TextEditingController _lengthMm;
  late final TextEditingController _heightMm;
  late final TextEditingController _widthMm;
  String _packageName = 'Basic';

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.line.description);
    _quantity = TextEditingController(text: widget.line.quantity.toString());
    _unit = TextEditingController(text: widget.line.unit);
    _unitRate = TextEditingController(text: widget.line.unitRate.toString());
    _lengthMm = TextEditingController(
      text: widget.line.lengthMm?.toStringAsFixed(0) ?? '',
    );
    _heightMm = TextEditingController(
      text: widget.line.heightMm?.toStringAsFixed(0) ?? '',
    );
    _widthMm = TextEditingController(
      text: widget.line.widthMm?.toStringAsFixed(0) ?? '',
    );
    _packageName = widget.line.packageName ?? 'Basic';
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    _unitRate.dispose();
    _lengthMm.dispose();
    _heightMm.dispose();
    _widthMm.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    double? optionalDimension(TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }
    Navigator.pop(
      context,
      StudioQuoteLine(
        id: widget.line.id,
        description: _description.text.trim(),
        quantity: double.parse(_quantity.text.trim()),
        unit: _unit.text.trim(),
        unitRate: double.parse(_unitRate.text.trim()),
        packageName: _packageName,
        lengthMm: optionalDimension(_lengthMm),
        heightMm: optionalDimension(_heightMm),
        widthMm: optionalDimension(_widthMm),
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
                DropdownButtonFormField<String>(
                  initialValue: _packageName,
                  decoration:
                      const InputDecoration(labelText: 'Hardware package'),
                  items: const ['Basic', 'Medium', 'Luxury']
                      .map(
                        (packageName) => DropdownMenuItem(
                          value: packageName,
                          child: Text(packageName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _packageName = value);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lengthMm,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Length (mm)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _heightMm,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Height (mm)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _widthMm,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Width (mm)'),
                      ),
                    ),
                  ],
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
