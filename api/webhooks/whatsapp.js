const {
  createHash,
  createHmac,
  timingSafeEqual,
} = require('node:crypto');
const { getPool, withUserTransaction } = require('../_lib/database');
const { HttpError, loadWorkspace, saveWorkspace } = require('../workspace');
const { attachRequestId } = require('../_lib/request_id');

const maximumWebhookBytes = 1024 * 1024;
const statusOrder = {
  Draft: 0,
  'Ready to send': 1,
  Queued: 2,
  Sending: 3,
  Sent: 4,
  Delivered: 5,
  Read: 6,
  Failed: 7,
};

function providerStatus(status) {
  switch (status) {
    case 'sent': return 'Sent';
    case 'delivered': return 'Delivered';
    case 'read': return 'Read';
    case 'failed': return 'Failed';
    default: return null;
  }
}

function isValidSignature(rawBody, signature, appSecret) {
  if (typeof signature !== 'string' ||
      !/^sha256=[0-9a-f]{64}$/i.test(signature) ||
      typeof appSecret !== 'string' ||
      appSecret.length === 0) {
    return false;
  }
  const expected = createHmac('sha256', appSecret)
    .update(rawBody)
    .digest();
  const supplied = Buffer.from(signature.slice(7), 'hex');
  return supplied.length === expected.length &&
    timingSafeEqual(supplied, expected);
}

async function readRawBody(req) {
  const chunks = [];
  let length = 0;
  for await (const chunk of req) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    length += bytes.length;
    if (length > maximumWebhookBytes) {
      throw new HttpError(413, 'webhook_payload_too_large');
    }
    chunks.push(bytes);
  }
  return Buffer.concat(chunks, length);
}

