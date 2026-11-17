const { randomUUID } = require('node:crypto');

function attachRequestId(res) {
  const requestId = randomUUID();
  res.setHeader('X-Request-Id', requestId);
  return requestId;
}

module.exports = { attachRequestId };
