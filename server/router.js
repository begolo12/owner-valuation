import { HttpError, json, num, oneOf, readBody, requireToken, str } from './http.js';
import { q } from './db.js';
import { MODELS, QUARTER_RE, WEIGHTS, computeScore, currentQuarter } from './score.js';

const PAYMENT_METHODS = ['cash', 'kpr', 'installment', 'other'];

const holdingOut = (r) => ({
  id: r.id,
  name: r.name,
  notes: r.notes,
  ownerCount: Number(r.owner_count ?? 0),
  createdAt: r.created_at,
});

const ownerOut = (r) => ({
  id: r.id,
  holdingId: r.holding_id,
  name: r.name,
  project: r.project,
  notes: r.notes,
  createdAt: r.created_at,
});

const assessmentOut = (r) => ({
  id: r.id,
  ownerId: r.owner_id,
  quarter: r.quarter,
  model: r.model,
  paymentMethod: r.payment_method,
  paymentTenor: r.payment_tenor,
  paidAmount: Number(r.paid_amount),
  projectionValue: Number(r.projection_value),
  projectionNotes: r.projection_notes,
  scores: {
    holding: Number(r.holding_score),
    payment: Number(r.payment_score),
    tenor: Number(r.tenor_score),
    projection: Number(r.projection_score),
  },
  total: Number(r.total_score),
  grade: r.grade,
  createdAt: r.created_at,
  updatedAt: r.updated_at,
});

function quarterParam(value) {
  const quarter = str(value, 'quarter', { optional: true }) ?? currentQuarter();
  if (!QUARTER_RE.test(quarter)) throw new HttpError(400, 'quarter harus format YYYY-Q1..Q4');
  return quarter;
}

async function findHolding(id) {
  const [row] = await q(
    'select id, name, notes, created_at from holdings where id = $1',
    [id],
  );
  if (!row) throw new HttpError(404, 'Holding tidak ditemukan');
  return row;
}

async function findOwner(id) {
  const [row] = await q(
    `select o.*, h.name as holding_name from owners o
       join holdings h on h.id = o.holding_id
      where o.id = $1`,
    [id],
  );
  if (!row) throw new HttpError(404, 'Owner/proyek tidak ditemukan');
  return row;
}

