import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:raams_crm/backend/remote_customer_workspace_repository.dart';

typedef WorkspaceAccessTokenProvider = Future<String?> Function();

class OrganizationWorkspace {
  const OrganizationWorkspace({
    required this.id,
    required this.name,
    required this.userId,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.projectPermissions,
  });

  final String id;
  final String name;
  final String userId;
  final String roleId;
  final String roleName;
  final List<String> permissions;
  final List<String> projectPermissions;

  factory OrganizationWorkspace.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final projectPermissions = json['projectPermissions'];
    if (json['id'] is! String ||
        json['name'] is! String ||
        json['userId'] is! String ||
        role is! Map<String, dynamic> ||
        role['id'] is! String ||
        role['name'] is! String ||
        role['permissions'] is! List<dynamic> ||
        !(role['permissions'] as List<dynamic>).every(
          (permission) => permission is String,
        ) ||
        projectPermissions is! List<dynamic> ||
        !projectPermissions.every(
          (permissions) =>
              permissions is List<dynamic> &&
              permissions.every((permission) => permission is String),
        )) {
      throw const FormatException(
        'The server returned an invalid organization.',
      );
    }
    return OrganizationWorkspace(
      id: json['id'] as String,
      name: json['name'] as String,
      userId: json['userId'] as String,
      roleId: role['id'] as String,
      roleName: role['name'] as String,
      permissions: (role['permissions'] as List<dynamic>).cast<String>(),
      projectPermissions: projectPermissions
          .cast<List<dynamic>>()
          .expand((permissions) => permissions.cast<String>())
          .toSet()
          .toList(),
    );
  }
}

class WorkspaceInvitation {
  const WorkspaceInvitation({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.roleName,
  });

  final String id;
  final String workspaceId;
  final String workspaceName;
  final String roleName;

  factory WorkspaceInvitation.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['workspaceId'] is! String ||
        json['workspaceName'] is! String ||
        json['roleName'] is! String) {
      throw const FormatException('The server returned an invalid invitation.');
    }
    return WorkspaceInvitation(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      workspaceName: json['workspaceName'] as String,
      roleName: json['roleName'] as String,
    );
  }
}