function webhookTimestamp(value) {
  const seconds = Number(value);
  if (!Number.isSafeInteger(seconds) || seconds < 0) return new Date();
  const date = new Date(seconds * 1000);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

async function persistWebhookEvent({
  ownerUserId,
  workspaceId,
  eventId,
  providerMessageId,
  eventType,
  payloadHash,
  occurredAt,
  operation,
}) {
  return withUserTransaction(ownerUserId, async (client) => {
    const inserted = await client.query(
      `INSERT INTO communication_provider_events
         (workspace_id, provider, event_id, provider_message_id, event_type,
          payload_hash, occurred_at)
       VALUES ($1, 'whatsapp', $2, $3, $4, $5, $6)
       ON CONFLICT (workspace_id, provider, event_id) DO NOTHING
       RETURNING event_id`,
      [
        workspaceId,
        eventId,
        providerMessageId,
        eventType,
        payloadHash,
        occurredAt,
      ],
    );
    if (inserted.rowCount === 0) return false;
    await operation(client);
    return true;
  });
}

async function updateOutboundStatus({
  client,
  ownerUserId,
  workspaceId,
  providerMessageId,
  nextStatus,
  occurredAt,
}) {
  const result = await client.query(
    `SELECT id
     FROM communication_messages
     WHERE workspace_id = $1 AND provider_message_id = $2`,
    [workspaceId, providerMessageId],
  );
  if (result.rows.length === 0) return;
  const current = await loadWorkspace(client, ownerUserId);
  if (!current.snapshot) return;
  const message = current.snapshot.communications.find(
    (entry) => entry.id === result.rows[0].id,
  );
  if (!message) return;
  const currentOrder = statusOrder[message.status] ?? -1;
  const nextOrder = statusOrder[nextStatus] ?? -1;
  const successfulDelivery = ['Delivered', 'Read'].includes(nextStatus);
  if ((message.status === 'Failed' && !successfulDelivery) ||
      (['Delivered', 'Read'].includes(message.status) &&
        nextStatus === 'Failed') ||
      (message.status !== 'Failed' && nextOrder <= currentOrder)) {
    return;
  }

  const updated = {
    ...message,
    status: nextStatus,
    updatedAt: occurredAt.toISOString(),
  };
  const snapshot = {
    ...current.snapshot,
    communications: current.snapshot.communications.map((entry) =>
      entry.id === updated.id ? updated : entry),
  };
  const profile = await loadOwnerProfile(client, workspaceId);
  await saveWorkspace(
    client,
    ownerUserId,
    current.revision,
    snapshot,
    profile,
    new Set(['communications']),
    false,
  );
}

async function saveInboundMessage({
  client,
  ownerUserId,
  workspaceId,
  providerMessageId,
  from,
  messageType,
  body,
  occurredAt,
}) {
  const current = await loadWorkspace(client, ownerUserId);
  if (!current.snapshot) return;
  const id = `whatsapp-${createHash('sha256')
    .update(providerMessageId)
    .digest('hex')
    .slice(0, 40)}`;
  if (current.snapshot.communications.some((entry) => entry.id === id)) {
    await client.query(
      `UPDATE communication_messages
       SET provider_message_id = $3
       WHERE workspace_id = $1 AND id = $2`,
      [workspaceId, id, providerMessageId],
    );
    return;
  }
  const persona = current.snapshot.personas[0];
  if (!persona) return;
  const text = typeof body === 'string' && body.trim().length > 0
    ? body.trim().slice(0, 5000)
    : `Received ${messageType} WhatsApp message`;
  const now = occurredAt.toISOString();
  const incoming = {
    id,
    clientId: null,
    clientName: '',
    projectId: null,
    projectName: '',
    channel: 'WhatsApp',
    subject: 'Received WhatsApp message',
    body: text,
    recipient: from,
    status: 'Received',
    createdByPersonaId: persona.id,
    createdByName: 'WhatsApp',
    createdAt: now,
    updatedAt: now,
    mentionedPersonaIds: [],
    readByPersonaIds: [],
  };
  const snapshot = {
    ...current.snapshot,
    communications: [incoming, ...current.snapshot.communications],
  };
  const profile = await loadOwnerProfile(client, workspaceId);
  await saveWorkspace(
    client,
    ownerUserId,
    current.revision,
    snapshot,
    profile,
    new Set(['communications']),
    false,
  );
  await client.query(
    `UPDATE communication_messages
     SET provider_message_id = $3
     WHERE workspace_id = $1 AND id = $2`,
    [workspaceId, id, providerMessageId],
  );
}

async function loadOwnerProfile(client, workspaceId) {
  const result = await client.query(
    `SELECT display_name AS "displayName", email
     FROM workspace_owner_profiles WHERE workspace_id = $1`,
    [workspaceId],
  );
  return result.rows[0] || {};
}

async function processPayload(payload, env) {
  if (payload?.object !== 'whatsapp_business_account' ||
      !Array.isArray(payload.entry)) {
    throw new HttpError(400, 'invalid_whatsapp_webhook');
  }
  const pool = getPool(env);
  for (const account of payload.entry) {
    for (const change of Array.isArray(account.changes) ? account.changes : []) {
      if (change.field !== 'messages') continue;
      const value = change.value;
      const accountId = value?.metadata?.phone_number_id;
      if (typeof accountId !== 'string' || !/^\d{6,32}$/.test(accountId) ||
          !Array.isArray(value?.statuses) &&
          !Array.isArray(value?.messages)) {
        continue;
      }
      const accountResult = await pool.query(
        'SELECT workspace_id, owner_user_id FROM lookup_whatsapp_workspace($1)',
        [accountId],
      );
      if (accountResult.rows.length === 0) continue;
      const { workspace_id: workspaceId, owner_user_id: ownerUserId } =
        accountResult.rows[0];

      for (const status of Array.isArray(value.statuses) ? value.statuses : []) {
        const mappedStatus = providerStatus(status.status);
        if (mappedStatus == null ||
            typeof status.id !== 'string' ||
            status.id.length > 200 ||
            typeof status.timestamp !== 'string' ||
            !/^\d{1,15}$/.test(status.timestamp)) {
          continue;
        }
        const occurredAt = webhookTimestamp(status.timestamp);
        const eventId = `${status.id}:${status.status}:${status.timestamp}`;
        const event = {
          providerMessageId: status.id,
          status: status.status,
          timestamp: status.timestamp,
        };
        const inserted = await persistWebhookEvent({
          ownerUserId,
          workspaceId,
          eventId,
          providerMessageId: status.id,
          eventType: `status:${status.status}`,
          payloadHash: createHash('sha256')
            .update(JSON.stringify(event))
            .digest('hex'),
          occurredAt,
          operation: (client) => updateOutboundStatus({
            client,
            ownerUserId,
            workspaceId,
            providerMessageId: status.id,
            nextStatus: mappedStatus,
            occurredAt,
          }),
        });
        if (!inserted) continue;
      }

      for (const message of Array.isArray(value.messages) ? value.messages : []) {
        if (typeof message.id !== 'string' ||
            message.id.length > 200 ||
            typeof message.from !== 'string' ||
            !/^\d{8,15}$/.test(message.from) ||
            typeof message.timestamp !== 'string' ||
            !/^\d{1,15}$/.test(message.timestamp)) {
          continue;
        }
        const occurredAt = webhookTimestamp(message.timestamp);
        const eventId = `inbound:${message.id}`;
        const event = {
          providerMessageId: message.id,
          from: message.from,
          type: message.type,
          timestamp: message.timestamp,
        };
        await persistWebhookEvent({
          ownerUserId,
          workspaceId,
          eventId,
          providerMessageId: message.id,
          eventType: `inbound:${String(message.type || 'unknown').slice(0, 60)}`,
          payloadHash: createHash('sha256')
            .update(JSON.stringify(event))
            .digest('hex'),
          occurredAt,
          operation: (client) => saveInboundMessage({
            client,
            ownerUserId,
            workspaceId,
            providerMessageId: message.id,
            from: message.from,
            messageType: String(message.type || 'unknown').slice(0, 60),
            body: message.type === 'text' ? message.text?.body : null,
            occurredAt,
          }),
        });
      }
    }
  }
}

function createWhatsAppWebhookHandler({
  env = process.env,
  logger = console.error,
} = {}) {
  return async function whatsAppWebhookHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    if (req.method === 'GET') {
      const mode = req.query?.['hub.mode'];
      const token = req.query?.['hub.verify_token'];
      const challenge = req.query?.['hub.challenge'];
      if (mode === 'subscribe' &&
          typeof env.WHATSAPP_VERIFY_TOKEN === 'string' &&
          env.WHATSAPP_VERIFY_TOKEN.length > 0 &&
          token === env.WHATSAPP_VERIFY_TOKEN &&
          typeof challenge === 'string') {
        res.setHeader('Content-Type', 'text/plain');
        return res.status(200).send(challenge);
      }
      return res.status(403).json({ error: 'webhook_verification_failed' });
    }
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'GET, POST');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const rawBody = await readRawBody(req);
      if (!isValidSignature(
        rawBody,
        req.headers['x-hub-signature-256'],
        env.WHATSAPP_APP_SECRET,
      )) {
        return res.status(401).json({ error: 'invalid_webhook_signature' });
      }
      let payload;
      try {
        payload = JSON.parse(rawBody.toString('utf8'));
      } catch {
        throw new HttpError(400, 'invalid_whatsapp_webhook');
      }
      await processPayload(payload, env);
      return res.status(200).json({ received: true });
    } catch (error) {
      if (error instanceof HttpError) {
        return res.status(error.statusCode).json({ error: error.code });
      }
      logger('WhatsApp webhook processing failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'webhook_processing_failed' });
    }
  };
}

const handler = createWhatsAppWebhookHandler();
handler.config = { api: { bodyParser: false } };
Object.assign(handler, {
  createWhatsAppWebhookHandler,
  isValidSignature,
  processPayload,
});
module.exports = handler;