const routes = [
  ['GET', /^health$/, async () => ({ ok: true, now: new Date().toISOString() })],

  ['GET', /^meta$/, async () => ({
    models: MODELS,
    weights: WEIGHTS,
    paymentMethods: PAYMENT_METHODS,
    currentQuarter: currentQuarter(),
  })],

  // ---- holdings ----
  ['GET', /^holdings$/, async (req) => {
    const quarter = quarterParam(req.query.quarter);
    const rows = await q(
      `select h.id, h.name, h.notes, h.created_at,
              (select count(*) from owners o where o.holding_id = h.id) as owner_count
         from holdings h order by lower(h.name)`,
    );
    return { quarter, items: rows.map(holdingOut) };
  }],

  ['POST', /^holdings$/, async (req) => {
    const body = await readBody(req);
    const name = str(body.name, 'name', { max: 120 });
    const notes = str(body.notes, 'notes', { max: 2000, optional: true });
    const [row] = await q(
      `insert into holdings (name, notes) values ($1, $2)
       on conflict (lower(name)) do update set notes = coalesce(excluded.notes, holdings.notes)
       returning id, name, notes, created_at`,
      [name, notes],
    );
    return holdingOut(row);
  }],

  ['GET', /^holdings\/([0-9a-f-]{36})$/, async (req, id) => {
    const quarter = quarterParam(req.query.quarter);
    const holding = await findHolding(id);
    const owners = await q(
      `select id, holding_id, name, project, notes, created_at
         from owners where holding_id = $1 order by lower(name)`,
      [id],
    );
    const ids = owners.map((o) => o.id);
    const latest = ids.length
      ? await q(
          `select distinct on (owner_id, model)
                  owner_id, quarter, model, total_score, grade
             from assessments
            where owner_id = any($1::uuid[])
            order by owner_id, model, quarter desc`,
          [ids],
        )
      : [];
    const history = ids.length
      ? await q(
          `select owner_id, quarter, model, total_score, grade
             from assessments where owner_id = any($1::uuid[])
            order by quarter, model`,
          [ids],
        )
      : [];
    return {
      quarter,
      holding: holdingOut(holding),
      owners: owners.map((o) => ({
        ...ownerOut(o),
        latest: latest
          .filter((a) => a.owner_id === o.id)
          .map((a) => ({
            model: a.model,
            quarter: a.quarter,
            total: Number(a.total_score),
            grade: a.grade,
          })),
        history: history
          .filter((a) => a.owner_id === o.id)
          .map((a) => ({
            quarter: a.quarter,
            model: a.model,
            total: Number(a.total_score),
            grade: a.grade,
          })),
      })),
    };
  }],

  ['PATCH', /^holdings\/([0-9a-f-]{36})$/, async (req, id) => {
    await findHolding(id);
    const body = await readBody(req);
    const name = str(body.name, 'name', { max: 120, optional: true });
    const notes = str(body.notes, 'notes', { max: 2000, optional: true });
    const [row] = await q(
      `update holdings set name = coalesce($2, name), notes = coalesce($3, notes)
        where id = $1 returning id, name, notes, created_at`,
      [id, name, notes],
    );
    return holdingOut(row);
  }],

  ['DELETE', /^holdings\/([0-9a-f-]{36})$/, async (req, id) => {
    await findHolding(id);
    await q('delete from holdings where id = $1', [id]);
    return { deleted: id };
  }],

  // ---- owners / proyek ----
  ['POST', /^holdings\/([0-9a-f-]{36})\/owners$/, async (req, holdingId) => {
    await findHolding(holdingId);
    const body = await readBody(req);
    const name = str(body.name, 'name', { max: 120 });
    const project = str(body.project, 'project', { max: 160, optional: true });
    const notes = str(body.notes, 'notes', { max: 2000, optional: true });
    const [row] = await q(
      `insert into owners (holding_id, name, project, notes) values ($1, $2, $3, $4)
       returning id, holding_id, name, project, notes, created_at`,
      [holdingId, name, project, notes],
    );
    return ownerOut(row);
  }],

  ['GET', /^owners\/([0-9a-f-]{36})$/, async (req, id) => {
    const owner = await findOwner(id);
    const assessments = await q(
      'select * from assessments where owner_id = $1 order by quarter desc, model',
      [id],
    );
    return {
      owner: { ...ownerOut(owner), holdingName: owner.holding_name },
      assessments: assessments.map(assessmentOut),
    };
  }],

  ['PATCH', /^owners\/([0-9a-f-]{36})$/, async (req, id) => {
    await findOwner(id);
    const body = await readBody(req);
    const name = str(body.name, 'name', { max: 120, optional: true });
    const project = str(body.project, 'project', { max: 160, optional: true });
    const notes = str(body.notes, 'notes', { max: 2000, optional: true });
    const [row] = await q(
      `update owners set name = coalesce($2, name), project = coalesce($3, project),
              notes = coalesce($4, notes)
        where id = $1 returning id, holding_id, name, project, notes, created_at`,
      [id, name, project, notes],
    );
    return ownerOut(row);
  }],

  ['DELETE', /^owners\/([0-9a-f-]{36})$/, async (req, id) => {
    await findOwner(id);
    await q('delete from owners where id = $1', [id]);
    return { deleted: id };
  }],

  // ---- penilaian per kuartal ----
  ['PUT', /^owners\/([0-9a-f-]{36})\/assessments$/, async (req, ownerId) => {
    await findOwner(ownerId);
    const body = await readBody(req);
    const quarter = quarterParam(body.quarter);
    const model = oneOf(body.model, 'model', MODELS);
    const paymentMethod = oneOf(body.paymentMethod, 'paymentMethod', PAYMENT_METHODS);
    const paymentTenor = num(body.paymentTenor, 'paymentTenor', { min: 0, max: 600 });
    const paidAmount = num(body.paidAmount, 'paidAmount', { min: 0, optional: true, fallback: 0 });
    const projectionValue = num(body.projectionValue, 'projectionValue', {
      min: 0,
      optional: true,
      fallback: 0,
    });
    const projectionNotes = str(body.projectionNotes, 'projectionNotes', {
      max: 2000,
      optional: true,
    });
    const scores = body.scores ?? {};
    const holding = num(scores.holding, 'scores.holding', { min: 0, max: 100 });
    const payment = num(scores.payment, 'scores.payment', { min: 0, max: 100 });
    const tenor = num(scores.tenor, 'scores.tenor', { min: 0, max: 100 });
    const projection = num(scores.projection, 'scores.projection', { min: 0, max: 100 });

    const { total, grade } = computeScore(model, { holding, payment, tenor, projection });

    const [row] = await q(
      `insert into assessments (owner_id, quarter, model, payment_method, payment_tenor,
                                paid_amount, projection_value, projection_notes,
                                holding_score, payment_score, tenor_score, projection_score,
                                total_score, grade)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       on conflict (owner_id, quarter, model) do update set
         payment_method = excluded.payment_method,
         payment_tenor = excluded.payment_tenor,
         paid_amount = excluded.paid_amount,
         projection_value = excluded.projection_value,
         projection_notes = excluded.projection_notes,
         holding_score = excluded.holding_score,
         payment_score = excluded.payment_score,
         tenor_score = excluded.tenor_score,
         projection_score = excluded.projection_score,
         total_score = excluded.total_score,
         grade = excluded.grade
       returning *`,
      [
        ownerId, quarter, model, paymentMethod, paymentTenor,
        paidAmount, projectionValue, projectionNotes,
        holding, payment, tenor, projection, total, grade,
      ],
    );
    return assessmentOut(row);
  }],

  ['DELETE', /^owners\/([0-9a-f-]{36})\/assessments\/([0-9a-f-]{36})$/, async (req, ownerId, id) => {
    await findOwner(ownerId);
    const rows = await q('delete from assessments where id = $1 and owner_id = $2 returning id', [
      id,
      ownerId,
    ]);
    if (!rows.length) throw new HttpError(404, 'Penilaian tidak ditemukan');
    return { deleted: id };
  }],

  // ---- ringkasan ----
  ['GET', /^dashboard$/, async (req) => {
    const quarter = quarterParam(req.query.quarter);
    const [summary] = await q(
      `select
         (select count(*) from holdings) as holdings,
         (select count(*) from owners) as owners,
         (select count(*) from assessments where quarter = $1) as assessed,
         (select count(*) from owners o
            where not exists (select 1 from assessments a
                               where a.owner_id = o.id and a.quarter = $1)) as missing`,
      [quarter],
    );
    const byModel = await q(
      `select model, count(*)::int as count, round(avg(total_score), 2) as avg
         from assessments where quarter = $1 group by model order by model`,
      [quarter],
    );
    const trend = await q(
      `select quarter, model, count(*)::int as count, round(avg(total_score), 2) as avg
         from assessments group by quarter, model order by quarter desc, model limit 24`,
    );
    const top = await q(
      `select o.id, o.name, o.project, h.name as holding, a.model, a.total_score, a.grade
         from assessments a
         join owners o on o.id = a.owner_id
         join holdings h on h.id = o.holding_id
        where a.quarter = $1
        order by a.total_score desc, lower(o.name) limit 10`,
      [quarter],
    );
    return {
      quarter,
      totals: {
        holdings: Number(summary.holdings),
        owners: Number(summary.owners),
        assessed: Number(summary.assessed),
        missing: Number(summary.missing),
      },
      byModel: byModel.map((r) => ({ model: r.model, count: r.count, avg: Number(r.avg) })),
      trend: trend.map((r) => ({
        quarter: r.quarter,
        model: r.model,
        count: r.count,
        avg: Number(r.avg),
      })),
      top: top.map((r) => ({
        ownerId: r.id,
        name: r.name,
        project: r.project,
        holding: r.holding,
        model: r.model,
        total: Number(r.total_score),
        grade: r.grade,
      })),
    };
  }],
];

export default async function dispatch(req, res, path) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', 'content-type,x-app-token');
  res.setHeader('access-control-allow-methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }

  const url = new URL(req.url ?? '/', 'http://local');
  req.query = { ...req.query, ...Object.fromEntries(url.searchParams) };

  try {
    if (path !== 'health') requireToken(req);

    for (const [method, pattern, fn] of routes) {
      if (method !== req.method) continue;
      const match = path.match(pattern);
      if (!match) continue;
      const body = await fn(req, ...match.slice(1));
      return json(res, 200, body);
    }
    throw new HttpError(404, `Endpoint tidak ada: ${req.method} /api/${path}`);
  } catch (err) {
    const status = err instanceof HttpError ? err.status : 500;
    if (status === 500) console.error(err);
    return json(res, status, {
      error: status === 500 ? 'Terjadi kesalahan di server' : err.message,
    });
  }
}
