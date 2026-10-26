// Klien API. Token disimpan di perangkat, tidak pernah di-bundle.
// localStorage + cookie: sebagian browser (Safari/iOS, mode privat, in-app)
// membuang localStorage walau perangkatnya sama, cookie jadi cadangan.
const TOKEN_KEY = 'ov.token';
const TOKEN_COOKIE = 'ov_token';
const COOKIE_AGE = 34560000; // 400 hari, batas maksimum umur cookie di Chrome

// Akses localStorage bisa melempar (mode privat / kebijakan browser).
const store = {
  get(k) {
    try {
      return localStorage.getItem(k) || '';
    } catch {
      return '';
    }
  },
  set(k, v) {
    try {
      localStorage.setItem(k, v);
    } catch {
      /* cookie di bawah tetap menyimpan */
    }
  },
  del(k) {
    try {
      localStorage.removeItem(k);
    } catch {
      /* tidak ada yang bisa dibersihkan */
    }
  },
};

function readCookie(name) {
  const hit = document.cookie.split('; ').find((c) => c.startsWith(`${name}=`));
  return hit ? decodeURIComponent(hit.slice(name.length + 1)) : '';
}

export const token = () => store.get(TOKEN_KEY) || readCookie(TOKEN_COOKIE) || '';

export function saveToken(tok) {
  store.set(TOKEN_KEY, tok);
  const secure = location.protocol === 'https:' ? '; Secure' : '';
  document.cookie = `${TOKEN_COOKIE}=${encodeURIComponent(tok)}; path=/; max-age=${COOKIE_AGE}; SameSite=Lax${secure}`;
}

export function forgetToken() {
  store.del(TOKEN_KEY);
  document.cookie = `${TOKEN_COOKIE}=; path=/; max-age=0; SameSite=Lax`;
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function send(method, path, body) {
  const res = await fetch(`/api/${path}`, {
    method,
    headers: {
      'x-app-token': token(),
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      throw new ApiError(res.status, `Respons server bukan JSON (${res.status})`);
    }
  }
  if (!res.ok) throw new ApiError(res.status, data.error || `Gagal (${res.status})`);
  return data;
}

export const api = {
  meta: () => send('GET', 'meta'),
  dashboard: () => send('GET', 'dashboard'),
  holdings: () => send('GET', 'holdings'),
  holding: (id) => send('GET', `holdings/${id}`),
  createHolding: (name) => send('POST', 'holdings', { name }),
  deleteHolding: (id) => send('DELETE', `holdings/${id}`),
  createOwner: (holdingId, name, project) =>
    send('POST', `holdings/${holdingId}/owners`, { name, project }),
  owner: (id) => send('GET', `owners/${id}`),
  deleteOwner: (id) => send('DELETE', `owners/${id}`),
  saveAssessment: (ownerId, payload) => send('PUT', `owners/${ownerId}/assessments`, payload),
  deleteAssessment: (ownerId, aid) => send('DELETE', `owners/${ownerId}/assessments/${aid}`),
};
