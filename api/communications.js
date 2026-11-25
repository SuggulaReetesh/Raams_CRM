const nodemailer = require('nodemailer');
const { authenticateRequest } = require('./_lib/auth');
const {
  requirePermission,
  WorkspaceAccessError,
  withWorkspaceTransaction,
} = require('./_lib/database');
const { getWorkspaceId } = require('./_lib/workspace_context');
const { attachRequestId } = require('./_lib/request_id');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');
const { decryptSecrets } = require('./_lib/integration_secrets');
const { HttpError, loadWorkspace, saveWorkspace } = require('./workspace');

const maximumRequestBytes = 16 * 1024;
const validEmail = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const validId = /^[A-Za-z0-9._-]{1,160}$/;

class DeliveryError extends Error {
  constructor(provider, statusCode = null) {
    super('Provider delivery failed.');
    this.name = 'DeliveryError';
    this.provider = provider;
    this.statusCode = statusCode;
  }
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function prepareMessage(value, snapshot) {
  const procurementCollections = new Map([
    ['requisition', snapshot.delivery.requisitions],
    ['rfq', snapshot.delivery.rfqs],
    ['quote', snapshot.delivery.vendorQuotes],
    ['purchaseOrder', snapshot.delivery.purchaseOrders],
  ]);
  const relatedProcurementRecord =
    value?.procurementRecordType == null ||
        value?.procurementRecordId == null
      ? null
      : procurementCollections.get(value.procurementRecordType)?.find(
          (record) => record.id === value.procurementRecordId,
        );
  const vendor = value?.vendorId == null
    ? null
    : snapshot.delivery.vendors.find(
        (item) => item.id === value.vendorId,
      );
  if (!isRecord(value) ||
      typeof value.id !== 'string' ||
      !validId.test(value.id) ||
      !['Email', 'WhatsApp'].includes(value.channel) ||
      typeof value.recipient !== 'string' ||
      typeof value.body !== 'string' ||
      value.body.trim().length === 0 ||
      value.body.length > (value.channel === 'WhatsApp' ? 4096 : 5000) ||
      typeof value.subject !== 'string' ||
      value.subject.length > 200 ||
      /[\r\n]/.test(value.subject) ||
      typeof value.createdByPersonaId !== 'string' ||
      typeof value.createdByName !== 'string' ||
      (value.vendorId != null && !vendor) ||
      (value.procurementRecordId != null &&
        (!relatedProcurementRecord ||
          relatedProcurementRecord.projectId !== value.projectId)) ||
      (value.procurementRecordType != null &&
        value.procurementRecordId == null) ||
      (value.procurementRecordId != null &&
        value.procurementRecordType == null) ||
      (value.procurementRecordType === 'rfq' &&
        value.vendorId != null &&
        !relatedProcurementRecord.vendorIds.includes(value.vendorId)) ||
      (['quote', 'purchaseOrder'].includes(value.procurementRecordType) &&
        value.vendorId != null &&
        relatedProcurementRecord.vendorId !== value.vendorId) ||
      (value.vendorId != null &&
        value.procurementRecordId != null &&
        value.procurementRecordType === 'requisition') ||
      value.createdByName.trim().length === 0 ||
      value.createdByName.length > 120 ||
      !Array.isArray(value.mentionedPersonaIds) ||
      !validId.test(value.createdByPersonaId) ||
      (value.clientId != null &&
        !snapshot.customers.some((customer) => customer.id === value.clientId)) ||
      (value.projectId != null &&
        !snapshot.delivery.projects.some((project) =>
          project.id === value.projectId)) ||
      (value.channel === 'Email' &&
        (!validEmail.test(value.recipient) || value.recipient.length > 254)) ||
      (value.channel === 'WhatsApp' &&
        !/^\+?[1-9]\d{7,14}$/.test(
          value.recipient.replace(/[\s().-]/g, ''),
        ))) {
    throw new HttpError(400, 'invalid_outbound_message');
  }
  if (!snapshot.personas.some((persona) =>
    persona.id === value.createdByPersonaId)) {
    throw new HttpError(400, 'invalid_message_author');
  }
  const project = value.projectId == null
    ? null
    : snapshot.delivery.projects.find((item) => item.id === value.projectId);
  const client = value.clientId == null
    ? null
    : snapshot.customers.find((item) => item.id === value.clientId);
  if (project?.customerId && client && project.customerId !== client.id) {
    throw new HttpError(400, 'invalid_message_references');
  }
  const now = new Date().toISOString();
  return {
    id: value.id,
    clientId: client?.id ?? null,
    clientName: client?.name ?? '',
    vendorId: vendor?.id ?? null,
    procurementRecordType: value.procurementRecordType ?? null,
    procurementRecordId: relatedProcurementRecord?.id ?? null,
    projectId: project?.id ?? null,
    projectName: project?.name ?? '',
    channel: value.channel,
    subject: value.subject.trim(),
    body: value.body.trim(),
    recipient: value.channel === 'WhatsApp'
      ? value.recipient.replace(/\D/g, '')
      : value.recipient.trim(),
    status: 'Sending',
    createdByPersonaId: value.createdByPersonaId,
    createdByName: value.createdByName.trim(),
    createdAt: now,
    updatedAt: now,
    mentionedPersonaIds: [],
    readByPersonaIds: [],
  };
}

async function loadProviderSettings(client, workspaceId, provider, env) {
  const result = await client.query(
    `SELECT i.*
     FROM workspace_integrations i
     JOIN workspaces w ON w.id = i.workspace_id
     WHERE w.id = $1 AND i.provider = $2`,
    [workspaceId, provider],
  );
  if (result.rows.length === 0) {
    throw new HttpError(409, 'integration_not_configured');
  }
  return decryptSecrets(
    result.rows[0],
    `${workspaceId}:${provider}`,
    env,
  );
}

async function deliverEmail(settings, message, env) {
  const host = env.POSTAL_SMTP_HOST?.trim();
  const port = Number(env.POSTAL_SMTP_PORT || 587);
  if (!host || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new HttpError(503, 'postal_smtp_not_configured');
  }
  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port !== 465,
    auth: {
      user: settings.smtpUser,
      pass: settings.smtpPassword,
    },
    tls: { minVersion: 'TLSv1.2' },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 20000,
  });
  try {
    const result = await transporter.sendMail({
      from: { name: settings.fromName, address: settings.fromAddress },
      to: message.recipient,
      subject: message.subject,
      text: message.body,
    });
    return result.messageId || null;
  } catch (error) {
    throw new DeliveryError('postal', Number.isInteger(error?.responseCode)
      ? error.responseCode
      : null);
  } finally {
    transporter.close();
  }
}

