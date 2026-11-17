const { withUserTransaction } = require('./database');

class RateLimitError extends Error {
  constructor(retryAfterSeconds) {
    super('Request rate limit exceeded.');
    this.name = 'RateLimitError';
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function respondToRateLimit(error, res) {
  if (!(error instanceof RateLimitError)) return false;
  res.setHeader('Retry-After', String(error.retryAfterSeconds));
  res.status(429).json({ error: 'rate_limit_exceeded' });
  return true;
}

async function enforceUserRateLimit(
  userId,
  scope,
  { limit, windowSeconds },
  withTransaction = withUserTransaction,
) {
  if (!Number.isSafeInteger(limit) || limit < 1 ||
      !Number.isSafeInteger(windowSeconds) || windowSeconds < 1 ||
      typeof scope !== 'string' || scope.length < 1 || scope.length > 80) {
    throw new TypeError('Invalid rate limit configuration.');
  }

  const result = await withTransaction(userId, async (client) => {
    await client.query(
      `DELETE FROM api_rate_limit_windows
       WHERE owner_user_id = $1
         AND window_started_at < clock_timestamp() - interval '1 day'`,
      [userId],
    );
    const bucket = await client.query(
      `WITH current_window AS (
         SELECT date_bin(
           make_interval(secs => $3::double precision),
           clock_timestamp(),
           'epoch'::timestamptz
         ) AS window_started_at
       )
       INSERT INTO api_rate_limit_windows
         (owner_user_id, scope, window_started_at, request_count)
       SELECT $1, $2, window_started_at, 1
       FROM current_window
       ON CONFLICT (owner_user_id, scope, window_started_at)
       DO UPDATE SET request_count =
         api_rate_limit_windows.request_count + 1
       RETURNING request_count,
         GREATEST(
           1,
           CEIL(EXTRACT(EPOCH FROM (
             window_started_at
             + make_interval(secs => $3::double precision)
             - clock_timestamp()
           )))::integer
         ) AS retry_after_seconds`,
      [userId, scope, windowSeconds],
    );
    return bucket.rows[0];
  });

  if (Number(result.request_count) > limit) {
    throw new RateLimitError(Number(result.retry_after_seconds));
  }
}

module.exports = {
  RateLimitError,
  enforceUserRateLimit,
  respondToRateLimit,
};
