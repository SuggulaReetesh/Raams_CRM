const { getRuntimeEnvironment } = require('./_lib/config');
const { attachRequestId } = require('./_lib/request_id');

module.exports = function health(req, res) {
  attachRequestId(res);
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  return res.status(200).json({
    status: 'ok',
    environment: getRuntimeEnvironment(),
  });
};
