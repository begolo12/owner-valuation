// Klien API. Token disimpan di localStorage, tidak pernah di-bundle.
const BASE_KEY = 'ov.baseUrl';
const TOKEN_KEY = 'ov.token';

export const baseUrl = () => localStorage.getItem(BASE_KEY) || '';
export const token = () => localStorage.getItem(TOKEN_KEY) || '';

export function saveConnection({ base, tok }) {
  if (base) localStorage.setItem(BASE_KEY, base.replace(/\/+$/, ''));
  if (tok) localStorage.setItem(TOKEN_KEY, tok);
}

export function forgetToken() {
  localStorage.removeItem(TOKEN_KEY);
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
