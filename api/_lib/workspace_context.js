const { WorkspaceAccessError } = require('./database');

const workspaceIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function getWorkspaceId(req) {
  const workspaceId = req.headers?.['x-workspace-id'];
  if (typeof workspaceId !== 'string' ||
      !workspaceIdPattern.test(workspaceId)) {
    throw new WorkspaceAccessError(400, 'workspace_required');
  }
  return workspaceId;
}

module.exports = { getWorkspaceId };
