class StudioQuoteLine {
  const StudioQuoteLine({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitRate,
  });

  final String id;
  final String description;
  final double quantity;
  final String unit;
  final double unitRate;

  double get amount => _roundMoney(quantity * unitRate);

  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unitRate': unitRate,
      };

  factory StudioQuoteLine.fromJson(Object? value) {
    final map = _financeMap(value, 'quotation line');
    return StudioQuoteLine(
      id: _financeString(map, 'id'),
      description: _financeString(map, 'description'),
      quantity: _financeNumber(map, 'quantity'),
      unit: _financeString(map, 'unit'),
      unitRate: _financeNumber(map, 'unitRate'),
    );
  }
}

class StudioQuotation {
  const StudioQuotation({
    required this.id,
    required this.number,
    required this.projectId,
    required this.projectName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.title,
    required this.items,
    required this.taxRate,
    required this.currencySymbol,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String number;
  final String projectId;
  final String projectName;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String title;
  final List<StudioQuoteLine> items;
  final double taxRate;
  final String currencySymbol;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get subtotal =>
      _roundMoney(items.fold(0, (total, item) => total + item.amount));
  double get taxAmount => _roundMoney(subtotal * taxRate / 100);
  double get total => _roundMoney(subtotal + taxAmount);

  StudioQuotation copyWith({
    String? title,
    List<StudioQuoteLine>? items,
    double? taxRate,
    String? currencySymbol,
    DateTime? updatedAt,
  }) =>
      StudioQuotation(
        id: id,
        number: number,
        projectId: projectId,
        projectName: projectName,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        title: title ?? this.title,
        items: items ?? this.items,
        taxRate: taxRate ?? this.taxRate,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'number': number,
        'projectId': projectId,
        'projectName': projectName,
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'title': title,
        'items': items.map((item) => item.toJson()).toList(),
        'taxRate': taxRate,
        'currencySymbol': currencySymbol,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudioQuotation.fromJson(Object? value) {
    final map = _financeMap(value, 'quotation');
    return StudioQuotation(
      id: _financeString(map, 'id'),
      number: _financeString(map, 'number'),
      projectId: _financeString(map, 'projectId'),
      projectName: _financeString(map, 'projectName'),
      clientId: _financeString(map, 'clientId'),
      clientName: _financeString(map, 'clientName'),
      clientEmail: _financeString(map, 'clientEmail'),
      title: _financeString(map, 'title'),
      items: _financeList(map, 'items', StudioQuoteLine.fromJson),
      taxRate: _financeNumber(map, 'taxRate'),
      currencySymbol: _financeString(map, 'currencySymbol'),
      createdAt: _financeDate(map, 'createdAt'),
      updatedAt: _financeDate(map, 'updatedAt'),
    );
  }
}

class StudioDocumentTemplate {
  const StudioDocumentTemplate({
    required this.id,
    required this.name,
    required this.brandName,
    required this.introduction,
    required this.terms,
    required this.footer,
    required this.accentColor,
    required this.sectionOrder,
  });

  static const sectionLabels = {
    'cover': 'Cover',
    'overview': 'Project overview',
    'scope': 'Scope of work',
    'investment': 'Investment',
    'terms': 'Terms',
    'footer': 'Studio footer',
  };
  static const standard = StudioDocumentTemplate(
    id: 'template-standard',
    name: 'Sravya classic',
    brandName: '',
    introduction: 'A considered approach to creating a home that feels like you.',
    terms: 'This proposal is valid for 30 days. Work begins after written approval and the agreed initial payment.',
    footer: 'Prepared with care by your studio.',
    accentColor: 0xFFB77C56,
    sectionOrder: ['cover', 'overview', 'scope', 'investment', 'terms', 'footer'],
  );

  final String id;
  final String name;
  final String brandName;
  final String introduction;
  final String terms;
  final String footer;
  final int accentColor;
  final List<String> sectionOrder;

  StudioDocumentTemplate copyWith({
    String? name,
    String? brandName,
    String? introduction,
    String? terms,
    String? footer,
    int? accentColor,
    List<String>? sectionOrder,
  }) =>
      StudioDocumentTemplate(
        id: id,
        name: name ?? this.name,
        brandName: brandName ?? this.brandName,
        introduction: introduction ?? this.introduction,
        terms: terms ?? this.terms,
        footer: footer ?? this.footer,
        accentColor: accentColor ?? this.accentColor,
        sectionOrder: sectionOrder ?? this.sectionOrder,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'brandName': brandName,
        'introduction': introduction,
        'terms': terms,
        'footer': footer,
        'accentColor': accentColor,
        'sectionOrder': sectionOrder,
      };

  factory StudioDocumentTemplate.fromJson(Object? value) {
    final map = _financeMap(value, 'document template');
    final color = map['accentColor'];
    if (color is! int) {
      throw const FormatException('A saved template has an invalid accent color.');
    }
    return StudioDocumentTemplate(
      id: _financeString(map, 'id'),
      name: _financeString(map, 'name'),
      brandName: _financeString(map, 'brandName'),
      introduction: _financeString(map, 'introduction'),
      terms: _financeString(map, 'terms'),
      footer: _financeString(map, 'footer'),
      accentColor: color,
      sectionOrder: _financeStringList(map, 'sectionOrder'),
    );
  }
}

class StudioFinancialSettings {
  const StudioFinancialSettings({
    required this.quotationPrefix,
    required this.nextQuotationNumber,
    required this.proposalPrefix,
    required this.nextProposalNumber,
    required this.invoicePrefix,
    required this.nextInvoiceNumber,
    required this.currencySymbol,
    required this.defaultTaxRate,
    required this.defaultTerms,
  });

  static const defaults = StudioFinancialSettings(
    quotationPrefix: 'QT-',
    nextQuotationNumber: 1,
    proposalPrefix: 'PR-',
    nextProposalNumber: 1,
    invoicePrefix: 'INV-',
    nextInvoiceNumber: 1,
    currencySymbol: '\$',
    defaultTaxRate: 0,
    defaultTerms:
        'This proposal is valid for 30 days. Work begins after written approval and the agreed initial payment.',
  );

  final String quotationPrefix;
  final int nextQuotationNumber;
  final String proposalPrefix;
  final int nextProposalNumber;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final String currencySymbol;
  final double defaultTaxRate;
  final String defaultTerms;

  StudioFinancialSettings copyWith({
    String? quotationPrefix,
    int? nextQuotationNumber,
    String? proposalPrefix,
    int? nextProposalNumber,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? currencySymbol,
    double? defaultTaxRate,
    String? defaultTerms,
  }) =>
      StudioFinancialSettings(
        quotationPrefix: quotationPrefix ?? this.quotationPrefix,
        nextQuotationNumber: nextQuotationNumber ?? this.nextQuotationNumber,
        proposalPrefix: proposalPrefix ?? this.proposalPrefix,
        nextProposalNumber: nextProposalNumber ?? this.nextProposalNumber,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
        defaultTerms: defaultTerms ?? this.defaultTerms,
      );

  Map<String, Object?> toJson() => {
        'quotationPrefix': quotationPrefix,
        'nextQuotationNumber': nextQuotationNumber,
        'proposalPrefix': proposalPrefix,
        'nextProposalNumber': nextProposalNumber,
        'invoicePrefix': invoicePrefix,
        'nextInvoiceNumber': nextInvoiceNumber,
        'currencySymbol': currencySymbol,
        'defaultTaxRate': defaultTaxRate,
        'defaultTerms': defaultTerms,
      };

  factory StudioFinancialSettings.fromJson(Object? value) {
    final map = _financeMap(value, 'financial settings');
    return StudioFinancialSettings(
      quotationPrefix: _financeString(map, 'quotationPrefix'),
      nextQuotationNumber: _financeInt(map, 'nextQuotationNumber'),
      proposalPrefix: _financeString(map, 'proposalPrefix'),
      nextProposalNumber: _financeInt(map, 'nextProposalNumber'),
      invoicePrefix: _financeString(map, 'invoicePrefix'),
      nextInvoiceNumber: _financeInt(map, 'nextInvoiceNumber'),
      currencySymbol: _financeString(map, 'currencySymbol'),
      defaultTaxRate: _financeNumber(map, 'defaultTaxRate'),
      defaultTerms: _financeString(map, 'defaultTerms'),
    );
  }
}

class StudioProposal {
  const StudioProposal({
    required this.id,
    required this.number,
    required this.quotationId,
    required this.projectId,
    required this.projectName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.title,
    required this.requirementRooms,
    required this.designStyle,
    required this.projectBrief,
    required this.budgetMin,
    required this.budgetMax,
    required this.startDate,
    required this.targetDate,
    required this.brandName,
    required this.introduction,
    required this.terms,
    required this.footer,
    required this.accentColor,
    required this.sectionOrder,
    required this.items,
    required this.taxRate,
    required this.currencySymbol,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  static const statuses = ['Draft', 'Pending approval', 'Approved', 'Rejected'];

  final String id;
  final String number;
  final String quotationId;
  final String projectId;
  final String projectName;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String title;
  final List<String> requirementRooms;
  final String designStyle;
  final String projectBrief;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startDate;
  final DateTime? targetDate;
  final String brandName;
  final String introduction;
  final String terms;
  final String footer;
  final int accentColor;
  final List<String> sectionOrder;
  final List<StudioQuoteLine> items;
  final double taxRate;
  final String currencySymbol;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get subtotal =>
      _roundMoney(items.fold(0, (total, item) => total + item.amount));
  double get taxAmount => _roundMoney(subtotal * taxRate / 100);
  double get total => _roundMoney(subtotal + taxAmount);

  StudioProposal copyWith({String? status, DateTime? updatedAt}) =>
      StudioProposal(
        id: id,
        number: number,
        quotationId: quotationId,
        projectId: projectId,
        projectName: projectName,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        title: title,
        requirementRooms: requirementRooms,
        designStyle: designStyle,
        projectBrief: projectBrief,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        startDate: startDate,
        targetDate: targetDate,
        brandName: brandName,
        introduction: introduction,
        terms: terms,
        footer: footer,
        accentColor: accentColor,
        sectionOrder: sectionOrder,
        items: items,
        taxRate: taxRate,
        currencySymbol: currencySymbol,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'number': number,
        'quotationId': quotationId,
        'projectId': projectId,
        'projectName': projectName,
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'title': title,
        'requirementRooms': requirementRooms,
        'designStyle': designStyle,
        'projectBrief': projectBrief,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'startDate': startDate?.toIso8601String(),
        'targetDate': targetDate?.toIso8601String(),
        'brandName': brandName,
        'introduction': introduction,
        'terms': terms,
        'footer': footer,
        'accentColor': accentColor,
        'sectionOrder': sectionOrder,
        'items': items.map((item) => item.toJson()).toList(),
        'taxRate': taxRate,
        'currencySymbol': currencySymbol,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudioProposal.fromJson(Object? value) {
    final map = _financeMap(value, 'proposal');
    final color = map['accentColor'];
    if (color is! int) {
      throw const FormatException('A saved proposal has an invalid accent color.');
    }
    return StudioProposal(
      id: _financeString(map, 'id'),
      number: _financeString(map, 'number'),
      quotationId: _financeString(map, 'quotationId'),
      projectId: _financeString(map, 'projectId'),
      projectName: _financeString(map, 'projectName'),
      clientId: _financeString(map, 'clientId'),
      clientName: _financeString(map, 'clientName'),
      clientEmail: _financeString(map, 'clientEmail'),
      title: _financeString(map, 'title'),
      requirementRooms: map['requirementRooms'] == null
          ? const []
          : _financeStringList(map, 'requirementRooms'),
      designStyle: map['designStyle'] == null
          ? ''
          : _financeString(map, 'designStyle'),
      projectBrief: map['projectBrief'] == null
          ? ''
          : _financeString(map, 'projectBrief'),
      budgetMin: _financeNullableNumber(map, 'budgetMin'),
      budgetMax: _financeNullableNumber(map, 'budgetMax'),
      startDate: _financeNullableDate(map, 'startDate'),
      targetDate: _financeNullableDate(map, 'targetDate'),
      brandName: _financeString(map, 'brandName'),
      introduction: _financeString(map, 'introduction'),
      terms: _financeString(map, 'terms'),
      footer: _financeString(map, 'footer'),
      accentColor: color,
      sectionOrder: _financeStringList(map, 'sectionOrder'),
      items: _financeList(map, 'items', StudioQuoteLine.fromJson),
      taxRate: _financeNumber(map, 'taxRate'),
      currencySymbol: _financeString(map, 'currencySymbol'),
      status: _financeString(map, 'status'),
      createdAt: _financeDate(map, 'createdAt'),
      updatedAt: _financeDate(map, 'updatedAt'),
    );
  }
}

class StudioInvoice {
  const StudioInvoice({
    required this.id,
    required this.number,
    required this.proposalId,
    required this.projectId,
    required this.projectName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.title,
    required this.items,
    required this.taxRate,
    required this.currencySymbol,
    required this.issuedAt,
    required this.dueDate,
    required this.memo,
    required this.status,
    required this.paidAmount,
  });

  static const statuses = ['Draft', 'Sent', 'Partially paid', 'Paid'];

  final String id;
  final String number;
  final String proposalId;
  final String projectId;
  final String projectName;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String title;
  final List<StudioQuoteLine> items;
  final double taxRate;
  final String currencySymbol;
  final DateTime issuedAt;
  final DateTime dueDate;
  final String memo;
  final String status;
  final double paidAmount;

  double get subtotal =>
      _roundMoney(items.fold(0, (total, item) => total + item.amount));
  double get taxAmount => _roundMoney(subtotal * taxRate / 100);
  double get total => _roundMoney(subtotal + taxAmount);
  double get balance => _roundMoney(
      paidAmount >= total ? 0 : total - paidAmount);

  StudioInvoice copyWith({String? status, double? paidAmount}) =>
      StudioInvoice(
        id: id,
        number: number,
        proposalId: proposalId,
        projectId: projectId,
        projectName: projectName,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        title: title,
        items: items,
        taxRate: taxRate,
        currencySymbol: currencySymbol,
        issuedAt: issuedAt,
        dueDate: dueDate,
        memo: memo,
        status: status ?? this.status,
        paidAmount: paidAmount ?? this.paidAmount,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'number': number,
        'proposalId': proposalId,
        'projectId': projectId,
        'projectName': projectName,
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'title': title,
        'items': items.map((item) => item.toJson()).toList(),
        'taxRate': taxRate,
        'currencySymbol': currencySymbol,
        'issuedAt': issuedAt.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'memo': memo,
        'status': status,
        'paidAmount': paidAmount,
      };

  factory StudioInvoice.fromJson(Object? value) {
    final map = _financeMap(value, 'invoice');
    return StudioInvoice(
      id: _financeString(map, 'id'),
      number: _financeString(map, 'number'),
      proposalId: _financeString(map, 'proposalId'),
      projectId: _financeString(map, 'projectId'),
      projectName: _financeString(map, 'projectName'),
      clientId: _financeString(map, 'clientId'),
      clientName: _financeString(map, 'clientName'),
      clientEmail: _financeString(map, 'clientEmail'),
      title: _financeString(map, 'title'),
      items: _financeList(map, 'items', StudioQuoteLine.fromJson),
      taxRate: _financeNumber(map, 'taxRate'),
      currencySymbol: _financeString(map, 'currencySymbol'),
      issuedAt: _financeDate(map, 'issuedAt'),
      dueDate: _financeDate(map, 'dueDate'),
      memo: _financeString(map, 'memo'),
      status: _financeString(map, 'status'),
      paidAmount: _financeNumber(map, 'paidAmount'),
    );
  }
}

class StudioFinancialWorkspace {
  const StudioFinancialWorkspace({
    this.quotations = const [],
    this.templates = const [],
    this.proposals = const [],
    this.invoices = const [],
    this.settings = StudioFinancialSettings.defaults,
  });

  final List<StudioQuotation> quotations;
  final List<StudioDocumentTemplate> templates;
  final List<StudioProposal> proposals;
  final List<StudioInvoice> invoices;
  final StudioFinancialSettings settings;

  factory StudioFinancialWorkspace.defaults() =>
      const StudioFinancialWorkspace(templates: [StudioDocumentTemplate.standard]);

  StudioFinancialWorkspace copyWith({
    List<StudioQuotation>? quotations,
    List<StudioDocumentTemplate>? templates,
    List<StudioProposal>? proposals,
    List<StudioInvoice>? invoices,
    StudioFinancialSettings? settings,
  }) =>
      StudioFinancialWorkspace(
        quotations: quotations ?? this.quotations,
        templates: templates ?? this.templates,
        proposals: proposals ?? this.proposals,
        invoices: invoices ?? this.invoices,
        settings: settings ?? this.settings,
      );

  Map<String, Object?> toJson() => {
        'quotations': quotations.map((item) => item.toJson()).toList(),
        'templates': templates.map((item) => item.toJson()).toList(),
        'proposals': proposals.map((item) => item.toJson()).toList(),
        'invoices': invoices.map((item) => item.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory StudioFinancialWorkspace.fromJson(Object? value) {
    final map = _financeMap(value, 'financial workspace');
    final settings = map['settings'];
    return StudioFinancialWorkspace(
      quotations: _financeList(map, 'quotations', StudioQuotation.fromJson),
      templates:
          _financeList(map, 'templates', StudioDocumentTemplate.fromJson),
      proposals: _financeList(map, 'proposals', StudioProposal.fromJson),
      invoices: _financeList(map, 'invoices', StudioInvoice.fromJson),
      settings: StudioFinancialSettings.fromJson(settings),
    );
  }
}

Map<String, dynamic> _financeMap(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Saved $label data is invalid.');
  }
  return value;
}

String _financeString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved financial record is missing "$key".');
  }
  return value;
}

double _financeNumber(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  return value.toDouble();
}

int _financeInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  return value;
}

DateTime _financeDate(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('A saved financial record is missing "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  return date;
}

DateTime? _financeNullableDate(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  return date;
}

double? _financeNullableNumber(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('A saved financial record has an invalid "$key".');
  }
  return value.toDouble();
}

List<String> _financeStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List<dynamic> ||
      !value.every((item) => item is String)) {
    throw FormatException('A saved financial record has invalid "$key" data.');
  }
  return value.cast<String>();
}

List<T> _financeList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(Object?) decode,
) {
  final value = map[key];
  if (value is! List<dynamic>) {
    throw FormatException('Saved financial "$key" data is not a list.');
  }
  return value.map(decode).toList();
}

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;
