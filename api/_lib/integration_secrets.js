const {
  createCipheriv,
  createDecipheriv,
  randomBytes,
} = require('node:crypto');

class IntegrationSecretError extends Error {
  constructor(message) {
    super(message);
    this.name = 'IntegrationSecretError';
  }
}

function getEncryptionKey(env = process.env) {
  const encoded = env.INTEGRATION_ENCRYPTION_KEY;
  if (typeof encoded !== 'string' || encoded.length === 0) {
    throw new IntegrationSecretError(
      'INTEGRATION_ENCRYPTION_KEY is not configured.',
    );
  }
  const key = Buffer.from(encoded, 'base64');
  if (key.length !== 32 || key.toString('base64') !== encoded) {
    throw new IntegrationSecretError(
      'INTEGRATION_ENCRYPTION_KEY must be a base64-encoded 32-byte key.',
    );
  }
  return key;
}

function encryptSecrets(value, context, env = process.env) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', getEncryptionKey(env), iv);
  cipher.setAAD(Buffer.from(context, 'utf8'));
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(value), 'utf8'),
    cipher.final(),
  ]);
  return { ciphertext, iv, authTag: cipher.getAuthTag() };
}

function decryptSecrets(record, context, env = process.env) {
  try {
    const decipher = createDecipheriv(
      'aes-256-gcm',
      getEncryptionKey(env),
      record.secret_iv,
    );
    decipher.setAAD(Buffer.from(context, 'utf8'));
    decipher.setAuthTag(record.secret_auth_tag);
    const plaintext = Buffer.concat([
      decipher.update(record.secret_ciphertext),
      decipher.final(),
    ]).toString('utf8');
    const value = JSON.parse(plaintext);
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('Invalid secret payload.');
    }
    return value;
  } catch (error) {
    if (error instanceof IntegrationSecretError) throw error;
    throw new IntegrationSecretError(
      'The stored integration credentials could not be decrypted.',
    );
  }
}

module.exports = {
  IntegrationSecretError,
  decryptSecrets,
  encryptSecrets,
};
