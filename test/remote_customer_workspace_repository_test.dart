import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raams_crm/backend/remote_customer_workspace_repository.dart';
import 'package:raams_crm/customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Customer> createCustomers(int count) => List.generate(
    count,
    (index) => Customer(
      id: 'customer-$index',
      name: 'Customer $index',
      project: 'Project $index',
      stage: 'New inquiry',
      value: '—',
      email: 'customer$index@example.test',
      phone: '',
      notes: '',
      initials: 'C$index',
      tint: Colors.blue,
    ),
  );

  Future<Map<String, List<Map<String, dynamic>>>> createPageData(
    List<Customer> customers,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const codec = SharedPreferencesCustomerWorkspaceRepository();
    final workspace = await codec.loadWorkspace(
      initialCustomers: customers,
      initialStages: const ['New inquiry', 'Discovery'],
    );
    final snapshot = codec.encodeWorkspaceData(
      customers: workspace.customers,
      pipelineStages: workspace.pipelineStages,
      activities: workspace.activities,
      personas: workspace.personas,
      preferences: workspace.preferences,
      delivery: workspace.delivery,
      financials: workspace.financials,
      communications: workspace.communications,
    );
    List<Map<String, dynamic>> maps(Object? value) => (value as List<dynamic>)
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();
    final delivery = snapshot['delivery']! as Map<String, Object?>;
    final financials = snapshot['financials']! as Map<String, Object?>;
    return {
      'customers': maps(snapshot['customers']),
      'pipelineStages': [
        for (
          var index = 0;
          index < (snapshot['pipelineStages']! as List<dynamic>).length;
          index++
        )
          {
            'name': (snapshot['pipelineStages']! as List<dynamic>)[index],
            'position': index,
          },
      ],
      'activities': maps(snapshot['activities']),
      'personas': maps(snapshot['personas']),
      'projects': maps(delivery['projects']),
      'tasks': maps(delivery['tasks']),
      'milestones': maps(delivery['milestones']),
      'punchItems': maps(delivery['punchItems']),
      'assets': maps(delivery['assets']),
      'workLogs': maps(delivery['workLogs']),
      'attendance': maps(delivery['attendance']),
      'approvals': maps(delivery['approvals']),
      'quotations': maps(financials['quotations']),
      'templates': maps(financials['templates']),
      'proposals': maps(financials['proposals']),
      'invoices': maps(financials['invoices']),
      'communications': maps(snapshot['communications']),
      'preferences': [
        Map<String, dynamic>.from(snapshot['preferences']! as Map),
      ],
      'financialSettings': [
        Map<String, dynamic>.from(financials['settings']! as Map),
      ],
    };
  }

  test(
    'remote repository loads its server revision and saves with that revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      const codec = SharedPreferencesCustomerWorkspaceRepository();
      final workspace = await codec.loadWorkspace(
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      );
      final snapshot = codec.encodeWorkspaceData(
        customers: workspace.customers,
        pipelineStages: workspace.pipelineStages,
        activities: workspace.activities,
        personas: workspace.personas,
        preferences: workspace.preferences,
        delivery: workspace.delivery,
        financials: workspace.financials,
        communications: workspace.communications,
      );
      final requests = <int>[];
      final client = MockClient((request) async {
        requests.add(request.method == 'GET' ? 0 : 1);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'revision': 7, 'snapshot': snapshot}),
            200,
          );
        }
        expect(jsonDecode(request.body)['revision'], 7);
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response('{"revision":8}', 200);
      });
      final repository = RemoteCustomerWorkspaceRepository(
        baseUri: Uri.parse('https://api.example.test'),
        accessTokenProvider: () async => 'access-token',
        client: client,
      );

      final restored = await repository.loadWorkspace(
        initialCustomers: const [],
        initialStages: const [],
      );
      await repository.saveWorkspace(
        customers: restored.customers,
        pipelineStages: restored.pipelineStages,
        activities: restored.activities,
        personas: restored.personas,
        preferences: restored.preferences,
        delivery: restored.delivery,
        financials: restored.financials,
        communications: restored.communications,
      );

      expect(requests, [0, 1]);
      expect(repository.revision, 8);
      repository.close();
    },
  );

  test(
    'remote repository reports revision conflicts rather than overwriting',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"revision":2,"snapshot":null}', 200);
        }
        return http.Response('{"error":"workspace_revision_conflict"}', 409);
      });
      final repository = RemoteCustomerWorkspaceRepository(
        baseUri: Uri.parse('https://api.example.test'),
        accessTokenProvider: () async => 'access-token',
        client: client,
      );
      final workspace = await repository.loadWorkspace(
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      );

      await expectLater(
        repository.saveWorkspace(
          customers: workspace.customers,
          pipelineStages: workspace.pipelineStages,
          activities: workspace.activities,
          personas: workspace.personas,
          preferences: workspace.preferences,
          delivery: workspace.delivery,
          financials: workspace.financials,
          communications: workspace.communications,
        ),
        throwsA(isA<WorkspaceApiException>()),
      );
      repository.close();
    },
  );

  test(
    'paged workspace loading rebuilds all collections at one revision',
    () async {
      final pageData = await createPageData(createCustomers(101));
      final requestedPages = <String>[];
      final client = MockClient((request) async {
        final collection = request.url.queryParameters['collection']!;
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(request.url.queryParameters['limit'] ?? '50');
        requestedPages.add('$collection:$offset');
        final records = pageData[collection]!;
        final end = offset + limit < records.length
            ? offset + limit
            : records.length;
        return http.Response(
          jsonEncode({
            'collection': collection,
            'records': records.sublist(offset, end),
            'total': records.length,
            'nextOffset': end < records.length ? end : null,
            'revision': 7,
            'workspaceExists': true,
          }),
          200,
        );
      });
      final repository = RemoteCustomerWorkspaceRepository(
        baseUri: Uri.parse('https://api.example.test'),
        accessTokenProvider: () async => 'access-token',
        client: client,
      );

      final workspace = await repository.loadWorkspacePaged(
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      );

      expect(workspace.customers, hasLength(101));
      expect(workspace.customers.last.id, 'customer-100');
      expect(repository.revision, 7);
      expect(requestedPages, contains('customers:100'));
      repository.close();
    },
  );

  test('paged workspace loading rejects pages from mixed revisions', () async {
    final pageData = await createPageData(createCustomers(101));
    final client = MockClient((request) async {
      final collection = request.url.queryParameters['collection']!;
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '50');
      final records = pageData[collection]!;
      final end = offset + limit < records.length
          ? offset + limit
          : records.length;
      return http.Response(
        jsonEncode({
          'collection': collection,
          'records': records.sublist(offset, end),
          'total': records.length,
          'nextOffset': end < records.length ? end : null,
          'revision': collection == 'customers' && offset == 100 ? 8 : 7,
          'workspaceExists': true,
        }),
        200,
      );
    });
    final repository = RemoteCustomerWorkspaceRepository(
      baseUri: Uri.parse('https://api.example.test'),
      accessTokenProvider: () async => 'access-token',
      client: client,
    );

    await expectLater(
      repository.loadWorkspacePaged(
        initialCustomers: const [],
        initialStages: const ['New inquiry', 'Discovery'],
      ),
      throwsA(
        isA<WorkspaceApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
    repository.close();
  });
}
