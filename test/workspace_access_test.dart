import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raams_crm/backend/workspace_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('organization selection parses roles and scoped permissions', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/workspaces');
      expect(request.headers['authorization'], 'Bearer token');
      return http.Response(
        jsonEncode({
          'workspaces': [
            {
              'id': 'workspace-1',
              'name': 'Build Co',
              'userId': 'member-1',
              'role': {
                'id': 'role-1',
                'name': 'Member',
                'permissions': ['workspace.read'],
              },
              'projectPermissions': [
                ['manageTasks'],
              ],
            },
          ],
        }),
        200,
      );
    });
    final access = WorkspaceAccessClient(
      baseUri: Uri.parse('https://api.example.test'),
      accessTokenProvider: () async => 'token',
      client: client,
    );

    final organizations = await access.loadOrganizations();

    expect(organizations.single.id, 'workspace-1');
    expect(organizations.single.userId, 'member-1');
    expect(organizations.single.projectPermissions, ['manageTasks']);
    access.close();
  });

  test(
    'workspace access calls are scoped to the selected organization',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['x-workspace-id'], 'workspace-1');
        expect(jsonDecode(request.body)['action'], 'invite_member');
        return http.Response('{"invitation":{"id":"invite-1"}}', 201);
      });
      final access = WorkspaceAccessClient(
        baseUri: Uri.parse('https://api.example.test'),
        workspaceId: 'workspace-1',
        accessTokenProvider: () async => 'token',
        client: client,
      );

      await access.inviteMember('person@example.test', 'role-1');

      access.close();
    },
  );

  test('project assignees are requested for a specific project', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/workspace-access');
      expect(request.url.queryParameters['projectId'], 'project 1');
      expect(request.headers['x-workspace-id'], 'workspace-1');
      return http.Response(
        jsonEncode({
          'assignees': ['Site lead (12345678)'],
        }),
        200,
      );
    });
    final access = WorkspaceAccessClient(
      baseUri: Uri.parse('https://api.example.test'),
      workspaceId: 'workspace-1',
      accessTokenProvider: () async => 'token',
      client: client,
    );

    final assignees = await access.loadProjectAssignees('project 1');

    expect(assignees, ['Site lead (12345678)']);
    access.close();
  });
}
