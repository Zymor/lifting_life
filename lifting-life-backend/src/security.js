import crypto from 'node:crypto';

// Password Security (PBKDF2 with 100,000 iterations and sha256)
export function generateSalt() {
  return crypto.randomBytes(16).toString('hex');
}

export function hashPassword(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256').toString('hex');
}

export function verifyPassword(password, salt, hash) {
  const calculated = hashPassword(password, salt);
  return crypto.timingSafeEqual(Buffer.from(calculated, 'hex'), Buffer.from(hash, 'hex'));
}

export function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

export function generateSixDigitCode() {
  return crypto.randomInt(100000, 999999).toString();
}

export function generateBackupCodes(count = 8) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    const part1 = crypto.randomBytes(2).toString('hex').toUpperCase();
    const part2 = crypto.randomBytes(2).toString('hex').toUpperCase();
    codes.push(`${part1}-${part2}`);
  }
  return codes;
}

// Base32 for TOTP Secret (RFC 4648)
const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function generateTotpSecret(length = 20) {
  const bytes = crypto.randomBytes(length);
  let bits = 0;
  let value = 0;
  let output = '';
  for (let i = 0; i < bytes.length; i++) {
    value = (value << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      output += BASE32_CHARS[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    output += BASE32_CHARS[(value << (5 - bits)) & 31];
  }
  return output;
}

function base32ToBuffer(base32) {
  const clean = base32.replace(/[\s=-]/g, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (let i = 0; i < clean.length; i++) {
    const idx = BASE32_CHARS.indexOf(clean[i]);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

// RFC 6238 TOTP computation
export function computeTotp(secret, timeStep = 30, forTimeMs = Date.now()) {
  const key = base32ToBuffer(secret);
  const counter = Math.floor(forTimeMs / 1000 / timeStep);
  const buf = Buffer.alloc(8);
  buf.writeBigInt64BE(BigInt(counter));
  const hmac = crypto.createHmac('sha1', key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const codeInt =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  const str = (codeInt % 1000000).toString().padStart(6, '0');
  return str;
}

export function verifyTotp(secret, token, window = 1, timeStep = 30) {
  if (!token || token.length !== 6) return false;
  const now = Date.now();
  for (let error = -window; error <= window; error++) {
    const candidate = computeTotp(secret, timeStep, now + error * timeStep * 1000);
    if (candidate === token) return true;
  }
  return false;
}

// In-Memory Rate Limiting
const rateLimitMap = new Map();

export function clearRateLimit(key) {
  rateLimitMap.delete(key);
}

export function clearAllRateLimits() {
  rateLimitMap.clear();
}

export function checkRateLimit(key, maxRequests = 5, windowMs = 60000) {
  const isLocal = key.includes('127.0.0.1') || key.includes('::1') || key.includes('localhost') || key.includes('::ffff:127.0.0.1');
  const effectiveMax = isLocal ? Math.max(maxRequests, 100) : maxRequests;

  const now = Date.now();
  const record = rateLimitMap.get(key) || { count: 0, resetAt: now + windowMs };
  if (now > record.resetAt) {
    record.count = 1;
    record.resetAt = now + windowMs;
    rateLimitMap.set(key, record);
    return { allowed: true, remaining: effectiveMax - 1 };
  }
  record.count += 1;
  rateLimitMap.set(key, record);
  if (record.count > effectiveMax) {
    return { allowed: false, remaining: 0, retryAfterSeconds: Math.ceil((record.resetAt - now) / 1000) };
  }
  return { allowed: true, remaining: effectiveMax - record.count };
}

