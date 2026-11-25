class StudioCommunication {
  const StudioCommunication({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.projectId,
    required this.projectName,
    required this.channel,
    required this.subject,
    required this.body,
    required this.recipient,
    required this.status,
    required this.createdByPersonaId,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.vendorId,
    this.procurementRecordType,
    this.procurementRecordId,
    this.mentionedPersonaIds = const [],
    this.readByPersonaIds = const [],
  });

  static const channels = [
    'Internal note',
    'Email',
    'WhatsApp',
    'Call',
    'Meeting',
    'Message',
    'Other',
  ];
  static const statuses = [
    'Logged',
    'Draft',
    'Ready to send',
    'Queued',
    'Sending',
    'Sent',
    'Delivered',
    'Read',
    'Failed',
    'Received',
  ];

  final String id;
  final String? clientId;
  final String clientName;
  final String? projectId;
  final String projectName;
  final String channel;
  final String subject;
  final String body;
  final String recipient;
  final String status;
  final String createdByPersonaId;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? vendorId;
  final String? procurementRecordType;
  final String? procurementRecordId;
  final List<String> mentionedPersonaIds;
  final List<String> readByPersonaIds;

  StudioCommunication copyWith({
    String? status,
    DateTime? updatedAt,
    List<String>? readByPersonaIds,
    bool clearClient = false,
  }) => StudioCommunication(
    id: id,
    clientId: clearClient ? null : clientId,
    clientName: clientName,
    vendorId: vendorId,
    procurementRecordType: procurementRecordType,
    procurementRecordId: procurementRecordId,
    projectId: projectId,
    projectName: projectName,
    channel: channel,
    subject: subject,
    body: body,
    recipient: recipient,
    status: status ?? this.status,
    createdByPersonaId: createdByPersonaId,
    createdByName: createdByName,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mentionedPersonaIds: mentionedPersonaIds,
    readByPersonaIds: readByPersonaIds ?? this.readByPersonaIds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'vendorId': vendorId,
    'procurementRecordType': procurementRecordType,
    'procurementRecordId': procurementRecordId,
    'projectId': projectId,
    'projectName': projectName,
    'channel': channel,
    'subject': subject,
    'body': body,
    'recipient': recipient,
    'status': status,
    'createdByPersonaId': createdByPersonaId,
    'createdByName': createdByName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'mentionedPersonaIds': mentionedPersonaIds,
    'readByPersonaIds': readByPersonaIds,
  };

  factory StudioCommunication.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved communication entry is invalid.');
    }

    String readString(String key) {
      final field = value[key];
      if (field is! String) {
        throw FormatException('A saved communication entry is missing "$key".');
      }
      return field;
    }

    String? readNullableString(String key) {
      final field = value[key];
      if (field == null) return null;
      if (field is! String) {
        throw FormatException(
          'A saved communication entry has an invalid "$key".',
        );
      }
      return field;
    }

    List<String> readStringList(String key) {
      final field = value[key];
      if (field == null) return const [];
      if (field is! List<dynamic> || !field.every((item) => item is String)) {
        throw FormatException(
          'A saved communication entry has an invalid "$key".',
        );
      }
      return field.cast<String>();
    }

    DateTime readDate(String key) {
      final date = DateTime.tryParse(readString(key));
      if (date == null) {
        throw FormatException(
          'A saved communication entry has an invalid "$key".',
        );
      }
      return date;
    }

    return StudioCommunication(
      id: readString('id'),
      clientId: readNullableString('clientId'),
      clientName: readString('clientName'),
      vendorId: readNullableString('vendorId'),
      procurementRecordType: readNullableString('procurementRecordType'),
      procurementRecordId: readNullableString('procurementRecordId'),
      projectId: readNullableString('projectId'),
      projectName: readString('projectName'),
      channel: readString('channel'),
      subject: readString('subject'),
      body: readString('body'),
      recipient: readString('recipient'),
      status: readString('status'),
      createdByPersonaId: readString('createdByPersonaId'),
      createdByName: readString('createdByName'),
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
      mentionedPersonaIds: readStringList('mentionedPersonaIds'),
      readByPersonaIds: readStringList('readByPersonaIds'),
    );
  }
}