async function deliverWhatsApp(settings, message, env) {
  const version = env.WHATSAPP_GRAPH_API_VERSION?.trim();
  if (!version || !/^v\d+\.\d+$/.test(version)) {
    throw new HttpError(503, 'whatsapp_api_version_not_configured');
  }
  let response;
  try {
    response = await fetch(
      `https://graph.facebook.com/${version}/${settings.phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${settings.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: message.recipient,
          type: 'text',
          text: { preview_url: false, body: message.body },
        }),
        signal: AbortSignal.timeout(15000),
      },
    );
  } catch {
    throw new DeliveryError('whatsapp');
  }
  if (!response.ok) {
    throw new DeliveryError('whatsapp', response.status);
  }
  let result;
  try {
    result = await response.json();
  } catch {
    throw new DeliveryError('whatsapp');
  }
  const providerMessageId = result?.messages?.[0]?.id;
  if (typeof providerMessageId !== 'string' ||
      providerMessageId.length === 0 ||
      providerMessageId.length > 200) {
    throw new DeliveryError('whatsapp');
  }
  return providerMessageId;
}

function createCommunicationsHandler({
  authenticate = authenticateRequest,
  withWorkspace = withWorkspaceTransaction,
  loadWorkspaceFn = loadWorkspace,
  saveWorkspaceFn = saveWorkspace,
  rateLimit = null,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function communicationsHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId, profile } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(userId, 'communications_send', {
          limit: 10,
          windowSeconds: 60,
        });
      }
      const workspaceId = getWorkspaceId(req);
      if (!isRecord(req.body) ||
          Buffer.byteLength(JSON.stringify(req.body)) > maximumRequestBytes ||
          !Number.isSafeInteger(req.body.revision) ||
          req.body.revision < 0 ||
          !isRecord(req.body.message)) {
        throw new HttpError(400, 'invalid_communication_request');
      }

      const requestedMessage = req.body.message;
      if (typeof requestedMessage.id !== 'string' ||
          !validId.test(requestedMessage.id) ||
          !['Email', 'WhatsApp'].includes(requestedMessage.channel) ||
          typeof requestedMessage.recipient !== 'string' ||
          typeof requestedMessage.subject !== 'string' ||
          typeof requestedMessage.body !== 'string') {
        throw new HttpError(400, 'invalid_outbound_message');
      }

      const provider = requestedMessage.channel === 'Email'
        ? 'postal'
        : 'whatsapp';
      const initial = await withWorkspace(
        userId,
        workspaceId,
        async (client, access) => {
        requirePermission(access, 'manageCommunications');
        const current = await loadWorkspaceFn(client, userId);
        if (!current.snapshot) throw new HttpError(404, 'workspace_not_found');
        const existing = current.snapshot.communications.find(
          (entry) => entry.id === requestedMessage.id,
        );
        if (existing) {
          const requestedRecipient = requestedMessage.channel === 'WhatsApp'
            ? requestedMessage.recipient.replace(/\D/g, '')
            : requestedMessage.recipient.trim();
          const sameContent = existing.channel === requestedMessage.channel &&
            existing.recipient === requestedRecipient &&
            existing.subject === requestedMessage.subject.trim() &&
            existing.body === requestedMessage.body.trim();
          if (!sameContent) {
            throw new HttpError(409, 'communication_idempotency_conflict');
          }
          return {
            communication: existing,
            revision: current.revision,
            shouldDeliver: false,
          };
        }
        if (current.revision !== req.body.revision) {
          throw new HttpError(409, 'workspace_revision_conflict');
        }
        const message = prepareMessage(requestedMessage, current.snapshot);
        await loadProviderSettings(
          client,
          workspaceId,
          provider,
          env,
        );
        const snapshot = {
          ...current.snapshot,
          communications: [message, ...current.snapshot.communications],
        };
        const revision = await saveWorkspaceFn(
          client,
          userId,
          current.revision,
          snapshot,
          profile,
          new Set(['communications']),
          false,
        );
        return { communication: message, revision, shouldDeliver: true };
        },
      );

      if (!initial.shouldDeliver) {
        return res.status(200).json({
          communication: initial.communication,
          revision: initial.revision,
          deliveryError: initial.communication.status === 'Failed'
            ? 'provider_delivery_failed'
            : null,
        });
      }

      let providerMessageId = null;
      let deliveryFailed = false;
      try {
        const settings = await withWorkspace(
          userId,
          workspaceId,
          (client) => loadProviderSettings(client, workspaceId, provider, env),
        );
        providerMessageId = provider === 'postal'
          ? await deliverEmail(settings, initial.communication, env)
          : await deliverWhatsApp(settings, initial.communication, env);
      } catch (error) {
        deliveryFailed = true;
        logger('Communication provider delivery failed.', {
          requestId,
          provider,
          ...(Number.isInteger(error?.statusCode)
            ? { statusCode: error.statusCode }
            : {}),
          ...(Number.isInteger(error?.responseCode)
            ? { responseCode: error.responseCode }
            : {}),
        });
      }

      let completed;
      for (let attempt = 0; attempt < 3; attempt += 1) {
        try {
          completed = await withWorkspace(
            userId,
            workspaceId,
            async (client) => {
            const current = await loadWorkspaceFn(client, userId);
            if (!current.snapshot) {
              throw new HttpError(404, 'workspace_not_found');
            }
            const message = current.snapshot.communications.find(
              (entry) => entry.id === initial.communication.id,
            );
            if (!message) throw new HttpError(404, 'communication_not_found');
            const updated = {
              ...message,
              status: deliveryFailed ? 'Failed' : 'Sent',
              updatedAt: new Date().toISOString(),
            };
            const snapshot = {
              ...current.snapshot,
              communications: current.snapshot.communications.map((entry) =>
                entry.id === updated.id ? updated : entry),
            };
            const revision = await saveWorkspaceFn(
              client,
              userId,
              current.revision,
              snapshot,
              profile,
              new Set(['communications']),
              false,
            );
            if (providerMessageId) {
              await client.query(
                `UPDATE communication_messages
                 SET provider_message_id = $3
                 WHERE workspace_id = $1 AND id = $2`,
                [workspaceId, updated.id, providerMessageId],
              );
            }
            return { communication: updated, revision };
            },
          );
          break;
        } catch (error) {
          if (!(error instanceof HttpError) ||
              error.code !== 'workspace_revision_conflict' ||
              attempt === 2) {
            throw error;
          }
        }
      }
      return res.status(200).json({
        ...completed,
        deliveryError: deliveryFailed ? 'provider_delivery_failed' : null,
      });
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError || error instanceof WorkspaceAccessError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ||
              error instanceof WorkspaceAccessError
            ? error.code
            : 'unauthorized',
        });
      }
      logger('Communications API request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createCommunicationsHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, {
  createCommunicationsHandler,
  prepareMessage,
});
module.exports = handler;
