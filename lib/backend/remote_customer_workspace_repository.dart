import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:raams_crm/communication.dart';
import 'package:raams_crm/customer.dart';
import 'package:raams_crm/delivery.dart';
import 'package:raams_crm/finance.dart';

typedef AccessTokenProvider = Future<String?> Function();

class WorkspaceApiException implements Exception {
  const WorkspaceApiException(this.statusCode, this.code);

  final int statusCode;
  final String code;

  @override
  String toString() => switch (statusCode) {
    401 => 'Your session expired. Sign in again.',
    409 when code == 'integration_not_configured' =>
      'Connect this workspace sender account before sending.',
    409 when code == 'communication_idempotency_conflict' =>
      'This message ID was already used for different content.',
    409 when code == 'workspace_revision_conflict' =>
      'This workspace changed on another device. Reload before saving.',
    409 when code == 'duplicate_line_item_name' =>
      'A line item with this name already exists in the workspace catalog.',
    409 => 'The request conflicts with the current workspace state.',
    _ => 'Workspace request failed ($statusCode): $code',
  };
}

class WorkspaceCollectionPage {
  const WorkspaceCollectionPage({
    required this.collection,
    required this.records,
    required this.total,
    required this.nextOffset,
    required this.revision,
    required this.workspaceExists,
  });

  final String collection;
  final List<Map<String, dynamic>> records;
  final int total;
  final int? nextOffset;
  final int revision;
  final bool workspaceExists;
}

