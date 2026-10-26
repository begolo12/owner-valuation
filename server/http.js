export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.statusCode = status;
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.setHeader('cache-control', 'no-store');
  res.end(payload);
}

export async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1_000_000) throw new HttpError(413, 'Body terlalu besar');
    chunks.push(chunk);
  }
  if (!size) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new HttpError(400, 'Body bukan JSON valid');
  }
}

export function requireToken(req) {
  const expected = process.env.APP_TOKEN;
  if (!expected) throw new HttpError(500, 'APP_TOKEN belum diset di environment');
  const got = req.headers['x-app-token'];
  if (got !== expected) throw new HttpError(401, 'Token aplikasi salah');
}

export function str(value, field, { max = 200, optional = false } = {}) {
  if (value === undefined || value === null || value === '') {
    if (optional) return null;
    throw new HttpError(400, `${field} wajib diisi`);
  }
  if (typeof value !== 'string') throw new HttpError(400, `${field} harus teks`);
  const trimmed = value.trim();
  if (!trimmed && !optional) throw new HttpError(400, `${field} wajib diisi`);
  if (trimmed.length > max) throw new HttpError(400, `${field} maksimal ${max} karakter`);
  return trimmed || null;
}

export function num(value, field, { min = -Infinity, max = Infinity, optional = false, fallback } = {}) {
  if (value === undefined || value === null || value === '') {
    if (optional) return fallback ?? null;
    throw new HttpError(400, `${field} wajib diisi`);
  }
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) throw new HttpError(400, `${field} harus angka`);
  if (n < min || n > max) throw new HttpError(400, `${field} harus antara ${min} dan ${max}`);
  return n;
}

export function oneOf(value, field, allowed) {
  if (!allowed.includes(value)) {
    throw new HttpError(400, `${field} harus salah satu dari: ${allowed.join(', ')}`);
  }
  return value;
}
