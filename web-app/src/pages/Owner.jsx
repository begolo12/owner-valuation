import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from '../api.js';
import { AssessmentRow, Grade, Modal, Notice, Spinner } from '../components.jsx';
import {
  criteria,
  gradeOf,
  levelScore,
  modelLabels,
  paymentHints,
  paymentLabels,
  scoreLabels,
  tenorBands,
} from '../labels.js';
import { useEscape } from '../useEscape.js';

export default function Owner({ id, meta, go }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [assessing, setAssessing] = useState(false);

  const load = useCallback(async () => {
    try {
      setData(await api.owner(id));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const del = async (a) => {
    if (!window.confirm(`Hapus penilaian ${a.quarter} · ${modelLabels[a.model]}?`)) return;
    try {
      await api.deleteAssessment(id, a.id);
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  if (error && !data) {
    return (
      <div className="page">
        <Notice error>{error}</Notice>
        <div style={{ marginTop: 12 }}>
          <button onClick={() => go('/')}>← Dashboard</button>
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="page">
        <div className="empty"><Spinner /></div>
      </div>
    );
  }

  const { owner, assessments } = data;

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <button className="ghost" onClick={() => go(`/holding/${owner.holdingId}`)} style={{ marginBottom: 8 }}>
            ← {owner.holdingName || 'Holding'}
          </button>
          <h1>{owner.name}</h1>
          <p>{owner.project || 'Tanpa nama proyek'}</p>
        </div>
        <div className="spacer" />
        <button className="primary" onClick={() => setAssessing(true)}>
          Nilai
        </button>
      </div>

      {error && <Notice error>{error}</Notice>}

      {owner.latest.length > 0 && (
        <div className="grid-2" style={{ marginBottom: 12 }}>
          {owner.latest.map((l) => (
            <div className="card" key={l.model}>
              <div className="sub" style={{ margin: 0 }}>{modelLabels[l.model] || l.model}</div>
              <div className="row" style={{ marginTop: 4 }}>
                <strong style={{ fontSize: 22 }}>{l.total.toFixed(1)}</strong>
                <Grade grade={l.grade} compact />
                <span className="meta" style={{ marginLeft: 'auto' }}>{l.quarter}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="section">Riwayat penilaian</div>
      <p className="sub" style={{ marginTop: 0 }}>
        Satu nilai per model per kuartal. Menyimpan kuartal yang sama akan menimpa nilai lama.
      </p>

      {assessments.length === 0 ? (
        <div className="card empty">Belum ada penilaian. Tekan “Nilai” untuk mulai.</div>
      ) : (
        <div className="stack">
          {assessments.map((a) => (
            <AssessmentRow key={a.id} a={a} onDelete={() => del(a)} />
          ))}
        </div>
      )}

      {assessing && (
        <AssessDialog
          ownerId={id}
          meta={meta}
          existing={assessments}
          onClose={() => setAssessing(false)}
          onSaved={() => {
            setAssessing(false);
            load();
          }}
        />
      )}
    </div>
  );
}

function AssessDialog({ ownerId, meta, existing, onClose, onSaved }) {
  const [model, setModel] = useState(meta.models[0]);
  const [quarter, setQuarter] = useState(meta.currentQuarter);
  const [payment, setPayment] = useState(meta.paymentMethods[0]);
  const [tenor, setTenor] = useState(30);
  const [holdingLevel, setHoldingLevel] = useState('Developer mapan');
  const [projectionLevel, setProjectionLevel] = useState('Sesuai rencana');
  const [paidAmount, setPaidAmount] = useState('');
  const [projectionValue, setProjectionValue] = useState('');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  useEscape(onClose);

  // Kalau kuartal + model ini sudah ada, buka nilai lama untuk dikoreksi.
  useEffect(() => {
    const prev = existing.find((a) => a.model === model && a.quarter === quarter);
    if (!prev) return;
    setPayment(prev.paymentMethod);
    setTenor(prev.paymentTenor);
    setPaidAmount(prev.paidAmount ? String(prev.paidAmount) : '');
    setProjectionValue(prev.projectionValue ? String(prev.projectionValue) : '');
    setNotes(prev.projectionNotes || '');
    setHoldingLevel(nearestLevel('holding', prev.scores.holding));
    setProjectionLevel(nearestLevel('projection', prev.scores.projection));
  }, [model, quarter, existing]);

  const quarters = useMemo(() => {
    const [y0, q0] = meta.currentQuarter.split('-Q').map(Number);
    let y = y0;
    let q = q0;
    return Array.from({ length: 8 }, () => {
      const label = `${y}-Q${q}`;
      q -= 1;
      if (q === 0) {
        q = 4;
        y -= 1;
      }
      return label;
    });
  }, [meta.currentQuarter]);

  const scores = {
    holding: levelScore('holding', holdingLevel),
    payment: meta.paymentScores?.[payment] ?? 60,
    tenor: tenorBands.find((b) => tenor <= b.max)?.score ?? 25,
    projection: levelScore('projection', projectionLevel),
  };

  const weights = meta.weights[model];
  const total = Math.round(
    (scores.holding * weights.holding +
      scores.payment * weights.payment +
      scores.tenor * weights.tenor +
      scores.projection * weights.projection) *
      100,
  ) / 100;

  const save = async () => {
    setBusy(true);
    setErr(null);
    try {
      await api.saveAssessment(ownerId, {
        quarter,
        model,
        paymentMethod: payment,
        paymentTenor: tenor,
        paidAmount: Number(paidAmount) || 0,
        projectionValue: Number(projectionValue) || 0,
        projectionNotes: notes.trim() || null,
        scores: { holding: scores.holding, projection: scores.projection },
      });
      onSaved();
    } catch (e) {
      setErr(e.message);
      setBusy(false);
    }
  };

  return (
    <Modal
      title="Nilai owner"
      subtitle="Pilih kondisi yang paling mendekati. Skema bayar dan TOP menentukan skornya sendiri."
      onClose={onClose}
      actions={
        <>
          <button onClick={onClose}>Batal</button>
          <button className="primary" disabled={busy} onClick={save}>
            {busy ? 'Menyimpan…' : 'Simpan'}
          </button>
        </>
      }
    >
      {err && <Notice error>{err}</Notice>}

      <div className="grid-2">
        <div className="field">
          <label htmlFor="m">Model</label>
          <select id="m" value={model} onChange={(e) => setModel(e.target.value)}>
            {meta.models.map((m) => (
              <option key={m} value={m}>{modelLabels[m] || m}</option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="q">Kuartal</label>
          <select id="q" value={quarter} onChange={(e) => setQuarter(e.target.value)}>
            {quarters.map((q) => (
              <option key={q} value={q}>{q}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="section">Pembayaran</div>
      <div className="field">
        <label htmlFor="p">Skema bayar</label>
        <select id="p" value={payment} onChange={(e) => setPayment(e.target.value)}>
          {meta.paymentMethods.map((p) => (
            <option key={p} value={p}>{paymentLabels[p] || p}</option>
          ))}
        </select>
        <div className="help">
          {paymentHints[payment]} — skor {scores.payment}
        </div>
      </div>

      <div className="field">
        <label htmlFor="t">TOP — term of payment (hari)</label>
        <input
          id="t"
          type="number"
          min="0"
          max="365"
          value={tenor}
          onChange={(e) => setTenor(Number(e.target.value) || 0)}
        />
        <div className="help">
          Skor {scores.tenor} — {tenorBands.find((b) => tenor <= b.max)?.label}. Makin pendek makin baik.
        </div>
      </div>

      <div className="grid-2">
        <div className="field">
          <label htmlFor="paid">Nilai PO / kontrak (Rp, opsional)</label>
          <input
            id="paid"
            type="number"
            value={paidAmount}
            onChange={(e) => setPaidAmount(e.target.value)}
            placeholder="0"
          />
        </div>
        <div className="field">
          <label htmlFor="proj">Proyeksi order berikutnya (Rp, opsional)</label>
          <input
            id="proj"
            type="number"
            value={projectionValue}
            onChange={(e) => setProjectionValue(e.target.value)}
            placeholder="0"
          />
        </div>
      </div>

      {criteria.map((c) => (
        <div key={c.key}>
          <div className="section">{c.label}</div>
          <div className="help" style={{ marginBottom: 2 }}>{c.question}</div>
          {c.levels.map((l) => {
            const on = (c.key === 'holding' ? holdingLevel : projectionLevel) === l.label;
            return (
              <button
                key={l.label}
                className={`choice${on ? ' on' : ''}`}
                onClick={() =>
                  c.key === 'holding' ? setHoldingLevel(l.label) : setProjectionLevel(l.label)
                }
                type="button"
              >
                <span className="dot" />
                <span>
                  <span className="t">{l.label}</span>
                  <span className="d" style={{ display: 'block' }}>{l.hint}</span>
                </span>
                <span className="s">{l.score}</span>
              </button>
            );
          })}
        </div>
      ))}

      <div className="field">
        <label htmlFor="n">Catatan (opsional)</label>
        <input
          id="n"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="mis. pembayaran lewat SCF Bank Mandiri"
        />
      </div>

      <div className="total">
        <span className="label">Total</span>
        <span className="value">{total.toFixed(2)}</span>
        <Grade grade={gradeOf(total)} />
      </div>
      <div className="help">
        Bobot:{' '}
        {Object.entries(weights)
          .map(([k, v]) => `${scoreLabels[k] || k} ${Math.round(v * 100)}%`)
          .join(' · ')}
      </div>
    </Modal>
  );
}

function nearestLevel(key, score) {
  const levels = criteria.find((c) => c.key === key).levels;
  return levels.reduce((a, b) => (Math.abs(a.score - score) <= Math.abs(b.score - score) ? a : b)).label;
}