class RemoteCustomerWorkspaceRepository implements CustomerWorkspaceRepository {
  RemoteCustomerWorkspaceRepository({
    required this.baseUri,
    required this.workspaceId,
    required this.accessTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final String workspaceId;
  final AccessTokenProvider accessTokenProvider;
  final http.Client _client;
  final SharedPreferencesCustomerWorkspaceRepository _codec =
      const SharedPreferencesCustomerWorkspaceRepository();
  int _revision = 0;
  bool _loaded = false;
  bool _isNewWorkspace = false;
  Map<String, Object?>? _snapshot;
  final Map<String, String> _uploadedPathsByAssetId = {};
  final Set<String> _pendingUploads = {};

  Uri get _workspaceUri => baseUri.resolve('/api/workspace');
  Uri get _quotationCatalogUri => baseUri.resolve('/api/quotation-catalog');

  Future<Map<String, String>> _headers() async {
    final token = await accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const WorkspaceApiException(401, 'unauthorized');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Workspace-Id': workspaceId,
    };
  }

  @override
  Future<List<StudioLineItemCatalogEntry>> loadLineItemCatalog() async {
    final response = await _client.get(
      _quotationCatalogUri,
      headers: await _headers(),
    );
    final body = _decodeResponse(response);
    final catalog = body['catalog'];
    if (catalog is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid catalog.');
    }
    final lineItems = catalog['lineItems'];
    if (lineItems is! List<dynamic>) {
      throw const FormatException(
        'The server returned an invalid line-item catalog.',
      );
    }
    return lineItems
        .map(StudioLineItemCatalogEntry.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveLineItemCatalogEntry(
    StudioLineItemCatalogEntry entry,
  ) async {
    final response = await _client.put(
      _quotationCatalogUri,
      headers: await _headers(),
      body: jsonEncode({'type': 'lineItems', 'record': entry.toJson()}),
    );
    _decodeResponse(response);
  }

  @override
  Future<CustomerWorkspace> loadWorkspace({
    required List<Customer> initialCustomers,
    required List<String> initialStages,
  }) async {
    final response = await _client.get(
      _workspaceUri,
      headers: await _headers(),
    );
    final body = _decodeResponse(response);
    final revision = body['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException(
        'The server returned an invalid workspace revision.',
      );
    }
    final snapshot = body['snapshot'];
    if (snapshot == null) {
      _snapshot = null;
      _revision = revision;
      _loaded = true;
      _isNewWorkspace = true;
      return _emptyWorkspace(initialStages);
    }
    if (snapshot is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid workspace.');
    }
    final workspace = _codec.decodeWorkspaceData(
      snapshot,
      initialCustomers: const [],
      initialStages: initialStages,
    );
    _snapshot = Map<String, Object?>.from(snapshot);
    _rememberAssetPaths(_snapshot!);
    _revision = revision;
    _loaded = true;
    _isNewWorkspace = false;
    return workspace;
  }

  Future<WorkspaceCollectionPage> loadCollection({
    required String collection,
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Collection pagination values are out of range.');
    }
    final query = <String, String>{
      'collection': collection,
      'limit': '$limit',
      'offset': '$offset',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _client.get(
      _workspaceUri.replace(queryParameters: query),
      headers: await _headers(),
    );
    final body = _decodeResponse(response);
    final records = body['records'];
    final total = body['total'];
    final nextOffset = body['nextOffset'];
    final revision = body['revision'];
    final workspaceExists = body['workspaceExists'];
    if (body['collection'] != collection ||
        records is! List<dynamic> ||
        !records.every((record) => record is Map<String, dynamic>) ||
        total is! int ||
        total < 0 ||
        (nextOffset != null && nextOffset is! int) ||
        revision is! int ||
        revision < 0 ||
        workspaceExists is! bool) {
      throw const FormatException(
        'The server returned an invalid collection page.',
      );
    }
    return WorkspaceCollectionPage(
      collection: collection,
      records: records.cast<Map<String, dynamic>>(),
      total: total,
      nextOffset: nextOffset as int?,
      revision: revision,
      workspaceExists: workspaceExists,
    );
  }

  Future<CustomerWorkspace> loadWorkspacePaged({
    required List<Customer> initialCustomers,
    required List<String> initialStages,
  }) async {
    final firstPreferencesPage = await loadCollection(
      collection: 'preferences',
      limit: 100,
    );
    if (!firstPreferencesPage.workspaceExists) {
      if (_loaded && !_isNewWorkspace) {
        throw const WorkspaceApiException(404, 'workspace_not_found');
      }
      _snapshot = null;
      _revision = firstPreferencesPage.revision;
      _loaded = true;
      _isNewWorkspace = true;
      return _emptyWorkspace(initialStages);
    }

    final revision = firstPreferencesPage.revision;
    final collections = <String>[
      'customers',
      'pipelineStages',
      'activities',
      'personas',
      'projects',
      'phases',
      'tasks',
      'milestones',
      'materials',
      'vendors',
      'requisitions',
      'rfqs',
      'vendorQuotes',
      'purchaseOrders',
      'punchItems',
      'assets',
      'workLogs',
      'attendance',
      'approvals',
      'quotations',
      'templates',
      'proposals',
      'invoices',
      'communications',
      'preferences',
      'financialSettings',
    ];
    final pages = await Future.wait(
      collections.map(
        (collection) => _loadAllCollection(
          collection,
          expectedRevision: revision,
          firstPage: collection == 'preferences' ? firstPreferencesPage : null,
        ),
      ),
    );
    final recordsByCollection = <String, List<Map<String, dynamic>>>{
      for (var index = 0; index < collections.length; index++)
        collections[index]: pages[index],
    };
    final stageRecords = recordsByCollection['pipelineStages']!;
    if (stageRecords.any(
      (stage) => stage['position'] is! int || stage['name'] is! String,
    )) {
      throw const FormatException(
        'The server returned invalid pipeline stage records.',
      );
    }
    stageRecords.sort(
      (first, second) =>
          (first['position'] as int).compareTo(second['position'] as int),
    );
    final preferences = recordsByCollection['preferences']!;
    final financialSettings = recordsByCollection['financialSettings']!;
    if (preferences.length != 1 || financialSettings.length > 1) {
      throw const FormatException(
        'The server returned incomplete workspace settings.',
      );
    }
    final snapshot = <String, Object?>{
      'schemaVersion': 5,
      'customers': recordsByCollection['customers'],
      'pipelineStages': stageRecords
          .map((stage) => stage['name'] as String)
          .toList(),
      'activities': recordsByCollection['activities'],
      'personas': recordsByCollection['personas'],
      'preferences': preferences.single,
      'delivery': {
        'projects': recordsByCollection['projects'],
        'phases': recordsByCollection['phases'],
        'tasks': recordsByCollection['tasks'],
        'milestones': recordsByCollection['milestones'],
        'materials': recordsByCollection['materials'],
        'vendors': recordsByCollection['vendors'],
        'requisitions': recordsByCollection['requisitions'],
        'rfqs': recordsByCollection['rfqs'],
        'vendorQuotes': recordsByCollection['vendorQuotes'],
        'purchaseOrders': recordsByCollection['purchaseOrders'],
        'punchItems': recordsByCollection['punchItems'],
        'assets': recordsByCollection['assets'],
        'workLogs': recordsByCollection['workLogs'],
        'attendance': recordsByCollection['attendance'],
        'approvals': recordsByCollection['approvals'],
      },
      'financials': {
        'quotations': recordsByCollection['quotations'],
        'templates': recordsByCollection['templates'],
        'proposals': recordsByCollection['proposals'],
        'invoices': recordsByCollection['invoices'],
        'settings': financialSettings.isEmpty
            ? StudioFinancialSettings.defaults.toJson()
            : financialSettings.single,
      },
      'communications': recordsByCollection['communications'],
    };
    final workspace = _codec.decodeWorkspaceData(
      snapshot,
      initialCustomers: const [],
      initialStages: initialStages,
    );
    _snapshot = snapshot;
    _rememberAssetPaths(snapshot);
    _revision = revision;
    _loaded = true;
    _isNewWorkspace = false;
    return workspace;
  }

  Future<List<Map<String, dynamic>>> _loadAllCollection(
    String collection, {
    required int expectedRevision,
    WorkspaceCollectionPage? firstPage,
  }) async {
    WorkspaceCollectionPage page;
    try {
      page =
          firstPage ?? await loadCollection(collection: collection, limit: 100);
    } on WorkspaceApiException catch (error) {
      if (error.statusCode == 403 && error.code == 'permission_denied') {
        return [];
      }
      rethrow;
    }
    if (!page.workspaceExists || page.revision != expectedRevision) {
      throw const WorkspaceApiException(409, 'workspace_revision_conflict');
    }
    if (page.total > 10000) {
      throw const FormatException(
        'The workspace collection exceeds the supported export size.',
      );
    }
    final total = page.total;
    final records = <Map<String, dynamic>>[...page.records];
    var offset = page.nextOffset;
    while (offset != null) {
      page = await loadCollection(
        collection: collection,
        limit: 100,
        offset: offset,
      );
      if (!page.workspaceExists ||
          page.revision != expectedRevision ||
          page.total != total ||
          page.nextOffset != null && page.nextOffset! <= offset ||
          page.nextOffset != null && page.records.isEmpty) {
        throw const WorkspaceApiException(409, 'workspace_revision_conflict');
      }
      records.addAll(page.records);
      if (records.length > page.total || records.length > 10000) {
        throw const FormatException(
          'The server returned an invalid collection page sequence.',
        );
      }
      offset = page.nextOffset;
    }
    if (records.length != page.total) {
      throw const FormatException(
        'The server returned an incomplete collection.',
      );
    }
    return records;
  }

  Future<Map<String, String>> loadCommunicationIntegrations() async {
    final response = await _client.get(
      baseUri.resolve('/api/integrations'),
      headers: await _headers(),
    );
    final body = _decodeResponse(response);
    final integrations = body['integrations'];
    if (integrations is! List<dynamic>) {
      throw const FormatException(
        'The server returned invalid communication integrations.',
      );
    }
    final result = <String, String>{};
    for (final value in integrations) {
      if (value is! Map<String, dynamic> ||
          value['configured'] != true ||
          value['provider'] is! String ||
          value['accountHint'] is! String) {
        throw const FormatException(
          'The server returned invalid communication integration data.',
        );
      }
      result[value['provider'] as String] = value['accountHint'] as String;
    }
    return result;
  }

  Future<void> saveCommunicationIntegration({
    required String provider,
    required Map<String, String> settings,
    required String workspaceName,
  }) async {
    final response = await _client.put(
      baseUri.resolve('/api/integrations'),
      headers: await _headers(),
      body: jsonEncode({
        'provider': provider,
        'settings': settings,
        'workspaceName': workspaceName,
      }),
    );
    _decodeResponse(response);
  }

  Future<void> removeCommunicationIntegration(String provider) async {
    final response = await _client.delete(
      baseUri.resolve('/api/integrations'),
      headers: await _headers(),
      body: jsonEncode({'provider': provider}),
    );
    _decodeResponse(response);
  }

  Future<StudioCommunication> sendCommunication(
    StudioCommunication message,
  ) async {
    if (!_loaded || _snapshot == null) {
      throw StateError('Load the remote workspace before sending a message.');
    }
    final response = await _client.post(
      baseUri.resolve('/api/communications'),
      headers: await _headers(),
      body: jsonEncode({'revision': _revision, 'message': message.toJson()}),
    );
    final body = _decodeResponse(response);
    final revision = body['revision'];
    final storedMessage = body['communication'];
    if (revision is! int ||
        revision < _revision ||
        storedMessage is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid send result.',
      );
    }
    final updatedMessage = StudioCommunication.fromJson(storedMessage);
    final snapshot = Map<String, Object?>.from(_snapshot!);
    final communications = List<dynamic>.from(
      snapshot['communications']! as List<dynamic>,
    );
    final index = communications.indexWhere(
      (value) =>
          value is Map<String, dynamic> && value['id'] == updatedMessage.id,
    );
    if (index < 0) {
      communications.insert(0, updatedMessage.toJson());
    } else {
      communications[index] = updatedMessage.toJson();
    }
    snapshot['communications'] = communications;
    _snapshot = snapshot;
    _revision = revision;
    return updatedMessage;
  }

  @override
  Future<void> saveWorkspace({
    required List<Customer> customers,
    required List<String> pipelineStages,
    required List<StudioActivity> activities,
    required List<StudioPersona> personas,
    required WorkspacePreferences preferences,
    required StudioDeliveryWorkspace delivery,
    required StudioFinancialWorkspace financials,
    required List<StudioCommunication> communications,
  }) async {
    if (!_loaded) {
      throw StateError('Load the remote workspace before saving changes.');
    }
    final snapshot = _codec.encodeWorkspaceData(
      customers: customers,
      pipelineStages: pipelineStages,
      activities: activities,
      personas: personas,
      preferences: preferences,
      delivery: delivery,
      financials: financials,
      communications: communications,
    );
    final uploadedThisSave = <String>[];
    final previousPaths = _storedAssetPaths(_snapshot);
    final storedSnapshot = await _prepareStoredSnapshot(
      snapshot,
      uploadedThisSave,
    );
    try {
      final changes = _snapshot == null
          ? null
          : _changedCollections(_snapshot!, storedSnapshot);
      if (changes != null && changes.isEmpty) return;
      final response = _snapshot == null
          ? await _client.put(
              _workspaceUri,
              headers: await _headers(),
              body: jsonEncode({
                'revision': _revision,
                'snapshot': storedSnapshot,
              }),
            )
          : await _client.patch(
              _workspaceUri,
              headers: await _headers(),
              body: jsonEncode({'revision': _revision, 'changes': changes}),
            );
      final body = _decodeResponse(response);
      final revision = body['revision'];
      if (revision is! int || revision <= _revision) {
        throw const FormatException(
          'The server returned an invalid save revision.',
        );
      }
      _revision = revision;
      _snapshot = storedSnapshot;
      _rememberAssetPaths(storedSnapshot);
      _isNewWorkspace = false;
      _pendingUploads.clear();
      await _removeObsoleteAssets(
        previousPaths,
        _storedAssetPaths(storedSnapshot),
      );
    } catch (error) {
      if (error is WorkspaceApiException &&
          error.statusCode >= 400 &&
          error.statusCode < 500) {
        await _removeUploadedPaths(uploadedThisSave);
      } else if (uploadedThisSave.isNotEmpty) {
        debugPrint(
          'Project file upload cleanup was deferred after an uncertain workspace save.',
        );
      }
      rethrow;
    }
  }

  Future<String> uploadProjectFile({
    required String projectId,
    required String assetId,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > StudioProjectAsset.maxFileBytes) {
      throw const FormatException('The project file size is not allowed.');
    }
    if (!StudioProjectAsset.allowedMimeTypes.contains(mimeType)) {
      throw const FormatException('The project file type is not allowed.');
    }
    final safeSegment = RegExp(r'^[A-Za-z0-9._-]{1,160}$');
    if (!safeSegment.hasMatch(projectId) || !safeSegment.hasMatch(assetId)) {
      throw const FormatException('The project file path is invalid.');
    }
    final request = await _requestFileAction({
      'action': 'create_upload',
      'projectId': projectId,
      'assetId': assetId,
      'mimeType': mimeType,
    });
    final path = request['storagePath'];
    final uploadUrl = request['uploadUrl'];
    if (path != '$workspaceId/$projectId/$assetId' || uploadUrl is! String) {
      throw const FormatException('The server returned an invalid upload URL.');
    }
    final response = await _client.put(
      _validatedStorageUrl(uploadUrl),
      headers: {'Content-Type': mimeType, 'x-upsert': 'false'},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceApiException(
        response.statusCode,
        'project_file_upload_failed',
      );
    }
    _uploadedPathsByAssetId[assetId] = path;
    _pendingUploads.add(path);
    return path;
  }

  Future<Uint8List> downloadProjectFile(StudioProjectAsset asset) async {
    final path = asset.storagePath;
    if (path == null || !_isAssetPath(path, asset.projectId, asset.id)) {
      throw const FormatException('The project file path is invalid.');
    }
    final request = await _requestFileAction({
      'action': 'create_download',
      'projectId': asset.projectId,
      'assetId': asset.id,
    });
    final downloadUrl = request['downloadUrl'];
    if (downloadUrl is! String) {
      throw const FormatException(
        'The server returned an invalid download URL.',
      );
    }
    final response = await _client.get(_validatedStorageUrl(downloadUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceApiException(
        response.statusCode,
        'project_file_download_failed',
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty ||
        bytes.length > StudioProjectAsset.maxFileBytes ||
        (asset.sizeBytes > 0 && bytes.length != asset.sizeBytes)) {
      throw const FormatException('The stored project file is invalid.');
    }
    return bytes;
  }

  bool _isAssetPath(String path, String projectId, String assetId) {
    final segments = path.split('/');
    final safeSegment = RegExp(r'^[A-Za-z0-9._-]{1,160}$');
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return segments.length == 3 &&
        segments[1] == projectId &&
        segments[2] == assetId &&
        (segments[0] == workspaceId || uuid.hasMatch(segments[0])) &&
        segments.every(safeSegment.hasMatch);
  }

  Uri _validatedStorageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        !(uri.scheme == 'https' ||
            uri.scheme == 'http' &&
                const {'localhost', '127.0.0.1'}.contains(uri.host))) {
      throw const FormatException(
        'The server returned an invalid storage URL.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> _requestFileAction(
    Map<String, Object?> body,
  ) async {
    final response = await _client.post(
      baseUri.resolve('/api/project-files'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<void> _deleteProjectFilePaths(Set<String> paths) async {
    if (paths.isEmpty) return;
    final response = await _client.delete(
      baseUri.resolve('/api/project-files'),
      headers: await _headers(),
      body: jsonEncode({'paths': paths.toList()}),
    );
    _decodeResponse(response);
  }

  Future<Map<String, Object?>> _prepareStoredSnapshot(
    Map<String, Object?> snapshot,
    List<String> uploadedThisSave,
  ) async {
    final prepared = Map<String, Object?>.from(snapshot);
    final delivery = Map<String, dynamic>.from(
      snapshot['delivery']! as Map<String, dynamic>,
    );
    final assets = delivery['assets']! as List<dynamic>;
    final storedAssets = <Map<String, Object?>>[];
    for (final value in assets) {
      final asset = Map<String, dynamic>.from(value as Map<String, dynamic>);
      final id = asset['id'] as String;
      final projectId = asset['projectId'] as String;
      final dataBase64 = asset['dataBase64'] as String? ?? '';
      var path = asset['storagePath'] as String?;
      final byteLength =
          asset['byteLength'] as int? ??
          (dataBase64.isEmpty ? 0 : base64Decode(dataBase64).length);
      if (path == null || path.isEmpty) {
        path = _uploadedPathsByAssetId[id];
        if (path == null) {
          if (dataBase64.isEmpty) {
            throw const FormatException('A project file has no stored data.');
          }
          final bytes = base64Decode(dataBase64);
          path = await uploadProjectFile(
            projectId: projectId,
            assetId: id,
            mimeType: asset['mimeType'] as String,
            bytes: Uint8List.fromList(bytes),
          );
          uploadedThisSave.add(path);
        }
      }
      if (!_isAssetPath(path, projectId, id)) {
        throw const FormatException('A project file path is invalid.');
      }
      asset
        ..remove('dataBase64')
        ..['storagePath'] = path
        ..['byteLength'] = byteLength;
      storedAssets.add(asset);
    }
    delivery['assets'] = storedAssets;
    prepared['delivery'] = delivery;
    return prepared;
  }

  Set<String> _storedAssetPaths(Map<String, Object?>? snapshot) {
    final delivery = snapshot?['delivery'];
    if (delivery is! Map<String, dynamic>) return {};
    final assets = delivery['assets'];
    if (assets is! List<dynamic>) return {};
    return assets
        .whereType<Map<String, dynamic>>()
        .map((asset) => asset['storagePath'])
        .whereType<String>()
        .toSet();
  }

  void _rememberAssetPaths(Map<String, Object?> snapshot) {
    final delivery = snapshot['delivery'];
    if (delivery is! Map<String, dynamic>) return;
    final assets = delivery['assets'];
    if (assets is! List<dynamic>) return;
    for (final value in assets.whereType<Map<String, dynamic>>()) {
      final id = value['id'];
      final path = value['storagePath'];
      if (id is String && path is String) {
        _uploadedPathsByAssetId[id] = path;
      }
    }
  }

  Future<void> _removeObsoleteAssets(
    Set<String> previousPaths,
    Set<String> currentPaths,
  ) async {
    final obsolete = previousPaths.difference(currentPaths);
    if (obsolete.isEmpty) return;
    try {
      await _deleteProjectFilePaths(obsolete);
    } on Exception catch (error) {
      debugPrint(
        'Removed project files from workspace records, but Storage cleanup failed: $error',
      );
    }
  }

  Future<void> _removeUploadedPaths(List<String> paths) async {
    final cleanup = {...paths, ..._pendingUploads};
    if (cleanup.isEmpty) return;
    try {
      await _deleteProjectFilePaths(cleanup);
      for (final path in cleanup) {
        _pendingUploads.remove(path);
        _uploadedPathsByAssetId.removeWhere((_, value) => value == path);
      }
    } on Exception catch (error) {
      debugPrint('Could not roll back uploaded project files: $error');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('The server returned an invalid response.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw WorkspaceApiException(
        response.statusCode,
        error is String ? error : 'unknown_error',
      );
    }
    return decoded;
  }

  Map<String, Object?> _changedCollections(
    Map<String, Object?> previous,
    Map<String, Object?> current,
  ) {
    final changes = <String, Object?>{};
    void compare(String path, Object? oldValue, Object? newValue) {
      if (jsonEncode(oldValue) != jsonEncode(newValue)) {
        changes[path] = newValue;
      }
    }

    for (final field in [
      'customers',
      'pipelineStages',
      'activities',
      'personas',
      'preferences',
      'communications',
    ]) {
      compare(field, previous[field], current[field]);
    }
    for (final field in [
      'projects',
      'phases',
      'tasks',
      'milestones',
      'materials',
      'vendors',
      'requisitions',
      'rfqs',
      'vendorQuotes',
      'purchaseOrders',
      'punchItems',
      'assets',
      'workLogs',
      'attendance',
      'approvals',
    ]) {
      compare(
        'delivery.$field',
        (previous['delivery'] as Map<String, dynamic>)[field],
        (current['delivery'] as Map<String, dynamic>)[field],
      );
    }
    for (final field in ['quotations', 'templates', 'proposals', 'invoices']) {
      compare(
        'financials.$field',
        (previous['financials'] as Map<String, dynamic>)[field],
        (current['financials'] as Map<String, dynamic>)[field],
      );
    }
    compare(
      'financials.settings',
      (previous['financials'] as Map<String, dynamic>)['settings'],
      (current['financials'] as Map<String, dynamic>)['settings'],
    );
    return changes;
  }

  CustomerWorkspace _emptyWorkspace(List<String> initialStages) {
    final stages = List<String>.of(initialStages);
    return CustomerWorkspace(
      customers: const [],
      pipelineStages: stages,
      activities: const [],
      personas: StudioPersona.defaults(),
      preferences: WorkspacePreferences.defaults(
        defaultPipelineStage: stages.isEmpty ? '' : stages.first,
      ),
      delivery: StudioDeliveryWorkspace.forCustomers(const []),
      financials: StudioFinancialWorkspace.defaults(),
      communications: const [],
    );
  }

  @visibleForTesting
  int get revision => _revision;

  bool get isNewWorkspace => _isNewWorkspace;

  void close() => _client.close();
}