class WorkspaceAccessClient {
  WorkspaceAccessClient({
    required this.baseUri,
    required this.accessTokenProvider,
    this.workspaceId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final WorkspaceAccessTokenProvider accessTokenProvider;
  final String? workspaceId;
  final http.Client _client;

  Future<List<OrganizationWorkspace>> loadOrganizations() async {
    final body = await _request('GET', '/api/workspaces');
    final workspaces = body['workspaces'];
    if (workspaces is! List<dynamic>) {
      throw const FormatException('The server returned invalid organizations.');
    }
    return workspaces.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'The server returned an invalid organization.',
        );
      }
      return OrganizationWorkspace.fromJson(item);
    }).toList();
  }

  Future<List<WorkspaceInvitation>> loadInvitations() async {
    final body = await _request('GET', '/api/workspace-access');
    final invitations = body['invitations'];
    if (invitations is! List<dynamic>) {
      throw const FormatException('The server returned invalid invitations.');
    }
    return invitations.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'The server returned an invalid invitation.',
        );
      }
      return WorkspaceInvitation.fromJson(item);
    }).toList();
  }

  Future<OrganizationWorkspace> createOrganization(String name) async {
    final body = await _request(
      'POST',
      '/api/workspaces',
      requestBody: {'name': name},
    );
    final workspace = body['workspace'];
    if (workspace is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid organization.',
      );
    }
    return OrganizationWorkspace.fromJson(workspace);
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _request(
      'POST',
      '/api/workspace-access',
      requestBody: {
        'action': 'accept_invitation',
        'invitationId': invitationId,
      },
    );
  }

  Future<WorkspaceAccessData> loadAccess() async {
    final body = await _request('GET', '/api/workspace-access');
    final members = body['members'];
    final roles = body['roles'];
    final invitations = body['invitations'];
    final projectMemberships = body['projectMemberships'];
    if (members is! List<dynamic> ||
        roles is! List<dynamic> ||
        invitations is! List<dynamic> ||
        projectMemberships is! List<dynamic>) {
      throw const FormatException('The server returned invalid access data.');
    }
    return WorkspaceAccessData(
      members: members
          .map((item) => WorkspaceAccessMember.fromJson(_object(item)))
          .toList(),
      roles: roles
          .map((item) => WorkspaceRole.fromJson(_object(item)))
          .toList(),
      invitations: invitations.map(_object).toList(),
      projectMemberships: projectMemberships.map(_object).toList(),
    );
  }

  Future<List<String>> loadProjectAssignees(String projectId) async {
    final path =
        '/api/workspace-access?projectId=${Uri.encodeQueryComponent(projectId)}';
    final body = await _request('GET', path);
    final assignees = body['assignees'];
    if (assignees is! List<dynamic> ||
        !assignees.every((assignee) => assignee is String)) {
      throw const FormatException(
        'The server returned invalid project assignees.',
      );
    }
    return assignees.cast<String>();
  }

  Future<void> inviteMember(String email, String roleId) async {
    await _action({
      'action': 'invite_member',
      'email': email,
      'roleId': roleId,
    });
  }

  Future<void> createRole({
    required String scope,
    required String name,
    required List<String> permissions,
    String? projectId,
  }) async {
    await _action({
      'action': 'create_role',
      'scope': scope,
      'name': name,
      'permissions': permissions,
      if (projectId != null) 'projectId': projectId,
    });
  }

  Future<void> updateRole({
    required String roleId,
    required String name,
    required List<String> permissions,
  }) async {
    await _action({
      'action': 'update_role',
      'roleId': roleId,
      'name': name,
      'permissions': permissions,
    });
  }

  Future<void> assignMemberRole(String userId, String roleId) async {
    await _action({
      'action': 'assign_member_role',
      'userId': userId,
      'roleId': roleId,
    });
  }

  Future<void> assignProjectRole({
    required String projectId,
    required String userId,
    required String roleId,
  }) async {
    await _action({
      'action': 'assign_project_role',
      'projectId': projectId,
      'userId': userId,
      'roleId': roleId,
    });
  }

  Future<void> removeMember(String userId) async {
    await _action({'action': 'remove_member', 'userId': userId});
  }

  Future<void> setMemberStatus(String userId, String status) async {
    await _action({
      'action': 'set_member_status',
      'userId': userId,
      'status': status,
    });
  }

  Future<void> revokeInvitation(String invitationId) async {
    await _action({
      'action': 'revoke_invitation',
      'invitationId': invitationId,
    });
  }

  Future<void> _action(Map<String, Object?> requestBody) async {
    await _request('POST', '/api/workspace-access', requestBody: requestBody);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? requestBody,
  }) async {
    final token = await accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const WorkspaceApiException(401, 'unauthorized');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (workspaceId != null) 'X-Workspace-Id': workspaceId!,
    };
    final uri = baseUri.resolve(path);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
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

  void close() => _client.close();

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The server returned invalid access data.');
    }
    return value;
  }
}

class WorkspaceAccessData {
  const WorkspaceAccessData({
    required this.members,
    required this.roles,
    required this.invitations,
    required this.projectMemberships,
  });

  final List<WorkspaceAccessMember> members;
  final List<WorkspaceRole> roles;
  final List<Map<String, dynamic>> invitations;
  final List<Map<String, dynamic>> projectMemberships;
}

class WorkspaceAccessMember {
  const WorkspaceAccessMember({
    required this.id,
    required this.displayName,
    required this.email,
    required this.status,
    required this.roleId,
    required this.roleName,
  });

  final String id;
  final String displayName;
  final String? email;
  final String status;
  final String roleId;
  final String roleName;

  factory WorkspaceAccessMember.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['displayName'] is! String ||
        json['status'] is! String ||
        json['roleId'] is! String ||
        json['roleName'] is! String ||
        (json['email'] != null && json['email'] is! String)) {
      throw const FormatException('The server returned an invalid member.');
    }
    return WorkspaceAccessMember(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      status: json['status'] as String,
      roleId: json['roleId'] as String,
      roleName: json['roleName'] as String,
    );
  }
}

class WorkspaceRole {
  const WorkspaceRole({
    required this.id,
    required this.scope,
    required this.projectId,
    required this.name,
    required this.permissions,
    required this.isSystem,
  });

  final String id;
  final String scope;
  final String? projectId;
  final String name;
  final List<String> permissions;
  final bool isSystem;

  factory WorkspaceRole.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'];
    if (json['id'] is! String ||
        json['scope'] is! String ||
        json['name'] is! String ||
        permissions is! List<dynamic> ||
        !permissions.every((permission) => permission is String) ||
        json['isSystem'] is! bool ||
        (json['projectId'] != null && json['projectId'] is! String)) {
      throw const FormatException('The server returned an invalid role.');
    }
    return WorkspaceRole(
      id: json['id'] as String,
      scope: json['scope'] as String,
      projectId: json['projectId'] as String?,
      name: json['name'] as String,
      permissions: permissions.cast<String>(),
      isSystem: json['isSystem'] as bool,
    );
  }
}
